// git-log.mjs — read SDD trailers (Task, Refs, Change) from git history (sdd-pipeline). Node >= 18, no dependencies.
// Library only: no console output and no process.exit; failures throw GitError.
//
//   readCommits(repo, { rev = "HEAD", paths = [], follow = false, files = false })
//       → [{ sha, parents, subject, body, tasks, refs, changes, ids, files, legacy, reverts }]
//   effectiveCommits(list)        → same list with `effective` (reverts subtracted; a revert of a revert restores)
//   commitsFor(list, id)          → commits whose Task/Refs/Change contain `id` as an exact token
//   parseMessage(text), checkMessage(message, trailers), trailersOf(message, cwd)  → used by `sdd verify`
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";

export class GitError extends Error {}

export const TASK_RE = /^TASK-F\d+-\d{3,4}$/;
export const REFS_RE = /^[A-Z][A-Z0-9]*(-[A-Z0-9]+)+$/;
export const CHANGE_RE = /^(CHG-\d{4}-\d{2}-\d{2}-\d{3}|CR-\d+|[A-Z]{2,5}-\d+)$/;
// CR-/CHG- ids that old commits packed into Refs are reported as `change` too.
const LEGACY_CHANGE_IN_REFS = /^(CHG-\d{4}-\d{2}-\d{2}-\d{3}|CR-\d+)$/;
const KEYS = ["Task", "Refs", "Change"];
const BODY_TRAILER_RE = /^(Task|Refs|Change)\s*:\s*(.*)$/i;

export function git(repo, args, input) {
  return spawnSync("git", ["-C", repo, "-c", "core.quotepath=off", ...args],
    { encoding: "utf8", maxBuffer: 512 * 1024 * 1024, input });
}
export function gitOk(repo, args, input) {
  const r = git(repo, args, input);
  if (r.error) throw new GitError(`git not available: ${r.error.message}`);
  if (r.status !== 0) throw new GitError(`git ${args[0]} failed: ${(r.stderr || "").trim()}`);
  return r.stdout;
}
export function isRepo(repo) {
  return existsSync(repo) && git(repo, ["rev-parse", "--is-inside-work-tree"]).status === 0;
}
export function topLevel(repo) {
  const r = git(repo, ["rev-parse", "--show-toplevel"]);
  return r.status === 0 ? r.stdout.trim() : path.resolve(repo);
}

/** Split a trailer value into tokens: "REQ-F-01, UC-001 CR-3" → ["REQ-F-01", "UC-001", "CR-3"]. */
export function tokens(value) {
  return String(value || "").split(/[\s,;]+/).map((t) => t.replace(/^[(\[]+|[.)\]]+$/g, "")).filter(Boolean);
}
const uniq = (a) => [...new Set(a)];

function classify(taskVal, refsVal, changeVal) {
  const tasks = uniq(tokens(taskVal).filter((t) => /^TASK-F\d+-\d+$/.test(t)));
  const refs = uniq(tokens(refsVal));
  const changes = uniq([...tokens(changeVal), ...refs.filter((t) => LEGACY_CHANGE_IN_REFS.test(t))]);
  return { tasks, refs, changes, ids: uniq([...tasks, ...refs, ...changes]) };
}

/** Body lines `Task:|Refs:|Change:` — the fallback for commits whose trailer block git does not parse. */
export function bodyTrailers(body) {
  const out = { Task: [], Refs: [], Change: [] };
  for (const l of String(body || "").split(/\r?\n/)) {
    const m = l.match(BODY_TRAILER_RE);
    if (m) out[KEYS.find((k) => k.toLowerCase() === m[1].toLowerCase())].push(m[2]);
  }
  return out;
}

/**
 * Commits reachable from `rev` (a revision or a range such as A..B), newest first.
 * An unborn HEAD yields []; an unknown revision throws.
 */
export function readCommits(repo, { rev = "HEAD", paths = [], follow = false, files = false } = {}) {
  if (!isRepo(repo)) throw new GitError(`not a git repository: ${repo}`);
  const isRange = /\.\.|\^!|\^@|\s/.test(rev);
  if (!isRange && git(repo, ["rev-parse", "--verify", "-q", `${rev}^{commit}`]).status !== 0) {
    if (rev === "HEAD") return [];
    throw new GitError(`unknown revision: ${rev}`);
  }
  const tr = (k) => `%(trailers:key=${k},valueonly,separator=%x2C)`;
  const fmt = `--format=%x1e%H%x1f%P%x1f${tr("Task")}%x1f${tr("Refs")}%x1f${tr("Change")}%x1f%s%x1f%b%x1f`;
  const args = ["log", fmt];
  if (files) args.push("--name-only");
  if (follow && paths.length === 1) args.push("--follow");
  args.push(...rev.split(/\s+/).filter(Boolean));
  if (paths.length) args.push("--", ...paths);
  const out = gitOk(repo, args);
  return out.split("\x1e").slice(1).map((rec) => {
    const [sha, parents = "", t = "", r = "", c = "", subject = "", body = "", tail = ""] = rec.split("\x1f");
    let cls = classify(t, r, c), legacy = false;
    if (!cls.ids.length) {
      const bt = bodyTrailers(body);
      if (bt.Task.length || bt.Refs.length || bt.Change.length) {
        cls = classify(bt.Task.join(","), bt.Refs.join(","), bt.Change.join(","));
        legacy = cls.ids.length > 0;
      }
    }
    return {
      sha, parents: parents.split(" ").filter(Boolean), subject, body: body.replace(/\n+$/, ""), ...cls, legacy,
      files: files ? tail.split("\n").map((s) => s.trim()).filter(Boolean) : [],
      reverts: [...body.matchAll(/This reverts commit ([0-9a-f]{7,40})/g)].map((m) => m[1]),
    };
  });
}

/** Marks each commit `effective` unless an effective commit reverts it (a revert of a revert restores). */
export function effectiveCommits(list) {
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

/** Commits naming `id` exactly (REQ-F-01 never matches REQ-F-012). */
export function commitsFor(list, id) {
  return list.filter((c) => c.ids.includes(id));
}

/** Resolve the ids of a revert-of-revert (which carries no trailers) back to the original commit. */
export function originIds(repo, commit, depth = 0) {
  if (commit.ids.length || !commit.reverts.length || depth > 4) return commit;
  const inner = readCommits(repo, { rev: `${commit.reverts[0]}^!` })[0];
  if (!inner || !inner.reverts.length) return commit;
  const orig = readCommits(repo, { rev: `${inner.reverts[0]}^!` })[0];
  if (!orig) return commit;
  const o = originIds(repo, orig, depth + 1);
  return { ...commit, tasks: o.tasks, refs: o.refs, changes: o.changes, ids: o.ids, legacy: o.legacy, restores: o.sha };
}

// ------------------------------------------------------------------ commit message validation (sdd verify)
export const TYPES = ["feat", "fix", "docs", "style", "refactor", "perf", "test", "build", "ci", "chore", "revert"];
const SUBJECT_RE = /^([a-z]+)(?:\(([^()]*)\))?(!)?: \S/;
const SCISSORS = /^# -+ >8 -+$/;

/** Strip comment lines and everything after the scissors line, as git does before committing. */
export function parseMessage(text) {
  const lines = String(text).replace(/\r\n/g, "\n").split("\n");
  const kept = [];
  for (let i = 0; i < lines.length; i++) {
    if (SCISSORS.test(lines[i])) break;
    if (lines[i].startsWith("#")) continue;
    kept.push({ n: i + 1, text: lines[i] });
  }
  while (kept.length && !kept[0].text.trim()) kept.shift();
  while (kept.length && !kept[kept.length - 1].text.trim()) kept.pop();
  return { lines: kept, message: kept.map((l) => l.text).join("\n") + (kept.length ? "\n" : "") };
}

/** Trailers exactly as git parses them: [{ key, value }]. */
export function trailersOf(message, cwd = ".") {
  const r = spawnSync("git", ["interpret-trailers", "--parse"], { cwd, input: message, encoding: "utf8" });
  if (r.error) throw new GitError(`git not available: ${r.error.message}`);
  if (r.status !== 0) throw new GitError(`git interpret-trailers failed: ${(r.stderr || "").trim()}`);
  return parseTrailerLines(r.stdout);
}
export function parseTrailerLines(text) {
  return String(text).split("\n").map((l) => l.match(/^([^:\s][^:]*?)\s*:\s?(.*)$/)).filter(Boolean)
    .map((m) => ({ key: m[1], value: m[2].trim() }));
}

/**
 * Validate one commit message against the SDD vocabulary.
 * `lines` = [{n, text}] from parseMessage; `trailers` = parsed trailers.
 * → { subject, type, scope, exempt, trailers: {Task, Refs, Change}, errors, warnings }
 */
export function checkMessage(lines, trailers) {
  const errors = [], warnings = [];
  const subject = (lines[0] || { text: "" }).text;
  const all = lines.map((l) => l.text).join("\n");
  const res = { subject, type: null, scope: null, exempt: null, trailers: { Task: [], Refs: [], Change: [] }, errors, warnings };
  if (!subject.trim()) { errors.push("empty commit message"); return res; }
  if (/^Merge /.test(subject)) res.exempt = "merge";
  else if (/^Revert "/.test(subject)) res.exempt = "revert";
  else if (/^(fixup|squash|amend)! /.test(subject)) res.exempt = subject.split("!")[0];
  else if (/\[skip-sdd\]/.test(all)) res.exempt = "skip-sdd";

  for (const t of trailers) {
    const canon = KEYS.find((k) => k.toLowerCase() === t.key.toLowerCase());
    if (!canon) continue;
    if (t.key !== canon) warnings.push(`trailer key \`${t.key}\` should be written \`${canon}\``);
    res.trailers[canon].push(...tokens(t.value));
  }
  // Broken block: a Task/Refs/Change line in the body that git does not parse as a trailer.
  for (const l of lines.slice(1)) {
    const m = l.text.match(BODY_TRAILER_RE);
    if (!m) continue;
    const found = trailers.some((t) => t.key.toLowerCase() === m[1].toLowerCase() && t.value.startsWith(m[2].trim()));
    if (!found) errors.push(`line ${l.n}: \`${l.text.trim()}\` is outside the trailer block — git reads trailers only from the last paragraph, and only when every line in it is a trailer (no prose, \`Closes #N\` or blank line after it); write it with \`git commit --trailer\``);
  }
  if (res.exempt) return res;

  const m = subject.match(SUBJECT_RE);
  if (!m) { errors.push(`subject is not a conventional commit \`<type>(<scope>): <summary>\`: ${subject}`); return res; }
  res.type = m[1]; res.scope = m[2] ?? null;
  if (!TYPES.includes(res.type)) { errors.push(`unknown commit type \`${res.type}\` (use ${TYPES.join(", ")})`); return res; }
  if (res.type === "revert") { res.exempt = "revert"; return res; }

  const { Task, Refs, Change } = res.trailers;
  for (const t of Task) if (!TASK_RE.test(t)) errors.push(`Task \`${t}\` does not match TASK-F<N>-<NNN>`);
  if (Task.length > 1) warnings.push(`${Task.length} Task ids in one commit (1 task = 1 commit)`);
  for (const t of Refs) if (!REFS_RE.test(t)) errors.push(`Refs \`${t}\` is not a spec id (e.g. REQ-F-001, UC-003)`);
  for (const t of Change) if (!CHANGE_RE.test(t)) errors.push(`Change \`${t}\` does not match CHG-YYYY-MM-DD-NNN, CR-N or a finding id (e.g. SEC-12)`);
  if (["feat", "test", "refactor"].includes(res.type) && !Task.length) errors.push(`\`${res.type}\` needs a \`Task:\` trailer`);
  if (["fix", "perf"].includes(res.type) && !Task.length && !Change.length) errors.push(`\`${res.type}\` needs a \`Task:\` or \`Change:\` trailer`);
  if (res.type === "docs" && res.scope === "specs" && !Refs.length) errors.push("`docs(specs)` needs a `Refs:` trailer");
  return res;
}

// ------------------------------------------------------------------ SDD Stack Profile
/** Files that may hold the `## SDD Stack Profile` section, in the order they are read (same as `sdd_profile_get` of
 *  hooks/lib/sdd-common.sh): the first file that has the section is the profile; later files are not read. */
export const PROFILE_FILES = ["CLAUDE.md", ".claude/CLAUDE.md"];

/**
 * The `## SDD Stack Profile` section of one CLAUDE.md text → { found, profile: { key: value }, lines: { key: { n, text } } }.
 * The section runs from its heading to the next `#`/`##` heading. Lines inside fenced code blocks (``` or ~~~, closed by
 * the same fence) are skipped, so an example `- literal_gate: off` inside a block does not count. A key repeated in
 * the section keeps its last value (what every CLI gate has always read; `sdd lint --floor` compares with the same
 * reading). Keys are lower-cased; a value wrapped in backticks is unwrapped.
 */
export function parseStackProfile(text) {
  const profile = {}, lines = {};
  let inside = false, found = false, fence = null;
  String(text ?? "").split(/\r?\n/).forEach((l, i) => {
    const f = l.match(/^\s*(`{3,}|~{3,})/);
    if (fence) { if (f && f[1][0] === fence[0] && f[1].length >= fence.length && !l.trim().slice(f[1].length).trim()) fence = null; return; }
    if (f) { fence = f[1]; return; }
    if (/^#{1,2}\s/.test(l)) {
      inside = /^##\s+SDD Stack Profile\s*$/i.test(l.trimEnd());
      if (inside) found = true;
      return;
    }
    const m = inside && l.match(/^\s*[-*]\s+([A-Za-z_]+)\s*:\s*(.*?)\s*$/);
    if (!m) return;
    const k = m[1].toLowerCase();
    profile[k] = m[2].replace(/^`(.*)`$/, "$1");
    lines[k] = { n: i + 1, text: l };
  });
  return { found, profile, lines };
}

/** Profile from the texts of PROFILE_FILES in order ([{ file, text }], text null when absent): the first with the
 *  section wins. → { file (or null), profile, lines }. */
export function profileFromTexts(list) {
  for (const { file, text } of list) {
    if (text === null || text === undefined) continue;
    const p = parseStackProfile(text);
    if (p.found) return { file, profile: p.profile, lines: p.lines };
  }
  return { file: null, profile: {}, lines: {} };
}

/** Stack Profile of <repo>/CLAUDE.md, else <repo>/.claude/CLAUDE.md, as { key: value }. */
export function stackProfile(repo) {
  return stackProfileWithSource(repo).profile;
}
/** Same, with the file that holds the section and the line of each key. */
export function stackProfileWithSource(repo) {
  return profileFromTexts(PROFILE_FILES.map((file) => {
    const f = path.join(repo, file);
    let text = null;
    try { if (existsSync(f)) text = readFileSync(f, "utf8"); } catch { text = null; }
    return { file, text };
  }));
}
