// route.mjs — `sdd route`: the adaptive route. Decides which optional pipeline stages a project needs, with a
// readable reason per stage, and (with --write) records the decision in pipeline-state.json. Node >= 18, no deps.
//
// Facts are counted from requirements/REQUIREMENTS.md and requirements/CUSTOMER-NEEDS.md (the parsers of
// scripts/sdd-jev.mjs) and the repo; the seven factor judgments of scripts/jev/route.json come from --answers (the
// LLM answered them) or from Jev through `sdd-jev.mjs judge` (the same HTTP client, retries and limits). The rules
// live in scripts/lib/route-rules.mjs.
//
// --write takes the same lock as the hooks (hooks/lib/sdd-common.sh sdd_lock: mkdir <file>.lock, 50 × 0.1 s, a lock
// older than 60 s is broken under <file>.lock.break) and writes the file resolved by scripts/sdd-state.sh path.
// It never overwrites a stage that is done or running and never un-skips a stage on its own: a re-evaluation that
// now wants a skipped stage reports it in `escalations`; only --full or --set <stage>=run (a person's choice) turns
// a skipped stage back to pending. A re-evaluation never lowers rigor either: a stage an earlier route ran stays run.
import { readFileSync, writeFileSync, existsSync, mkdirSync, rmdirSync, renameSync, statSync, unlinkSync } from "node:fs";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { parseRequirements, parseNeeds } from "../sdd-jev.mjs";
import { stackProfile } from "./git-log.mjs";
import {
  FACTORS, OPTIONAL_STAGES, CORE_STAGES, evaluateFactors, computeFacts, decideRoute, savedMinutes, loadThresholds,
} from "./route-rules.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const JEV = path.join(HERE, "..", "sdd-jev.mjs");
const QUESTIONS = path.join(HERE, "..", "jev", "route.json");
const STATE_SH = path.join(HERE, "..", "sdd-state.sh");

let PROG = "sdd";
class Exit extends Error { constructor(code) { super(`exit ${code}`); this.code = code; } }
const fail = (msg, code = 2) => { process.stderr.write(`${PROG} route: ${msg}\n`); throw new Exit(code); };
const out = (s) => process.stdout.write(s + "\n");

function parse(argv) {
  const o = { set: [], json: false, write: false, full: false };
  for (let i = 0; i < argv.length; i++) {
    let a = argv[i], v;
    const eq = a.match(/^(--[a-z-]+)=(.*)$/);
    if (eq) { a = eq[1]; v = eq[2]; }
    const take = () => { if (v !== undefined) return v; if (i + 1 >= argv.length) fail(`${a} needs a value`); return argv[++i]; };
    switch (a) {
      case "route": break;
      case "--repo": o.repo = take(); break;
      case "--answers": o.answers = take(); break;
      case "--confirm": o.confirm = take(); break;
      case "--json": o.json = true; break;
      case "--write": o.write = true; break;
      case "--full": o.full = true; break;
      case "--set":
        o.set.push(take());
        while (i + 1 < argv.length && /^[a-z-]+=/.test(argv[i + 1])) o.set.push(argv[++i]);
        break;
      default: fail(`unknown argument ${a}`);
    }
  }
  const sets = {};
  for (const s of o.set) {
    const m = s.match(/^([a-z-]+)=(run|skip)$/);
    if (!m) fail(`--set wants <stage>=run|skip, got "${s}"`);
    if (CORE_STAGES.includes(m[1])) fail(`${m[1]} is a core stage and always runs`);
    if (!OPTIONAL_STAGES.includes(m[1])) fail(`unknown stage ${m[1]} (optional stages: ${OPTIONAL_STAGES.join(", ")})`);
    sets[m[1]] = m[2] === "run";
  }
  o.sets = sets;
  if (o.confirm !== undefined && !o.write) fail("--confirm records who confirmed the route and needs --write");
  return o;
}

// ── factor answers ───────────────────────────────────────────────────────────
// --answers FILE: {"factors": {name: p}} (or the map alone). A value may be a probability, {p}, or yes/no/doubt.
function readAnswers(file) {
  let j;
  try { j = JSON.parse(readFileSync(file, "utf8")); } catch (e) { fail(`cannot read --answers ${file}: ${e.message}`); }
  const map = j && typeof j === "object" ? j.factors || j : {};
  const probs = {};
  for (const f of FACTORS) {
    let v = map[f];
    if (v && typeof v === "object") v = v.p;
    if (typeof v === "string") v = { yes: 1, no: 0, doubt: 0.5 }[v.toLowerCase()] ?? Number(v);
    if (typeof v === "number" && Number.isFinite(v)) probs[f] = v;
  }
  return probs;
}

function askJev(state) {
  const r = spawnSync(process.execPath, [JEV, "judge", "--questions", QUESTIONS, "--items", "-", "--concurrency", "1"],
    { input: JSON.stringify({ id: "route", state }) + "\n", encoding: "utf8", maxBuffer: 16 * 1024 * 1024 });
  if (r.status === 3) fail("Jev is disabled (TYPESAFE_API_KEY not set or SDD_JEV=off): answer the factors (LLM) and pass --answers", 3);
  let res;
  try { res = JSON.parse(r.stdout); } catch { res = null; }
  const err = res?.errors?.[0]?.error || (r.stderr || "").trim().split("\n").pop();
  if (!res || !res.items?.length) fail(`Jev failed (${err || `exit ${r.status}`}): answer the factors (LLM) and pass --answers`, 3);
  return { probs: res.items[0].answers, model: res.model || null, tokens: res.usage?.input_tokens ?? null };
}

// ── pipeline-state.json ──────────────────────────────────────────────────────
function stateFile(root) {
  const r = spawnSync("bash", [STATE_SH, "path"], { cwd: root, encoding: "utf8", env: { ...process.env, CLAUDE_PROJECT_DIR: root } });
  const f = (r.stdout || "").trim();
  return { file: f || path.join(root, "pipeline-state.json"), exists: r.status === 0 && Boolean(f) && existsSync(f) };
}
function readJson(f) { try { return JSON.parse(readFileSync(f, "utf8")); } catch { return null; } }

const nap = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
const isStale = (d) => { try { return Date.now() - statSync(d).mtimeMs > 60000; } catch { return false; } };
function lock(file) {
  const dir = `${file}.lock`;
  const max = Number(process.env.SDD_LOCK_RETRIES) || 50;
  for (let tries = 0; ; tries++) {
    try { mkdirSync(dir); return dir; } catch (e) { if (e.code !== "EEXIST") throw e; }
    if (tries >= max) return null;
    if (isStale(dir)) {
      const brk = `${dir}.break`;
      try {
        mkdirSync(brk);
        if (isStale(dir)) { try { rmdirSync(dir); } catch { /* someone else did */ } }
        rmdirSync(brk);
      } catch { if (isStale(brk)) { try { rmdirSync(brk); } catch { /* ignore */ } } }
      continue;
    }
    nap(100);
  }
}

function writeState(file, route, stages, explicit) {
  const dir = lock(file);
  if (!dir) fail(`could not get the lock ${file}.lock (another writer holds it)`, 1);
  const changed = [], kept = [];
  try {
    const j = readJson(file);
    if (!j || typeof j !== "object") fail(`${file} is not valid JSON`, 1);
    if (!j.stages || typeof j.stages !== "object" || Array.isArray(j.stages)) j.stages = {};
    for (const k of OPTIONAL_STAGES) {
      const want = stages[k];
      let g = j.stages[k];
      const cur = g && typeof g === "object" ? g.status || "pending" : "absent";
      if (!want.run) {
        if (cur === "done" || cur === "running") { kept.push({ stage: k, status: cur }); continue; }
        if (cur === "skipped" && g.skipReason === want.reason) continue;
        if (!g || typeof g !== "object") g = j.stages[k] = { status: "pending", outputHash: null, lastRun: null, staleReason: null };
        g.status = "skipped"; g.skipReason = want.reason; g.staleReason = null;
        changed.push({ stage: k, from: cur, to: "skipped" });
      } else if (cur === "skipped") {
        if (explicit.has(k)) {
          g.status = "pending"; delete g.skipReason;
          changed.push({ stage: k, from: "skipped", to: "pending" });
        } else kept.push({ stage: k, status: "skipped", escalation: true });
      }
    }
    const now = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
    j.route = { decidedAt: now, ...route };
    j.lastUpdated = now;
    const tmp = `${file}.tmp.${process.pid}`;
    writeFileSync(tmp, JSON.stringify(j, null, 2) + "\n");
    try { renameSync(tmp, file); } catch (e) { try { unlinkSync(tmp); } catch { /* ignore */ } throw e; }
  } finally {
    try { rmdirSync(dir); } catch { /* ignore */ }
  }
  return { file, changed, kept };
}

// ── main ─────────────────────────────────────────────────────────────────────
export function computeRoute(root, o) {
  const reqFile = path.join(root, "requirements", "REQUIREMENTS.md");
  const needsFile = path.join(root, "requirements", "CUSTOMER-NEEDS.md");
  if (!existsSync(reqFile)) fail(`${path.relative(process.cwd(), reqFile) || reqFile} not found (run sdd-requirements-engineer first)`);
  const reqText = readFileSync(reqFile, "utf8");
  const reqs = parseRequirements(reqText);
  if (!reqs.length) fail(`no "### REQ-…" blocks in ${reqFile}`);
  let needsText = "";
  if (existsSync(needsFile)) needsText = readFileSync(needsFile, "utf8");
  else process.stderr.write(`${PROG} route: note: ${needsFile} not found; routing from the requirements alone\n`);
  const needs = parseNeeds(needsText);
  const facts = computeFacts({ reqs, needs, profile: stackProfile(root), root });
  const thresholds = loadThresholds(QUESTIONS);

  let probs, source, jev = null;
  if (o.answers) { probs = readAnswers(path.resolve(o.answers)); source = "answers"; }
  else {
    const name = (needsText.match(/^>?\s*\*\*Project:?\*\*:?\s*(.+)$/m) || reqText.match(/^>?\s*\*\*Project:?\*\*:?\s*(.+)$/m) || [])[1]?.trim()
      || path.basename(root);
    const state = {
      project: { name },
      needs: needs.filter((n) => n.status !== "out-of-scope" && n.quote).map((n) => ({ id: n.id, quote: n.quote, ...(n.who ? { who: n.who } : {}) })),
      requirements: reqs.filter((r) => !r.deprecated).map((r) => ({ id: r.id, type: r.type, priority: r.priority, statement: r.statement })),
    };
    jev = askJev(state);
    probs = jev.probs; source = "jev";
  }
  const { factors, doubts } = evaluateFactors(probs, thresholds);
  const auto = decideRoute(facts, factors);
  const reqHash = "sha256:" + createHash("sha256").update(reqText).update("\0").update(needsText).digest("hex");
  return { facts, factors, doubts, auto, reqHash, source, jev, thresholds };
}

export function runRoute(argv, { prog = "sdd" } = {}) {
  PROG = prog;
  try {
    const o = parse(argv);
    const root = path.resolve(o.repo || ".");
    const r = computeRoute(root, o);
    const st = stateFile(root);
    const prior = st.exists ? readJson(st.file) : null;
    const priorStages = prior?.route?.stages || null;
    const status = (k) => prior?.stages?.[k]?.status || null;

    // Re-evaluation: never lower rigor on its own; report stages that now should run but were skipped before.
    const stages = JSON.parse(JSON.stringify(r.auto));
    const escalations = [];
    for (const k of OPTIONAL_STAGES) {
      const was = priorStages?.[k];
      const busy = status(k) === "done" || status(k) === "running";
      if (stages[k].run && !busy && ((was && was.run === false) || status(k) === "skipped")) escalations.push(k);
      if (!stages[k].run && was?.run === true) stages[k] = { run: true, reason: `kept: an earlier route ran it and the route never lowers rigor on its own (now: ${stages[k].reason})` };
    }
    const explicit = new Set();
    if (o.full) for (const k of OPTIONAL_STAGES) if (!stages[k].run || status(k) === "skipped") { stages[k] = { run: true, reason: "set by user: full pipeline" }; explicit.add(k); }
    for (const [k, run] of Object.entries(o.sets)) { stages[k] = { run, reason: "set by user" }; explicit.add(k); }

    const result = {
      factors: r.factors, facts: r.facts, stages, doubts: r.doubts, escalations,
      saved_minutes_estimate: savedMinutes(stages),
      source: r.source, thresholds: r.thresholds, reqHash: r.reqHash,
      ...(r.jev ? { jev: { model: r.jev.model, input_tokens: r.jev.tokens } } : {}),
    };
    if (o.write) {
      if (!st.exists) fail(`no pipeline-state.json at ${st.file} (run /sdd-setup first)`);
      const route = { factors: r.factors, facts: r.facts, stages, doubts: r.doubts, escalations, confirmedBy: o.confirm || null, reqHash: r.reqHash };
      result.written = writeState(st.file, route, stages, explicit);
    }
    if (o.json) out(JSON.stringify(result, null, 2));
    else printHuman(result);
    return 0;
  } catch (e) {
    if (e instanceof Exit) return e.code;
    throw e;
  }
}

function printHuman(r) {
  const skipped = Object.entries(r.stages).filter(([, v]) => !v.run).map(([k]) => k);
  out(`route: ${skipped.length ? `${skipped.length} optional stage(s) skipped` : "full pipeline"}` +
    (r.saved_minutes_estimate ? `, ~${r.saved_minutes_estimate} min saved (measured on the todo-app run)` : ""));
  const w = Math.max(...Object.keys(r.stages).map((k) => k.length));
  for (const [k, v] of Object.entries(r.stages)) out(`  ${v.run ? "run " : "skip"}  ${k.padEnd(w)}  ${v.reason}`);
  out(`factors: ${Object.entries(r.factors).map(([k, v]) => `${k}=${v.value}${v.p === null ? "" : `(${v.p})`}`).join(" ")}`);
  const f = r.facts;
  out(`facts: ${f.req_f} REQ-F, ${f.req_nf} REQ-NF, ${f.req_c} REQ-C, ${f.must} Must, ${f.needs} needs (${f.needs_out} out of scope), ` +
    `code ${f.has_code ? "yes" : "no"}, Stack Profile ${f.has_profile ? "yes" : "no"}`);
  if (r.doubts.length) out(`doubts (treated as yes): ${r.doubts.join(", ")}`);
  if (r.escalations.length) out(`escalations (skipped before, needed now; run them or --set <stage>=run): ${r.escalations.join(", ")}`);
  if (r.written) {
    for (const c of r.written.changed) out(`state: ${c.stage} ${c.from} → ${c.to}`);
    for (const c of r.written.kept) out(`state: ${c.stage} kept ${c.status}${c.escalation ? " (escalation: a person decides)" : ""}`);
    out(`state: route written to ${r.written.file}`);
  }
}
