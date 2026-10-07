// check.mjs — compares the raw outputs of tests/seeded/run.sh with the answer key (tests/seeded/EXPECTED.md).
// Usage: node tests/seeded/check.mjs OUT_DIR   (OUT_DIR holds NAME.json / NAME.err / NAME.rc for node-test, quotes,
// accept, gate, plan, tasks, and the second stage floor and floor2). Prints the table «defecto → cazado por» and exits 1 when an expected mechanical layer
// misses its defect, a control requirement is flagged, or a precondition fails. Node >= 18, no dependencies.
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";

const OUT = process.argv[2];
if (!OUT || !existsSync(OUT)) { console.error("usage: node check.mjs OUT_DIR"); process.exit(2); }
const read = (f) => (existsSync(path.join(OUT, f)) ? readFileSync(path.join(OUT, f), "utf8") : "");
const rcOf = (name) => Number(read(`${name}.rc`).trim() || "NaN");
const jsonOf = (name) => { try { return JSON.parse(read(`${name}.json`)); } catch { return null; } };

// ------------------------------------------------------------------ answer key (mirrors EXPECTED.md)
// expect: the mechanical layers that must catch the defect; "adversarial" = only the blind round can. Every test of
// the project quotes its criterion verbatim above the assert and keeps its literals, except D1 (literal dropped from
// the assert) and D2 (quote and assert of the text before a MODIFY): any other lint --quotes finding is a false
// positive. D2 also lacks the current literal, so Q-03 there is expected too.
const KEY = [
  { id: "D1", pattern: "P3", what: "literal debilitado", req: "REQ-F-002", ac: 1, expect: ["Q-03", "weakened"], allowQ: ["Q-03"] },
  { id: "D2", pattern: "P3", what: "cita desactualizada", req: "REQ-F-003", ac: 1, expect: ["Q-02", "weakened"], allowQ: ["Q-02", "Q-03"] },
  { id: "D3", pattern: "P2", what: "pieza no cableada", req: "REQ-F-004", ac: 1, expect: ["adversarial"] },
  { id: "D4", pattern: "P1", what: "mock ≠ real", req: "REQ-F-005", ac: 1, port: "CvGenerator", expect: ["V-21", "adversarial"] },
  { id: "D5", pattern: "P4", what: "replay", req: "REQ-F-006", ac: 2, expect: ["adversarial"] },
  { id: "D6", pattern: "M3", what: "sin captura", req: "REQ-F-007", ac: 1, expect: ["unshown"] },
  { id: "D7", pattern: "M3", what: "sin vídeo", wf: "WF-001", expect: ["missing_videos"] },
  { id: "C1", what: "control", req: "REQ-F-001", control: true },
  { id: "C2", what: "control", req: "REQ-F-008", control: true },
];

const failures = [];
const fail = (msg) => failures.push(msg);

// ------------------------------------------------------------------ inputs
const nodeTest = rcOf("node-test");
if (nodeTest !== 0) fail(`precondición: la suite del proyecto no está en verde (node --test exit ${nodeTest})`);

const tasksRc = rcOf("tasks");
if (tasksRc !== 0) fail(`sdd lint: exit ${tasksRc} (${read("tasks.json").trim().split("\n").pop()})`);

const plan = jsonOf("plan");
if (!plan) fail("sdd lint --plan --json: salida no JSON");
else if (plan.errors.length) fail(`sdd lint --plan: ${plan.errors.length} error(es): ${plan.errors.map((e) => `${e.check} ${e.message}`).join("; ")}`);

const ledger = jsonOf("accept");
if (!ledger) fail(`sdd accept --json: salida no JSON (exit ${rcOf("accept")}: ${read("accept.err").trim()})`);
else {
  if (ledger.summary.junit_stale_files) fail(`sdd accept: ${ledger.summary.junit_stale_files} JUnit stale (${read("accept.err").trim()})`);
  if (!ledger.summary.junit_files) fail("sdd accept: ningún JUnit leído");
}
const gate = jsonOf("gate");
const gateRc = rcOf("gate");
if (!gate) fail(`sdd gate --json: salida no JSON (exit ${gateRc})`);
else if (gateRc !== 1) fail(`sdd gate --fase 1: exit ${gateRc}, se esperaba 1 (goal not met)`);

// lint --quotes: SKIP while the CLI lacks it (unknown option); any other non-JSON output is a failure.
const quotesRc = rcOf("quotes");
const quotesJson = jsonOf("quotes");
let quotes = null; // null = not available
if (quotesJson && Array.isArray(quotesJson.findings)) {
  quotes = quotesJson.findings;
  if (quotesRc !== 1) fail(`sdd lint --quotes: exit ${quotesRc}, se esperaba 1 (hay Q-02/Q-03)`);
} else if (!/unknown option --quotes|unknown option|unexpected argument --quotes/i.test(read("quotes.err"))) {
  fail(`sdd lint --quotes --json: salida no reconocida (exit ${quotesRc}: ${read("quotes.err").trim().slice(0, 200)})`);
}
const literalLedger = Boolean(ledger && (ledger.summary.literal_gaps !== undefined
  || ledger.requirements.some((r) => (r.criteria || []).some((c) => c.state === "weakened"))));

// ------------------------------------------------------------------ detectors
const acNum = (v) => { const m = String(v ?? "").match(/(\d+)\s*$/); return m ? Number(m[1]) : null; };
const reqOf = (id) => ledger?.requirements.find((r) => r.id === id) || null;
const critOf = (id, n) => reqOf(id)?.criteria.find((c) => c.n === n) || null;
const qFindings = (req, ac) => (quotes || []).filter((f) => f.req === req && (ac == null || acNum(f.ac) === ac));

/** Every mechanical layer that flags this entry: [label]. */
function caughtBy(e) {
  const hits = [];
  if (e.req) {
    for (const f of qFindings(e.req, e.control ? null : e.ac)) hits.push(`lint --quotes ${f.code}`);
    const r = reqOf(e.req);
    if (r) {
      for (const c of r.criteria) {
        if (!e.control && c.n !== e.ac) continue;
        if (c.state === "weakened") hits.push(`ledger weakened (AC${c.n})`);
        else if (c.state === "unshown") hits.push(`ledger unshown (AC${c.n})`);
        else if (c.state !== "pass") hits.push(`ledger ${c.state} (AC${c.n})`);
      }
      if (r.verdict !== "VERIFIED" && !hits.some((h) => h.startsWith("ledger"))) hits.push(`ledger ${r.verdict}`);
    }
    for (const w of plan?.warnings || []) if (new RegExp(`\\b${e.req}\\b`).test(w.message)) hits.push(`lint --plan ${w.check}`);
  }
  if (e.port) for (const w of plan?.warnings || []) if (w.check === "V-21" && w.message.includes(`port ${e.port} `)) hits.push("lint --plan V-21");
  if (e.wf && (gate?.missing_videos || []).includes(e.wf)) hits.push("gate missing_videos");
  return [...new Set(hits)];
}

/** Whether the expected layer `x` caught entry e: true | false | null (layer not available: SKIP). */
function layerCaught(e, x, hits) {
  switch (x) {
    case "Q-02": case "Q-03": return quotes === null ? null : hits.includes(`lint --quotes ${x}`);
    case "weakened": return literalLedger ? critOf(e.req, e.ac)?.state === "weakened" : null;
    case "unshown": return critOf(e.req, e.ac)?.state === "unshown" && reqOf(e.req)?.verdict === "MISSING" && reqOf(e.req)?.reason === "no visual evidence";
    case "V-21": return hits.includes("lint --plan V-21");
    case "missing_videos": return hits.includes("gate missing_videos") && (ledger?.summary.missing_videos || []).includes(e.wf);
    default: return null;
  }
}
const LABEL = { "Q-02": "lint --quotes Q-02", "Q-03": "lint --quotes Q-03", weakened: "ledger weakened", unshown: "ledger unshown",
  "V-21": "lint --plan V-21", missing_videos: "gate missing_videos", adversarial: "solo ronda adversarial" };

// ------------------------------------------------------------------ table
const rows = [];
for (const e of KEY) {
  const hits = caughtBy(e);
  const target = e.req ? `${e.req}${e.control ? "" : ` AC${e.ac}`}` : e.wf;
  let result = "ok";
  const notes = [];
  if (e.control) {
    const r = reqOf(e.req);
    if (!r || r.verdict !== "VERIFIED") { result = "FAIL"; notes.push(`veredicto ${r?.verdict ?? "ausente"}`); }
    if (hits.length) { result = "FAIL"; notes.push("falso positivo"); }
    if (quotes === null && result === "ok") notes.push("sin lint --quotes");
    rows.push([e.id, e.what, target, "ninguna (VERIFIED, limpio)", hits.join(", ") || "—", result, notes.join("; ")]);
    if (result === "FAIL") fail(`${e.id} ${target}: ${notes.join("; ")}${hits.length ? ` (${hits.join(", ")})` : ""}`);
    continue;
  }
  const wrongQ = qFindings(e.req, e.ac).filter((f) => !(e.allowQ || []).includes(f.code));
  if (wrongQ.length) { result = "FAIL"; notes.push(`falso positivo de lint --quotes ${wrongQ.map((f) => f.code).join(", ")}`); }
  const mech = e.expect.filter((x) => x !== "adversarial");
  let skipped = 0;
  for (const x of mech) {
    const got = layerCaught(e, x, hits);
    if (got === null) { skipped++; notes.push(`SKIP ${LABEL[x]} (${x.startsWith("Q-") ? "lint --quotes no disponible" : "ledger sin estado weakened"})`); }
    else if (!got) { result = "FAIL"; notes.push(`${LABEL[x]} no lo caza`); }
  }
  if (result === "ok" && skipped && skipped === mech.length) result = "SKIP";
  else if (result === "ok" && skipped) result = "ok (parcial)";
  if (!mech.length) {
    // Adversarial-only: the mechanical layers are expected to stay silent; a hit is reported, never a failure.
    if (hits.length) notes.push("una capa mecánica también lo ve");
    if (reqOf(e.req)?.verdict === "VERIFIED" && !hits.length) notes.push("VERIFIED en verde: nada mecánico lo ve");
  } else if (e.expect.includes("adversarial")) notes.push("el resto, solo la ronda adversarial");
  rows.push([e.id, `${e.pattern} ${e.what}`, target, e.expect.map((x) => LABEL[x]).join(" + "), hits.join(", ") || "—", result, notes.join("; ")]);
  if (result === "FAIL") fail(`${e.id} ${target}: ${notes.filter((n) => !n.startsWith("SKIP")).join("; ")}`);
}

// ------------------------------------------------------------------ second stage: the floor guard (5.3)
// D8: a commit adds test.skip to the bound test of REQ-F-006 AC1 → exactly one F-01 error bound to it, no other F
// finding (control: the rest of the commit is clean). D9: a docs commit lowers literal_gate enforce → off → exactly one
// F-07 error on literal_gate, nothing else. Both against --base HEAD~1, so the base source is `flag`.
const FLOOR = [
  { id: "D8", what: "M1 test saltado", name: "floor", target: "REQ-F-006 AC1", expect: "lint --floor F-01",
    ok: (f) => f.code === "F-01" && f.severity === "error" && (f.criteria || []).includes("REQ-F-006 AC1") && f.file === "tests/api/confirmar.test.js" },
  { id: "D9", what: "M1 gate rebajado", name: "floor2", target: "literal_gate", expect: "lint --floor F-07",
    ok: (f) => f.code === "F-07" && f.severity === "error" && f.key === "literal_gate" && f.from === "enforce" && f.to === "off" },
];
for (const e of FLOOR) {
  const j = jsonOf(e.name), rc = rcOf(e.name);
  const notes = [];
  let result = "ok";
  if (!j || !Array.isArray(j.findings)) {
    result = "FAIL"; notes.push(`salida no JSON (exit ${rc}: ${read(`${e.name}.err`).trim().slice(0, 160)})`);
  } else {
    const hits = j.findings.filter(e.ok);
    const others = j.findings.filter((f) => !e.ok(f));
    if (hits.length !== 1) { result = "FAIL"; notes.push(`${hits.length} hallazgo(s) esperados, se quería 1`); }
    if (others.length) { result = "FAIL"; notes.push(`falso positivo: ${others.map((f) => `${f.code} ${f.severity} ${f.file}`).join(", ")}`); }
    if (rc !== 1) { result = "FAIL"; notes.push(`exit ${rc}, se esperaba 1`); }
    if (j.base?.source !== "flag") { result = "FAIL"; notes.push(`base ${j.base?.source}, se esperaba flag`); }
  }
  const caught = j && Array.isArray(j.findings) ? j.findings.map((f) => `${f.code} ${f.severity}`).join(", ") || "—" : "—";
  rows.push([e.id, e.what, e.target, e.expect, caught, result, notes.join("; ")]);
  if (result === "FAIL") fail(`${e.id} ${e.target}: ${notes.join("; ")}`);
}

// Findings of lint --quotes on requirements outside the key.
const known = new Set(KEY.filter((e) => e.req).map((e) => e.req));
for (const f of quotes || []) if (!known.has(f.req)) fail(`lint --quotes: hallazgo ${f.code} en ${f.req} (fuera de la clave)`);
// V-21 warnings other than the CvGenerator port.
for (const w of plan?.warnings || []) if (!(w.check === "V-21" && w.message.includes("port CvGenerator "))) fail(`lint --plan: aviso inesperado ${w.check} ${w.message}`);

const head = ["Defecto", "Qué", "Requisito / criterio", "Capa esperada", "Cazado por", "Resultado", "Notas"];
const widths = head.map((h, i) => Math.max(h.length, ...rows.map((r) => String(r[i]).length)));
const line = (cells) => `| ${cells.map((c, i) => String(c).padEnd(widths[i])).join(" | ")} |`;
console.log(line(head));
console.log(`|${widths.map((w) => "-".repeat(w + 2)).join("|")}|`);
for (const r of rows) console.log(line(r));
console.log("");
console.log(`precondición node --test: ${nodeTest === 0 ? "verde" : `exit ${nodeTest}`} · sdd lint: exit ${tasksRc} · lint --plan: ${plan ? `${plan.errors.length} error(es), ${plan.warnings.length} aviso(s)` : "?"} · gate --fase 1: exit ${gateRc}${gate ? ` (${gate.label})` : ""} · lint --quotes: ${quotes === null ? "no disponible (SKIP)" : `${quotes.length} hallazgo(s), exit ${quotesRc}`} · ledger weakened: ${literalLedger ? "sí" : "no disponible (SKIP)"}`);
if (failures.length) {
  console.log("");
  for (const f of failures) console.log(`FAIL ${f}`);
  console.log(`seeded: ${failures.length} fallo(s)`);
  process.exit(1);
}
console.log("seeded: ok");
