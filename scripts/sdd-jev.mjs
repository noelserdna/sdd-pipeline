#!/usr/bin/env node
// sdd-jev.mjs — optional bulk judgments with TypeSafe's Jev (a System One model) for SDD skills. Node >= 18, no deps.
//
// Jev answers narrow typed questions about a text state: a Noul (probability of yes), a Choice (one option of a set,
// with probabilities and confidence) or a Score (a level of an ordered rubric). It does not generate text, count or
// do date math. Skills use this script as a pre-pass: Jev screens many small items in one go and the LLM only reads
// the flagged or uncertain ones. The script never decides; it returns probabilities and the skill applies thresholds.
//
// Opt-in: it runs only when TYPESAFE_API_KEY is set and SDD_JEV is not "off". Data leaves the machine (state text
// goes to api.typesafe.ai), so skills must not call it on projects where that is not allowed.
//
// Usage:
//   node sdd-jev.mjs status
//       Prints "enabled <model>" or "disabled: <reason>"; exit 0 when enabled, 3 when disabled.
//   node sdd-jev.mjs judge --questions FILE.json [--items FILE.jsonl|-] [--out FILE.json] [--concurrency N]
//       Asks the question set of FILE.json (a TypeSafe `questions` map, or {"questions": {...}}) once per item.
//       Each JSONL item is {"id": ..., "state": ...} or any object (used whole as the state, id = line number).
//       Output: {model, items: [{id, answers}], errors: [{id, error}], usage}. Answers are compact:
//       noul → number; choice → {choice, confidence, p}; score → {score, confidence, p}.
//   node sdd-jev.mjs req-lint [requirements/REQUIREMENTS.md] [--out FILE.json] [--json]
//       Parses `### REQ-…` blocks and screens each statement: vague terms, compound behaviour, unverifiable
//       wording, implementation leak and EARS pattern (question set: scripts/jev/req-lint.json). REQ-C-* constraints
//       skip the EARS and implementation-leak questions. A requirement with acceptance criteria also gets `uncovered`
//       (a promise of the statement that no criterion checks; its own item {requirement: {statement, criteria}},
//       flagged at p >= thresholds.uncovered of the JSON). Prints the flagged requirements; --json prints the JSON.
//   node sdd-jev.mjs needs [CUSTOMER-NEEDS.md] [REQUIREMENTS.md] [--mechanical] [--out FILE.json] [--json]
//       Need coverage. Always runs the mechanical check first (no network): every need covered by a `Needs:` line or
//       out-of-scope with a decision, every REQ-F/REQ-NF traced to a need, a verification method per requirement,
//       Must ratio. Then, with Jev on, one Choice per need over the requirement IDs plus "none" (instructions and
//       thresholds: scripts/jev/need-coverage.json) and prints needs whose top choice is none, low-confidence or not
//       declared in `Needs:`; then one reverse Choice (over the need IDs plus "none") for each requirement no need
//       picked as top, and prints it as a gold-plating candidate when that answer is none or low-confidence.
//       --mechanical skips Jev and exits 1 when the check has errors; without it, exit 3 means Jev is off.
//   node sdd-jev.mjs chunks [--max-chars N] FILE...
//       Splits source files at top-level boundaries into JSONL items {id, path, start, end, code} (default 24000
//       chars, well under Jev's 32k-token state budget) for `judge`.
// Environment: TYPESAFE_API_KEY, SDD_JEV=off, SDD_JEV_MODEL (default jev-latest), SDD_JEV_URL (tests).
// Exit codes: 0 ok · 1 some items failed · 2 usage or input error · 3 disabled (skills fall back to the LLM).
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const URL_ = process.env.SDD_JEV_URL || "https://api.typesafe.ai/v1/systemone";
const MODEL = process.env.SDD_JEV_MODEL || "jev-latest";
const MAX_STATE_CHARS = 100000; // ~25k tokens; Jev allows 32k for state + the longest question
const THRESHOLD = 0.5;

function die(msg, code = 2) { process.stderr.write(`sdd-jev: ${msg}\n`); process.exit(code); }

function disabledReason() {
  if ((process.env.SDD_JEV || "").toLowerCase() === "off") return "SDD_JEV=off";
  if (!process.env.TYPESAFE_API_KEY) return "TYPESAFE_API_KEY not set";
  return null;
}

function args(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith("--")) {
      const k = a.slice(2);
      const v = argv[i + 1] !== undefined && !argv[i + 1].startsWith("--") ? argv[++i] : true;
      out[k] = v;
    } else out._.push(a);
  }
  return out;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function ask(state, questions) {
  const body = JSON.stringify({ state, model: MODEL, questions });
  let last = "";
  for (let attempt = 0; attempt < 5; attempt++) {
    let res;
    try {
      res = await fetch(URL_, { method: "POST", body, signal: AbortSignal.timeout(60000),
        headers: { Authorization: `Bearer ${process.env.TYPESAFE_API_KEY}`, "Content-Type": "application/json" } });
    } catch (e) { last = String(e.message || e); await sleep(500 * 2 ** attempt); continue; }
    if (res.ok) return res.json();
    last = `HTTP ${res.status}: ${(await res.text()).slice(0, 200)}`;
    if (![429, 500, 502, 503, 504].includes(res.status)) break;
    await sleep((Number(res.headers.get("retry-after")) || 0.5 * 2 ** attempt) * 1000);
  }
  throw new Error(last);
}

function compact(a) {
  if (a.type === "noul") return Math.round(a.noul * 1000) / 1000;
  const p = a.probabilities || {};
  if (a.type === "choice") return { choice: a.choice, confidence: a.confidence, p };
  return { score: a.score, confidence: a.confidence, p };
}

async function judgeAll(items, questionsFor, concurrency) {
  const out = { model: null, items: [], errors: [], usage: { input_tokens: 0, requests: 0 } };
  let next = 0;
  async function worker() {
    while (next < items.length) {
      const it = items[next++];
      const qs = questionsFor(it);
      if (!Object.keys(qs).length) continue;
      if (JSON.stringify(it.state).length > MAX_STATE_CHARS) {
        out.errors.push({ id: it.id, error: `state larger than ${MAX_STATE_CHARS} chars; split it (see chunks)` });
        continue;
      }
      try {
        const r = await ask(it.state, qs);
        out.model = out.model || r.model;
        out.usage.input_tokens += r.usage?.input_tokens || 0;
        out.usage.requests += 1;
        const answers = {};
        for (const [k, v] of Object.entries(r.answers)) answers[k] = compact(v);
        out.items.push({ id: it.id, answers });
      } catch (e) { out.errors.push({ id: it.id, error: String(e.message || e) }); }
    }
  }
  await Promise.all(Array.from({ length: Math.max(1, concurrency) }, worker));
  const order = new Map(items.map((it, i) => [String(it.id), i]));
  out.items.sort((a, b) => order.get(String(a.id)) - order.get(String(b.id)));
  return out;
}

function loadQuestions(file) {
  let q;
  try { q = JSON.parse(readFileSync(file, "utf8")); } catch (e) { die(`cannot read questions ${file}: ${e.message}`); }
  return q.questions || q;
}

function readItems(src) {
  const text = src === "-" || !src ? readFileSync(0, "utf8") : readFileSync(src, "utf8");
  return text.split("\n").filter((l) => l.trim()).map((l, i) => {
    let o;
    try { o = JSON.parse(l); } catch { die(`items line ${i + 1} is not JSON`); }
    return o && typeof o === "object" && "state" in o ? { id: o.id ?? i + 1, state: o.state } : { id: i + 1, state: o };
  });
}

function emit(result, outFile) {
  const json = JSON.stringify(result, null, 1);
  if (outFile && outFile !== true) {
    mkdirSync(path.dirname(path.resolve(outFile)), { recursive: true });
    writeFileSync(outFile, json + "\n");
  } else process.stdout.write(json + "\n");
}

// ── requirements / needs parsing ─────────────────────────────────────────────
// Field lines look like `- **Name:** value`; Spanish labels are accepted as aliases.
const FIELD = /^\s*[-*]?\s*\*\*([^*]+?)\s*:?\s*\*\*\s*:?\s*(.*)$/;
const REQ_FIELDS = {
  statement: "statement", enunciado: "statement", requirement: "statement", requisito: "statement",
  priority: "priority", prioridad: "priority",
  needs: "needs", necesidades: "needs",
  verification: "verification", "verificación": "verification", verificacion: "verification",
  status: "status", estado: "status",
  "examples reviewed by": "examplesReviewedBy", "ejemplos revisados por": "examplesReviewedBy",
};
export const VERIFICATION_METHODS = ["test", "demo", "measurement", "inspection"];
const NEED_ID = /\bN-\d{3,}\b/g;

function normPriority(v) {
  const t = (v || "").toLowerCase();
  if (/^(must|debe|imprescindible)/.test(t)) return "Must";
  if (/^(should|deber[ií]a|importante)/.test(t)) return "Should";
  if (/^(nice|could|could have|deseable|opcional)/.test(t)) return "Nice";
  return v ? v.trim() : null;
}

// Returns one object per `### REQ-…` block: {id, type (F|NF|C|other), title, statement, criteria[], priority
// (Must|Should|Nice|raw|null), needs (array of N-ids, [] for "—", null when the field is absent), verification
// (one of VERIFICATION_METHODS, the raw text when unknown, null when absent), deprecated, examplesReviewedBy}.
export function parseRequirements(text) {
  const reqs = [];
  let cur = null;
  for (const line of text.split("\n")) {
    const h = line.match(/^#{2,4}\s+(REQ-[A-Z]+(?:-[A-Z0-9]+)*-\d+)\s*[:—-]?\s*(.*)$/);
    if (h) {
      const type = (h[1].match(/^REQ-(F|NF|C)-\d+$/) || [])[1] || "other";
      cur = { id: h[1], type, title: h[2].trim(), statement: "", criteria: [], priority: null, needs: null,
        verification: null, deprecated: /\[deprecated\]|\(deprecated\)|\[obsoleto\]|^~~/i.test(h[2]), examplesReviewedBy: null };
      reqs.push(cur); continue;
    }
    if (!cur) continue;
    if (/^#{1,3}\s/.test(line)) { cur = null; continue; }
    const g = line.match(/^\s{2,}[-*]\s+(GIVEN|DADO|Given|Dado)\b(.+)$/);
    if (g) { cur.criteria.push((g[1] + g[2]).trim()); continue; }
    const f = line.match(FIELD);
    if (!f) continue;
    const key = REQ_FIELDS[f[1].trim().toLowerCase()];
    if (key !== "statement" && /^\s{2,}/.test(line)) continue; // nested bullets are not requirement fields
    const val = f[2].trim();
    if (key === "statement") cur.statement = val;
    else if (key === "priority") cur.priority = normPriority(val);
    else if (key === "needs") cur.needs = val.match(NEED_ID) || [];
    else if (key === "verification") {
      const m = val.toLowerCase().match(/^[a-z]+/);
      cur.verification = m && VERIFICATION_METHODS.includes(m[0]) ? m[0] : val || null;
    } else if (key === "status") { if (/deprecated|obsoleto/i.test(val)) cur.deprecated = true; }
    else if (key === "examplesReviewedBy") cur.examplesReviewedBy = val || null;
  }
  for (const r of reqs) if (!r.statement) r.statement = r.title;
  return reqs;
}

const NEED_FIELDS = { quote: "quote", cita: "quote", who: "who", "quién": "who", quien: "who",
  when: "when", "cuándo": "when", cuando: "when", status: "status", estado: "status" };

// Parses requirements/CUSTOMER-NEEDS.md: `### N-NNN: title` blocks with Quote, Who, When and Status fields.
// status is captured | confirmed | out-of-scope (or the raw text); decision is the text after "decision:".
export function parseNeeds(text) {
  const needs = [];
  let cur = null;
  for (const line of text.split("\n")) {
    const h = line.match(/^#{2,4}\s+(N-\d{3,})\s*[:—-]?\s*(.*)$/);
    if (h) { cur = { id: h[1], title: h[2].trim(), quote: "", who: null, when: null, status: null, decision: null }; needs.push(cur); continue; }
    if (!cur) continue;
    if (/^#{1,3}\s/.test(line)) { cur = null; continue; }
    const f = line.match(FIELD);
    if (!f) continue;
    const key = NEED_FIELDS[f[1].trim().toLowerCase()];
    const val = f[2].trim();
    if (key === "quote") cur.quote = val.replace(/^["“«]|["”»]$/g, "").trim();
    else if (key === "status") {
      const t = val.toLowerCase();
      cur.status = /^out[- ]of[- ]scope|^fuera de alcance/.test(t) ? "out-of-scope"
        : /^confirm/.test(t) ? "confirmed" : /^captur/.test(t) ? "captured" : val || null;
      const d = val.match(/(?:decision|decisión)\s*:\s*([^)]*)/i);
      if (d && d[1].trim()) cur.decision = d[1].trim();
    } else if (key) cur[key] = val || null;
  }
  return needs;
}

// Mechanical need coverage: the check that decides (Jev only suggests). errors block approval; warnings are
// shown at the gate. Deprecated requirements are ignored. REQ-C may carry `Needs: —` (team/architecture source).
export function checkNeedCoverage(needs, reqs, reqText = "") {
  const errors = [], warnings = [];
  const byId = new Map(needs.map((n) => [n.id, n]));
  const active = reqs.filter((r) => !r.deprecated);
  const fnf = active.filter((r) => r.type === "F" || r.type === "NF");
  const covered = new Map();
  for (const r of active) for (const n of r.needs || []) {
    if (!byId.has(n)) errors.push({ code: "unknown-need", id: r.id, need: n, msg: `${r.id} cites ${n}, which is not in CUSTOMER-NEEDS.md` });
    else if (byId.get(n).status === "out-of-scope") errors.push({ code: "out-of-scope-need", id: r.id, need: n, msg: `${r.id} cites ${n}, which is out-of-scope` });
    else covered.set(n, [...(covered.get(n) || []), r.id]);
  }
  const seen = new Set();
  for (const n of needs) {
    if (seen.has(n.id)) errors.push({ code: "duplicate-need", id: n.id, msg: `${n.id} is defined twice` });
    seen.add(n.id);
    if (!n.quote) errors.push({ code: "no-quote", id: n.id, msg: `${n.id} has no Quote` });
    if (n.status === "out-of-scope") {
      if (!n.decision) errors.push({ code: "no-decision", id: n.id, msg: `${n.id} is out-of-scope without "decision: …"` });
    } else if (!covered.has(n.id)) errors.push({ code: "uncovered-need", id: n.id, msg: `${n.id} is covered by no requirement and not out-of-scope` });
    if (n.status !== "confirmed" && n.status !== "out-of-scope")
      warnings.push({ code: "unconfirmed-need", id: n.id, msg: `${n.id} status is ${n.status || "missing"}; read it back to the customer` });
  }
  for (const r of fnf) {
    if (r.needs === null) errors.push({ code: "no-needs-field", id: r.id, msg: `${r.id} has no Needs: line` });
    else if (!r.needs.length) errors.push({ code: "gold-plating", id: r.id, msg: `${r.id} traces to no customer need (only REQ-C may use "Needs: —")` });
  }
  for (const r of active) {
    if (!r.verification) errors.push({ code: "no-verification", id: r.id, msg: `${r.id} has no Verification: line` });
    else if (!VERIFICATION_METHODS.includes(r.verification)) errors.push({ code: "bad-verification", id: r.id, msg: `${r.id} Verification "${r.verification}" is not ${VERIFICATION_METHODS.join(" | ")}` });
  }
  const docReviewed = /^>?\s*\*\*(Examples reviewed by|Ejemplos revisados por)\s*:?\*\*\s*:?\s*\S/im.test(reqText);
  for (const r of fnf) if (!r.examplesReviewedBy && !docReviewed)
    warnings.push({ code: "examples-not-reviewed", id: r.id, msg: `${r.id} has no "Examples reviewed by:" (nor a document-level one)` });
  const must = fnf.filter((r) => r.priority === "Must").length;
  const mustRatio = fnf.length ? Math.round((must / fnf.length) * 100) / 100 : 0;
  const mustConfirmed = /^>?\s*\*\*(Must list confirmed by|Lista Must confirmada por)\s*:?\*\*\s*:?\s*\S/im.test(reqText);
  if (mustRatio > 0.6 && !mustConfirmed)
    warnings.push({ code: "must-ratio", id: null, msg: `${Math.round(mustRatio * 100)} % of REQ-F/REQ-NF are Must (> 60 %); confirm the Must list with the customer` });
  return { errors, warnings, needs: needs.length, outOfScope: needs.filter((n) => n.status === "out-of-scope").length,
    requirements: active.length, must, mustRatio, mustConfirmed, coveredBy: Object.fromEntries(covered) };
}

// ── req-lint ─────────────────────────────────────────────────────────────────
async function reqLint(opts) {
  const file = opts._[1] || "requirements/REQUIREMENTS.md";
  if (!existsSync(file)) die(`${file} not found`);
  const reqs = parseRequirements(readFileSync(file, "utf8"));
  if (!reqs.length) die(`no "### REQ-…" blocks found in ${file}`);
  const cfgFile = path.join(HERE, "jev", "req-lint.json");
  const { uncovered, ...all } = loadQuestions(cfgFile);
  const uncoveredAt = JSON.parse(readFileSync(cfgFile, "utf8")).thresholds?.uncovered ?? THRESHOLD;
  // Two items per requirement: the statement questions keep their validated state {requirement: <statement>};
  // `uncovered` needs the acceptance criteria too, so it gets its own item, only when the requirement has criteria.
  const UNC = "#uncovered";
  const items = reqs.map((r) => ({ id: r.id, state: { requirement: r.statement } }));
  if (uncovered) for (const r of reqs) if (r.criteria.length)
    items.push({ id: r.id + UNC, state: { requirement: { statement: r.statement, criteria: r.criteria } } });
  const isConstraint = (id) => /^REQ-C-/.test(id);
  const res = await judgeAll(items, (it) => {
    if (String(it.id).endsWith(UNC)) return { uncovered };
    if (!isConstraint(it.id)) return all;
    const { ears, impl_leak, ...rest } = all;
    return rest;
  }, Number(opts.concurrency) || 16);
  const byId = new Map(res.items.filter((it) => !String(it.id).endsWith(UNC)).map((it) => [it.id, it]));
  for (const it of res.items) if (String(it.id).endsWith(UNC)) {
    const base = byId.get(it.id.slice(0, -UNC.length));
    if (base) Object.assign(base.answers, it.answers);
  }
  for (const e of res.errors) e.id = String(e.id).replace(UNC, "");
  res.items = [...byId.values()];
  for (const it of res.items) {
    const a = it.answers;
    const flags = ["vague", "compound", "unverifiable", "impl_leak"].filter((k) => typeof a[k] === "number" && a[k] > THRESHOLD);
    if (a.ears && a.ears.choice === "not_ears") flags.push("not_ears");
    if (typeof a.uncovered === "number" && a.uncovered >= uncoveredAt) flags.push("uncovered");
    it.flags = flags;
  }
  res.source = file;
  res.threshold = THRESHOLD;
  res.thresholds = { default: THRESHOLD, uncovered: uncoveredAt };
  if (opts.out) emit(res, opts.out);
  if (opts.json) { emit(res); return res; }
  const flagged = res.items.filter((i) => i.flags.length);
  for (const i of flagged) {
    const a = i.answers;
    const probs = ["vague", "compound", "unverifiable", "impl_leak", "uncovered"].filter((k) => k in a).map((k) => `${k}=${a[k].toFixed(2)}`).join(" ");
    process.stdout.write(`${i.id}\t${i.flags.join(",")}\t${a.ears ? `ears=${a.ears.choice}(${a.ears.confidence.toFixed(2)}) ` : ""}${probs}\n`);
  }
  process.stdout.write(`req-lint: ${res.items.length} requirements, ${flagged.length} flagged, ${res.errors.length} errors, ` +
    `${res.usage.input_tokens} tokens (${res.model || MODEL})\n`);
  return res;
}

// ── needs (need coverage) ────────────────────────────────────────────────────
// Mechanical check always (no network). With Jev on, one Choice per in-scope need over the active requirement IDs
// (criteria = statement) plus "none", built here because the options depend on the document.
async function needsCmd(opts) {
  const needsFile = opts._[1] || "requirements/CUSTOMER-NEEDS.md";
  const reqFile = opts._[2] || "requirements/REQUIREMENTS.md";
  for (const f of [needsFile, reqFile]) if (!existsSync(f)) die(`${f} not found`);
  const reqText = readFileSync(reqFile, "utf8");
  const needs = parseNeeds(readFileSync(needsFile, "utf8"));
  const reqs = parseRequirements(reqText);
  if (!needs.length) die(`no "### N-…" blocks found in ${needsFile}`);
  if (!reqs.length) die(`no "### REQ-…" blocks found in ${reqFile}`);
  const mech = checkNeedCoverage(needs, reqs, reqText);
  const res = { source: { needs: needsFile, requirements: reqFile }, mechanical: mech };
  const say = (s) => { if (!opts.json) process.stdout.write(s + "\n"); };
  for (const e of mech.errors) say(`error\t${e.code}\t${e.msg}`);
  for (const w of mech.warnings) say(`warn\t${w.code}\t${w.msg}`);
  say(`mechanical: ${mech.needs} needs (${mech.outOfScope} out-of-scope), ${mech.requirements} requirements, ` +
    `${mech.errors.length} errors, ${mech.warnings.length} warnings, Must ${Math.round(mech.mustRatio * 100)} %`);
  const off = disabledReason();
  if (opts.mechanical || off) {
    if (opts.out) emit(res, opts.out);
    if (opts.json) emit(res);
    if (opts.mechanical) return mech.errors.length ? 1 : 0;
    process.stderr.write(`sdd-jev: disabled (${off}); Jev suggestions skipped\n`);
    return 3;
  }
  const cfg = JSON.parse(readFileSync(path.join(HERE, "jev", "need-coverage.json"), "utf8"));
  const minConf = cfg.thresholds?.confidence ?? THRESHOLD;
  const options = reqs.filter((r) => !r.deprecated && (r.type === "F" || r.type === "NF" || (r.needs || []).length));
  const inScope = needs.filter((n) => n.status !== "out-of-scope" && n.quote);
  if (options.length > 254 || inScope.length > 254) die("more than 254 requirements or needs exceed Jev's 255 options; run per section");
  const withOptions = (q, opts_) => ({ ...q, criteria: { ...opts_, ...q.criteria } });
  // Pass 1: which requirement delivers each need.
  const requirements = Object.fromEntries(options.map((r) => [r.id, r.statement]));
  const q1 = { covered_by: withOptions(cfg.questions.covered_by, requirements) };
  const j = await judgeAll(inScope.map((n) => ({ id: n.id, state: { need: { id: n.id, quote: n.quote }, requirements } })),
    () => q1, Number(opts.concurrency) || 16);
  const top = new Set();
  for (const it of j.items) {
    const a = it.answers.covered_by;
    it.flags = [];
    if (a.choice === "none") it.flags.push("none");
    if (a.confidence < minConf) it.flags.push("low-confidence");
    if (a.choice !== "none" && !(mech.coveredBy[it.id] || []).includes(a.choice)) it.flags.push("not-declared");
    top.add(a.choice);
  }
  // Pass 2: requirements no need picked as top — which need, if any, do they serve?
  const needMap = Object.fromEntries(inScope.map((n) => [n.id, n.quote]));
  const q2 = { serves: withOptions(cfg.questions.serves, needMap) };
  const rest = options.filter((r) => !top.has(r.id));
  const j2 = await judgeAll(rest.map((r) => ({ id: r.id, state: { requirement: { id: r.id, statement: r.statement }, needs: needMap } })),
    () => q2, Number(opts.concurrency) || 16);
  const neverTop = j2.items.map((it) => {
    const a = it.answers.serves;
    const declared = (options.find((r) => r.id === it.id).needs || []);
    const flags = [];
    if (a.choice === "none" || a.confidence < minConf) flags.push("gold-plating-candidate");
    if (a.choice !== "none" && !declared.includes(a.choice)) flags.push("not-declared");
    return { id: it.id, serves: a.choice, confidence: a.confidence, p: a.p, declared, flags };
  });
  const errors = [...j.errors, ...j2.errors];
  const usage = { input_tokens: j.usage.input_tokens + j2.usage.input_tokens, requests: j.usage.requests + j2.usage.requests };
  Object.assign(res, { model: j.model || j2.model, thresholds: { confidence: minConf }, items: j.items, neverTop, errors, usage });
  if (opts.out) emit(res, opts.out);
  if (opts.json) { emit(res); return errors.length ? 1 : 0; }
  for (const it of j.items.filter((i) => i.flags.length)) {
    const a = it.answers.covered_by;
    const top3 = Object.entries(a.p || {}).sort((x, y) => y[1] - x[1]).slice(0, 3).map(([k, v]) => `${k}=${v.toFixed(2)}`).join(" ");
    say(`need\t${it.id}\t${it.flags.join(",")}\ttop=${a.choice}(${a.confidence.toFixed(2)}) ${top3}`);
  }
  for (const r of neverTop) say(`req\t${r.id}\tnever-top${r.flags.length ? "," + r.flags.join(",") : ""}\tserves=${r.serves}(${r.confidence.toFixed(2)}) declared=${r.declared.join(",") || "-"}`);
  const cand = neverTop.filter((r) => r.flags.includes("gold-plating-candidate")).length;
  say(`jev: ${j.items.length} needs judged, ${j.items.filter((i) => i.flags.length).length} flagged, ` +
    `${neverTop.length} never-top requirements (${cand} gold-plating candidates), ${errors.length} errors, ` +
    `${usage.input_tokens} tokens (${res.model || MODEL})`);
  return errors.length ? 1 : 0;
}

// ── chunks ───────────────────────────────────────────────────────────────────
const TOP = /^(export\s+)?(async\s+)?(def|class|function|const|let|module|public|private|func|fn|impl|interface|type)\b|^[A-Za-z_][\w-]*\s*\(\)\s*\{/;

export function chunkText(text, file, maxChars) {
  const lines = text.split("\n");
  const out = [];
  let start = 0, size = 0;
  const flush = (end) => {
    if (end > start) out.push({ id: `${file}:${start + 1}-${end}`, path: file, start: start + 1, end, code: lines.slice(start, end).join("\n") });
    start = end; size = 0;
  };
  for (let i = 0; i < lines.length; i++) {
    const len = lines[i].length + 1;
    if (size > 0 && (size + len > maxChars || (TOP.test(lines[i]) && size > maxChars / 2))) flush(i);
    size += len;
  }
  flush(lines.length);
  return out;
}

// ── main ─────────────────────────────────────────────────────────────────────
async function main() {
  const opts = args(process.argv.slice(2));
  const cmd = opts._[0];
  if (!cmd || cmd === "help" || opts.help) {
    process.stdout.write(readFileSync(fileURLToPath(import.meta.url), "utf8").split("\nimport ")[0].replace(/^#!.*\n/, "").replace(/^\/\/ ?/gm, "") + "\n");
    return 0;
  }
  if (cmd === "chunks") {
    const max = Number(opts["max-chars"]) || 24000;
    for (const f of opts._.slice(1)) for (const c of chunkText(readFileSync(f, "utf8"), f, max)) process.stdout.write(JSON.stringify(c) + "\n");
    return 0;
  }
  if (cmd === "needs") return needsCmd(opts);
  const off = disabledReason();
  if (cmd === "status") {
    process.stdout.write(off ? `disabled: ${off}\n` : `enabled ${MODEL}\n`);
    return off ? 3 : 0;
  }
  if (off) die(`disabled (${off}); fall back to the LLM`, 3);
  if (cmd === "judge") {
    if (!opts.questions) die("judge needs --questions FILE.json");
    const qs = loadQuestions(opts.questions);
    const res = await judgeAll(readItems(opts.items), () => qs, Number(opts.concurrency) || 16);
    emit(res, opts.out);
    if (opts.out) process.stderr.write(`sdd-jev: ${res.items.length} items, ${res.errors.length} errors, ${res.usage.input_tokens} tokens\n`);
    return res.errors.length ? 1 : 0;
  }
  if (cmd === "req-lint") {
    const res = await reqLint(opts);
    return res.errors.length ? 1 : 0;
  }
  die(`unknown command ${cmd}`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().then((c) => process.exit(c || 0), (e) => die(String(e.stack || e)));
}
