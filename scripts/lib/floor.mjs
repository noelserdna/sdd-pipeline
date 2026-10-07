// floor.mjs — `sdd lint --floor`: was the bar lowered between a base commit and the working tree? (sdd-pipeline 5.3)
// Node >= 18, no dependencies. Called from scripts/sdd.mjs; returns an exit code (never calls process.exit).
//
// Base (always printed with its source): --base REF (flag) · else `git merge-base HEAD <default branch>` (merge-base;
// the default branch resolves as in `sdd branch`, local ref first, then origin/<name>; skipped when HEAD is on the
// default branch itself) · else the nearest `fase-*-accepted` tag reachable from HEAD (tag) · else exit 2 "no base".
// The change set is the working tree against the base (`git diff -M <base>`) plus untracked files. Only added and
// removed lines count, and raising the bar (removing a skip, raising a gate) is never a finding.
//
// Findings
//   F-01  skip / only / focus / todo added in a test file (under the Stack Profile's test_paths). error when the test is
//         bound to a criterion (its name carries AC-NNN-NN or `REQ-X-NNN ACn`) or already existed in the base; a todo,
//         or a new unbound test, is a warning. Patterns: JS/TS `it|test|describe|context|suite|specify .skip/.only/.todo`,
//         `xit/xtest/xdescribe/xcontext`, `fit/fdescribe`, node:test `{ skip: … }` `{ only: … }` `{ todo: … }`,
//         `t.skip(` `t.todo(`; Python `@pytest.mark.skip|skipif|xfail`, `pytest.skip(`, `@unittest.skip…`; Ruby
//         `skip` / `pending` statements, `xit`, `fit`, `focus: true`. Comment lines are ignored.
//   F-02  test file deleted, or renamed (or moved out of test_paths) losing criterion ids it named in the base: error;
//         a deleted test file that named no criterion: warning.
//   F-04  coverage or security suppression added under code_paths + test_paths (`istanbul|c8|v8 ignore`,
//         `pragma: no cover`, `:nocov:`, `nosemgrep`, `gitleaks:allow`, `Stryker disable`): warning.
//   F-07  a gate of the SDD Stack Profile lowered against the base: literal_gate, acceptance_gate, adversarial_gate,
//         floor_gate (enforce > warn > off), visual_evidence (required > warn > off), prove_it (enforce > warn > off).
//         Only keys written in the base count (a missing key there is no finding); a key removed from the tree takes
//         its default. Error. Read with the CLI's parser (CLAUDE.md, else .claude/CLAUDE.md; fenced blocks skipped).
//
// Mode: Stack Profile `floor_gate: off|warn|enforce` (default enforce), read from the BASE (else the tree, else the
// default), so lowering it in the same change does not switch the check off — and is itself an F-07.
// Exit: 0 clean, only warnings, or mode warn/off · 1 an error not excepted under enforce · 2 no base, usage or git error.
//
// Human exception: `sdd accept record floor-exception --code F-0N --file PATH --line "exact line text" --base SHA
// --reason TEXT --by NAME --role ROLE` turns the finding with that code, file and line text (whitespace at both ends
// ignored) against that base commit into `excepted`. A changed line or another base brings the finding back. The
// record in acceptance/decisions.jsonl keeps { type: "floor-exception", code, file, text, base (full sha), reason, by,
// role, head, at } (`text` = the --line value).
//
// --json: { base: {sha, ref, source, detail}, head, mode, mode_source: base|default, test_paths, code_paths,
//   findings: [{code, severity: error|warn|excepted, file, line (number | null), text, message, kind?, criteria?,
//   scenarios?, key?, from?, to?, exception?}], testEdits: [{status: A|M|D|R, file, from?}], summary }.
// testEdits lists every test file (under test_paths) added, modified, deleted or renamed against the base, for the
// "test edits inside the loop" report.
import { existsSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import {
  git, isRepo, topLevel, refExists, defaultBranch, PROFILE_FILES, profileFromTexts, stackProfileWithSource,
} from "./git-log.mjs";
import { testKeys, loadScenarios, scenarioIndex, readDecisions, DECISIONS_FILE } from "./acceptance.mjs";
import { SOURCE_EXT } from "./quotes.mjs";

class Exit extends Error { constructor(code) { super(`exit ${code}`); this.code = code; } }
let PROG = "sdd";
const out = (s) => console.log(s);
const usage = (msg) => { console.error(`${PROG}: ${msg} (see --help)`); throw new Exit(2); };
const die = (msg) => { console.error(`${PROG}: lint --floor: ${msg}`); throw new Exit(2); };

export const FLOOR_MODES = ["off", "warn", "enforce"];
/** Gates F-07 compares, weakest first, and the value each tool takes when the key is absent or unknown. */
export const GATES = {
  literal_gate: { order: ["off", "warn", "enforce"], dflt: "enforce" },
  acceptance_gate: { order: ["off", "warn", "enforce"], dflt: "enforce" },
  adversarial_gate: { order: ["off", "warn", "enforce"], dflt: "enforce" },
  floor_gate: { order: ["off", "warn", "enforce"], dflt: "enforce" },
  visual_evidence: { order: ["off", "warn", "required"], dflt: "required" },
  prove_it: { order: ["off", "warn", "enforce"], dflt: "warn" },
};

// ------------------------------------------------------------------ patterns
const JS_SKIP = [
  { re: /\b(?:it|test|describe|context|suite|specify)(?:\.(?:concurrent|serial|each))*\.(skip|only|todo)\b/, kind: (m) => m[1] },
  { re: /(?<![\w$.])x(?:it|test|describe|context|specify)\s*\(/, kind: () => "skip" },
  { re: /(?<![\w$.])f(?:it|describe)\s*\(/, kind: () => "focus" },
  { re: /[{,]\s*(skip|only|todo)\s*:\s*(?!false\b|0\b|undefined\b|null\b)/, kind: (m) => m[1] },
  { re: /\bt\.(skip|todo)\s*\(/, kind: (m) => m[1] },
];
const PY_SKIP = [
  { re: /@pytest\.mark\.(skip|skipif|xfail)\b/, kind: () => "skip" },
  { re: /\bpytest\.skip\s*\(/, kind: () => "skip" },
  { re: /@unittest\.skip\w*/, kind: () => "skip" },
];
const RB_SKIP = [
  { re: /^\s*(?:skip|pending)\b(?!\s*[=:?!])/, kind: () => "skip" },
  { re: /^\s*x(?:it|describe|context|specify)\b/, kind: () => "skip" },
  { re: /^\s*f(?:it|describe|context)\b/, kind: () => "focus" },
  { re: /(?:\bfocus:\s*true\b|:focus\b)/, kind: () => "focus" },
];
const SUPPRESSIONS = /(?:\b(?:istanbul|c8|v8)\s+ignore\b|pragma:\s*no\s*cover|:nocov:|\bnosemgrep\b|gitleaks:allow|Stryker\s+disable)/i;

const JS_DECL = /^\s*(?:it|test|describe|context|suite|specify|xit|xtest|xdescribe|xcontext|fit|fdescribe)(?:\.\w+)*\s*\(/;
const RB_DECL = /^\s*(?:it|specify|scenario|describe|context|test|xit|fit|xdescribe|xcontext|fdescribe)\b\s*(?:\(|['"])/;
const PY_DECL = /^\s*(?:async\s+)?def\s+(test\w*)|^\s*class\s+(Test\w*)/;

const langOf = (file) => { const e = path.extname(file).toLowerCase(); return e === ".py" ? "py" : e === ".rb" ? "rb" : "js"; };
const isComment = (l, lang) => {
  const t = l.trim();
  if (lang === "py" || lang === "rb") return t.startsWith("#");
  return t.startsWith("//") || t.startsWith("/*") || t.startsWith("*");
};
function skipMatch(line, lang) {
  if (isComment(line, lang)) return null;
  const sets = lang === "py" ? PY_SKIP : lang === "rb" ? RB_SKIP : JS_SKIP;
  for (const p of sets) { const m = line.match(p.re); if (m) return { kind: p.kind(m), match: m[0].trim() }; }
  return null;
}
const declOf = (line, lang) => (lang === "py" ? PY_DECL : lang === "rb" ? RB_DECL : JS_DECL).test(line);
/** The test a skip line belongs to: the line itself when it declares one, the next declaration after a decorator
 *  (Python), else the nearest declaration above. → { text, name } (name: the first string literal or the def name). */
function enclosingTest(lines, idx, lang) {
  const nameOf = (l) => {
    if (lang === "py") { const m = l.match(PY_DECL); if (m) return m[1] || m[2]; }
    const s = l.match(/(['"`])((?:\\.|(?!\1).)+)\1/);
    return s ? s[2] : null;
  };
  const here = lines[idx] ?? "";
  if (declOf(here, lang)) return { text: here, name: nameOf(here) };
  if (here.trim().startsWith("@")) {
    for (let k = idx + 1; k < Math.min(lines.length, idx + 8); k++) if (declOf(lines[k], lang)) return { text: lines[k], name: nameOf(lines[k]) };
  }
  for (let k = idx - 1; k >= Math.max(0, idx - 80); k--) if (declOf(lines[k], lang)) return { text: lines[k], name: nameOf(lines[k]) };
  return { text: "", name: null };
}

// ------------------------------------------------------------------ git helpers
const posix = (p) => String(p).split(path.sep).join("/").replace(/^\.\//, "");
const listOf = (v, dflt) => { const l = String(v || "").split(",").map((s) => s.trim().replace(/^\.\//, "").replace(/\/+$/, "")).filter(Boolean); return l.length ? l : dflt; };
const under = (p, dirs) => dirs.some((d) => d === "." || p === d || p.startsWith(d + "/"));
function showAt(root, sha, file) {
  const r = git(root, ["show", `${sha}:${file}`]);
  return r.status === 0 ? r.stdout : null;
}
function ok(root, args) {
  const r = git(root, args);
  if (r.error) die(`git not available: ${r.error.message}`);
  if (r.status !== 0) die(`git ${args[0]} failed: ${(r.stderr || "").trim()}`);
  return r.stdout;
}

/** The effective base: { sha, ref, source: flag|merge-base|tag, detail } or null. */
export function resolveBase(root, ref) {
  if (ref) {
    const r = git(root, ["rev-parse", "-q", "--verify", `${ref}^{commit}`]);
    if (r.status !== 0) die(`unknown revision ${ref}`);
    return { sha: r.stdout.trim(), ref, source: "flag", detail: `--base ${ref}` };
  }
  const def = defaultBranch(root);
  const cur = git(root, ["symbolic-ref", "--short", "-q", "HEAD"]).stdout.trim() || null;
  if (def.name && cur !== def.name) {
    for (const r of [`refs/heads/${def.name}`, `refs/remotes/origin/${def.name}`]) {
      if (!refExists(root, r)) continue;
      const mb = git(root, ["merge-base", "HEAD", r]);
      if (mb.status === 0 && mb.stdout.trim()) {
        const short = r.replace(/^refs\/(heads|remotes)\//, "");
        return { sha: mb.stdout.trim(), ref: short, source: "merge-base", detail: `merge-base of HEAD and ${short}` };
      }
    }
  }
  const t = git(root, ["describe", "--tags", "--abbrev=0", "--match", "fase-*-accepted", "HEAD"]);
  if (t.status === 0 && t.stdout.trim()) {
    const tag = t.stdout.trim();
    const sha = ok(root, ["rev-parse", `${tag}^{commit}`]).trim();
    return { sha, ref: tag, source: "tag", detail: `last accepted FASE tag ${tag}` };
  }
  return null;
}

/** Name-status of the working tree against `sha` on `paths`, plus untracked files there:
 *  [{ status: A|M|D|R, file, from?, untracked? }]. */
function changes(root, sha, paths) {
  const ns = ok(root, ["diff", "--name-status", "-M", "--no-color", sha, "--", ...paths]);
  const list = [];
  for (const l of ns.split("\n").filter(Boolean)) {
    const [st, a, b] = l.split("\t");
    const s = st[0];
    if (s === "R") list.push({ status: "R", file: b, from: a });
    else if (s === "C") list.push({ status: "A", file: b });
    else if (s === "D" || s === "A") list.push({ status: s, file: a });
    else list.push({ status: "M", file: a });
  }
  const un = ok(root, ["ls-files", "--others", "--exclude-standard", "--", ...paths]);
  for (const f of un.split("\n").filter(Boolean)) list.push({ status: "A", file: f, untracked: true });
  return list;
}

/** Added and removed lines per new path: Map(file → { added: [{ n, text }], removed: [{ text }] }). */
function lineDiff(root, sha, paths) {
  const d = ok(root, ["diff", "-U0", "-M", "--no-color", "--no-ext-diff", sha, "--", ...paths]);
  const map = new Map();
  let cur = null, nNew = 0;
  for (const l of d.split("\n")) {
    if (l.startsWith("diff --git ")) { cur = null; continue; }
    if (l.startsWith("+++ ")) {
      const p = l.slice(4);
      if (p === "/dev/null") { cur = null; continue; }
      const f = p.replace(/^"?b\//, "").replace(/"$/, "");
      cur = map.get(f) || { added: [], removed: [] };
      map.set(f, cur);
      continue;
    }
    if (l.startsWith("--- ")) continue;
    const h = l.match(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/);
    if (h) { nNew = Number(h[1]); continue; }
    if (!cur) continue;
    if (l.startsWith("+")) { cur.added.push({ n: nNew, text: l.slice(1) }); nNew++; }
    else if (l.startsWith("-")) cur.removed.push({ text: l.slice(1) });
  }
  return map;
}

function readText(abs) {
  try { const st = statSync(abs); if (!st.isFile() || st.size > 4 * 1024 * 1024) return null; return readFileSync(abs, "utf8"); } catch { return null; }
}

// ------------------------------------------------------------------ the check
/**
 * Run the floor check. → { base, head, mode, mode_source, test_paths, code_paths, findings, testEdits, summary }.
 * Throws Exit(2) (via die) when there is no base or git fails.
 */
export function floorCheck(root, { baseRef } = {}) {
  if (!isRepo(root)) die(`not a git repository: ${root}`);
  if (git(root, ["rev-parse", "-q", "--verify", "HEAD"]).status !== 0) die("no commit yet: nothing to compare against");
  const base = resolveBase(root, baseRef);
  if (!base) die("no base: pass --base REF (not on the default branch, no merge-base with it and no fase-*-accepted tag reachable from HEAD)");
  const head = ok(root, ["rev-parse", "HEAD"]).trim();

  const cur = stackProfileWithSource(root);
  const baseProf = profileFromTexts(PROFILE_FILES.map((file) => ({ file, text: showAt(root, base.sha, file) })));
  const testPaths = listOf(cur.profile.test_paths, ["tests"]);
  const codePaths = listOf(cur.profile.code_paths, ["src"]);
  const validMode = (v) => FLOOR_MODES.includes(String(v ?? "").trim().toLowerCase()) ? String(v).trim().toLowerCase() : null;
  // The mode is the base's. A base without floor_gate means the default (enforce), never the tree's value: the same
  // change could otherwise add `floor_gate: off` and silence itself. A person lowers it in one change, checked by the
  // next; inside the change that lowers it, a person excepts the finding (floor-exception).
  let mode = validMode(baseProf.profile.floor_gate), modeSource = "base";
  if (!mode) { mode = "enforce"; modeSource = "default"; }

  const findings = [];
  const add = (f) => findings.push(f);

  // F-07: gates of the Stack Profile lowered against the base (only keys the base writes).
  for (const [key, g] of Object.entries(GATES)) {
    const bvRaw = baseProf.profile[key];
    if (bvRaw === undefined) continue;
    const bv = String(bvRaw).trim().toLowerCase();
    if (!g.order.includes(bv)) continue;
    const cvRaw = cur.profile[key];
    const cvl = cvRaw === undefined ? null : String(cvRaw).trim().toLowerCase();
    const cv = cvl !== null && g.order.includes(cvl) ? cvl : g.dflt;
    if (g.order.indexOf(cv) >= g.order.indexOf(bv)) continue;
    const at = cur.lines[key];
    add({ code: "F-07", severity: "error", file: at ? cur.file : baseProf.file, line: at ? at.n : null,
      text: at ? at.text : baseProf.lines[key].text, key, from: bv, to: cv,
      message: `${key} lowered from ${bv} to ${cv}${cvRaw === undefined ? " (key removed: its default)" : cvl !== cv ? ` (\`${cvRaw}\` reads as ${cv})` : ""} against the base: a Stack Profile gate is not lowered without a person (floor-exception)` });
  }

  // Changes under the test and code paths.
  const paths = [...new Set([...testPaths, ...codePaths])];
  const changed = changes(root, base.sha, paths);
  const diffs = lineDiff(root, base.sha, paths);
  const { byScenario } = scenarioIndex(loadScenarios(root));
  const isTestFile = (f) => under(f, testPaths) && SOURCE_EXT.has(path.extname(f).toLowerCase());
  const criteriaOf = (text) => {
    const k = testKeys(text);
    const crit = new Set(k.reqAcs.map((r) => `${r.req} AC${r.ac}`));
    for (const s of k.scenarios) for (const t of byScenario.get(s) || []) if (t.n > 0) crit.add(`${t.req} AC${t.n}`);
    return { criteria: [...crit].sort(), scenarios: k.scenarios };
  };

  for (const c of changed) {
    const lines = c.status === "D" ? null : (readText(path.join(root, c.file)) ?? "").split(/\r?\n/);
    const added = c.untracked ? (lines || []).map((text, i) => ({ n: i + 1, text })) : (diffs.get(c.file)?.added || []);
    // F-01: skip / only / focus / todo added in a test file.
    if (isTestFile(c.file) && lines) {
      const lang = langOf(c.file);
      const baseText = c.status === "A" ? null : showAt(root, base.sha, c.from || c.file);
      for (const a of added) {
        const sm = skipMatch(a.text, lang);
        if (!sm) continue;
        const t = enclosingTest(lines, a.n - 1, lang);
        const bound = criteriaOf(`${a.text}\n${t.text}`);
        const isBound = bound.criteria.length > 0 || bound.scenarios.length > 0;
        const existed = Boolean(baseText && t.name && baseText.includes(t.name));
        const error = sm.kind !== "todo" && (isBound || existed);
        const what = isBound ? `a test bound to ${(bound.criteria.length ? bound.criteria : bound.scenarios).join(", ")}`
          : existed ? "a test that exists in the base" : "a new test bound to no criterion";
        add({ code: "F-01", severity: error ? "error" : "warn", file: c.file, line: a.n, text: a.text, kind: sm.kind,
          criteria: bound.criteria, scenarios: bound.scenarios,
          message: `\`${sm.match}\` (${sm.kind}) added on ${what}${error ? ": a bound or existing test is not switched off — fix the code, or a person records a floor-exception" : sm.kind === "todo" ? " (a pending test, not a disabled one)" : ""}` });
      }
    }
    // F-04: coverage or security suppression added.
    for (const a of added) {
      const m = a.text.match(SUPPRESSIONS);
      if (m) add({ code: "F-04", severity: "warn", file: c.file, line: a.n, text: a.text, message: `coverage/security suppression added: \`${m[0]}\`` });
    }
  }

  // F-02: test files deleted, or renamed / moved losing the criterion ids they named in the base.
  for (const c of changed.filter((x) => (x.status === "D" || x.status === "R") && under(x.from || x.file, testPaths))) {
    const oldPath = c.from || c.file;
    if (!SOURCE_EXT.has(path.extname(oldPath).toLowerCase())) continue;
    const before = criteriaOf(showAt(root, base.sha, oldPath) || "");
    const ids = [...before.criteria, ...before.scenarios];
    if (c.status === "D") {
      add({ code: "F-02", severity: ids.length ? "error" : "warn", file: oldPath, line: null, text: "(deleted)", criteria: before.criteria, scenarios: before.scenarios,
        message: ids.length ? `test file deleted with the criterion ids it named in the base: ${ids.join(", ")}` : "test file deleted (it named no criterion id)" });
      continue;
    }
    const nowText = isTestFile(c.file) ? (readText(path.join(root, c.file)) ?? "") : "";
    const now = criteriaOf(nowText);
    const lost = ids.filter((id) => !now.criteria.includes(id) && !now.scenarios.includes(id));
    if (lost.length) add({ code: "F-02", severity: "error", file: oldPath, line: null, text: `(renamed to ${c.file})`, to: c.file,
      criteria: before.criteria.filter((x) => lost.includes(x)), scenarios: before.scenarios.filter((x) => lost.includes(x)),
      message: `test file renamed to ${c.file}${isTestFile(c.file) ? "" : " (outside test_paths)"} losing criterion ids it named in the base: ${lost.join(", ")}` });
  }

  // Human exceptions: same code, file and line text, same base.
  const { records } = readDecisions(path.join(root, DECISIONS_FILE));
  const exceptions = records.filter((r) => r.type === "floor-exception");
  for (const f of findings) {
    if (f.severity !== "error") continue;
    const ex = exceptions.find((r) => r.code === f.code && posix(r.file) === f.file && String(r.text ?? "").trim() === String(f.text ?? "").trim() && r.base === base.sha);
    if (ex) { f.severity = "excepted"; f.exception = { line: ex.line, by: ex.by, role: ex.role, reason: ex.reason }; f.message += ` — excepted by ${ex.by} (${ex.role}), ${DECISIONS_FILE}:${ex.line}`; }
  }
  const order = { "F-07": 0, "F-01": 1, "F-02": 2, "F-04": 4 };
  findings.sort((a, b) => order[a.code] - order[b.code] || String(a.file).localeCompare(String(b.file)) || (a.line ?? 0) - (b.line ?? 0));

  const testEdits = changed.filter((c) => under(c.file, testPaths) || (c.from && under(c.from, testPaths)))
    .map((c) => ({ status: c.status, file: c.file, ...(c.from ? { from: c.from } : {}) }))
    .sort((a, b) => a.file.localeCompare(b.file));
  const count = (s) => findings.filter((f) => f.severity === s).length;
  return { base, head, mode, mode_source: modeSource, test_paths: testPaths, code_paths: codePaths, findings, testEdits,
    summary: { errors: count("error"), warnings: count("warn"), excepted: count("excepted"), files_changed: changed.length, test_edits: testEdits.length } };
}

// ------------------------------------------------------------------ CLI
export function runFloor(argv, { prog = "sdd" } = {}) {
  PROG = prog;
  try {
    const o = { json: false };
    for (let i = 0; i < argv.length; i++) {
      let a = argv[i], v;
      const eq = a.match(/^(--[a-z-]+)=(.*)$/);
      if (eq) { a = eq[1]; v = eq[2]; }
      const take = () => { if (v !== undefined) return v; if (i + 1 >= argv.length) usage(`${a} needs a value`); return argv[++i]; };
      if (a === "--json") o.json = true;
      else if (a === "--base") o.base = take();
      else if (a === "--repo") o.repo = take();
      else if (a.startsWith("-")) usage(`unknown option ${a}`);
      else usage(`unexpected argument ${a}`);
    }
    const start = path.resolve(o.repo || ".");
    if (!existsSync(start)) die(`no such directory: ${start}`);
    const root = topLevel(start);
    const r = floorCheck(root, { baseRef: o.base });
    const failing = r.mode === "enforce" && r.summary.errors > 0;
    const code = failing ? 1 : 0;
    if (o.json) { out(JSON.stringify({ ...r, exit: code }, null, 2)); return code; }
    out(`floor: base ${r.base.sha.slice(0, 7)} (${r.base.source}: ${r.base.detail}) · floor_gate ${r.mode} (${r.mode_source})`);
    for (const f of r.findings) {
      const sev = f.severity === "warn" ? "warning" : f.severity;
      out(`${f.file}${f.line ? `:${f.line}` : ""} ${f.code} ${sev} ${f.message}`);
    }
    for (const t of r.testEdits) out(`test edit ${t.status} ${t.from ? `${t.from} -> ` : ""}${t.file}`);
    const firstErr = r.findings.find((f) => f.severity === "error");
    if (firstErr) out(`note: a person may except one finding: sdd accept record floor-exception --code ${firstErr.code} --file ${firstErr.file} --line '${String(firstErr.text).trim().replace(/'/g, "'\\''")}' --base ${r.base.sha} --reason … --by … --role …`);
    out(`lint --floor: ${r.summary.errors} error(s) · ${r.summary.warnings} warning(s) · ${r.summary.excepted} excepted · ${r.summary.test_edits} test edit(s) · base ${r.base.sha.slice(0, 7)} (${r.base.source})${r.mode !== "enforce" && r.summary.errors ? ` · floor_gate ${r.mode}: exit 0` : ""}`);
    return code;
  } catch (e) {
    if (e instanceof Exit) return e.code;
    throw e;
  }
}
