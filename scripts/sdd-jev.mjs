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
//       skip the EARS and implementation-leak questions. Prints the flagged requirements; --json prints the JSON.
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

// ── req-lint ─────────────────────────────────────────────────────────────────
export function parseRequirements(text) {
  const reqs = [];
  let cur = null;
  for (const line of text.split("\n")) {
    const h = line.match(/^#{2,4}\s+(REQ-[A-Z]+(?:-[A-Z0-9]+)*-\d+)\s*[:—-]?\s*(.*)$/);
    if (h) { cur = { id: h[1], title: h[2].trim(), statement: "", criteria: [] }; reqs.push(cur); continue; }
    if (!cur) continue;
    if (/^#{1,3}\s/.test(line)) { cur = null; continue; }
    const s = line.match(/^\s*[-*]?\s*\*\*(Statement|Enunciado|Requirement|Requisito)\s*:?\*\*\s*:?\s*(.+)$/i);
    if (s) { cur.statement = s[2].trim(); continue; }
    const g = line.match(/^\s{2,}[-*]\s+(GIVEN|DADO|Given|Dado)\b(.+)$/);
    if (g) cur.criteria.push((g[1] + g[2]).trim());
  }
  for (const r of reqs) if (!r.statement) r.statement = r.title;
  return reqs;
}

async function reqLint(opts) {
  const file = opts._[1] || "requirements/REQUIREMENTS.md";
  if (!existsSync(file)) die(`${file} not found`);
  const reqs = parseRequirements(readFileSync(file, "utf8"));
  if (!reqs.length) die(`no "### REQ-…" blocks found in ${file}`);
  const all = loadQuestions(path.join(HERE, "jev", "req-lint.json"));
  const items = reqs.map((r) => ({ id: r.id, state: { requirement: r.statement } }));
  const isConstraint = (id) => /^REQ-C-/.test(id);
  const res = await judgeAll(items, (it) => {
    if (!isConstraint(it.id)) return all;
    const { ears, impl_leak, ...rest } = all;
    return rest;
  }, Number(opts.concurrency) || 16);
  for (const it of res.items) {
    const a = it.answers;
    const flags = ["vague", "compound", "unverifiable", "impl_leak"].filter((k) => typeof a[k] === "number" && a[k] > THRESHOLD);
    if (a.ears && a.ears.choice === "not_ears") flags.push("not_ears");
    it.flags = flags;
  }
  res.source = file;
  res.threshold = THRESHOLD;
  if (opts.out) emit(res, opts.out);
  if (opts.json) { emit(res); return res; }
  const flagged = res.items.filter((i) => i.flags.length);
  for (const i of flagged) {
    const a = i.answers;
    const probs = ["vague", "compound", "unverifiable", "impl_leak"].filter((k) => k in a).map((k) => `${k}=${a[k].toFixed(2)}`).join(" ");
    process.stdout.write(`${i.id}\t${i.flags.join(",")}\t${a.ears ? `ears=${a.ears.choice}(${a.ears.confidence.toFixed(2)}) ` : ""}${probs}\n`);
  }
  process.stdout.write(`req-lint: ${res.items.length} requirements, ${flagged.length} flagged, ${res.errors.length} errors, ` +
    `${res.usage.input_tokens} tokens (${res.model || MODEL})\n`);
  return res;
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
