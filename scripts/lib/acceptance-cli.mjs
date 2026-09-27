// acceptance-cli.mjs — `sdd lint --needs`, `sdd accept`, `sdd accept record`, `sdd gate`, `sdd loop next`.
// Node >= 18, no dependencies. Called from scripts/sdd.mjs; returns an exit code (never calls process.exit).
import { existsSync, readFileSync, writeFileSync, mkdirSync, appendFileSync } from "node:fs";
import path from "node:path";
import { git, stackProfile } from "./git-log.mjs";
import { readJUnit } from "./junit.mjs";
import {
  SCHEMA, RECORD_TYPES, DECISIONS_FILE, ROUTES, evaluate, gitContext, loadScenarios, readDecisions,
  validateRecord, reqHash, faseScope, renderReport, renderPrBlock, routeHint, criterionHint, unchangedSince, acNumber,
} from "./acceptance.mjs";
import { parseRequirements, parseNeeds, checkNeedCoverage } from "../sdd-jev.mjs";

class Exit extends Error { constructor(code) { super(`exit ${code}`); this.code = code; } }
let PROG = "sdd";
const out = (s) => console.log(s);
const usage = (msg) => { console.error(`${PROG}: ${msg} (see --help)`); throw new Exit(2); };
const die = (msg) => { console.error(`${PROG}: ${msg}`); throw new Exit(2); };

// Options that take a value; those in MULTI also swallow the following non-option words (`--junit a.xml b.xml`).
const VALUED = new Set(["repo", "junit", "junit-sha", "fase", "out", "report", "mode", "ledger", "state", "max-cycles",
  "req", "ac", "by", "role", "reason", "follow-up", "observed", "pass", "metric", "op", "threshold", "paths", "note",
  "result", "channel", "demo", "requirements", "decisions"]);
const MULTI = new Set(["junit", "paths"]);
const FLAGS = new Set(["json", "md", "needs", "reset", "no-out", "help"]);

function parse(argv) {
  const o = { _: [], junit: [], paths: [] };
  for (let i = 0; i < argv.length; i++) {
    let a = argv[i], v;
    if (a === "-h") a = "--help";
    if (!a.startsWith("--") || a === "--") { o._.push(a); continue; }
    const eq = a.match(/^--([a-z-]+)=(.*)$/s);
    const k = eq ? eq[1] : a.slice(2);
    if (FLAGS.has(k)) { o[k] = true; continue; }
    if (!VALUED.has(k)) usage(`unknown option --${k}`);
    if (eq) v = eq[2];
    else { if (i + 1 >= argv.length) usage(`--${k} needs a value`); v = argv[++i]; }
    if (MULTI.has(k)) {
      o[k].push(...v.split(",").filter(Boolean));
      while (!eq && i + 1 < argv.length && !argv[i + 1].startsWith("-")) o[k].push(...argv[++i].split(",").filter(Boolean));
    } else o[k] = v;
  }
  if (o.fase !== undefined) {
    o.fase = Number(String(o.fase).replace(/^FASE-/i, ""));
    if (!Number.isInteger(o.fase)) usage("--fase needs a number");
  }
  return o;
}

function rootOf(o) { return path.resolve(o.repo || "."); }
function readReqs(root, o) {
  const f = path.resolve(root, o.requirements || "requirements/REQUIREMENTS.md");
  if (!existsSync(f)) die(`${path.relative(process.cwd(), f) || f} not found`);
  const reqs = parseRequirements(readFileSync(f, "utf8"));
  if (!reqs.length) die(`no "### REQ-…" blocks in ${f}`);
  return reqs;
}

// ------------------------------------------------------------------ lint --needs
function cmdLintNeeds(o) {
  const root = rootOf(o);
  const needsFile = path.resolve(root, o._[0] || "requirements/CUSTOMER-NEEDS.md");
  const reqFile = path.resolve(root, o._[1] || "requirements/REQUIREMENTS.md");
  for (const f of [needsFile, reqFile]) if (!existsSync(f)) die(`${f} not found`);
  const reqText = readFileSync(reqFile, "utf8");
  const needs = parseNeeds(readFileSync(needsFile, "utf8"));
  const reqs = parseRequirements(reqText);
  if (!needs.length) die(`no "### N-…" blocks in ${needsFile}`);
  if (!reqs.length) die(`no "### REQ-…" blocks in ${reqFile}`);
  const r = checkNeedCoverage(needs, reqs, reqText);
  if (o.json) out(JSON.stringify({ source: { needs: needsFile, requirements: reqFile }, ...r }, null, 2));
  else {
    for (const e of r.errors) out(`error  ${e.code}  ${e.msg}`);
    for (const w of r.warnings) out(`warning  ${w.code}  ${w.msg}`);
    out(`lint --needs: ${r.needs} needs (${r.outOfScope} out-of-scope), ${r.requirements} requirements, ${r.errors.length} error(s), ${r.warnings.length} warning(s), Must ${Math.round(r.mustRatio * 100)} %`);
  }
  return r.errors.length ? 1 : 0;
}

// ------------------------------------------------------------------ ledger
function scopeFor(root, reqs, fase) {
  if (fase === undefined) return null;
  const fs = faseScope(root, fase);
  const ids = fs.requirements || reqs.filter((r) => !r.deprecated).map((r) => r.id);
  return { set: new Set(ids), file: fs.file, fromHeader: Boolean(fs.requirements) };
}

function junitSpecs(root, o) {
  if (o.junit.length) return o.junit;
  const prof = stackProfile(root);
  if (prof.test_report_path) return prof.test_report_path.split(",").map((s) => s.trim()).filter(Boolean);
  return existsSync(path.join(root, ".sdd", "junit")) ? [".sdd/junit"] : [];
}

export function buildLedger(o) {
  const root = rootOf(o);
  const reqs = readReqs(root, o);
  const specs = junitSpecs(root, o);
  let junit = null;
  try { junit = specs.length ? readJUnit(root, specs) : null; } catch (e) { die(e.message); }
  const exclude = [...(junit?.files || []).map((f) => path.relative(root, f.path)), o.out, o.report].filter(Boolean);
  const g = gitContext(root, { exclude });
  const junitSha = o["junit-sha"] ? (g.repo ? resolveSha(root, o["junit-sha"]) : o["junit-sha"]) : null;
  const decisions = readDecisions(path.resolve(root, o.decisions || DECISIONS_FILE));
  const scope = scopeFor(root, reqs, o.fase);
  const ledger = evaluate({ root, reqs, scenarios: loadScenarios(root), junit, junitSha, decisions, git: g,
    scope: scope ? scope.set : null, fase: o.fase ?? null });
  if (scope) { ledger.scope.file = scope.file; ledger.scope.from_header = scope.fromHeader; }
  ledger.junit_searched = specs;
  return { root, ledger };
}
function resolveSha(root, rev) {
  const r = git(root, ["rev-parse", "-q", "--verify", `${rev}^{commit}`]);
  if (r.status !== 0) die(`unknown commit ${rev}`);
  return r.stdout.trim();
}

function writeJson(root, file, data) {
  const f = path.resolve(root, file);
  mkdirSync(path.dirname(f), { recursive: true });
  writeFileSync(f, JSON.stringify(data, null, 2) + "\n");
}
function writeText(root, file, text) {
  const f = path.resolve(root, file);
  mkdirSync(path.dirname(f), { recursive: true });
  writeFileSync(f, text);
}

function printLedger(ledger) {
  for (const r of ledger.requirements.filter((x) => x.in_scope)) {
    const tail = r.verdict === "DEPRECATED" ? "" : `${r.criteria_passing}/${r.criteria_total}${r.stale_evidence ? "  stale evidence" : ""}${r.verdict === "WAIVED" ? `  waiver ${DECISIONS_FILE}:${r.waiver.line}` : ""}`;
    out(`${r.id.padEnd(12)} ${String(r.priority || "-").padEnd(7)} ${String(r.verification || r.verification_raw || "-").padEnd(12)} ${r.verdict.padEnd(10)} ${tail}`.trimEnd());
  }
  for (const d of ledger.stale_decisions) out(`stale decision ${DECISIONS_FILE}:${d.line} ${d.type} ${d.req || `FASE ${d.fase}`}: ${d.reason}`);
  for (const e of ledger.decision_errors) out(`${DECISIONS_FILE}:${e.line}: ${e.msg}`);
  for (const j of ledger.junit.filter((x) => !x.fresh)) out(`stale junit ${j.path}: ${j.stale_reason}`);
  if (!ledger.junit.length) out(`note: no JUnit report read (${ledger.junit_searched.length ? ledger.junit_searched.join(", ") : "pass --junit PATH or write reports to .sdd/junit/"})`);
  const s = ledger.summary;
  const v = s.by_verdict;
  out(`accept: ${s.active} active requirement(s) · ${v.VERIFIED} verified · ${v.FAILING} failing · ${v.MISSING} missing · ${v.WAIVED} waived · ${s.deprecated} deprecated · Must ${s.must_verified}/${s.must_total} verified${s.must_waived ? `, ${s.must_waived} waived` : ""} · goal ${s.goal ? "met" : "not met"} (evaluated ${ledger.evaluated_sha ? ledger.evaluated_sha.slice(0, 7) : "no git"}${ledger.dirty ? ", dirty" : ""})`);
}

function cmdAccept(o) {
  if (o._[0] === "record") { o._.shift(); return cmdRecord(o); }
  if (o._.length) usage(`unexpected argument ${o._[0]}`);
  const { root, ledger } = buildLedger(o);
  const outFile = o["no-out"] ? null : (o.out || ".sdd/acceptance.json");
  if (outFile && outFile !== "-") writeJson(root, outFile, ledger);
  if (o.report) writeText(root, o.report, renderReport(ledger));
  if (o.json || outFile === "-") out(JSON.stringify(ledger, null, 2));
  else printLedger(ledger);
  return 0;
}

// ------------------------------------------------------------------ record
function cmdRecord(o) {
  const type = o._.shift();
  if (!RECORD_TYPES.includes(type)) usage(`accept record needs a type: ${RECORD_TYPES.join(" | ")}`);
  if (o._.length) usage(`unexpected argument ${o._[0]}`);
  const root = rootOf(o);
  const reqs = readReqs(root, o);
  const g = gitContext(root);
  const rec = { type, at: new Date().toISOString(), by: o.by, role: o.role, head: g.head };
  const bool = (v, name) => {
    if (v === undefined) return undefined;
    if (/^(true|yes|pass|1)$/i.test(v)) return true;
    if (/^(false|no|fail|0)$/i.test(v)) return false;
    usage(`${name} must be true or false`);
  };
  if (type === "fase-acceptance") {
    Object.assign(rec, { fase: o.fase, result: o.result, channel: o.channel });
    if (o.demo) rec.demo = o.demo;
    const scope = scopeFor(root, reqs, o.fase ?? -1);
    const ids = o.fase === undefined ? [] : [...scope.set];
    rec.reqHashes = Object.fromEntries(reqs.filter((r) => ids.includes(r.id)).map((r) => [r.id, reqHash(r)]));
  } else {
    rec.req = o.req;
    const req = reqs.find((r) => r.id === o.req);
    if (req) rec.reqHash = reqHash(req);
    if (o.ac !== undefined) { const n = acNumber(o.ac); rec.ac = Number.isNaN(n) ? o.ac : n; }
    if (o.paths.length) rec.paths = o.paths;
    if (type === "waiver") Object.assign(rec, { reason: o.reason, followUp: o["follow-up"] });
    if (type === "demo") Object.assign(rec, { observed: o.observed, pass: bool(o.pass, "--pass") });
    if (type === "measurement") Object.assign(rec, { metric: o.metric, observed: o.observed === undefined ? "" : Number(o.observed), op: o.op, threshold: o.threshold === undefined ? "" : Number(o.threshold) });
    if (type === "inspection") { rec.note = o.note; const p = bool(o.pass ?? (o.result ? String(o.result === "pass") : undefined), "--pass"); if (p === false) rec.pass = false; }
  }
  for (const k of Object.keys(rec)) if (rec[k] === undefined) delete rec[k];
  const errors = validateRecord(rec, reqs);
  if (errors.length) { for (const e of errors) console.error(`${PROG}: accept record ${type}: ${e}`); return 2; }
  const file = path.resolve(root, o.decisions || DECISIONS_FILE);
  mkdirSync(path.dirname(file), { recursive: true });
  const prev = existsSync(file) ? readFileSync(file, "utf8") : "";
  const line = JSON.stringify(rec);
  appendFileSync(file, (prev && !prev.endsWith("\n") ? "\n" : "") + line + "\n");
  const n = (prev ? prev.replace(/\n$/, "").split("\n").length : 0) + 1;
  if (o.json) out(JSON.stringify({ file: path.relative(root, file), line: n, record: rec }, null, 2));
  else out(`recorded ${type} ${rec.req || `FASE ${rec.fase}`} at ${path.relative(root, file)}:${n}`);
  return 0;
}

// ------------------------------------------------------------------ gate
const GATE_MODES = ["off", "warn", "enforce"];
/** 0 goal met · 1 not met · 2 stale evidence · 3 goal met with waived Musts. */
export function gateCode(ledger) {
  const s = ledger.summary;
  if (s.goal) return s.must_waived ? 3 : 0;
  return s.stale_evidence ? 2 : 1;
}
function cmdGate(o) {
  if (o._.length) usage(`unexpected argument ${o._[0]}`);
  const root = rootOf(o);
  const mode = o.mode || stackProfile(root).acceptance_gate || "enforce";
  if (!GATE_MODES.includes(mode)) usage(`--mode must be ${GATE_MODES.join(" | ")}`);
  if (mode === "off") return 0;
  let ledger, code;
  if (o.ledger) {
    const f = path.resolve(root, o.ledger);
    if (!existsSync(f)) die(`${o.ledger} not found`);
    try { ledger = JSON.parse(readFileSync(f, "utf8")); } catch { die(`${o.ledger} is not JSON`); }
    if (ledger.$schema !== SCHEMA) die(`${o.ledger} is not ${SCHEMA}`);
    const g = gitContext(root);
    const fresh = !g.repo || (ledger.evaluated_sha && !g.dirty && unchangedSince(root, ledger.evaluated_sha));
    if (!fresh) {
      const msg = `gate: ${o.ledger} was evaluated at ${String(ledger.evaluated_sha || "?").slice(0, 7)}, code changed since — run sdd accept again`;
      if (mode === "warn") { out(msg); out("gate: would exit 2 (mode warn)"); return 0; }
      console.error(msg); return 2;
    }
    if (o.fase !== undefined && (!ledger.scope || ledger.scope.fase !== o.fase)) die(`${o.ledger} was not evaluated for FASE ${o.fase}; run sdd gate --fase ${o.fase} without --ledger`);
  } else {
    ({ ledger } = buildLedger(o));
    if (o.out) writeJson(root, o.out, ledger);
  }
  code = gateCode(ledger);
  const s = ledger.summary;
  const labels = { 0: "goal met", 1: "goal not met", 2: "stale evidence — re-run the tests on this commit", 3: "goal met with waived Musts" };
  if (o.json) out(JSON.stringify({ code, mode, label: labels[code], evaluated_sha: ledger.evaluated_sha, scope: ledger.scope, summary: s,
    requirements: ledger.requirements.filter((r) => r.in_scope && r.verdict !== "DEPRECATED").map((r) => ({ id: r.id, priority: r.priority, verdict: r.verdict, criteria: `${r.criteria_passing}/${r.criteria_total}`, stale_evidence: r.stale_evidence })) }, null, 2));
  else if (o.md) process.stdout.write(renderPrBlock(ledger, code));
  else {
    for (const r of ledger.requirements.filter((x) => x.in_scope && x.priority === "Must" && !["VERIFIED", "DEPRECATED"].includes(x.verdict)))
      out(`${r.id}  ${r.verdict}${r.stale_evidence ? " (stale evidence)" : ""}  ${r.criteria_passing}/${r.criteria_total}`);
    out(`gate: ${labels[code]} — Must ${s.must_verified}/${s.must_total} verified${s.must_waived ? `, ${s.must_waived} waived (${s.waived_musts.join(", ")})` : ""}${ledger.scope ? ` · FASE ${ledger.scope.fase}` : ""} · exit ${code}`);
  }
  if (mode === "warn") { if (!o.json && !o.md) out(`gate: would exit ${code} (mode warn)`); return 0; }
  return code;
}

// ------------------------------------------------------------------ loop next
const HARD_CAP = 5;
function cmdLoop(o) {
  const sub = o._.shift();
  if (sub !== "next") usage("loop needs `next`");
  if (o._.length) usage(`unexpected argument ${o._[0]}`);
  const root = rootOf(o);
  let max = o["max-cycles"] === undefined ? 3 : Number(o["max-cycles"]);
  if (!Number.isInteger(max) || max < 1) usage("--max-cycles needs a positive integer");
  const capped = max > HARD_CAP;
  if (capped) max = HARD_CAP;
  const stateFile = path.resolve(root, o.state || ".sdd/acceptance-loop.json");
  let state = { $schema: "sdd-acceptance-loop-v1", cycles: [] };
  if (!o.reset && existsSync(stateFile)) {
    try { state = JSON.parse(readFileSync(stateFile, "utf8")); } catch { die(`${o.state || ".sdd/acceptance-loop.json"} is not JSON (use --reset)`); }
    if (!Array.isArray(state.cycles)) state.cycles = [];
  }
  const { ledger } = buildLedger(o);
  if (!o["no-out"]) writeJson(root, o.out || ".sdd/acceptance.json", ledger);
  const goalSet = ledger.requirements.filter((r) => r.in_scope && r.priority === "Must" && r.verdict !== "DEPRECATED");
  const count = (v) => goalSet.filter((r) => r.verdict === v).length;
  const progress = { verified: count("VERIFIED"), waived: count("WAIVED"), failing: count("FAILING"), missing: count("MISSING") };
  const verdicts = Object.fromEntries(goalSet.map((r) => [r.id, r.verdict]));
  const prev = state.cycles[state.cycles.length - 1] || null;
  const cycle = state.cycles.length + 1;
  const target = (r) => ({ req: r.id, priority: r.priority, verdict: r.verdict, verification: r.verification,
    criteria: r.criteria.filter((c) => c.state !== "pass").map((c) => ({ n: c.n, state: c.state, scenarios: c.scenarios, route_hint: criterionHint(r, c) })),
    route_hint: routeHint(r) });
  const open = (r) => ["FAILING", "MISSING"].includes(r.verdict);
  const targets = goalSet.filter(open).map(target);
  const others = ledger.requirements.filter((r) => r.in_scope && r.priority !== "Must" && open(r)).map(target);

  const everVerified = new Set(state.cycles.flatMap((c) => Object.entries(c.verdicts || {}).filter(([, v]) => v === "VERIFIED").map(([k]) => k)));
  const regressed = goalSet.filter((r) => everVerified.has(r.id) && open(r)).map((r) => r.id);
  let stop = null;
  if (ledger.summary.goal) stop = "goal";
  else if (regressed.length) stop = "regression";
  else if (targets.length && targets.every((t) => t.route_hint === ROUTES.human || t.route_hint === ROUTES.specGap)) stop = "needs-human";
  else if (prev && !(progress.verified > prev.progress.verified || progress.failing + progress.missing < prev.progress.failing + prev.progress.missing)) stop = "no-progress";
  else if (cycle > max) stop = "max-cycles";
  const result = { cycle, max_cycles: max, stop, evaluated_sha: ledger.evaluated_sha, progress,
    previous: prev ? { cycle: prev.cycle, progress: prev.progress } : null, regressed, targets, others,
    stale_evidence: ledger.summary.stale_evidence };
  if (capped) result.note = `--max-cycles capped at ${HARD_CAP}`;
  state.max_cycles = max;
  state.cycles.push({ cycle, at: ledger.generatedAt, evaluated_sha: ledger.evaluated_sha, progress, verdicts, stop });
  mkdirSync(path.dirname(stateFile), { recursive: true });
  writeFileSync(stateFile, JSON.stringify(state, null, 2) + "\n");
  out(JSON.stringify(result, null, 2));
  return 0;
}

// ------------------------------------------------------------------ entry
export function runAcceptance(cmd, argv, { prog = "sdd" } = {}) {
  PROG = prog;
  try {
    const o = parse(argv);
    if (cmd === "lint") return cmdLintNeeds(o);
    if (cmd === "accept") return cmdAccept(o);
    if (cmd === "gate") return cmdGate(o);
    if (cmd === "loop") return cmdLoop(o);
    usage(`unknown command ${cmd}`);
  } catch (e) {
    if (e instanceof Exit) return e.code;
    throw e;
  }
}

