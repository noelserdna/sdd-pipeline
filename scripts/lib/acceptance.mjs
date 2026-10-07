// acceptance.mjs — the acceptance ledger (sdd-pipeline): is each requirement satisfied, and with what evidence?
// Node >= 18, no dependencies. Library only: no console output, no process.exit.
//
// Inputs
//   requirements/REQUIREMENTS.md   parseRequirements (sdd-jev.mjs): id, priority, Verification method, criteria, status
//   spec/tests/BDD-*.md            scenario lines `Scenario: AC-NNN-NN — … [REQ-X-NNN ACn]` map criteria → scenarios
//   JUnit XML (lib/junit.mjs)      a testcase binds to a scenario when its name (or classname + name) contains the
//                                  scenario id (AC-001-02, AC_001_02) or `REQ-X-NNN ACn`. File-level Refs never bind.
//   acceptance/decisions.jsonl     human records: waiver, demo, measurement, inspection, fase-acceptance
//
// Verdict per requirement (first match): DEPRECATED · WAIVED · FAILING · MISSING · VERIFIED.
// Visual evidence (Stack Profile `visual_evidence: required|warn|off`, default required; files under `evidence_dir`,
// default evidencias/): a REQ-F criterion is shown when a fresh passing test, a fresh record or a fresh file of the
// evidence dir named after its scenario id (AC-NNN-NN) or `REQ-F-NNN-ACn` brings an image that is present. Under
// `required` a passing criterion without one is `unshown` and the requirement MISSING with reason "no visual evidence";
// `warn` only reports it. With a FASE scope, each WF-NNN of the FASE file's `Workflows:` header line (without that line,
// each one cited inside `## Demo`; with none, FASE-N) needs a video whose name carries it: any video file under the
// evidence dir (manual demo recordings too), a JUnit attachment or a record's --attach; a missing one makes the goal not met (`summary.missing_videos`). Attachments: [{path, sha256, bytes,
// kind: image|video|trace|other, present}] from JUnit `[[ATTACHMENT|…]]`, record `--attach` and name-bound files.
// Freshness (evidence older than the code does not count). "Code" is the Stack Profile's `code_paths` + `test_paths`
// (defaults `src`, `tests`; only those that exist): a docs, feedback or spec commit does not make evidence stale. When
// none of those paths exists, code means every file outside acceptance/** and .sdd/ (the conservative fallback).
// Build and test configuration outside those paths (package.json, vitest.config.*) is not watched: list it in
// `code_paths` when a change there should invalidate evidence.
//   - JUnit: with `junitSha`, fresh when the worktree equals that commit on the code paths; otherwise fresh when the
//     XML file's mtime is >= the time of the last commit that changed the code paths. Either way the code paths must be
//     clean: no tracked change and no untracked file under them (`untracked_paths` in the ledger; a new file the tests
//     depend on does not exist at evaluated_sha). The mtime rule is a heuristic: a report written after
//     the last code commit on a clean tree was produced from that tree, unless someone ran the tests on another
//     checkout and copied the XML; CI passes --junit-sha to assert it.
//   - demo / measurement / inspection records: fresh when `git diff --quiet <record.head> -- <paths>` holds (worktree
//     vs the record's commit) and no untracked file sits under those paths; a record without paths uses the code paths.
//   - a measurement record with a `command` (from `sdd accept measure`) is re-run by `sdd accept --remeasure` when it
//     is stale; the new record becomes the latest.
//   - waivers, inspections, demos, measurements and fase acceptances carry `reqHash` (sha256 of the requirement's
//     statement + criteria). A different hash means the text changed (a MODIFY): the record is stale, reported and
//     not applied.
// Literal letter (Stack Profile `literal_gate: off|warn|enforce`, default enforce; scripts/lib/quotes.mjs): the test
// files that name a criterion must carry its current quote and its literals (Q-02/Q-03 of `sdd lint --quotes`). Each
// criterion lists its `literal_gaps`; under enforce a passing criterion of a Must with a gap not excepted by a person
// (`literal-exception` record, bound to reqHash) is `weakened` and the requirement MISSING with reason "test does not
// carry the criterion's literal"; warn only lists the gaps. The ledger counts them in summary.literal_gaps.
// Adversarial challenges (acceptance/challenges.jsonl, written only by `sdd accept challenge add`): a finding of an
// independent verifier on one criterion, with its category, the literal quote and `path:line` evidence in production
// or test code. Each sits next to the verdict in `requirements[].challenges[]` and never changes it: `open`, `stale`
// once a cited file changed since the challenge's HEAD (a capture of the evidence dir: its sha256 changed) or the
// requirement text changed (reqHash), `dismissed` by a person (`challenge-dismissal` record in decisions.jsonl).
// `summary.must_challenged` counts the Musts with an open one; the Stack Profile's `adversarial_gate`
// (off | warn | enforce, default warn) decides whether `sdd gate` exits 4 on them.
import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import path from "node:path";
import { git, isRepo, stackProfile } from "./git-log.mjs";
import { VERIFICATION_METHODS } from "../sdd-jev.mjs";
import { lintQuotes, literalGate, literalGapsByCriterion, isCriterionLiteral } from "./quotes.mjs";

export const SCHEMA = "sdd-acceptance-v1";
export const VERDICTS = ["VERIFIED", "FAILING", "MISSING", "WAIVED", "DEPRECATED"];
export const RECORD_TYPES = ["waiver", "demo", "measurement", "inspection", "fase-acceptance", "challenge-dismissal", "literal-exception",
  "floor-exception"];
/** Finding codes of `sdd lint --floor` (scripts/lib/floor.mjs) that a person may except with a floor-exception record. */
export const FLOOR_CODES = ["F-01", "F-02", "F-04", "F-07"];
export const OPS = { lt: (a, b) => a < b, le: (a, b) => a <= b, gt: (a, b) => a > b, ge: (a, b) => a >= b, eq: (a, b) => a === b };
export const FASE_RESULTS = ["accepted", "rejected", "observations"];
export const DECISIONS_FILE = "acceptance/decisions.jsonl";
export const ROUTES = {
  implement: "implement-or-test",
  fix: "fix-code (Art. 12)",
  specGap: "spec-gap (human, req-change)",
  human: "needs-human",
  rerun: "rerun-tests",
  remeasure: "remeasure",
  capture: "capture-evidence", // run the journey again with capture; no code task
  adversarial: "adversarial-finding", // an open, confirmed challenge of the adversarial round
  weakened: "weakened-test", // the test passes without the criterion's literal: a test edit a person approves (Art. 12)
};
/** Symbol-keyed flag on each requirement of a ledger (JSON output ignores it): false when the project has no
 *  spec/tests, i.e. the route skipped the specifications and the requirement criteria are the contract. */
export const SPEC_TESTS = Symbol("specTests");

// ------------------------------------------------------------------ requirements
const norm = (s) => String(s ?? "").normalize("NFC").replace(/\s+/g, " ").trim();

/** sha256 of the requirement's normalized statement + criteria: the text a decision is tied to. */
export function reqHash(req) {
  const text = [norm(req.statement), ...(req.criteria || []).map(norm)].join("\n");
  return "sha256:" + createHash("sha256").update(text).digest("hex");
}

/** Must | Should | Nice | Won't | raw | null. A REQ-C without priority is binding, so it counts as Must. */
export function effectivePriority(req) {
  const p = req.priority;
  if (p && /^won'?t|^no\b/i.test(p)) return "Won't";
  if (!p && req.type === "C") return "Must";
  return p || null;
}

// ------------------------------------------------------------------ scenarios (spec/tests/BDD-*.md)
const AC_ID = /\bAC-(\d{3,})-(\d{2,})(?!\d)/gi;
const REQ_ID = /REQ-[A-Z]+(?:-[A-Z0-9]+)*-\d+/;
const canonAc = (a, b) => `AC-${a}-${b}`;

/** Tags inside `[…]`: REQ ids and the ACn after each. `[REQ-F-001 AC1, AC3]`, `[REQ-F-001 AC1; REQ-F-002 AC2]`. */
export function parseTags(line) {
  const tags = [];
  for (const b of line.matchAll(/\[([^\]]*)\]/g)) {
    let cur = null;
    for (const tok of b[1].split(/[\s,;]+/).filter(Boolean)) {
      if (new RegExp(`^${REQ_ID.source}$`).test(tok)) { cur = { req: tok, acs: [] }; tags.push(cur); }
      else if (cur && /^AC\d+$/i.test(tok)) cur.acs.push(Number(tok.slice(2)));
    }
  }
  return tags;
}

export function parseScenarios(text, file) {
  const out = [];
  const lines = String(text).split(/\r?\n/);
  for (let i = 0; i < lines.length; i++) {
    const l = lines[i];
    if (!/^\s*(?:#{1,6}\s*)?(?:\*\*)?(?:Scenario(?: Outline)?|Escenario|Esquema del escenario)\b/i.test(l)) continue;
    const ids = [...l.matchAll(AC_ID)].map((m) => canonAc(m[1], m[2]));
    if (!ids.length) continue;
    const title = l.replace(/^\s*(?:#{1,6}\s*)?(?:\*\*)?(?:Scenario(?: Outline)?|Escenario|Esquema del escenario)\s*:?\s*/i, "")
      .replace(/\[[^\]]*\]/g, "").replace(AC_ID, "").replace(/^[\s—–:-]+|[\s*]+$/g, "").trim();
    const tags = parseTags(l);
    for (const id of ids) out.push({ id, title, file, line: i + 1, tags });
  }
  return out;
}

export function loadScenarios(root) {
  const dir = path.join(root, "spec", "tests");
  if (!existsSync(dir)) return [];
  const files = readdirSync(dir).filter((f) => /^BDD-.*\.md$/i.test(f)).sort();
  return files.flatMap((f) => parseScenarios(readFileSync(path.join(dir, f), "utf8"), `spec/tests/${f}`));
}

/** Scenario index from the BDD tags: byCriterion `REQ#n` → Set of scenario ids; byScenario id → [{ req, n }]
 *  (n 0 = a tag on the whole requirement). The ledger and `sdd lint --quotes` bind test names through it. */
export function scenarioIndex(scenarios) {
  const byScenario = new Map(), byCriterion = new Map();
  for (const s of scenarios) {
    for (const t of s.tags) {
      const acs = t.acs.length ? t.acs : [0];
      for (const n of acs) {
        const k = `${t.req}#${n}`;
        if (!byCriterion.has(k)) byCriterion.set(k, new Set());
        byCriterion.get(k).add(s.id);
        if (!byScenario.has(s.id)) byScenario.set(s.id, []);
        byScenario.get(s.id).push({ req: t.req, n });
      }
    }
  }
  return { byScenario, byCriterion };
}

// ------------------------------------------------------------------ test names
/** Scenario ids and `REQ ACn` pairs named by a test (case-insensitive, `-` or `_` separators). */
export function testKeys(s) {
  const text = String(s || "");
  const scenarios = [...text.matchAll(/(?<![A-Za-z0-9])AC[-_](\d{3,})[-_](\d{2,})(?!\d)/gi)].map((m) => canonAc(m[1], m[2]));
  const reqAcs = [...text.matchAll(/(?<![A-Za-z0-9])REQ[-_]([A-Z]+(?:[-_][A-Z0-9]+)*?)[-_](\d+)[\s:_-]+AC(\d+)(?!\d)/gi)]
    .map((m) => ({ req: `REQ-${m[1].replace(/_/g, "-").toUpperCase()}-${m[2]}`, ac: Number(m[3]) }));
  return { scenarios: [...new Set(scenarios)], reqAcs };
}

// ------------------------------------------------------------------ decisions.jsonl
export function readDecisions(file) {
  const records = [], errors = [];
  if (!existsSync(file)) return { records, errors };
  const lines = readFileSync(file, "utf8").split(/\r?\n/);
  lines.forEach((l, i) => {
    if (!l.trim()) return;
    let r;
    try { r = JSON.parse(l); } catch { errors.push({ line: i + 1, msg: "not JSON" }); return; }
    if (!r || typeof r !== "object" || !RECORD_TYPES.includes(r.type)) { errors.push({ line: i + 1, msg: `unknown type ${r && r.type}` }); return; }
    records.push({ ...r, line: i + 1 });
  });
  return { records, errors };
}

/** Criterion number from `ac`: 2, "2", "AC2", "ac2". null = the whole requirement. */
export function acNumber(ac) {
  if (ac === undefined || ac === null || ac === "") return null;
  const m = String(ac).match(/^(?:AC)?(\d+)$/i);
  return m ? Number(m[1]) : NaN;
}

export function compareMeasurement(rec) {
  const obs = Number(rec.observed), thr = Number(rec.threshold);
  if (!OPS[rec.op] || !Number.isFinite(obs) || !Number.isFinite(thr)) return null;
  return OPS[rec.op](obs, thr);
}

export const FOLLOW_UP_RE = /^(#\d+|![0-9]+|[A-Z][A-Z0-9]+-\d+|[\w.-]+\/[\w.-]+[#!]\d+|https?:\/\/\S+)$/;

/** Validation for a record about to be appended (`sdd accept record`). Returns error strings.
 *  ctx.challenges: the challenges of acceptance/challenges.jsonl; ctx.records: decisions already recorded. */
export function validateRecord(rec, reqs, ctx = {}) {
  const e = [];
  if (!RECORD_TYPES.includes(rec.type)) return [`type must be one of ${RECORD_TYPES.join(", ")}`];
  if (!rec.by) e.push("--by is required (who decided)");
  if (!rec.role) e.push("--role is required (their role, e.g. product owner)");
  if (!rec.head) e.push("no HEAD commit: record decisions in a git repository with at least one commit");
  if (rec.type === "fase-acceptance") {
    if (!Number.isInteger(rec.fase)) e.push("--fase N is required");
    if (!FASE_RESULTS.includes(rec.result)) e.push(`--result must be ${FASE_RESULTS.join(" | ")}`);
    if (!rec.channel) e.push("--channel is required (where the customer accepted: meeting, email, issue…)");
    return e;
  }
  if (rec.type === "challenge-dismissal") {
    if (!rec.reason) e.push("--reason is required (why the finding does not hold)");
    if (!rec.challenge) { e.push("--challenge CH-NNN is required"); return e; }
    if (!(ctx.challenges || []).some((c) => c.id === rec.challenge)) e.push(`${rec.challenge} is not in ${CHALLENGES_FILE}`);
    else if ((ctx.records || []).some((r) => r.type === "challenge-dismissal" && r.challenge === rec.challenge)) e.push(`${rec.challenge} is already dismissed`);
    return e;
  }
  if (rec.type === "floor-exception") {
    // A person accepts one finding of `sdd lint --floor`: that code, file and exact line, against that base commit.
    if (!FLOOR_CODES.includes(rec.code)) e.push(`--code must be one of ${FLOOR_CODES.join(", ")}`);
    if (!rec.file) e.push("--file is required (the file of the finding, relative to the repository)");
    if (!String(rec.text ?? "").trim()) e.push("--line is required (the exact text of the finding's line, as `sdd lint --floor --json` prints it in `text`)");
    if (!/^[0-9a-f]{40}$/.test(String(rec.base || ""))) e.push("--base is required (the base commit of the floor check)");
    if (!rec.reason) e.push("--reason is required (why the lowered floor is right)");
    return e;
  }
  const req = reqs.find((r) => r.id === rec.req);
  if (!rec.req) { e.push("--req is required"); return e; }
  if (!req) { e.push(`${rec.req} is not in requirements/REQUIREMENTS.md`); return e; }
  if (req.deprecated) e.push(`${rec.req} is deprecated: it needs no acceptance`);
  const n = acNumber(rec.ac);
  if (Number.isNaN(n)) e.push("--ac must be a criterion number (2 or AC2)");
  else if (n !== null && n > Math.max(1, req.criteria.length)) e.push(`${rec.req} has ${req.criteria.length} criteria; AC${n} does not exist`);
  if (rec.type === "waiver") {
    if (!rec.reason) e.push("--reason is required");
    if (effectivePriority(req) === "Must" && !rec.followUp) e.push(`${rec.req} is a Must: a waiver needs --follow-up (the issue that tracks the deferred work, e.g. #42)`);
    if (rec.followUp && !FOLLOW_UP_RE.test(rec.followUp)) e.push("--follow-up must be an issue reference (#42, !7, PROJ-12, owner/repo#42 or a URL)");
  } else if (rec.type === "demo") {
    if (!rec.observed) e.push("--observed is required (what was seen)");
    if (typeof rec.pass !== "boolean") e.push("--pass true|false is required");
  } else if (rec.type === "measurement") {
    if (!rec.metric) e.push("--metric is required");
    if (!OPS[rec.op]) e.push(`--op must be ${Object.keys(OPS).join(" | ")}`);
    if (!Number.isFinite(Number(rec.observed)) || rec.observed === "") e.push("--observed must be a number");
    if (!Number.isFinite(Number(rec.threshold)) || rec.threshold === "") e.push("--threshold must be a number");
  } else if (rec.type === "inspection") {
    if (!rec.note) e.push("--note is required (what was reviewed and found)");
  } else if (rec.type === "literal-exception") {
    if (n === null) e.push("--ac N is required (the criterion whose literal a helper builds)");
    if (!rec.reason) e.push("--reason is required (why the literal is not verbatim in the test, e.g. the helper that builds it)");
    if (!String(rec.literal ?? "").trim()) e.push("--literal is required (the literal as the criterion writes it)");
    else if (Number.isInteger(n) && n >= 1 && req.criteria[n - 1] && !isCriterionLiteral(req.criteria[n - 1], rec.literal))
      e.push(`"${rec.literal}" is not a literal of ${rec.req} AC${n} (sdd req show ${rec.req} --ac ${n})`);
    return e;
  }
  if (rec.type !== "waiver" && req.verification && req.verification !== rec.type && VERIFICATION_METHODS.includes(req.verification))
    e.push(`${rec.req} is verified by ${req.verification}, not ${rec.type}`);
  return e;
}

// ------------------------------------------------------------------ git context
const WHOLE_TREE = [".", ":(exclude)acceptance", ":(exclude).sdd"];
const profileList = (v) => String(v || "").split(",").map((s) => s.trim().replace(/^\.\//, "").replace(/\/+$/, "")).filter(Boolean);

/** Paths whose change makes evidence stale: the profile's code_paths + test_paths (default src, tests) that exist; null = whole tree. */
export function evidencePaths(root) {
  const prof = stackProfile(root);
  const code = profileList(prof.code_paths), tests = profileList(prof.test_paths);
  const all = [...new Set([...(code.length ? code : ["src"]), ...(tests.length ? tests : ["tests"])])];
  const present = all.filter((p) => existsSync(path.join(root, p)));
  return present.length ? present : null;
}

const under = (p, dirs) => dirs.some((d) => p === d || p.startsWith(d + "/"));

/** Paths of `git status --porcelain` output minus acceptance/**, .sdd/ and `skip` (files or directories). */
function statusPaths(stdout, skip) {
  const all = ["acceptance/", ".sdd/", ...skip];
  return stdout.split("\n").filter(Boolean)
    .map((l) => ({ untracked: l.startsWith("??"), p: l.slice(3).replace(/^"|"$/g, "").split(" -> ").pop() }))
    .filter(({ p }) => !all.some((s) => p === s || p.startsWith(s.endsWith("/") ? s : s + "/") || p === s.replace(/\/$/, "")));
}

/**
 * Git state of the worktree. Tracked changes are read over the whole tree; untracked files only under the code paths
 * (`--untracked-files=all` limited to them): a new file the tests depend on makes the evidence describe a tree that
 * evaluated_sha does not contain. Without code paths (the whole-tree fallback) untracked files are not read.
 * dirtyPaths and codeDirtyPaths include those untracked paths, also listed apart in untrackedPaths.
 */
export function gitContext(root, { exclude = [] } = {}) {
  if (!isRepo(root)) return { repo: false, head: null, headTime: null, dirty: null, dirtyPaths: [], codePaths: null, codeTime: null, codeDirty: null, codeDirtyPaths: [], untrackedPaths: [] };
  const h = git(root, ["rev-parse", "-q", "--verify", "HEAD"]);
  const head = h.status === 0 ? h.stdout.trim() : null;
  const codePaths = evidencePaths(root);
  // Time of the last commit that changed something outside acceptance/** (headTime) and under the code paths (codeTime).
  let headTime = null, codeTime = null;
  if (head) {
    const headOnly = () => Number(git(root, ["show", "-s", "--format=%ct", "HEAD"]).stdout.trim());
    const t = git(root, ["log", "-1", "--format=%ct", "HEAD", "--", ...WHOLE_TREE]).stdout.trim();
    headTime = t ? Number(t) : headOnly();
    const c = codePaths ? git(root, ["log", "-1", "--format=%ct", "HEAD", "--", ...codePaths]).stdout.trim() : t;
    codeTime = c ? Number(c) : headOnly();
  }
  const tracked = statusPaths(git(root, ["status", "--porcelain", "--untracked-files=no"]).stdout, exclude).map((x) => x.p);
  const untrackedPaths = codePaths
    ? statusPaths(git(root, ["status", "--porcelain", "--untracked-files=all", "--", ...codePaths]).stdout, exclude)
      .filter((x) => x.untracked).map((x) => x.p)
    : [];
  const dirtyPaths = [...tracked, ...untrackedPaths];
  const codeDirtyPaths = codePaths ? dirtyPaths.filter((p) => under(p, codePaths)) : dirtyPaths;
  return { repo: true, head, headTime, dirty: dirtyPaths.length > 0, dirtyPaths,
    codePaths, codeTime, codeDirty: codeDirtyPaths.length > 0, codeDirtyPaths, untrackedPaths };
}

/** Uncommitted paths (tracked changes and untracked files) under `paths`; with no paths, tracked changes over the whole
 *  tree. acceptance/** and .sdd/ never count. What `accept record` / `accept measure` check before anchoring to HEAD. */
export function dirtyUnder(root, paths) {
  if (!isRepo(root)) return [];
  const list = (paths || []).map((p) => String(p).replace(/^\.\//, "").replace(/\/+$/, "")).filter(Boolean);
  const args = list.length ? ["status", "--porcelain", "--untracked-files=all", "--", ...list] : ["status", "--porcelain", "--untracked-files=no"];
  return statusPaths(git(root, args).stdout, []).map((x) => x.p);
}

/** True when the worktree equals `sha` on `paths` (all paths outside acceptance/** when empty). */
export function unchangedSince(root, sha, paths = [], cache = new Map()) {
  const key = `${sha}\0${paths.join("\0")}`;
  if (cache.has(key)) return cache.get(key);
  let ok;
  if (git(root, ["rev-parse", "-q", "--verify", `${sha}^{commit}`]).status !== 0) ok = false;
  else ok = git(root, ["diff", "--quiet", sha, "--", ...(paths.length ? paths : WHOLE_TREE)]).status === 0;
  cache.set(key, ok);
  return ok;
}

// ------------------------------------------------------------------ evidence files (screenshots, videos)
export const DEFAULT_EVIDENCE_DIR = "evidencias";
export const VISUAL_MODES = ["required", "warn", "off"];

/** Stack Profile `visual_evidence` (required | warn | off; default and any other value: required) and `evidence_dir`. */
export function evidenceSettings(root) {
  const prof = stackProfile(root);
  const v = String(prof.visual_evidence || "").trim().toLowerCase();
  const dir = String(prof.evidence_dir || "").trim().replace(/^\.\//, "").replace(/\/+$/, "") || DEFAULT_EVIDENCE_DIR;
  return { visual: VISUAL_MODES.includes(v) ? v : "required", dir };
}

const IMAGE_EXT = /\.(png|jpe?g|gif|webp|bmp)$/i;
const VIDEO_EXT = /\.(webm|mp4|mov|m4v|mkv)$/i;
/** image | video | trace | other, from the file name. Playwright traces (trace.zip) hold cookies and storage. */
export function attachmentKind(p) {
  const b = path.basename(String(p));
  if (IMAGE_EXT.test(b)) return "image";
  if (VIDEO_EXT.test(b)) return "video";
  if (/trace/i.test(b) && /\.(zip|trace)$/i.test(b)) return "trace";
  return "other";
}

const toPosix = (p) => p.split(path.sep).join("/");
/** { path (relative to root when inside it), sha256, bytes, kind, present } of one file; cached by absolute path. */
export function describeFile(root, abs, cache = new Map()) {
  if (cache.has(abs)) return cache.get(abs);
  const rel = path.relative(root, abs);
  const shown = rel && !rel.startsWith("..") && !path.isAbsolute(rel) ? toPosix(rel) : toPosix(abs);
  let d = { path: shown, sha256: null, bytes: null, kind: attachmentKind(abs), present: false };
  try {
    const st = statSync(abs);
    if (st.isFile()) d = { ...d, sha256: "sha256:" + createHash("sha256").update(readFileSync(abs)).digest("hex"), bytes: st.size, present: true };
  } catch { /* absent */ }
  cache.set(abs, d);
  return d;
}

/** A JUnit attachment path: absolute, else relative to the report's directory (Playwright) or to the repo root. */
export function resolveAttachment(root, report, raw, cache) {
  const p = String(raw).trim();
  if (path.isAbsolute(p)) return describeFile(root, p, cache);
  const cands = [...(report ? [path.resolve(path.dirname(report), p)] : []), path.resolve(root, p)];
  const hit = cands.find((c) => existsSync(c)) || cands[cands.length - 1];
  return describeFile(root, hit, cache);
}

/** Attachments stored on a decision record ({path, sha256}): present only while the file exists with the same hash. */
export function recordAttachments(root, list, cache) {
  return (Array.isArray(list) ? list : []).map((a) => {
    const now = describeFile(root, path.resolve(root, String(a.path || "")), cache);
    const same = now.present && (!a.sha256 || a.sha256 === now.sha256);
    return { path: now.path, sha256: a.sha256 || now.sha256, bytes: a.bytes ?? now.bytes, kind: a.kind || now.kind, present: same,
      ...(now.present && !same ? { changed: true } : {}) };
  });
}

/** True when a file name carries `id` (AC-001-02, REQ-F-001-AC2, WF-003, FASE-1) as a whole token: `-` or `_` between
 *  parts, not glued to a letter or digit before, no digit after (AC-001-02 is not in AC-001-021, FASE-1 not in FASE-10). */
export function nameHasId(name, id) {
  const body = String(id).split(/[-_\s]+/).map((p) => p.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join("[-_ ]");
  return new RegExp(`(?:^|[^A-Za-z0-9])${body}(?!\\d)`, "i").test(path.basename(String(name)));
}

/** Image and video files anywhere under the evidence dir: [{ abs, rel, kind, mtimeMs }]. Name binding reads them. */
export function scanEvidence(root, dir) {
  const base = path.resolve(root, dir);
  const out = [];
  const walk = (d) => {
    let entries;
    try { entries = readdirSync(d, { withFileTypes: true }); } catch { return; }
    for (const e of entries) {
      const p = path.join(d, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.isFile()) {
        const kind = attachmentKind(e.name);
        if (kind === "image" || kind === "video") out.push({ abs: p, rel: toPosix(path.relative(root, p)), kind, mtimeMs: statSync(p).mtimeMs });
      }
    }
  };
  walk(base);
  return out.sort((a, b) => a.rel.localeCompare(b.rel));
}

// ------------------------------------------------------------------ adversarial challenges
export const CHALLENGES_FILE = "acceptance/challenges.jsonl";
export const CHALLENGE_CATEGORIES = ["WEAKENED-ASSERT", "MOCK-ONLY", "UNWIRED", "BYPASS-PATH", "CROSSING", "NOT-IMPLEMENTED",
  "SPEC-QUESTION", "WRONG-CAPTURE"];
/** Counter-verification results; `refuted` findings are listed in the round's summary, never recorded. */
export const COUNTERS = ["confirmed", "refuted", "inconclusive"];
export const RECORDED_COUNTERS = ["confirmed", "inconclusive"];
export const ADVERSARIAL_MODES = ["off", "warn", "enforce"];
/** Top-level folders that are never evidence of compliance: they hold what the round checks (requirements, specs,
 *  plans, tasks, the test plan, audits, changes, feedback) or what a green test already convinced (acceptance/, the
 *  ledger in .sdd/). test/ is the exception when the Stack Profile declares it a test path (Rails Minitest). */
export const FORBIDDEN_EVIDENCE = ["acceptance", "feedback", "spec", "requirements", "plan", "task", "test", "audits", "changes", ".sdd"];

/** Stack Profile `adversarial_gate`: off | warn | enforce; default and any other value: enforce. */
export function adversarialGate(root) {
  const v = String(stackProfile(root).adversarial_gate || "").trim().toLowerCase();
  return ADVERSARIAL_MODES.includes(v) ? v : "enforce";
}

export function readChallenges(file) {
  const challenges = [], errors = [];
  if (!existsSync(file)) return { challenges, errors };
  readFileSync(file, "utf8").split(/\r?\n/).forEach((l, i) => {
    if (!l.trim()) return;
    let c;
    try { c = JSON.parse(l); } catch { errors.push({ line: i + 1, msg: "not JSON" }); return; }
    if (!c || typeof c !== "object" || !/^CH-\d{3,}$/.test(String(c.id)) || !c.req) { errors.push({ line: i + 1, msg: "not a challenge (id CH-NNN and req required)" }); return; }
    challenges.push({ ...c, line: i + 1 });
  });
  return { challenges, errors };
}

/** Next free id: CH-001, CH-002… (max + 1). */
export function nextChallengeId(challenges) {
  const max = challenges.reduce((m, c) => Math.max(m, Number(String(c.id).slice(3)) || 0), 0);
  return `CH-${String(max + 1).padStart(3, "0")}`;
}

/** `path:line` → { path, line }; a bare path → { path, line: null }. */
export function parseEvidenceRef(raw) {
  const s = String(raw || "").trim().replace(/^\.\//, "");
  const m = s.match(/^(.+?):(\d+)$/);
  return m ? { path: m[1], line: Number(m[2]) } : { path: s, line: null };
}

/** Why `rel` (posix, relative to the repo) cannot be cited as evidence, or null. */
export function forbiddenEvidence(rel, testPaths = []) {
  const top = rel.split("/")[0];
  if (!FORBIDDEN_EVIDENCE.includes(top)) return null;
  if (top === "test" && !/^test\/[^/]+\.md$/i.test(rel) && under(rel, testPaths)) return null;
  const why = top === "test" ? " (not a test path of the Stack Profile: test/ holds the test plan)" : "";
  return `${rel}: ${top}/ is never evidence${why}; cite production or test code`;
}

/**
 * Validate a challenge about to be appended (`sdd accept challenge add`). Returns { errors, warnings, evidence } with
 * evidence normalized to [{ path, line }] (a capture of the evidence dir: { path, line: null, sha256 }).
 * Cited files must exist, be committed (tracked, no uncommitted change) and hold the cited line.
 */
export function validateChallenge(ch, reqs, { root, testPaths = [], evidenceDir = DEFAULT_EVIDENCE_DIR } = {}) {
  const errors = [], warnings = [], evidence = [];
  if (!ch.head) errors.push("no HEAD commit: record challenges in a git repository with at least one commit");
  const req = ch.req ? reqs.find((r) => r.id === ch.req) : null;
  if (!ch.req) errors.push("--req is required");
  else if (!req) errors.push(`${ch.req} is not in requirements/REQUIREMENTS.md`);
  else {
    if (req.deprecated) errors.push(`${ch.req} is deprecated: it needs no acceptance`);
    const n = acNumber(ch.ac);
    if (n === null || Number.isNaN(n) || n < 1) errors.push("--ac N is required (the criterion the finding is about: 2 or AC2)");
    else if (n > Math.max(1, req.criteria.length)) errors.push(`${ch.req} has ${req.criteria.length} criteria; AC${n} does not exist`);
    else if (norm(ch.quote) && req.criteria[n - 1] && !norm(req.criteria[n - 1]).toLowerCase().includes(norm(ch.quote).toLowerCase()))
      warnings.push(`--quote is not a literal part of ${ch.req} AC${n} (\`sdd req show ${ch.req} --ac ${n}\`)`);
  }
  if (!CHALLENGE_CATEGORIES.includes(ch.category)) errors.push(`--category must be one of ${CHALLENGE_CATEGORIES.join(", ")}`);
  if (!norm(ch.quote)) errors.push("--quote is required: the literal words of the criterion that are not met");
  if (!norm(ch.verifier)) errors.push("--verifier is required (the agent that raised the finding)");
  if (ch.counter === "refuted") errors.push("--counter refuted: a refuted finding is not recorded; list it in the round's summary");
  else if (!RECORDED_COUNTERS.includes(ch.counter)) errors.push(`--counter must be ${RECORDED_COUNTERS.join(" | ")} (the counter-verifier's result)`);
  const refs = ch.evidence || [];
  if (!refs.length) errors.push("--evidence path:line is required (production or test code)");
  const repo = Boolean(root) && isRepo(root);
  const evDir = String(evidenceDir).replace(/^\.\//, "").replace(/\/+$/, "");
  for (const raw of refs) {
    const ref = parseEvidenceRef(raw);
    const abs = path.resolve(root, ref.path);
    const rel = toPosix(path.relative(root, abs));
    if (!ref.path || !rel || rel.startsWith("..") || path.isAbsolute(rel)) { errors.push(`--evidence ${raw}: not a path inside the repository`); continue; }
    const bad = forbiddenEvidence(rel, testPaths);
    if (bad) { errors.push(`--evidence ${bad}`); continue; }
    let st = null;
    try { st = statSync(abs); } catch { /* absent */ }
    if (!st || !st.isFile()) { errors.push(`--evidence ${raw}: no such file`); continue; }
    // A capture of the evidence dir (WRONG-CAPTURE) is not versioned and has no lines: it is pinned by its sha256.
    if (under(rel, [evDir])) {
      evidence.push({ path: rel, line: null, sha256: describeFile(root, abs).sha256 });
      continue;
    }
    if (ref.line === null || ref.line < 1) { errors.push(`--evidence ${raw}: needs a line (path:line)`); continue; }
    const lines = readFileSync(abs, "utf8").split(/\r?\n/);
    const count = lines.length - (lines[lines.length - 1] === "" ? 1 : 0);
    if (ref.line > count) { errors.push(`--evidence ${raw}: ${rel} has ${count} lines`); continue; }
    if (repo) {
      if (git(root, ["ls-files", "--error-unmatch", "--", rel]).status !== 0) { errors.push(`--evidence ${raw}: ${rel} is not committed: a finding is anchored to HEAD; commit first`); continue; }
      if (git(root, ["diff", "--quiet", "HEAD", "--", rel]).status !== 0) { errors.push(`--evidence ${raw}: ${rel} has uncommitted changes: a finding is anchored to HEAD; commit first`); continue; }
    }
    evidence.push({ path: rel, line: ref.line });
  }
  return { errors, warnings, evidence };
}

/** State of one challenge: dismissed (a person's record) · stale (requirement text changed or deprecated, a cited
 *  file changed since the challenge's HEAD, a cited capture changed) · open. */
export function challengeState(root, ch, { req, dismissal, repo = true, cache = new Map(), files = new Map(), evidenceDir = DEFAULT_EVIDENCE_DIR } = {}) {
  if (dismissal) return { state: "dismissed", dismissal: { line: dismissal.line, by: dismissal.by, role: dismissal.role, reason: dismissal.reason, at: dismissal.at || null } };
  if (!req) return { state: "stale", stale_reason: `${ch.req} is not in requirements/REQUIREMENTS.md` };
  if (req.deprecated) return { state: "stale", stale_reason: "requirement deprecated" };
  if (ch.reqHash !== reqHash(req)) return { state: "stale", stale_reason: "requirement text changed since the challenge (MODIFY)" };
  const evDir = String(evidenceDir).replace(/^\.\//, "").replace(/\/+$/, "");
  const ev = Array.isArray(ch.evidence) ? ch.evidence : [];
  for (const e of ev.filter((x) => x.sha256)) {
    const now = describeFile(root, path.resolve(root, String(e.path)), files);
    if (!now.present || now.sha256 !== e.sha256) return { state: "stale", stale_reason: `capture ${e.path} changed` };
  }
  if (repo) {
    const paths = [...new Set((Array.isArray(ch.paths) && ch.paths.length ? ch.paths : ev.map((x) => x.path)).map(String))]
      .filter((p) => !under(p, [evDir]));
    const changed = paths.filter((p) => !unchangedSince(root, ch.head, [p], cache));
    if (changed.length) return { state: "stale", stale_reason: `cited code changed since ${String(ch.head || "?").slice(0, 7)}: ${changed.slice(0, 3).join(", ")}${changed.length > 3 ? ", …" : ""}` };
  }
  return { state: "open" };
}

/** Challenges with their state, for `challenge list` and the ledger. records: decisions (challenge-dismissal ones count). */
export function challengeStates(root, challenges, reqs, records, opts = {}) {
  const byId = new Map(reqs.map((r) => [r.id, r]));
  const dis = new Map();
  for (const d of records) if (d.type === "challenge-dismissal") dis.set(d.challenge, d);
  return challenges.map((c) => ({ ...c, ...challengeState(root, c, { ...opts, req: byId.get(c.req), dismissal: dis.get(c.id) }) }));
}

/** The ledger's view of one challenge (requirements[].challenges[]). */
export const challengeView = (c) => ({ id: c.id, ac: c.ac, category: c.category, counter: c.counter, quote: c.quote,
  evidence: c.evidence, verifier: c.verifier, head: c.head, at: c.at || null, state: c.state,
  ...(c.stale_reason ? { stale_reason: c.stale_reason } : {}), ...(c.dismissal ? { dismissal: c.dismissal } : {}) });

/** Video ids a FASE gate asks for, from plan/fases/FASE-N-*.md: the WF-NNN of the header's `Workflows:` line (the
 *  user-facing workflows, written by plan-architect); without that line, the WF-NNN cited inside `## Demo`; else FASE-N.
 *  Workflows cited elsewhere (Specs a Leer, notes) are reading material, not journeys to film. */
export function faseVideoIds(root, fase) {
  const { file } = faseScope(root, fase);
  const lines = file ? readFileSync(path.join(root, file), "utf8").split(/\r?\n/) : [];
  const wfIds = (text) => [...new Set((text.match(/\bWF-\d{3,}\b/gi) || []).map((x) => x.toUpperCase()))].sort();
  const end = lines.findIndex((l, i) => i > 0 && /^##\s/.test(l));
  const header = lines.slice(0, end < 0 ? 40 : end).find((l) => /\bWorkflows\b[*\s]*:/i.test(l));
  let wf = header ? wfIds(header) : [];
  if (!header) {
    const start = lines.findIndex((l) => /^##\s+Demo\b/i.test(l));
    if (start >= 0) {
      const stop = lines.findIndex((l, i) => i > start && /^##?\s/.test(l));
      wf = wfIds(lines.slice(start + 1, stop < 0 ? lines.length : stop).join("\n"));
    }
  }
  return wf.length ? wf : [`FASE-${fase}`];
}

// ------------------------------------------------------------------ fase scope
/** REQ ids of the `Requisitos:` / `Requirements:` line in the header (before the first `## `) of plan/fases/FASE-N-*.md. */
export function faseScope(root, fase) {
  const dir = path.join(root, "plan", "fases");
  if (!existsSync(dir)) return { file: null, requirements: null };
  const f = readdirSync(dir).find((x) => new RegExp(`^FASE-0*${fase}(?:[-_.].*)?\\.md$`, "i").test(x));
  if (!f) return { file: null, requirements: null };
  const lines = readFileSync(path.join(dir, f), "utf8").split(/\r?\n/);
  const end = lines.findIndex((l, i) => i > 0 && /^##\s/.test(l));
  const head = lines.slice(0, end < 0 ? 40 : end);
  const line = head.find((l) => /\b(Requisitos|Requirements)\b[*\s]*:/i.test(l));
  const ids = line ? [...new Set(line.match(new RegExp(REQ_ID.source, "g")) || [])] : [];
  return { file: `plan/fases/${f}`, requirements: ids.length ? ids : null };
}

// ------------------------------------------------------------------ evaluation
function latest(list) { return list.length ? list[list.length - 1] : null; }

/**
 * Build the ledger.
 * opts: { root, reqs, scenarios, junit: {files, cases} | null, junitSha, decisions: {records, errors}, git: gitContext,
 *         scope: Set | null, fase, now }
 */
export function evaluate(opts) {
  const { root, reqs, scenarios, junit, junitSha = null, decisions = { records: [], errors: [] }, scope = null, fase = null,
    challenges = { challenges: [], errors: [] } } = opts;
  const g = opts.git || { repo: false, head: null, headTime: null, dirty: null, dirtyPaths: [] };
  // Code paths (profile code_paths + test_paths); a git context without them falls back to the whole tree.
  const codePaths = g.codePaths || [];
  const codeTime = g.codeTime ?? g.headTime;
  const codeDirty = g.codeDirty ?? g.dirty;
  const codeDirtyPaths = g.codeDirtyPaths || g.dirtyPaths || [];
  const where = codePaths.length ? ` in ${codePaths.join(", ")}` : "";
  const cache = new Map();
  const files = new Map(); // evidence files hashed once per evaluation
  const recAtt = (r) => ({ attachments: recordAttachments(root, r.attachments, files), ...(r.dirty ? { dirty: true } : {}) });
  const settings = opts.visual ? { visual: opts.visual, dir: opts.evidenceDir || DEFAULT_EVIDENCE_DIR } : evidenceSettings(root);
  const visual = settings.visual;
  // Literal check (sdd lint --quotes): Q-02/Q-03 errors of the test files that name a criterion, unless a person
  // excepted the literal. Under enforce a passing criterion of a Must with a gap is `weakened`.
  const literal = opts.literal || literalGate(root);
  const literalGaps = literal === "off" ? new Map()
    : literalGapsByCriterion(lintQuotes({ root, reqs, scenarios, records: decisions.records }));
  const evFiles = visual === "off" ? [] : scanEvidence(root, settings.dir);
  // A file of the evidence dir bound by its name counts like a JUnit report read without --junit-sha: captured on a
  // clean tree, after the last commit that changed the code paths.
  const fileFresh = (f) => {
    if (!g.repo || !g.head) return { ok: true, why: null };
    if (codeDirty) return { ok: false, why: `uncommitted changes${where}` };
    if (f.mtimeMs < codeTime * 1000) return { ok: false, why: `captured before the last code commit${where}` };
    return { ok: true, why: null };
  };
  /** Images named after one of the criterion's scenario ids (AC-NNN-NN) or after `REQ-F-NNN-ACn`: minitest and other
   *  runners that write no [[ATTACHMENT|…]] still bind their captures to the criterion. */
  const captures = (reqId, n, scen) => evFiles
    .filter((f) => f.kind === "image" && (scen.some((s) => nameHasId(f.rel, s)) || nameHasId(f.rel, `${reqId}-AC${n}`)))
    .map((f) => { const fr = fileFresh(f); return { kind: "capture", ref: f.rel, fresh: fr.ok, ...(fr.why ? { stale_reason: fr.why } : {}), attachments: [describeFile(root, f.abs, files)] }; });
  /** Evidence that shows a criterion: a fresh passing test, a fresh capture or a fresh record, with an image present. */
  const shows = (e) => e.fresh !== false && (e.kind !== "test" || e.status === "pass") && (e.attachments || []).some((a) => a.kind === "image" && a.present);
  const untracked = g.untrackedPaths || [];
  // A record is fresh when the worktree equals its commit on its paths and no untracked file sits under them.
  const fresh = (sha, paths) => {
    if (!g.repo) return true;
    if (!sha) return false;
    const on = (paths?.length ? paths : codePaths).map((p) => String(p).replace(/^\.\//, "").replace(/\/+$/, ""));
    if (untracked.some((p) => !on.length || under(p, on))) return false;
    return unchangedSince(root, sha, on, cache);
  };

  // JUnit freshness per file.
  const junitFresh = new Map();
  for (const f of junit?.files || []) {
    let ok = true, why = null;
    if (g.repo && g.head) {
      if (codeDirty) { ok = false; why = `uncommitted changes${where}: ${codeDirtyPaths.slice(0, 3).join(", ")}${untracked.length ? ` (untracked: ${untracked.slice(0, 3).join(", ")})` : ""}`; }
      else if (junitSha) { ok = fresh(junitSha); if (!ok) why = `code changed since ${junitSha.slice(0, 7)}${where}`; }
      else if (f.mtimeMs < codeTime * 1000) { ok = false; why = `report older than the last code commit${where}`; }
    }
    junitFresh.set(f.path, { ok, why });
  }
  const rel = (p) => path.relative(root, p) || p;

  const { byScenario, byCriterion } = scenarioIndex(scenarios);

  // Tests bound to (req, n).
  const testsByCriterion = new Map(), unboundTests = [], unknownScenarios = new Set();
  const addTest = (req, n, c, via) => {
    const k = `${req}#${n}`;
    if (!testsByCriterion.has(k)) testsByCriterion.set(k, []);
    const jf = junitFresh.get(c.source) || { ok: true, why: null };
    testsByCriterion.get(k).push({ name: c.name, classname: c.classname, file: c.file, status: c.status, message: c.message,
      via, fresh: jf.ok, stale_reason: jf.why, report: c.source ? rel(c.source) : null,
      attachments: (c.attachments || []).map((a) => resolveAttachment(root, c.source, a, files)) });
  };
  for (const c of junit?.cases || []) {
    const keys = testKeys(`${c.classname || ""} ${c.name}`);
    let bound = false;
    for (const sid of keys.scenarios) {
      const targets = byScenario.get(sid);
      if (!targets) { unknownScenarios.add(sid); continue; }
      for (const t of targets) { addTest(t.req, t.n, c, sid); bound = true; }
    }
    for (const ra of keys.reqAcs) { addTest(ra.req, ra.ac, c, `${ra.req} AC${ra.ac}`); bound = true; }
    if (!bound && (keys.scenarios.length || keys.reqAcs.length)) unboundTests.push(c.name);
  }

  const recs = decisions.records;
  const staleDecisions = [];
  const requirements = [];
  const specTests = existsSync(path.join(root, "spec", "tests"));

  for (const req of reqs) {
    const hash = reqHash(req);
    const priority = effectivePriority(req);
    const method = VERIFICATION_METHODS.includes(req.verification) ? req.verification : null;
    const base = { id: req.id, type: req.type, title: req.title, priority, needs: req.needs || [], verification: method,
      verification_raw: method ? null : req.verification, reqHash: hash,
      in_scope: scope ? scope.has(req.id) : true, [SPEC_TESTS]: specTests };
    const mine = recs.filter((r) => r.req === req.id && r.type !== "challenge-dismissal");
    if (req.deprecated) {
      requirements.push({ ...base, verdict: "DEPRECATED", reason: null, criteria: [], criteria_total: 0, criteria_passing: 0, evidence: [], waiver: null, stale_evidence: false });
      continue;
    }
    // Hash-bound records: a different hash means the requirement text changed after the decision.
    const current = [];
    for (const r of mine) {
      if (r.reqHash && r.reqHash !== hash) { staleDecisions.push({ line: r.line, type: r.type, req: req.id, reason: "requirement text changed since the decision (MODIFY)" }); continue; }
      if (!r.reqHash && (r.type === "waiver" || r.type === "inspection")) { staleDecisions.push({ line: r.line, type: r.type, req: req.id, reason: "record has no reqHash" }); continue; }
      current.push(r);
    }
    const n = Math.max(1, req.criteria.length);
    const criteria = [];
    const inspection = method === "inspection" ? latest(current.filter((r) => r.type === "inspection")) : null;
    let inspectionState = null;
    if (method === "inspection") {
      if (!inspection) inspectionState = { state: "missing", evidence: [] };
      else {
        const ok = fresh(inspection.head, inspection.paths);
        if (!ok) staleDecisions.push({ line: inspection.line, type: "inspection", req: req.id, reason: `files changed since ${String(inspection.head || "?").slice(0, 7)}${inspection.paths?.length ? ` in ${inspection.paths.join(", ")}` : where}` });
        inspectionState = { state: !ok ? "stale" : inspection.pass === false ? "fail" : "pass",
          evidence: [{ kind: "inspection", ref: `${DECISIONS_FILE}:${inspection.line}`, by: inspection.by, role: inspection.role, note: inspection.note, fresh: ok, ...recAtt(inspection) }] };
      }
    }
    for (let i = 1; i <= n; i++) {
      const text = req.criteria[i - 1] || null;
      const scen = [...(byCriterion.get(`${req.id}#${i}`) || []), ...(req.criteria.length ? [] : [...(byCriterion.get(`${req.id}#0`) || [])])];
      const tests = [...(testsByCriterion.get(`${req.id}#${i}`) || []), ...(req.criteria.length ? [] : (testsByCriterion.get(`${req.id}#0`) || []))];
      const c = { n: i, text, scenarios: [...new Set(scen)], tests, records: [], state: "missing", evidence: [] };
      if (method === "test") {
        const live = tests.filter((t) => t.fresh && t.status !== "skip");
        if (live.some((t) => t.status === "fail" || t.status === "error")) c.state = "fail";
        else if (live.some((t) => t.status === "pass")) c.state = "pass";
        else if (tests.some((t) => !t.fresh && t.status !== "skip")) c.state = "stale";
        c.evidence = tests.map((t) => ({ kind: "test", ref: t.via, name: t.name, status: t.status, fresh: t.fresh, attachments: t.attachments }));
      } else if (method === "demo" || method === "measurement") {
        const r = latest(current.filter((x) => x.type === method && (acNumber(x.ac) === null || acNumber(x.ac) === i)));
        if (r) {
          const ok = fresh(r.head, r.paths);
          const pass = method === "demo" ? r.pass === true : compareMeasurement(r);
          if (!ok) staleDecisions.push({ line: r.line, type: method, req: req.id, ac: i, reason: `files changed since ${String(r.head || "?").slice(0, 7)}${r.paths?.length ? ` in ${r.paths.join(", ")}` : where}` });
          c.state = !ok ? "stale" : pass === true ? "pass" : "fail";
          c.records.push(r.line);
          c.evidence = [{ kind: method, ref: `${DECISIONS_FILE}:${r.line}`, fresh: ok, pass: pass === true,
            ...(method === "measurement" ? { metric: r.metric, observed: Number(r.observed), op: r.op, threshold: Number(r.threshold),
              by: r.by, ...(r.command ? { command: r.command } : {}) } : { observed: r.observed }), ...recAtt(r) }];
        }
      } else if (method === "inspection") {
        c.state = inspectionState.state;
        c.evidence = inspectionState.evidence;
        if (inspection) c.records.push(inspection.line);
      }
      if (req.type === "F" && visual !== "off") c.evidence.push(...captures(req.id, i, c.scenarios));
      if (literal !== "off") {
        c.literal_gaps = literalGaps.get(`${req.id}#${i}`) || [];
        if (literal === "enforce" && priority === "Must" && method === "test" && c.state === "pass" && c.literal_gaps.length) c.state = "weakened";
      }
      criteria.push(c);
    }
    // Visual evidence (REQ-F): a criterion is shown to the customer only with a screenshot. `required` holds a passing
    // criterion without one as `unshown` (the requirement is not VERIFIED); `warn` reports it and keeps the state.
    if (req.type === "F" && visual !== "off") {
      for (const c of criteria) {
        c.visual = c.evidence.some(shows) ? "shown" : "missing";
        if (visual === "required" && c.state === "pass" && c.visual === "missing") c.state = "unshown";
      }
    }
    // Waiver: the latest current one; a Must waiver without reason, role and follow-up issue is not valid.
    const w = latest(current.filter((r) => r.type === "waiver"));
    let waiver = null;
    if (w) {
      const missing = ["reason", "by", "role"].filter((k) => !w[k]);
      if (priority === "Must" && !w.followUp) missing.push("followUp");
      waiver = { line: w.line, reason: w.reason || null, by: w.by || null, role: w.role || null, followUp: w.followUp || null, at: w.at || null, valid: missing.length === 0, missing };
      if (!waiver.valid) staleDecisions.push({ line: w.line, type: "waiver", req: req.id, reason: `waiver lacks ${missing.join(", ")}` });
    }
    const passing = criteria.filter((c) => c.state === "pass").length;
    let verdict;
    if (waiver?.valid) verdict = "WAIVED";
    else if (criteria.some((c) => c.state === "fail")) verdict = "FAILING";
    else if (!method || passing < criteria.length) verdict = "MISSING";
    else verdict = "VERIFIED";
    const evidence = criteria.flatMap((c) => c.evidence.map((e) => ({ ac: c.n, ...e })));
    const heldBack = verdict === "MISSING" && criteria.every((c) => ["pass", "unshown", "weakened"].includes(c.state));
    const reason = !heldBack ? null : criteria.some((c) => c.state === "weakened") ? "test does not carry the criterion's literal"
      : criteria.some((c) => c.state === "unshown") ? "no visual evidence" : null;
    requirements.push({ ...base, verdict, reason, criteria, criteria_total: criteria.length, criteria_passing: passing, evidence, waiver,
      stale_evidence: verdict === "MISSING" && criteria.some((c) => c.state === "stale") });
  }

  // Fase acceptances: the latest per FASE, stale when any requirement it covered changed text.
  const hashes = new Map(requirements.map((r) => [r.id, r.reqHash]));
  const faseAcc = new Map();
  for (const r of recs.filter((x) => x.type === "fase-acceptance")) faseAcc.set(r.fase, r);
  const faseAcceptances = [...faseAcc.values()].map((r) => {
    const changed = Object.entries(r.reqHashes || {}).filter(([id, h]) => hashes.get(id) !== h).map(([id]) => id);
    if (changed.length) staleDecisions.push({ line: r.line, type: "fase-acceptance", fase: r.fase, reason: `requirement text changed: ${changed.join(", ")}` });
    return { fase: r.fase, result: r.result, by: r.by, role: r.role, channel: r.channel, head: r.head, at: r.at || null,
      demo: r.demo || null, line: r.line, stale: changed.length > 0, changed, ...recAtt(r) };
  });

  // Video per FASE: each id of faseVideoIds (WF-NNN or FASE-N) needs a present video whose name carries it, from a
  // fresh JUnit attachment, a fresh file of the evidence dir or a decision record.
  let videos = null;
  if (fase !== null && fase !== undefined && visual !== "off") {
    const wanted = faseVideoIds(root, fase);
    const found = [];
    for (const c of junit?.cases || []) {
      if (!(junitFresh.get(c.source)?.ok ?? true) || c.status === "skip") continue;
      for (const a of c.attachments || []) { const d = resolveAttachment(root, c.source, a, files); if (d.kind === "video" && d.present) found.push(d.path); }
    }
    for (const f of evFiles) if (f.kind === "video" && fileFresh(f).ok) found.push(f.rel);
    for (const r of recs) for (const a of recordAttachments(root, r.attachments, files)) if (a.kind === "video" && a.present) found.push(a.path);
    const all = [...new Set(found)].sort();
    videos = { required: wanted, found: all.filter((p) => wanted.some((id) => nameHasId(p, id))), missing: wanted.filter((id) => !all.some((p) => nameHasId(p, id))) };
  }

  // Adversarial challenges: next to the verdict, never changing it.
  const adversarial = opts.adversarial || adversarialGate(root);
  const chStates = challengeStates(root, challenges.challenges || [], reqs, recs, { repo: Boolean(g.repo), cache, files, evidenceDir: settings.dir });
  for (const r of requirements) r.challenges = chStates.filter((c) => c.req === r.id).map(challengeView);
  const unknownChallenges = chStates.filter((c) => !requirements.some((r) => r.id === c.req)).map((c) => c.id);

  const summary = summarize(requirements.filter((r) => r.in_scope));
  if (videos) {
    summary.missing_videos = videos.missing;
    if (visual === "required" && videos.missing.length) summary.goal = false;
  }
  summary.stale_decisions = staleDecisions.length;
  summary.junit_files = (junit?.files || []).length;
  summary.junit_stale_files = [...junitFresh.values()].filter((x) => !x.ok).length;
  const ledger = {
    $schema: SCHEMA, evaluated_sha: g.head, dirty: g.dirty, untracked_paths: untracked, generatedAt: (opts.now || new Date()).toISOString(),
    scope: scope ? { fase, requirements: [...scope] } : null,
    junit: (junit?.files || []).map((f) => ({ path: rel(f.path), cases: f.cases.length, fresh: junitFresh.get(f.path).ok, stale_reason: junitFresh.get(f.path).why })),
    junit_sha: junitSha,
    spec_tests: specTests,
    visual_evidence: visual, evidence_dir: settings.dir, videos, literal_gate: literal,
    requirements, summary,
    fase_acceptances: faseAcceptances,
    stale_decisions: staleDecisions,
    decision_errors: decisions.errors,
    adversarial_gate: adversarial, challenge_errors: challenges.errors || [], unknown_challenges: unknownChallenges,
    unknown_scenarios: [...unknownScenarios].sort(),
    unbound_tests: unboundTests,
  };
  if (scope) ledger.summary_all = summarize(requirements);
  return ledger;
}

export function summarize(list) {
  const by_priority = {}, by_verdict = Object.fromEntries(VERDICTS.map((v) => [v, 0]));
  for (const r of list) {
    by_verdict[r.verdict]++;
    if (r.verdict === "DEPRECATED") continue;
    const k = r.priority || "Unspecified";
    by_priority[k] ||= { total: 0, VERIFIED: 0, FAILING: 0, MISSING: 0, WAIVED: 0 };
    by_priority[k].total++;
    by_priority[k][r.verdict]++;
  }
  const musts = list.filter((r) => r.verdict !== "DEPRECATED" && r.priority === "Must");
  const must_verified = musts.filter((r) => r.verdict === "VERIFIED").length;
  const waived = musts.filter((r) => r.verdict === "WAIVED");
  const challenged = musts.filter((r) => r.verdict !== "WAIVED" && (r.challenges || []).some((c) => c.state === "open"));
  return {
    active: list.filter((r) => r.verdict !== "DEPRECATED").length, deprecated: by_verdict.DEPRECATED,
    by_verdict, by_priority, must_total: musts.length, must_verified, must_waived: waived.length,
    goal: musts.every((r) => r.verdict === "VERIFIED" || r.verdict === "WAIVED"),
    waived_musts: waived.map((r) => r.id),
    stale_evidence: list.filter((r) => r.stale_evidence).length,
    // Adversarial round: open challenges (any priority) and the Musts carrying at least one (the enforce gate's input).
    // A waived Must is deferred by a person, so its challenges are shown but do not count here.
    challenges_open: list.flatMap((r) => r.challenges || []).filter((c) => c.state === "open").length,
    must_challenged: challenged.length,
    challenged_musts: challenged.map((r) => r.id),
    // REQ-F criteria whose tests pass without a screenshot (state unshown under `required`, still pass under `warn`).
    unshown: list.filter((r) => r.verdict !== "DEPRECATED" && r.verdict !== "WAIVED")
      .flatMap((r) => r.criteria || []).filter((c) => c.visual === "missing" && (c.state === "pass" || c.state === "unshown")).length,
    // Criteria whose test file lacks the criterion's letter (Q-02/Q-03 of sdd lint --quotes, not excepted), and those
    // held back as `weakened` under literal_gate enforce (Musts).
    literal_gaps: list.filter((r) => r.verdict !== "DEPRECATED" && r.verdict !== "WAIVED")
      .flatMap((r) => r.criteria || []).filter((c) => (c.literal_gaps || []).length).length,
    weakened: list.flatMap((r) => r.criteria || []).filter((c) => c.state === "weakened").length,
  };
}

// ------------------------------------------------------------------ loop routing
/** A stale measurement whose latest record has a command: `sdd accept --remeasure` re-runs it, no person needed. */
const remeasurable = (c) => c.state === "stale" && c.evidence.some((e) => e.kind === "measurement" && e.command);

/** A criterion with neither a scenario nor a test: without spec/tests there is no scenario layer to fill in, so the
 *  criterion itself is the contract and the work is a test named after it (`REQ-X-NNN ACn`); with spec/tests the
 *  missing scenario is a spec gap for a human. `ctx.specTests` overrides the flag stored on the requirement. */
const uncovered = (c) => !c.scenarios.length && !c.tests.length;
const specGapFor = (r, ctx) => ((ctx && ctx.specTests !== undefined ? ctx.specTests : r[SPEC_TESTS]) === false ? ROUTES.implement : ROUTES.specGap);

/** Deterministic route hint for a requirement that is not VERIFIED / WAIVED / DEPRECATED. */
export function routeHint(r, ctx) {
  if (r.verdict === "FAILING") return ROUTES.fix;
  if (!r.verification) return ROUTES.specGap;
  const open = r.criteria.filter((c) => c.state !== "pass");
  if (open.length && open.every((c) => c.state === "weakened" || c.state === "unshown") && open.some((c) => c.state === "weakened")) return ROUTES.weakened;
  if (open.length && open.every((c) => c.state === "unshown")) return ROUTES.capture;
  if (r.verification === "measurement" && open.length && open.every(remeasurable)) return ROUTES.remeasure;
  if (r.verification !== "test") return ROUTES.human;
  if (open.some((c) => uncovered(c))) return specGapFor(r, ctx);
  if (open.every((c) => c.state === "stale")) return ROUTES.rerun;
  return ROUTES.implement;
}
export function criterionHint(r, c, ctx) {
  if (c.state === "pass") return null;
  if (c.state === "fail") return ROUTES.fix;
  if (c.state === "unshown") return ROUTES.capture;
  if (c.state === "weakened") return ROUTES.weakened;
  if (!r.verification) return ROUTES.specGap;
  if (r.verification === "measurement" && remeasurable(c)) return ROUTES.remeasure;
  if (r.verification !== "test") return ROUTES.human;
  if (uncovered(c)) return specGapFor(r, ctx);
  if (c.state === "stale") return ROUTES.rerun;
  return ROUTES.implement;
}

// ------------------------------------------------------------------ report
const cell = (s) => String(s ?? "").replace(/\|/g, "\\|").replace(/\s+/g, " ").trim();
const clip = (t, n = 80) => { const x = String(t ?? ""); return x.length > n ? `${x.slice(0, n - 1)}…` : x; };
/** Tests of one criterion, summarised: counts plus at most 2 names; failing tests always listed (up to 5).
 *  The full list stays in .sdd/acceptance.json, so a report or PR body stays readable at any suite size. */
function testSummary(n, evidence) {
  const tests = evidence.filter((e) => e.kind === "test" && e.status !== "skip");
  if (!tests.length) return null;
  const name = (e) => `"${clip(e.name)}"`;
  const failing = tests.filter((e) => e.fresh && (e.status === "fail" || e.status === "error"));
  const passing = tests.filter((e) => e.fresh && e.status === "pass");
  const stale = tests.filter((e) => !e.fresh);
  const plural = (k) => `${k} test${k === 1 ? "" : "s"}`;
  if (failing.length) {
    const shown = failing.slice(0, 5).map((e) => `${name(e)} (${e.status})`);
    const more = failing.length > 5 ? ` +${failing.length - 5} more` : "";
    return `AC${n}: ${failing.length} of ${plural(tests.length)} fail — ${shown.join(", ")}${more}`;
  }
  if (passing.length) {
    const more = passing.length > 2 ? ` +${passing.length - 2} more` : "";
    return `AC${n}: ${plural(passing.length)} pass — ${passing.slice(0, 2).map(name).join(", ")}${more}${stale.length ? ` (${stale.length} stale)` : ""}`;
  }
  return `AC${n}: ${plural(stale.length)} stale — ${name(stale[0])}${stale.length > 1 ? ` +${stale.length - 1} more` : ""}`;
}
function evidenceCell(r) {
  if (r.verdict === "WAIVED") return `waiver ${DECISIONS_FILE}:${r.waiver.line}`;
  const parts = [];
  for (const c of r.criteria) {
    const t = testSummary(c.n, c.evidence);
    if (t) parts.push(t);
    for (const e of c.evidence) {
      if (e.kind === "test" || e.kind === "capture") continue;
      const mark = !e.fresh ? "stale" : (e.kind === "inspection" ? (c.state === "pass" ? "pass" : c.state) : (e.pass ? "pass" : "fail"));
      if (e.kind === "measurement") parts.push(`AC${c.n} ${e.metric} ${e.observed} ${e.op} ${e.threshold} — ${e.ref} (${mark})`);
      else if (e.kind === "inspection") { if (c.n === 1) parts.push(`inspection by ${e.by} (${e.role}) — ${e.ref} (${mark})`); }
      else parts.push(`AC${c.n} demo — ${e.ref} (${mark})`);
    }
    if (c.visual) { const img = screenshotOf(c); parts.push(img ? `AC${c.n} screenshot ${img}` : `AC${c.n} no screenshot`); }
    for (const gap of c.literal_gaps || []) parts.push(`AC${c.n} ${gapText(gap)}`);
  }
  return parts.length ? parts.join("; ") : "—";
}
/** First screenshot that shows the criterion (same rule as the ledger), or null. */
function screenshotOf(c) {
  for (const e of c.evidence) {
    if (e.fresh === false || (e.kind === "test" && e.status !== "pass")) continue;
    const a = (e.attachments || []).find((x) => x.kind === "image" && x.present);
    if (a) return a.path;
  }
  return null;
}
const openOf = (r) => (r.challenges || []).filter((c) => c.state === "open");
const verdictCell = (r) => `${r.verdict}${r.reason ? ` (${r.reason})` : ""}${r.stale_evidence ? " (stale evidence)" : ""}${openOf(r).length ? ` · challenged ${openOf(r).map((c) => c.id).join(", ")}` : ""}`;
/** One line on open adversarial challenges for the PR block and the report, or null when there is none. */
function adversarialLine(ledger) {
  const open = ledger.requirements.filter((r) => r.in_scope).flatMap((r) => openOf(r).map((c) => `${c.id} ${r.id} AC${c.ac} ${c.category}`));
  if (!open.length) return null;
  const musts = ledger.summary.must_challenged || 0;
  return `Adversarial (\`adversarial_gate: ${ledger.adversarial_gate || "enforce"}\`): ${open.length} open challenge${open.length === 1 ? "" : "s"}${musts ? `, ${musts} on Must requirement${musts === 1 ? "" : "s"}` : ""} (${open.slice(0, 6).join(", ")}${open.length > 6 ? ", …" : ""}) — route adversarial-finding; the verdicts do not change.`;
}
const gapText = (g) => g.code === "Q-02" ? `quote not current (Q-02 ${g.file}:${g.line})` : `literal "${clip(g.literal, 40)}" not in the test (Q-03 ${g.file}:${g.line})`;
/** One line on literal gaps (sdd lint --quotes) for the PR block and the report, or null when there is none. */
function literalLine(ledger) {
  const mode = ledger.literal_gate;
  if (!mode || mode === "off") return null;
  const crit = ledger.requirements.filter((r) => r.in_scope && r.verdict !== "WAIVED" && r.verdict !== "DEPRECATED")
    .flatMap((r) => (r.criteria || []).filter((c) => (c.literal_gaps || []).length).map((c) => `${r.id} AC${c.n}${c.state === "weakened" ? " weakened" : ""}`));
  if (!crit.length) return null;
  return `Literal letter (\`literal_gate: ${mode}\`): ${crit.length} criteri${crit.length === 1 ? "on" : "a"} whose test lacks the criterion's quote or literal (${crit.slice(0, 8).join(", ")}${crit.length > 8 ? ", …" : ""}) — route weakened-test (a test edit a person approves); \`sdd lint --quotes\` lists them.`;
}
/** One line on visual evidence for the PR block and the report, or null when the rule is off or nothing is missing. */
function visualLine(ledger) {
  const mode = ledger.visual_evidence, s = ledger.summary;
  if (!mode || mode === "off") return null;
  const missing = s.missing_videos || [];
  if (!s.unshown && !missing.length) return null;
  const crit = ledger.requirements.filter((r) => r.in_scope && r.verdict !== "WAIVED" && r.verdict !== "DEPRECATED")
    .flatMap((r) => (r.criteria || []).filter((c) => c.visual === "missing" && (c.state === "pass" || c.state === "unshown")).map((c) => `${r.id} AC${c.n}`));
  const parts = [];
  if (crit.length) parts.push(`${crit.length} criteri${crit.length === 1 ? "on" : "a"} without a screenshot (${crit.slice(0, 8).join(", ")}${crit.length > 8 ? ", …" : ""})`);
  if (missing.length) parts.push(`missing video${missing.length === 1 ? "" : "s"}: ${missing.join(", ")}`);
  return `Visual evidence (${mode}): ${parts.join("; ")} — route capture-evidence.`;
}

export function renderReport(ledger) {
  const s = ledger.summary;
  const date = ledger.generatedAt.slice(0, 10);
  const sha = ledger.evaluated_sha ? ledger.evaluated_sha.slice(0, 12) : "(no git)";
  const o = ["# Acceptance Report", "",
    `> Evaluated at \`${sha}\`${ledger.dirty ? " (uncommitted changes present)" : ""} · ${date} · generated by \`sdd accept\` — do not edit by hand.`,
    `> Scope: ${ledger.scope ? `FASE ${ledger.scope.fase} (${ledger.scope.requirements.join(", ")})` : "all requirements"}`, ""];
  const prio = Object.entries(s.by_priority).map(([k, v]) => `${k} ${v.VERIFIED}/${v.total} verified${v.WAIVED ? `, ${v.WAIVED} waived` : ""}`).join(" · ");
  o.push(`**Goal: ${s.goal ? (s.must_waived ? "met with waivers" : "met") : "not met"}** — every Must requirement verified or waived. ${prio || "No active requirements."}`, "");
  o.push("## Waived Must requirements", "");
  const waived = ledger.requirements.filter((r) => r.in_scope && r.verdict === "WAIVED" && r.priority === "Must");
  if (!waived.length) o.push("None.", "");
  else {
    o.push("| Requirement | Title | Reason | Approved by | Follow-up |", "|---|---|---|---|---|");
    for (const r of waived) o.push(`| ${r.id} | ${cell(r.title)} | ${cell(r.waiver.reason)} | ${cell(`${r.waiver.by} (${r.waiver.role})`)} | ${cell(r.waiver.followUp || "—")} |`);
    o.push("");
  }
  o.push("## Requirements", "", "| ID | Title | Priority | Needs | Verification | Verdict | Criteria | Evidence |", "|---|---|---|---|---|---|---|---|");
  for (const r of ledger.requirements.filter((x) => x.in_scope && x.verdict !== "DEPRECATED")) {
    o.push(`| ${r.id} | ${cell(r.title)} | ${cell(r.priority || "—")} | ${cell(r.needs.join(", ") || "—")} | ${cell(r.verification || r.verification_raw || "—")} | ${verdictCell(r)} | ${r.criteria_passing}/${r.criteria_total} | ${cell(evidenceCell(r))} |`);
  }
  if (ledger.visual_evidence && ledger.visual_evidence !== "off") {
    o.push("", "## Visual evidence", "",
      `Rule \`visual_evidence: ${ledger.visual_evidence}\` · screenshots and videos under \`${ledger.evidence_dir || DEFAULT_EVIDENCE_DIR}/\` (not versioned; \`sdd accept pack --fase N\` bundles them). ${visualLine(ledger) || "Every functional criterion in scope is shown."}`, "");
    const rows = ledger.requirements.filter((r) => r.in_scope && r.verdict !== "DEPRECATED" && r.verdict !== "WAIVED")
      .flatMap((r) => (r.criteria || []).filter((c) => c.visual).map((c) => `| ${r.id} | AC${c.n} | ${c.state} | ${cell(screenshotOf(c) || "none")} |`));
    if (rows.length) o.push("| Requirement | Criterion | State | Screenshot |", "|---|---|---|---|", ...rows, "");
    if (ledger.videos) o.push(`Videos for FASE ${ledger.scope?.fase ?? "?"}: ${ledger.videos.required.map((id) => `${id} ${ledger.videos.missing.includes(id) ? "missing" : "present"}`).join(" · ")}.`);
  }
  if (literalLine(ledger)) {
    o.push("", "## Literal letter", "", `Tests that name a criterion must quote it and assert each of its literals (\`sdd lint --quotes\`). ${literalLine(ledger)}`, "",
      "| Requirement | Criterion | State | Gap |", "|---|---|---|---|");
    for (const r of ledger.requirements.filter((x) => x.in_scope && x.verdict !== "WAIVED" && x.verdict !== "DEPRECATED"))
      for (const c of (r.criteria || []).filter((x) => (x.literal_gaps || []).length))
        o.push(`| ${r.id} | AC${c.n} | ${c.state} | ${cell(c.literal_gaps.map(gapText).join("; "))} |`);
  }
  const challenged = ledger.requirements.filter((r) => r.in_scope && (r.challenges || []).length);
  if (challenged.length) {
    o.push("", "## Adversarial challenges", "",
      `Findings of the adversarial round (\`${CHALLENGES_FILE}\`) that sit next to the verdicts without changing them: \`open\` until the cited code or the requirement changes (\`stale\`) or a person dismisses it. Gate \`adversarial_gate: ${ledger.adversarial_gate || "enforce"}\`. ${adversarialLine(ledger) || "No challenge is open."}`, "",
      "| Challenge | Requirement | Criterion | Category | Counter | State | Quote | Evidence |", "|---|---|---|---|---|---|---|---|");
    for (const r of challenged) for (const c of r.challenges) {
      const state = c.state === "stale" ? `stale (${c.stale_reason})` : c.state === "dismissed" ? `dismissed by ${c.dismissal.by} (${c.dismissal.role}): ${c.dismissal.reason}` : "open";
      o.push(`| ${c.id} | ${r.id} | AC${c.ac} | ${c.category} | ${c.counter} | ${cell(state)} | ${cell(`"${clip(c.quote)}"`)} | ${cell((c.evidence || []).map((e) => e.line ? `${e.path}:${e.line}` : e.path).join(", "))} |`);
    }
  }
  o.push("", "## Deprecated", "");
  const dep = ledger.requirements.filter((r) => r.in_scope && r.verdict === "DEPRECATED");
  if (!dep.length) o.push("None.");
  else { o.push("| ID | Title |", "|---|---|"); for (const r of dep) o.push(`| ${r.id} | ${cell(r.title)} |`); }
  o.push("", "## Decisions to re-confirm", "");
  if (!ledger.stale_decisions.length) o.push("None.");
  else {
    o.push("| Record | Type | Subject | Why |", "|---|---|---|---|");
    for (const d of ledger.stale_decisions) o.push(`| ${DECISIONS_FILE}:${d.line} | ${d.type} | ${d.req ? d.req + (d.ac ? ` AC${d.ac}` : "") : `FASE ${d.fase}`} | ${cell(d.reason)} |`);
  }
  if (ledger.fase_acceptances.length) {
    o.push("", "## FASE acceptances", "", "| FASE | Result | By | Channel | Commit | Current |", "|---|---|---|---|---|---|");
    for (const f of ledger.fase_acceptances) o.push(`| ${f.fase} | ${f.result} | ${cell(`${f.by} (${f.role})`)} | ${cell(f.channel)} | ${String(f.head || "").slice(0, 7)} | ${f.stale ? `no — changed: ${f.changed.join(", ")}` : "yes"} |`);
  }
  return o.join("\n") + "\n";
}

/** PR-body block for `sdd gate --md`. */
export function renderPrBlock(ledger, code) {
  const s = ledger.summary;
  const rows = ledger.requirements.filter((r) => r.in_scope && r.verdict !== "DEPRECATED");
  const sha = ledger.evaluated_sha ? ledger.evaluated_sha.slice(0, 7) : "no-git";
  const o = [`### Acceptance${ledger.scope ? ` — FASE ${ledger.scope.fase}` : ""} (evaluated at \`${sha}\`, gate exit ${code})`, "",
    `Goal: **${s.goal ? (s.must_waived ? "met with waivers" : "met") : "not met"}** — Must ${s.must_verified}/${s.must_total} verified${s.must_waived ? `, ${s.must_waived} waived (${s.waived_musts.join(", ")})` : ""}.`, "",
    ...(visualLine(ledger) ? [visualLine(ledger), ""] : []),
    ...(literalLine(ledger) ? [literalLine(ledger), ""] : []),
    ...(adversarialLine(ledger) ? [adversarialLine(ledger), ""] : []),
    "| Requirement | Priority | Verification | Verdict | Criteria | Evidence |", "|---|---|---|---|---|---|"];
  for (const r of rows) o.push(`| ${r.id} ${cell(r.title)} | ${cell(r.priority || "—")} | ${cell(r.verification || "—")} | ${verdictCell(r).replace(" (stale evidence)", "")} | ${r.criteria_passing}/${r.criteria_total} | ${cell(evidenceCell(r))} |`);
  o.push("", `Refs: ${rows.map((r) => r.id).join(", ") || "—"}`);
  return o.join("\n") + "\n";
}
