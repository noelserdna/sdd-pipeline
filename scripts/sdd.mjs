#!/usr/bin/env node
// sdd.mjs — the sdd-pipeline CLI: task files, git traceability, commit verification and branches. Node >= 18, no deps.
//
// Usage (paths are relative to --repo when given, else to the current directory; every command takes --repo DIR):
//   sdd lint [--dir task] [--fase N] [--json] [file.md ...]
//       Lint task/TASK-FASE-*.md: V-19 task-line grammar (also `### TASK-` headings, `**TASK-…**` bold ids, unindented
//       field lines), V-09 id format + uniqueness, V-05/V-06 Commit/Acceptance present, V-16 `## Stream Ownership`
//       vs tasks. Prints `file:line V-xx message` and a summary line; exit 1 on errors. [RETROACTIVE] files are skipped.
//   sdd tasks json   [--dir task] [--fase N] [file.md ...]      task list as JSON (legacy shapes parsed too)
//   sdd tasks status [--dir task] [--fase N] [--rev HEAD] [--state checkbox|trailers] [--json] [--require-done]
//       done = a `Task:` trailer in a non-reverted commit reachable from --rev; plus checkbox state, blocked `[!]` and
//       divergences. --state defaults to `task_state` of `## SDD Stack Profile` in CLAUDE.md, else checkbox.
//   sdd tasks index  [--dir task] [--fase N] [file.md ...]      derived TASK-INDEX.md to stdout
//   sdd trace commits [--rev R] [--files] [--json]             commits with their Task/Refs/Change ids (reverts marked)
//   sdd trace req <ID> [--rev R] [--json]                      commits whose Task/Refs/Change contain ID exactly
//   sdd trace why <file>[:line[-line]] [--json]                blame → commit → trailers → ids (whole file: all commits)
//   sdd trace delivered <ID> [--rev R] [--json]                commits for ID → tags and branches that contain them
//   sdd verify --message FILE|- [--json]                       validate one commit message (the commit-msg hook)
//   sdd verify --range A..B [--json]                           validate every commit in a range + squash detection
//   sdd branch status [--json]                                 current branch, default branch, detached, worktree
//   sdd branch start fase <N> <slug> [--issue N] [--json]      fase-{N}-{slug}
//   sdd branch start change <CHG-ID> <slug> [--issue N]        change/{CHG-ID}-{slug}
//   sdd branch start audit [YYYY-MM-DD] [--issue N]            audit/fix-{date}
//       On the default branch: `git switch -c <name>` (uncommitted changes carry over). On another branch: stay there.
//       Detached HEAD: exit 1. Default branch = Stack Profile default_branch → origin/HEAD → init.defaultBranch →
//       main/master. --issue N prefixes the name with `{N}-`.
// Commit vocabulary: references/git-conventions.md. Old entry point: scripts/sdd-task-lint.mjs (alias).
// Exit codes: 0 ok · 1 findings (lint errors, invalid messages, --require-done unmet, nothing traced) · 2 usage or git error.
//
// Task line grammar (V-19), one line per task, continuation lines indented two spaces:
//   ^- \[( |x|!)\] TASK-F\d+-\d{3,4}( \[P\])? .+ \| `[^`]+`(, `[^`]+`)*$
import { readFileSync, readdirSync, existsSync, statSync, realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  GitError, git, gitOk, isRepo, topLevel, readCommits, effectiveCommits, commitsFor, originIds,
  parseMessage, trailersOf, parseTrailerLines, checkMessage, stackProfile,
} from "./lib/git-log.mjs";

const GRAMMAR = /^- \[( |x|!)\] TASK-F\d+-\d{3,4}( \[P\])? .+ \| `[^`]+`(, `[^`]+`)*$/;
const ID_FORMAT = /^TASK-F\d+-\d{3,4}$/;
const LIST_RE = /^(\s*)[-*] \[([^\]])\]\s*(\*\*)?(TASK-F\d+-\d+)(\*\*)?(.*)$/;
const BOLD_NOCHECK_RE = /^(\s*)[-*]\s+\*\*(TASK-F\d+-\d+)\*\*(.*)$/;
const HEADING_TASK_RE = /^(#{1,6})\s+(?:\[([ xX!])\]\s*)?(?:✅\s*)?(\*\*)?(TASK-F\d+-\d+)(\*\*)?(.*)$/;
const FIELD_RE = /^(\s*)(?:[-*]\s+)?\*\*([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ -]*?)\s*:?\s*\*\*\s*:?\s*(.*)$/;
const PHASE_WORDS = /^(setup|foundation|domain|contracts?|slices?|integration|integraci[oó]n|tests?|verification|verificaci[oó]n)\b/i;
const SPEC_ID_RE = /\b(?:REQ|UC|WF|API|BDD|INV|ADR|RN|NFR|VO|ENT)-[A-Z0-9]+(?:-[A-Z0-9]+)*\b/g;
const FIELD_NAMES = { commit: "commit", acceptance: "acceptance", "aceptación": "acceptance", aceptacion: "acceptance",
  refs: "refs", revert: "revert", review: "review", files: "files" };

let PROG = "sdd";
let HELP_URL = import.meta.url;
class Exit extends Error { constructor(code) { super(`exit ${code}`); this.code = code; } }
const exit = (code) => { throw new Exit(code); };

// ------------------------------------------------------------------ args
function parseArgs(argv) {
  const o = { args: [], files: [], json: false, requireDone: false, withFiles: false };
  for (let i = 0; i < argv.length; i++) {
    let a = argv[i], v;
    const eq = a.match(/^(--[a-z-]+)=(.*)$/);
    if (eq) { a = eq[1]; v = eq[2]; }
    const take = () => { if (v !== undefined) return v; if (i + 1 >= argv.length) usage(`${a} needs a value`); return argv[++i]; };
    switch (a) {
      case "--dir": o.dir = take(); break;
      case "--fase": o.fase = Number(String(take()).replace(/^FASE-/i, "")); break;
      case "--repo": o.repo = take(); break;
      case "--rev": o.rev = take(); break;
      case "--state": o.state = take(); break;
      case "--message": o.message = take(); break;
      case "--range": o.range = take(); break;
      case "--issue": o.issue = take(); break;
      case "--json": o.json = true; break;
      case "--files": o.withFiles = true; break;
      case "--require-done": o.requireDone = true; break;
      case "-h": case "--help": help(0); break;
      case "-": o.args.push(a); break;
      default:
        if (a.startsWith("-")) usage(`unknown option ${a}`);
        o.args.push(a);
    }
  }
  if (o.fase !== undefined && !Number.isInteger(o.fase)) usage("--fase needs a number");
  if (o.state && !["checkbox", "trailers"].includes(o.state)) usage("--state must be checkbox or trailers");
  if (o.issue !== undefined && !/^\d+$/.test(o.issue)) usage("--issue needs a number");
  return o;
}
function help(code) {
  const lines = readFileSync(new URL(HELP_URL), "utf8").split("\n").slice(1);
  const head = lines.slice(0, lines.findIndex((l) => !l.startsWith("//")));
  console.log(head.map((l) => l.replace(/^\/\/ ?/, "")).join("\n"));
  exit(code);
}
function usage(msg) { console.error(`${PROG}: ${msg} (see --help)`); exit(2); }
function die(msg) { console.error(`${PROG}: ${msg}`); exit(2); }
const out = (s) => console.log(s);
const json = (v) => console.log(JSON.stringify(v, null, 2));

// ------------------------------------------------------------------ files
function baseDir(o) { return path.resolve(o.repo || "."); }
function display(abs) {
  const rel = path.relative(process.cwd(), abs);
  return rel && !rel.startsWith("..") && !path.isAbsolute(rel) ? rel : abs;
}
function faseOfName(file) { const m = path.basename(file).match(/TASK-FASE-(\d+)/); return m ? Number(m[1]) : null; }
function taskFiles(o) {
  const base = baseDir(o);
  let list;
  if (o.files.length) list = o.files.map((f) => path.resolve(base, f));
  else {
    const dir = path.resolve(base, o.dir || "task");
    if (!existsSync(dir)) die(`no task directory: ${display(dir)}`);
    if (statSync(dir).isFile()) list = [dir];
    else list = readdirSync(dir).filter((f) => /^TASK-FASE-\d+.*\.md$/.test(f)).map((f) => path.join(dir, f));
  }
  for (const f of list) if (!existsSync(f)) die(`no such file: ${display(f)}`);
  list.sort((a, b) => (faseOfName(a) ?? 1e9) - (faseOfName(b) ?? 1e9) || a.localeCompare(b));
  if (o.fase !== undefined) list = list.filter((f) => faseOfName(f) === null || faseOfName(f) === o.fase);
  if (!list.length) die(`no TASK-FASE-*.md files in ${display(path.resolve(base, o.dir || "task"))}`);
  return list;
}

// ------------------------------------------------------------------ task parser
function splitLinePaths(rest) {
  const m = rest.match(/^(.*?)\s+\|\s+((?:`[^`]+`\s*,?\s*)+)$/);
  if (m) return { description: m[1], paths: [...m[2].matchAll(/`([^`]+)`/g)].map((x) => x[1]) };
  const idx = rest.lastIndexOf(" | ");
  if (idx >= 0) {
    const tail = rest.slice(idx + 3);
    const ticks = [...tail.matchAll(/`([^`]+)`/g)].map((x) => x[1]);
    return { description: rest.slice(0, idx), paths: ticks.length ? ticks : tail.split(",").map((s) => s.trim()).filter(Boolean) };
  }
  return { description: rest, paths: [] };
}
function phaseName(text) {
  const t = text.replace(/^Phase\s+\d+\s*[:—–-]?\s*/i, "").replace(/\s*\(.*$/, "").trim();
  return /^Phase\s+\d+/i.test(text) || PHASE_WORDS.test(t) ? t : null;
}
function idFase(id) { return Number(id.match(/^TASK-F(\d+)-/)[1]); }

function parseFile(file) {
  const lines = readFileSync(file, "utf8").split(/\r?\n/);
  const titleLine = lines.find((l) => /^# /.test(l)) || "";
  const doc = {
    file, display: display(file), fase: faseOfName(file), title: titleLine.replace(/^#\s+/, "").trim(),
    retroactive: /\[RETROACTIVE\]/.test(titleLine), tasks: [], streams: null,
  };
  let fence = null, cur = null, phase = null, inStreams = false;
  const close = () => { if (cur) doc.tasks.push(cur); cur = null; };
  const start = (t) => { close(); cur = { ...t, phase, body: [] }; };
  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i], n = i + 1;
    const f = raw.match(/^\s*(```+|~~~+)/);
    if (fence || f) {
      if (!fence) fence = f[1]; else if (f && raw.trim().startsWith(fence)) fence = null;
      if (cur) cur.body.push({ n, raw, fenced: true });
      continue;
    }
    const h = raw.match(/^(#{1,6})\s+(.*)$/);
    const ht = raw.match(HEADING_TASK_RE);
    if (ht) {
      inStreams = false;
      let rest = ht[6].replace(/^\s*[:—–-]?\s*/, "");
      let state = ht[2] ? ht[2] : " ";
      const st = rest.match(/\[([ xX!])\]/);
      if (st) state = st[1];
      if (/✅/.test(rest)) state = "x";
      const parallel = /\[P\]/.test(rest);
      rest = rest.replace(/\s*[—–-]\s*(?:\[[ xX!]\]|✅)\s*\S*\s*$/, "").replace(/\[(?:P|RETROACTIVE)\]/g, "").replace(/\s+/g, " ").trim();
      const sp = splitLinePaths(rest);
      start({ id: ht[4], state, parallel, description: sp.description.replace(/[:\s]+$/, ""), linePaths: sp.paths,
        line: n, raw, shape: "heading", level: ht[1].length, indent: "" });
      continue;
    }
    if (h) {
      const level = h[1].length, text = h[2].trim();
      if (cur && (cur.shape !== "heading" || level <= cur.level)) close();
      inStreams = /^Stream Ownership\b/i.test(text);
      if (inStreams) doc.streams = { line: n, rows: [] };
      const ph = phaseName(text);
      if (level === 2) phase = ph; else if (ph && level === 3) phase = ph;
      if (cur) cur.body.push({ n, raw });
      continue;
    }
    const lm = raw.match(LIST_RE) || null;
    const bm = lm ? null : raw.match(BOLD_NOCHECK_RE);
    if (lm || bm) {
      inStreams = false;
      const id = lm ? lm[4] : bm[2];
      const bold = lm ? Boolean(lm[3] || lm[5]) : true;
      let rest = (lm ? lm[6] : bm[3]).replace(/^\*\*/, "").trim();
      const parallel = /^\[P\]/.test(rest) || /\s\[P\](\s|$)/.test(rest);
      rest = rest.replace(/^\[P\]\s*/, "").replace(/\s\[P\](?=\s|$)/g, "");
      const sp = splitLinePaths(rest);
      start({ id, state: lm ? lm[2] : " ", parallel, description: sp.description.trim(), linePaths: sp.paths, line: n, raw,
        shape: bold ? "bold" : "list", indent: (lm ? lm[1] : bm[1]) || "", checkbox: Boolean(lm) });
      continue;
    }
    if (inStreams && /^\s*\|/.test(raw)) {
      const cells = raw.trim().replace(/^\|/, "").replace(/\|$/, "").split("|").map((c) => c.trim());
      const isSep = cells.every((c) => /^:?-{2,}:?$/.test(c) || c === "");
      if (!isSep && !/^(tasks|tareas)$/i.test(cells[1] || "")) doc.streams.rows.push({ n, stream: cells[0].replace(/[`*]/g, "").trim(), cell: cells[1] || "" });
      continue;
    }
    if (cur) {
      if (cur.shape !== "heading" && (/^\s*\|/.test(raw) && !/^\s/.test(raw) || /^(-{3,}|\*{3,})\s*$/.test(raw))) { close(); continue; }
      cur.body.push({ n, raw });
    }
  }
  close();
  for (const t of doc.tasks) finishTask(t, doc);
  return doc;
}

function finishTask(t, doc) {
  t.fase = idFase(t.id);
  t.file = doc.display;
  t.retroactive = doc.retroactive || /\[RETROACTIVE\]/.test(t.raw);
  t.planGap = /\[PLAN GAP\]/.test(t.raw);
  t.fields = {};
  t.blockedBy = [];
  t.files = [];
  t.refs = [];
  t.unindentedFields = [];
  for (const b of t.body) {
    if (b.fenced) continue;
    const bb = b.raw.match(/^\s*[-*]\s+blocked-by:\s*(.*)$/i);
    if (bb) { t.blockedBy.push(...(bb[1].match(/TASK-F\d+-\d+/g) || [])); continue; }
    const fm = b.raw.match(FIELD_RE);
    if (!fm) continue;
    const name = FIELD_NAMES[fm[2].toLowerCase()];
    if (!name) continue;
    if (!t.fields[name]) t.fields[name] = { n: b.n, value: fm[3] };
    if (fm[1] === "") t.unindentedFields.push({ n: b.n, name });
    if (name === "files") t.files.push(...[...fm[3].matchAll(/`([^`]+)`/g)].map((x) => x[1]));
    if (name === "refs") t.refs.push(...(fm[3].match(SPEC_ID_RE) || []));
  }
  const rv = t.fields.revert?.value.match(/^`?(SAFE|COUPLED|MIGRATION|CONFIG|RETROACTIVE)\b/i);
  t.revert = rv ? rv[1].toUpperCase() : (t.fields.revert ? "OTHER" : null);
  t.paths = [...new Set([...t.linePaths, ...t.files])];
  t.refs = [...new Set(t.refs)];
}

// Stream Ownership table → Map(stream → ids[]) with ranges `TASK-F1-001 .. TASK-F1-013` / `TASK-F1-005 … 022`
function streamIds(cell) {
  const ids = [];
  const expanded = cell.replace(/TASK-F(\d+)-(\d+)\s*(?:\.\.\.?|…)\s*(?:TASK-F(\d+)-)?(\d+)/g, (all, f, a, f2, b) => {
    if (f2 && f2 !== f) return all;
    const o = [];
    for (let k = Number(a); k <= Number(b) && o.length < 10000; k++) o.push(`TASK-F${f}-${String(k).padStart(a.length, "0")}`);
    return o.join(", ");
  });
  for (const m of expanded.matchAll(/TASK-F\d+-\d+/g)) ids.push(m[0]);
  return ids;
}
function streamOf(doc) {
  const map = new Map();
  if (!doc.streams) return map;
  for (const r of doc.streams.rows) for (const id of streamIds(r.cell)) if (!map.has(id)) map.set(id, r.stream);
  return map;
}

// ------------------------------------------------------------------ lint
function lint(docs) {
  const errors = [], warnings = [];
  const err = (file, line, check, message) => errors.push({ file, line, check, message });
  const warn = (file, line, check, message) => warnings.push({ file, line, check, message });
  const seen = new Map();
  let count = 0;
  for (const doc of docs) {
    if (doc.retroactive) { warn(doc.display, 1, "V-19", "file marked [RETROACTIVE]: skipped"); continue; }
    if (!doc.tasks.length) warn(doc.display, 1, "V-19", "no task lines found");
    count += doc.tasks.length;
    for (const t of doc.tasks) {
      const where = [doc.display, t.line];
      const line = t.raw.replace(/\s+$/, "");
      if (!GRAMMAR.test(line)) {
        if (t.shape === "heading") err(...where, "V-19", `heading task \`${line.match(/^#+/)[0]} ${t.id}\` is forbidden: write \`- [ ] ${t.id} <Description> | \`<path>\`\``);
        else if (t.shape === "bold") err(...where, "V-19", `bold task id \`**${t.id}**\` is forbidden: write \`- [ ] ${t.id} <Description> | \`<path>\`\``);
        else if (t.indent) err(...where, "V-19", "task line must start at column 0");
        else if (!/^[ x!]$/.test(t.state)) err(...where, "V-19", `checkbox must be [ ], [x] or [!] (found [${t.state}])`);
        else if (t.planGap && !t.linePaths.length) warn(...where, "V-19", "[PLAN GAP] task without write-set path");
        else if (!/ \| `/.test(line)) err(...where, "V-19", "missing ` | `<path>`` write-set after the description");
        else err(...where, "V-19", "task line does not match the grammar `- [ ] TASK-F<N>-<SEQ> [P] <Description> | `<path>`[, `<path>`]*`");
      }
      if (t.shape !== "heading") for (const u of t.unindentedFields) err(doc.display, u.n, "V-19", `${t.id}: field line must be indented two spaces (\`  - **${u.name[0].toUpperCase() + u.name.slice(1)}:** …\`)`);
      if (!ID_FORMAT.test(t.id)) err(...where, "V-09", `${t.id}: id must be TASK-F<N>-<SEQ> with a 3-4 digit SEQ`);
      if (doc.fase !== null && t.fase !== doc.fase) err(...where, "V-09", `${t.id} belongs to FASE-${t.fase} but the file is TASK-FASE-${doc.fase}`);
      if (seen.has(t.id)) err(...where, "V-09", `duplicate id ${t.id} (first at ${seen.get(t.id)})`);
      else seen.set(t.id, `${doc.display}:${t.line}`);
      if (!t.fields.commit) err(...where, "V-05", `${t.id}: missing **Commit:**`);
      if (!t.fields.acceptance && !t.planGap) err(...where, "V-06", `${t.id}: missing **Acceptance:**`);
    }
    if (doc.streams) {
      const defined = new Set(doc.tasks.map((t) => t.id));
      const where = new Map();
      for (const r of doc.streams.rows) {
        for (const id of streamIds(r.cell)) {
          if (!defined.has(id)) { err(doc.display, r.n, "V-16", `unknown task ${id} in Stream ${r.stream}`); continue; }
          if (where.has(id) && where.get(id) !== r.stream) err(doc.display, r.n, "V-16", `${id} listed in Streams ${where.get(id)} and ${r.stream}`);
          else if (where.has(id)) err(doc.display, r.n, "V-16", `${id} listed twice in Stream ${r.stream}`);
          else where.set(id, r.stream);
        }
      }
      for (const t of doc.tasks) if (!where.has(t.id)) err(doc.display, t.line, "V-16", `${t.id} missing from ## Stream Ownership`);
    }
  }
  return { errors, warnings, count };
}

// ------------------------------------------------------------------ tasks status / index
function repoCommits(repo, rev, opts = {}) {
  if (!isRepo(repo)) die(`not a git repository: ${display(repo)}`);
  return effectiveCommits(readCommits(repo, { rev, ...opts }));
}
function status(o, docs) {
  const repo = baseDir(o);
  const rev = o.rev || "HEAD";
  const profile = stackProfile(repo);
  const state = o.state || (["checkbox", "trailers"].includes(profile.task_state) ? profile.task_state : "checkbox");
  const list = repoCommits(repo, rev);
  const done = new Map(), reverted = new Map();
  for (const c of list) for (const id of c.tasks) {
    const m = c.effective ? done : reverted;
    if (!m.has(id)) m.set(id, []);
    m.get(id).push(c.sha.slice(0, 7));
  }
  const all = docs.flatMap((d) => d.tasks);
  const known = new Set(all.map((t) => t.id));
  const tasks = all.filter((t) => o.fase === undefined || t.fase === o.fase).map((t) => {
    const isDone = done.has(t.id);
    const checkbox = /^[xX]$/.test(t.state) ? "x" : t.state === "!" ? "!" : " ";
    let divergence = null;
    if (checkbox === "x" && !isDone) divergence = "checked-without-trailer";
    else if (isDone && checkbox !== "x" && state === "checkbox") divergence = "trailer-without-checkbox";
    return { id: t.id, fase: t.fase, file: t.file, line: t.line, checkbox, done: isDone, blocked: !isDone && checkbox === "!",
      commits: done.get(t.id) || [], reverted: reverted.get(t.id) || [], divergence };
  });
  const unknownTrailers = [...done.entries()].filter(([id]) => !known.has(id)).map(([id, shas]) => ({ id, commits: shas }));
  const summary = { total: tasks.length, done: tasks.filter((t) => t.done).length, blocked: tasks.filter((t) => t.blocked).length,
    divergences: tasks.filter((t) => t.divergence).length };
  summary.pending = summary.total - summary.done - summary.blocked;
  return { repo: display(repo), rev, task_state: state, tasks, summary, unknownTrailers };
}

function cellEscape(s) { return String(s).replace(/\|/g, "\\|").replace(/\s+/g, " ").trim(); }
function faseTitle(doc) {
  return doc.title.replace(/^Tasks?\s*[:—–-]?\s*/i, "").replace(/^TASK-FASE-\d+\s*[:—–-]?\s*/i, "")
    .replace(/^FASE-\d+\s*[:—–-]?\s*/i, "").replace(/\s*\[RETROACTIVE\]\s*/, "").trim() || "—";
}
function index(docs) {
  const tasks = docs.flatMap((d) => d.tasks);
  const fases = [...new Set(tasks.map((t) => t.fase))].sort((a, b) => a - b);
  const o = ["# Task Index", "",
    "> Derived view of `task/TASK-FASE-*.md`, generated by `scripts/sdd.mjs tasks index` — do not edit by hand.",
    `> **Total tasks:** ${tasks.length} · **FASEs covered:** ${fases.map((f) => `FASE-${f}`).join(", ") || "—"}`, "",
    "## Summary by FASE", "", "| FASE | Title | Tasks | Parallelizable | Checked |", "|------|-------|-------|----------------|---------|"];
  for (const f of fases) {
    const ts = tasks.filter((t) => t.fase === f);
    const doc = docs.find((d) => d.fase === f) || docs.find((d) => d.tasks.some((t) => t.fase === f));
    const p = ts.filter((t) => t.parallel).length;
    o.push(`| FASE-${f} | ${cellEscape(faseTitle(doc))} | ${ts.length} | ${p} (${ts.length ? Math.round((100 * p) / ts.length) : 0}%) | ${ts.filter((t) => /^[xX]$/.test(t.state)).length} |`);
  }
  o.push("", "## All Tasks (Flat List)", "", "| ID | FASE | Phase | Description | Parallel | Status |", "|----|------|-------|-------------|----------|--------|");
  for (const t of tasks) o.push(`| ${t.id} | ${t.fase} | ${cellEscape(t.phase || "—")} | ${cellEscape(t.description)} | ${t.parallel ? "[P]" : "-"} | [${/^[xX]$/.test(t.state) ? "x" : t.state}] |`);
  const matrix = new Map();
  for (const t of tasks) for (const r of t.refs) { if (!matrix.has(r)) matrix.set(r, []); matrix.get(r).push(t.id); }
  const natural = (a, b) => a.localeCompare(b, "en", { numeric: true });
  o.push("", "## Traceability Matrix", "", "| Spec | Tasks |", "|------|-------|");
  for (const r of [...matrix.keys()].sort(natural)) o.push(`| ${r} | ${matrix.get(r).join(", ")} |`);
  if (!matrix.size) o.push("| — | — |");
  return o.join("\n") + "\n";
}

function cmdLint(o) {
  o.files = o.args;
  const docs = taskFiles(o).map(parseFile);
  const r = lint(docs);
  if (o.json) {
    json({ files: docs.map((d) => ({ file: d.display, fase: d.fase, tasks: d.tasks.length, skipped: d.retroactive })),
      tasks: r.count, errors: r.errors, warnings: r.warnings });
  } else {
    const all = [...r.errors.map((e) => ({ ...e, sev: "" })), ...r.warnings.map((w) => ({ ...w, sev: "warning: " }))]
      .sort((a, b) => a.file.localeCompare(b.file) || a.line - b.line);
    for (const e of all) out(`${e.file}:${e.line} ${e.check} ${e.sev}${e.message}`);
    out(`${PROG}: ${docs.length} file(s), ${r.count} task(s), ${r.errors.length} error(s), ${r.warnings.length} warning(s)`);
  }
  return r.errors.length ? 1 : 0;
}
function cmdTasks(o) {
  const sub = o.args.shift();
  if (sub === "lint") return cmdLint(o);
  if (!["json", "status", "index"].includes(sub)) usage(`unknown tasks command ${sub ?? "(none)"}: use json, status or index`);
  o.files = o.args;
  const docs = taskFiles(o).map(parseFile);
  if (sub === "json") {
    const streams = new Map(docs.map((d) => [d.display, streamOf(d)]));
    const tasks = docs.flatMap((d) => d.tasks).filter((t) => o.fase === undefined || t.fase === o.fase).map((t) => ({
      id: t.id, fase: t.fase, parallel: t.parallel, description: t.description, paths: t.paths,
      checked: /^[xX]$/.test(t.state), state: /^[xX]$/.test(t.state) ? "x" : t.state, blocked: t.state === "!",
      line: t.line, file: t.file, shape: t.shape, phase: t.phase, stream: streams.get(t.file).get(t.id) || null,
      blockedBy: t.blockedBy, refs: t.refs, revert: t.revert, retroactive: t.retroactive, planGap: t.planGap }));
    json({ files: docs.map((d) => ({ file: d.display, fase: d.fase, title: d.title, tasks: d.tasks.length,
      retroactive: d.retroactive, streamOwnership: Boolean(d.streams) })), count: tasks.length, tasks });
    return 0;
  }
  if (sub === "index") { process.stdout.write(index(docs)); return 0; }
  const s = status(o, docs);
  if (o.json) json(s);
  else {
    for (const t of s.tasks) {
      const label = t.done ? "done" : t.blocked ? "blocked" : "pending";
      const extra = [t.commits.join(","), t.divergence, t.reverted.length ? `reverted: ${t.reverted.join(",")}` : ""].filter(Boolean).join("  ");
      out(`${t.id}  ${label.padEnd(7)}  [${t.checkbox}]  ${extra}`.trimEnd());
    }
    for (const u of s.unknownTrailers) out(`trailer ${u.id} (${u.commits.join(",")}) names no task in the task files`);
    const m = s.summary;
    out(`status: ${m.total} task(s) · ${m.done} done · ${m.pending} pending · ${m.blocked} blocked · ${m.divergences} divergence(s) (task_state: ${s.task_state}, rev ${s.rev})`);
  }
  return o.requireDone && s.summary.done < s.summary.total ? 1 : 0;
}

// ------------------------------------------------------------------ trace
const short = (sha) => sha.slice(0, 7);
function commitJson(c, withFiles) {
  const j = { sha: c.sha, subject: c.subject, parents: c.parents, tasks: c.tasks, refs: c.refs, changes: c.changes,
    legacy: c.legacy, effective: c.effective, reverts: c.reverts };
  if (c.restores) j.restores = c.restores;
  if (withFiles) j.files = c.files;
  return j;
}
function commitLine(c, withFiles) {
  const ids = [...c.tasks, ...c.refs.filter((r) => !c.changes.includes(r)), ...c.changes].join(" ") || "-";
  const flags = [c.effective === false ? "[reverted]" : "", c.legacy ? "[legacy]" : ""].filter(Boolean).join(" ");
  let s = `${short(c.sha)}  ${ids}  ${c.subject}${flags ? "  " + flags : ""}`;
  if (withFiles && c.files.length) s += "\n" + c.files.map((f) => `    ${f}`).join("\n");
  return s;
}
function cmdTrace(o) {
  const sub = o.args.shift();
  const repo = baseDir(o);
  const rev = o.rev || "HEAD";
  if (sub === "commits") {
    const list = repoCommits(repo, rev, { files: o.withFiles });
    if (o.json) json({ rev, commits: list.map((c) => commitJson(c, o.withFiles)) });
    else { for (const c of list) out(commitLine(c, o.withFiles)); out(`trace: ${list.length} commit(s) from ${rev}`); }
    return 0;
  }
  if (sub === "req" || sub === "delivered") {
    const id = o.args[0];
    if (!id) usage(`trace ${sub} needs an ID`);
    const all = repoCommits(repo, rev);
    const hits = commitsFor(all, id);
    const eff = hits.filter((c) => c.effective);
    if (sub === "req") {
      if (o.json) json({ id, rev, commits: hits.map((c) => commitJson(c)), effective: eff.length, reverted: hits.length - eff.length });
      else { for (const c of hits) out(commitLine(c)); out(`trace req ${id}: ${eff.length} commit(s), ${hits.length - eff.length} reverted`); }
      return eff.length ? 0 : 1;
    }
    const first = eff[eff.length - 1], last = eff[0];
    const tagsOf = (c) => (c ? gitOk(repo, ["tag", "--contains", c.sha, "--sort=creatordate"]).split("\n").filter(Boolean) : []);
    const branchesOf = (c) => (c ? gitOk(repo, ["branch", "--format=%(refname:short)", "--contains", c.sha]).split("\n").filter(Boolean) : []);
    let deliveredIn = null;
    if (eff.length) {
      const sets = eff.map((c) => new Set(tagsOf(c)));
      deliveredIn = tagsOf(last).filter((t) => sets.every((s) => s.has(t)));
    }
    const r = { id, rev, commits: eff.length, reverted: hits.length - eff.length,
      first: first ? { sha: first.sha, subject: first.subject, tags: tagsOf(first), branches: branchesOf(first) } : null,
      last: last ? { sha: last.sha, subject: last.subject, tags: tagsOf(last), branches: branchesOf(last) } : null,
      delivered_in: deliveredIn || [] };
    if (o.json) json(r);
    else if (!eff.length) out(`trace delivered ${id}: no effective commit names ${id}`);
    else {
      out(`first  ${short(first.sha)}  ${first.subject}  tags: ${r.first.tags.join(", ") || "-"}  branches: ${r.first.branches.join(", ") || "-"}`);
      out(`last   ${short(last.sha)}  ${last.subject}  tags: ${r.last.tags.join(", ") || "-"}  branches: ${r.last.branches.join(", ") || "-"}`);
      out(r.delivered_in.length ? `trace delivered ${id}: in ${r.delivered_in.join(", ")} (earliest ${r.delivered_in[0]})`
        : `trace delivered ${id}: ${eff.length} commit(s), not in any tag yet`);
    }
    return r.delivered_in.length ? 0 : 1;
  }
  if (sub === "why") {
    const target = o.args[0];
    if (!target) usage("trace why needs <file>[:line]");
    if (!isRepo(repo)) die(`not a git repository: ${display(repo)}`);
    const m = target.match(/^(.*?):(\d+)(?:-(\d+))?$/);
    const file = m && !existsSync(path.resolve(repo, target)) ? m[1] : target;
    if (m && file === m[1]) {
      const from = Number(m[2]), to = Number(m[3] || m[2]);
      const r = git(repo, ["blame", "--porcelain", "-L", `${from},${to}`, "--", file]);
      if (r.status !== 0) die(`git blame failed: ${r.stderr.trim()}`);
      const lines = [];
      let curSha = null;
      for (const l of r.stdout.split("\n")) {
        const h = l.match(/^([0-9a-f]{40}) \d+ (\d+)/);
        if (h) { curSha = h[1]; lines.push({ line: Number(h[2]), sha: curSha }); }
      }
      const shas = [...new Set(lines.map((x) => x.sha))];
      const commits = shas.map((sha) => {
        if (/^0+$/.test(sha)) return { sha, subject: "(not committed yet)", tasks: [], refs: [], changes: [], ids: [], legacy: false, reverts: [], parents: [] };
        return originIds(repo, readCommits(repo, { rev: `${sha}^!` })[0]);
      });
      const bySha = new Map(commits.map((c) => [c.sha, c]));
      if (o.json) json({ file, from, to, lines: lines.map((x) => ({ line: x.line, sha: x.sha })), commits: commits.map((c) => commitJson(c)),
        ids: [...new Set(commits.flatMap((c) => c.ids))] });
      else for (const x of lines) out(`${file}:${x.line}  ${commitLine(bySha.get(x.sha))}`);
      return commits.some((c) => c.ids.length) ? 0 : 1;
    }
    const list = effectiveCommits(readCommits(repo, { rev, paths: [file], follow: true }));
    if (!list.length) die(`no commits touch ${file}`);
    const ids = [...new Set(list.filter((c) => c.effective).flatMap((c) => c.ids))];
    if (o.json) json({ file, commits: list.map((c) => commitJson(c)), ids });
    else { for (const c of list) out(commitLine(c)); out(`trace why ${file}: ${list.length} commit(s), ids: ${ids.join(" ") || "-"}`); }
    return ids.length ? 0 : 1;
  }
  usage(`unknown trace command ${sub ?? "(none)"}: use commits, req, why or delivered`);
}

// ------------------------------------------------------------------ verify
function codePaths(repo) {
  const prof = stackProfile(topLevel(repo));
  const list = (prof.code_paths || "").split(",").map((s) => s.trim().replace(/^\.\//, "").replace(/\/+$/, "")).filter(Boolean);
  return list.length ? list : ["src"];
}
function report(results, o, extra = {}) {
  const errors = results.reduce((n, r) => n + r.errors.length, 0) + (extra.rangeErrors || []).length;
  if (o.json) { json({ ok: errors === 0, results, ...extra }); return errors ? 1 : 0; }
  for (const r of results) {
    const where = r.sha ? short(r.sha) : r.source;
    for (const e of r.errors) out(`${where}: error: ${e}`);
    for (const w of r.warnings) out(`${where}: warning: ${w}`);
  }
  for (const e of extra.rangeErrors || []) out(`range: error: ${e}`);
  const warns = results.reduce((n, r) => n + r.warnings.length, 0);
  out(`verify: ${results.length} message(s), ${errors} error(s), ${warns} warning(s)`);
  return errors ? 1 : 0;
}
function cmdVerify(o) {
  if (!o.message === !o.range) usage("verify needs exactly one of --message FILE or --range A..B");
  const repo = baseDir(o);
  if (o.message) {
    let text;
    try { text = o.message === "-" ? readFileSync(0, "utf8") : readFileSync(path.resolve(o.message), "utf8"); }
    catch (e) { die(`cannot read ${o.message}: ${e.message}`); }
    const pm = parseMessage(text);
    const cwd = isRepo(repo) ? repo : process.cwd();
    const r = { source: o.message === "-" ? "stdin" : display(path.resolve(o.message)), ...checkMessage(pm.lines, pm.lines.length ? trailersOf(pm.message, cwd) : []) };
    return report([r], o);
  }
  if (!isRepo(repo)) die(`not a git repository: ${display(repo)}`);
  const fmt = "--format=%x1e%H%x1f%P%x1f%(trailers:only,unfold)%x1f%B%x1f";
  const raw = gitOk(repo, ["log", "--name-only", fmt, ...o.range.split(/\s+/).filter(Boolean)]);
  const code = codePaths(repo);
  const inCode = (f) => code.some((p) => f === p || f.startsWith(p + "/"));
  const results = [], perTask = {};
  let codeCommits = 0;
  for (const rec of raw.split("\x1e").slice(1)) {
    const [sha, parents = "", tr = "", body = "", tail = ""] = rec.split("\x1f");
    const lines = body.replace(/\n+$/, "").split("\n").map((text, i) => ({ n: i + 1, text }));
    const r = { sha, ...checkMessage(lines, parseTrailerLines(tr)) };
    const files = tail.split("\n").map((s) => s.trim()).filter(Boolean);
    r.code = parents.split(" ").filter(Boolean).length < 2 && files.some(inCode);
    if (r.code) codeCommits++;
    for (const t of r.trailers.Task) (perTask[t] ||= []).push(short(sha));
    results.push(r);
  }
  const rangeErrors = [];
  if (codeCommits && !Object.keys(perTask).length) {
    rangeErrors.push(`${o.range} has ${codeCommits} commit(s) touching code paths (${code.join(", ")}) but no Task: trailer — a squash or rebase merge drops the per-task commits; merge with a merge commit (git merge --no-ff) instead`);
  }
  return report(results, o, { range: o.range, code_paths: code, code_commits: codeCommits, per_task_commits: perTask, rangeErrors });
}

// ------------------------------------------------------------------ branch
function refExists(repo, ref) { return git(repo, ["show-ref", "--verify", "-q", ref]).status === 0; }
function defaultBranch(repo) {
  const prof = stackProfile(topLevel(repo));
  if (prof.default_branch) return { name: prof.default_branch, source: "profile" };
  const oh = git(repo, ["symbolic-ref", "--short", "-q", "refs/remotes/origin/HEAD"]);
  if (oh.status === 0 && oh.stdout.trim()) return { name: oh.stdout.trim().replace(/^origin\//, ""), source: "origin/HEAD" };
  const cfg = git(repo, ["config", "--get", "init.defaultBranch"]).stdout.trim();
  const unborn = git(repo, ["rev-parse", "-q", "--verify", "HEAD"]).status !== 0;
  const cur = git(repo, ["symbolic-ref", "--short", "-q", "HEAD"]).stdout.trim();
  if (cfg && (refExists(repo, `refs/heads/${cfg}`) || (unborn && cur === cfg))) return { name: cfg, source: "init.defaultBranch" };
  for (const b of ["main", "master"]) if (refExists(repo, `refs/heads/${b}`)) return { name: b, source: "existing" };
  if (unborn && cur) return { name: cur, source: "unborn HEAD" };
  return { name: null, source: null };
}
function branchInfo(repo) {
  const cur = git(repo, ["symbolic-ref", "--short", "-q", "HEAD"]);
  const current = cur.status === 0 ? cur.stdout.trim() : null;
  const def = defaultBranch(repo);
  const gd = path.resolve(repo, gitOk(repo, ["rev-parse", "--git-dir"]).trim());
  const cd = path.resolve(repo, gitOk(repo, ["rev-parse", "--git-common-dir"]).trim());
  return { current, detached: current === null, default: def.name, default_source: def.source,
    is_default: current !== null && current === def.name, linked_worktree: gd !== cd, top_level: topLevel(repo) };
}
function slugify(s) { return String(s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, ""); }
function cmdBranch(o) {
  const sub = o.args.shift();
  const repo = baseDir(o);
  if (!isRepo(repo)) die(`not a git repository: ${display(repo)}`);
  const info = branchInfo(repo);
  if (sub === "status") {
    if (o.json) json(info);
    else out(info.detached ? `branch: detached HEAD (default: ${info.default ?? "unknown"})`
      : `branch: ${info.current}${info.is_default ? " (default)" : ""} · default: ${info.default ?? "unknown"} (${info.default_source ?? "-"})${info.linked_worktree ? " · linked worktree" : ""}`);
    return 0;
  }
  if (sub !== "start") usage(`unknown branch command ${sub ?? "(none)"}: use status or start`);
  const [kind, id, slugArg] = o.args;
  let name;
  if (kind === "fase") {
    const n = String(id || "").replace(/^FASE-/i, "");
    if (!/^\d+$/.test(n)) usage("branch start fase needs <N> <slug>");
    const slug = slugify(slugArg); if (!slug) usage("branch start fase needs a slug");
    name = `fase-${Number(n)}-${slug}`;
  } else if (kind === "change") {
    if (!id || !/^[A-Za-z0-9][A-Za-z0-9-]*$/.test(id)) usage("branch start change needs <CHG-ID> <slug>");
    const slug = slugify(slugArg); if (!slug) usage("branch start change needs a slug");
    name = `change/${id}-${slug}`;
  } else if (kind === "audit") {
    const date = id || new Date().toISOString().slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) usage("branch start audit takes an optional YYYY-MM-DD");
    name = `audit/fix-${date}`;
  } else usage("branch start needs fase, change or audit");
  if (o.issue) name = `${o.issue}-${name}`;
  if (git(repo, ["check-ref-format", "--branch", name]).status !== 0) usage(`invalid branch name ${name}`);
  const result = (action, code, msg) => { if (o.json) json({ action, branch: action === "refused" ? null : (action === "stayed" ? info.current : name), wanted: name, ...info, message: msg }); else out(msg); return code; };
  if (info.detached) return result("refused", 1, `branch: HEAD is detached — switch to a branch first (git switch ${info.default ?? "<default>"}), then run again`);
  if (!info.default) die("cannot detect the default branch: set `default_branch` in the SDD Stack Profile of CLAUDE.md");
  if (!info.is_default) return result("stayed", 0, `branch: staying on work branch ${info.current} (default is ${info.default})`);
  if (refExists(repo, `refs/heads/${name}`)) {
    const dirty = git(repo, ["status", "--porcelain", "--untracked-files=no"]).stdout.trim();
    if (dirty) return result("refused", 1, `branch: ${name} already exists and tracked files have uncommitted changes — commit them or run git switch ${name} yourself`);
    gitOk(repo, ["switch", "-q", name]);
    return result("resumed", 0, `branch: switched to existing ${name}`);
  }
  gitOk(repo, ["switch", "-q", "-c", name]);
  return result("created", 0, `branch: created ${name} from ${info.current}`);
}

// ------------------------------------------------------------------ main
/** Run the CLI; returns the exit code. `legacy` = the sdd-task-lint.mjs command set (lint|json|status|index). */
export function run(argv, { prog = "sdd", helpUrl = import.meta.url, legacy = false } = {}) {
  PROG = prog; HELP_URL = helpUrl;
  try {
    const o = parseArgs(argv);
    const cmd = o.args.shift();
    if (!cmd || cmd === "help") help(cmd ? 0 : 2);
    if (legacy) {
      if (cmd === "lint") return cmdLint(o);
      if (["json", "status", "index"].includes(cmd)) { o.args.unshift(cmd); return cmdTasks(o); }
      usage(`unknown command ${cmd}`);
    }
    switch (cmd) {
      case "lint": return cmdLint(o);
      case "tasks": return cmdTasks(o);
      case "trace": return cmdTrace(o);
      case "verify": return cmdVerify(o);
      case "branch": return cmdBranch(o);
      default: usage(`unknown command ${cmd}`);
    }
  } catch (e) {
    if (e instanceof Exit) return e.code;
    if (e instanceof GitError) { console.error(`${PROG}: ${e.message}`); return 2; }
    throw e;
  }
}

const self = fileURLToPath(import.meta.url);
let invoked = "";
try { invoked = process.argv[1] ? realpathSync(process.argv[1]) : ""; } catch { invoked = ""; }
if (invoked === realpathSync(self)) process.exitCode = run(process.argv.slice(2));
