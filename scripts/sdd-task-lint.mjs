#!/usr/bin/env node
// sdd-task-lint.mjs — parse, lint and query task/TASK-FASE-*.md (sdd-pipeline). Node >= 18, no dependencies.
//
// Usage (paths are relative to --repo when given, else to the current directory):
//   node sdd-task-lint.mjs lint   [--dir task] [--fase N] [--json] [file.md ...]
//       V-19 task-line grammar (also flags `### TASK-` headings, `**TASK-…**` bold ids and unindented field lines),
//       V-09 id format + uniqueness, V-05/V-06 Commit/Acceptance present, V-16 `## Stream Ownership` vs tasks
//       (only when the table exists). Prints `file:line V-xx message` (warnings: `file:line V-xx warning: message`)
//       and a summary line; exit 1 on errors. Files whose title carries [RETROACTIVE] are skipped with a warning.
//   node sdd-task-lint.mjs json   [--dir task] [--fase N] [file.md ...]
//       Task list as JSON (id, fase, parallel, description, paths, checked, state, blocked, line, file, shape, phase,
//       stream, blockedBy, refs, revert). Legacy shapes (headings, bold ids) are parsed too.
//   node sdd-task-lint.mjs status [--dir task] [--fase N] [--repo DIR] [--rev HEAD] [--state checkbox|trailers]
//                                 [--json] [--require-done]
//       done = a `Task:` trailer in a commit reachable from --rev that is not reverted ("This reverts commit <sha>";
//       a revert of a revert restores it). Also the checkbox state, blocked (`[!]`) and divergences:
//       checked-without-trailer, trailer-without-checkbox. --state defaults to `task_state` of `## SDD Stack Profile`
//       in <repo>/CLAUDE.md, else checkbox; with `trailers` an unchecked box is expected and not a divergence.
//       --require-done exits 1 when a selected task is not done.
//   node sdd-task-lint.mjs index  [--dir task] [--fase N] [file.md ...]
//       Derived TASK-INDEX.md (Summary by FASE, flat task list, traceability matrix from Refs) to stdout.
// Exit codes: 0 ok · 1 lint errors or --require-done unmet · 2 usage error, no task files, git failure.
//
// Task line grammar (V-19), one line per task, continuation lines indented two spaces:
//   ^- \[( |x|!)\] TASK-F\d+-\d{3,4}( \[P\])? .+ \| `[^`]+`(, `[^`]+`)*$
import { readFileSync, readdirSync, existsSync, statSync } from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

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

// ------------------------------------------------------------------ args
function parseArgs(argv) {
  const o = { cmd: argv[0], files: [], json: false, requireDone: false };
  for (let i = 1; i < argv.length; i++) {
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
      case "--json": o.json = true; break;
      case "--require-done": o.requireDone = true; break;
      case "-h": case "--help": help(0); break;
      default:
        if (a.startsWith("-")) usage(`unknown option ${a}`);
        o.files.push(a);
    }
  }
  if (o.fase !== undefined && !Number.isInteger(o.fase)) usage("--fase needs a number");
  if (o.state && !["checkbox", "trailers"].includes(o.state)) usage("--state must be checkbox or trailers");
  return o;
}
function help(code) {
  const lines = readFileSync(new URL(import.meta.url), "utf8").split("\n").slice(1);
  const head = lines.slice(0, lines.findIndex((l) => !l.startsWith("//")));
  console.log(head.map((l) => l.replace(/^\/\/ ?/, "")).join("\n"));
  process.exit(code);
}
function usage(msg) { console.error(`sdd-task-lint: ${msg} (see --help)`); process.exit(2); }
function die(msg) { console.error(`sdd-task-lint: ${msg}`); process.exit(2); }

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

// ------------------------------------------------------------------ parser
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
    const out = [];
    for (let k = Number(a); k <= Number(b) && out.length < 10000; k++) out.push(`TASK-F${f}-${String(k).padStart(a.length, "0")}`);
    return out.join(", ");
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

// ------------------------------------------------------------------ git / status
function stackProfile(repo) {
  const f = path.join(repo, "CLAUDE.md");
  if (!existsSync(f)) return {};
  const prof = {};
  let inside = false;
  for (const l of readFileSync(f, "utf8").split(/\r?\n/)) {
    if (/^#{1,2}\s/.test(l)) { inside = /^##\s+SDD Stack Profile\s*$/i.test(l); continue; }
    const m = inside && l.match(/^\s*[-*]\s+([a-z_]+):\s*(.*?)\s*$/);
    if (m) prof[m[1]] = m[2].replace(/^`(.*)`$/, "$1");
  }
  return prof;
}
function git(repo, args) {
  return spawnSync("git", ["-C", repo, ...args], { encoding: "utf8", maxBuffer: 512 * 1024 * 1024 });
}
function commits(repo, rev) {
  const inside = git(repo, ["rev-parse", "--is-inside-work-tree"]);
  if (inside.status !== 0) die(`not a git repository: ${display(repo)}`);
  if (git(repo, ["rev-parse", "--verify", "-q", `${rev}^{commit}`]).status !== 0) {
    if (rev === "HEAD") return [];
    die(`unknown revision: ${rev}`);
  }
  const r = git(repo, ["log", rev, "--format=%x1e%H%x1f%(trailers:key=Task,valueonly)%x1f%s%x1f%b"]);
  if (r.status !== 0) die(`git log failed: ${r.stderr.trim()}`);
  return r.stdout.split("\x1e").slice(1).map((rec) => {
    const [sha, trailers = "", subject = "", body = ""] = rec.split("\x1f");
    return { sha, subject, tasks: [...new Set(trailers.match(/TASK-F\d+-\d+/g) || [])],
      reverts: [...body.matchAll(/This reverts commit ([0-9a-f]{7,40})/g)].map((m) => m[1]) };
  });
}
function effectiveCommits(list) {
  const bySha = new Map(list.map((c) => [c.sha, c]));
  const revertedBy = new Map();
  for (const c of list) for (const target of c.reverts) {
    const full = bySha.has(target) ? target : list.find((x) => x.sha.startsWith(target))?.sha;
    if (!full) continue;
    if (!revertedBy.has(full)) revertedBy.set(full, []);
    revertedBy.get(full).push(c);
  }
  const memo = new Map();
  const effective = (c) => {
    if (memo.has(c.sha)) return memo.get(c.sha);
    memo.set(c.sha, true);
    const v = !(revertedBy.get(c.sha) || []).some(effective);
    memo.set(c.sha, v);
    return v;
  };
  return list.map((c) => ({ ...c, effective: effective(c) }));
}
function status(o, docs) {
  const repo = baseDir(o);
  const rev = o.rev || "HEAD";
  const profile = stackProfile(repo);
  const state = o.state || (["checkbox", "trailers"].includes(profile.task_state) ? profile.task_state : "checkbox");
  const list = effectiveCommits(commits(repo, rev));
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

// ------------------------------------------------------------------ index
function cellEscape(s) { return String(s).replace(/\|/g, "\\|").replace(/\s+/g, " ").trim(); }
function faseTitle(doc) {
  return doc.title.replace(/^Tasks?\s*[:—–-]?\s*/i, "").replace(/^TASK-FASE-\d+\s*[:—–-]?\s*/i, "")
    .replace(/^FASE-\d+\s*[:—–-]?\s*/i, "").replace(/\s*\[RETROACTIVE\]\s*/, "").trim() || "—";
}
function index(docs) {
  const tasks = docs.flatMap((d) => d.tasks);
  const fases = [...new Set(tasks.map((t) => t.fase))].sort((a, b) => a - b);
  const out = ["# Task Index", "",
    "> Derived view of `task/TASK-FASE-*.md`, generated by `scripts/sdd-task-lint.mjs index` — do not edit by hand.",
    `> **Total tasks:** ${tasks.length} · **FASEs covered:** ${fases.map((f) => `FASE-${f}`).join(", ") || "—"}`, "",
    "## Summary by FASE", "", "| FASE | Title | Tasks | Parallelizable | Checked |", "|------|-------|-------|----------------|---------|"];
  for (const f of fases) {
    const ts = tasks.filter((t) => t.fase === f);
    const doc = docs.find((d) => d.fase === f) || docs.find((d) => d.tasks.some((t) => t.fase === f));
    const p = ts.filter((t) => t.parallel).length;
    out.push(`| FASE-${f} | ${cellEscape(faseTitle(doc))} | ${ts.length} | ${p} (${ts.length ? Math.round((100 * p) / ts.length) : 0}%) | ${ts.filter((t) => /^[xX]$/.test(t.state)).length} |`);
  }
  out.push("", "## All Tasks (Flat List)", "", "| ID | FASE | Phase | Description | Parallel | Status |", "|----|------|-------|-------------|----------|--------|");
  for (const t of tasks) out.push(`| ${t.id} | ${t.fase} | ${cellEscape(t.phase || "—")} | ${cellEscape(t.description)} | ${t.parallel ? "[P]" : "-"} | [${/^[xX]$/.test(t.state) ? "x" : t.state}] |`);
  const matrix = new Map();
  for (const t of tasks) for (const r of t.refs) { if (!matrix.has(r)) matrix.set(r, []); matrix.get(r).push(t.id); }
  const natural = (a, b) => a.localeCompare(b, "en", { numeric: true });
  out.push("", "## Traceability Matrix", "", "| Spec | Tasks |", "|------|-------|");
  for (const r of [...matrix.keys()].sort(natural)) out.push(`| ${r} | ${matrix.get(r).join(", ")} |`);
  if (!matrix.size) out.push("| — | — |");
  return out.join("\n") + "\n";
}

// ------------------------------------------------------------------ main
const o = parseArgs(process.argv.slice(2));
if (!o.cmd || o.cmd === "-h" || o.cmd === "--help" || o.cmd === "help") help(o.cmd ? 0 : 2);
if (!["lint", "json", "status", "index"].includes(o.cmd)) usage(`unknown command ${o.cmd}`);
const docs = taskFiles(o).map(parseFile);

if (o.cmd === "lint") {
  const r = lint(docs);
  if (o.json) {
    console.log(JSON.stringify({ files: docs.map((d) => ({ file: d.display, fase: d.fase, tasks: d.tasks.length, skipped: d.retroactive })),
      tasks: r.count, errors: r.errors, warnings: r.warnings }, null, 2));
  } else {
    const all = [...r.errors.map((e) => ({ ...e, sev: "" })), ...r.warnings.map((w) => ({ ...w, sev: "warning: " }))]
      .sort((a, b) => a.file.localeCompare(b.file) || a.line - b.line);
    for (const e of all) console.log(`${e.file}:${e.line} ${e.check} ${e.sev}${e.message}`);
    console.log(`sdd-task-lint: ${docs.length} file(s), ${r.count} task(s), ${r.errors.length} error(s), ${r.warnings.length} warning(s)`);
  }
  process.exit(r.errors.length ? 1 : 0);
}
if (o.cmd === "json") {
  const streams = new Map(docs.map((d) => [d.display, streamOf(d)]));
  const tasks = docs.flatMap((d) => d.tasks).filter((t) => o.fase === undefined || t.fase === o.fase).map((t) => ({
    id: t.id, fase: t.fase, parallel: t.parallel, description: t.description, paths: t.paths,
    checked: /^[xX]$/.test(t.state), state: /^[xX]$/.test(t.state) ? "x" : t.state, blocked: t.state === "!",
    line: t.line, file: t.file, shape: t.shape, phase: t.phase, stream: streams.get(t.file).get(t.id) || null,
    blockedBy: t.blockedBy, refs: t.refs, revert: t.revert, retroactive: t.retroactive, planGap: t.planGap }));
  console.log(JSON.stringify({ files: docs.map((d) => ({ file: d.display, fase: d.fase, title: d.title, tasks: d.tasks.length,
    retroactive: d.retroactive, streamOwnership: Boolean(d.streams) })), count: tasks.length, tasks }, null, 2));
  process.exit(0);
}
if (o.cmd === "index") { process.stdout.write(index(docs)); process.exit(0); }
if (o.cmd === "status") {
  const s = status(o, docs);
  if (o.json) console.log(JSON.stringify(s, null, 2));
  else {
    for (const t of s.tasks) {
      const label = t.done ? "done" : t.blocked ? "blocked" : "pending";
      const extra = [t.commits.join(","), t.divergence, t.reverted.length ? `reverted: ${t.reverted.join(",")}` : ""].filter(Boolean).join("  ");
      console.log(`${t.id}  ${label.padEnd(7)}  [${t.checkbox}]  ${extra}`.trimEnd());
    }
    for (const u of s.unknownTrailers) console.log(`trailer ${u.id} (${u.commits.join(",")}) names no task in the task files`);
    const m = s.summary;
    console.log(`status: ${m.total} task(s) · ${m.done} done · ${m.pending} pending · ${m.blocked} blocked · ${m.divergences} divergence(s) (task_state: ${s.task_state}, rev ${s.rev})`);
  }
  process.exit(o.requireDone && s.summary.done < s.summary.total ? 1 : 0);
}
