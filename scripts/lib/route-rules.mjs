// route-rules.mjs — the rules of the adaptive route (`sdd route`). Node >= 18, no deps.
//
// The pipeline decides which optional stages a project needs from two kinds of input:
//   facts    counted by code from requirements/REQUIREMENTS.md, requirements/CUSTOMER-NEEDS.md and the repo;
//   factors  seven narrow yes/no judgments about the needs and requirements (scripts/jev/route.json), answered
//            by Jev or by the LLM, as probabilities. p >= 0.65 is yes, p <= 0.35 is no, anything in between is a
//            doubt, and a doubt counts as yes (doubt raises rigor) and is named to the human.
// Each rule below returns {run, reason}: the reason is short English text citing the numbers and factors that
// decided it (skills translate it for the user). Edit a rule here and the route, its reasons and the tests follow.
import { readFileSync, readdirSync, existsSync, statSync } from "node:fs";
import path from "node:path";

export const FACTORS = ["external_customer", "sensitive_data", "multi_actor", "integrations", "ui_flows", "long_lived", "complex_state"];
export const DEFAULT_THRESHOLDS = { yes: 0.65, no: 0.35 };

// Stages that always run (the core of every route) and the optional ones the rules decide, in pipeline order.
export const CORE_STAGES = ["requirements-engineer", "plan-architect", "task-generator", "task-implementer", "acceptance"];
export const OPTIONAL_STAGES = ["specifications-engineer", "spec-auditor", "test-planner", "security-auditor", "ux-designer", "tech-designer", "gap-detector"];
export const STAGE_ORDER = ["requirements-engineer", "specifications-engineer", "spec-auditor", "test-planner", "plan-architect",
  "task-generator", "task-implementer", "acceptance", "security-auditor", "ux-designer", "tech-designer", "gap-detector"];

// Minutes each stage took on the real todo-app run (examples/todo-app/AUDIT-HISTORY.md, 2026-09): formal specs 29,
// spec audit 17, test plan 24. The lateral stages were not run there and do not run by default, so skipping them
// saves nothing against the default pipeline.
export const MEASURED_MINUTES = { "specifications-engineer": 29, "spec-auditor": 17, "test-planner": 24 };

// Thresholds for REQ-F counts: above 8 functional requirements formal specs pay off; above 5 their audit does.
export const SPEC_REQ_F = 8;
export const AUDIT_REQ_F = 5;
export const TESTPLAN_REQ_F = 8;

const LABEL = {
  external_customer: ["external customer", "no external customer"],
  sensitive_data: ["sensitive data", "no sensitive data"],
  multi_actor: ["several user types", "one user type"],
  integrations: ["external integrations", "no integrations"],
  ui_flows: ["UI screens", "no UI screens"],
  long_lived: ["long-lived", "not long-lived"],
  complex_state: ["complex state", "no complex state"],
};

/** Probability → "yes" | "no" | "doubt". A missing or invalid probability is a doubt (conservative). */
export function classify(p, t = DEFAULT_THRESHOLDS) {
  if (typeof p !== "number" || !Number.isFinite(p) || p < 0 || p > 1) return "doubt";
  if (p >= t.yes) return "yes";
  if (p <= t.no) return "no";
  return "doubt";
}

/** {name: probability} → {factors: {name: {p, value}}, doubts: [name]}. */
export function evaluateFactors(probs, t = DEFAULT_THRESHOLDS) {
  const factors = {};
  const doubts = [];
  for (const f of FACTORS) {
    const raw = probs ? probs[f] : undefined;
    const p = typeof raw === "number" && Number.isFinite(raw) ? Math.round(raw * 1000) / 1000 : null;
    const value = classify(p, t);
    factors[f] = { p, value };
    if (value === "doubt") doubts.push(f);
  }
  return { factors, doubts };
}

// ── facts ────────────────────────────────────────────────────────────────────
function hasFiles(dir, depth = 0) {
  let entries;
  try { entries = readdirSync(dir, { withFileTypes: true }); } catch { return false; }
  for (const e of entries) {
    if (e.name.startsWith(".") || e.name === "node_modules") continue;
    if (e.isFile()) return true;
    if (e.isDirectory() && depth < 6 && hasFiles(path.join(dir, e.name), depth + 1)) return true;
  }
  return false;
}

// A REQ-C that names the language, runtime or framework counts as a declared stack (tech-designer can be skipped).
const STACK_WORDS = /\b(typescript|javascript|node(\.js)?|deno|bun|python|django|flask|fastapi|ruby|rails|go(lang)?|rust|java|kotlin|spring|swift|php|laravel|c#|\.net|elixir|phoenix|next\.js|react|vue|svelte|angular|flutter|dart)\b/i;

/**
 * Counted facts. reqs/needs come from parseRequirements/parseNeeds of scripts/sdd-jev.mjs; profile is the SDD Stack
 * Profile of the project's CLAUDE.md ({} when absent); root is the project directory.
 *   req_f, req_nf, req_c   active (not deprecated) requirements of each type
 *   must                   active requirements with priority Must
 *   needs, needs_out       customer needs in scope / out of scope
 *   has_code               some code_paths entry of the Stack Profile (default src) exists and holds files (brownfield)
 *   has_profile            CLAUDE.md has `## SDD Stack Profile` with a `test` command
 *   stack_declared         has_profile, or a REQ-C names the language, runtime or framework
 */
export function computeFacts({ reqs, needs, profile = {}, root }) {
  const active = reqs.filter((r) => !r.deprecated);
  const count = (t) => active.filter((r) => r.type === t).length;
  const codePaths = String(profile.code_paths || "").split(",").map((s) => s.trim().replace(/^\.\//, "").replace(/\/+$/, "")).filter((s) => s && s !== ".");
  const has_code = (codePaths.length ? codePaths : ["src"]).some((p) => {
    const abs = path.join(root, p);
    try { return statSync(abs).isDirectory() ? hasFiles(abs) : existsSync(abs); } catch { return false; }
  });
  const has_profile = Boolean(profile.test && String(profile.test).trim());
  const stack_declared = has_profile || active.some((r) => r.type === "C" && STACK_WORDS.test(r.statement || ""));
  return {
    req_f: count("F"), req_nf: count("NF"), req_c: count("C"),
    must: active.filter((r) => r.priority === "Must").length,
    needs: needs.filter((n) => n.status !== "out-of-scope").length,
    needs_out: needs.filter((n) => n.status === "out-of-scope").length,
    has_code, has_profile, stack_declared,
  };
}

// ── rules ────────────────────────────────────────────────────────────────────
// A rule lists its triggers: [label, fired]. A factor trigger fires on yes or doubt; its label is the factor label
// ("sensitive data") or "doubt about sensitive data". run = any trigger fired; the reason names the fired triggers,
// or, when none fired, the negative label of every trigger that was checked.
function factorTrigger(factors, name) {
  const v = factors[name]?.value || "doubt";
  if (v === "yes") return { fired: true, text: LABEL[name][0] };
  if (v === "doubt") return { fired: true, text: `doubt about ${LABEL[name][0]}` };
  return { fired: false, text: LABEL[name][1] };
}
function countTrigger(n, limit, what) {
  return n > limit ? { fired: true, text: `${n} ${what} (> ${limit})` } : { fired: false, text: `${n} ${what} (≤ ${limit})` };
}
function decide(triggers) {
  const fired = triggers.filter((t) => t.fired);
  return fired.length
    ? { run: true, reason: `run: ${fired.map((t) => t.text).join(", ")}` }
    : { run: false, reason: `skip: ${triggers.map((t) => t.text).join(", ")}` };
}

export const RULES = {
  // Formal specs pay off when there are many functional requirements or anything that needs precise shared models.
  "specifications-engineer": (f, x) => decide([
    countTrigger(f.req_f, SPEC_REQ_F, "REQ-F"),
    factorTrigger(x, "multi_actor"), factorTrigger(x, "integrations"),
    factorTrigger(x, "sensitive_data"), factorTrigger(x, "complex_state"),
  ]),
  // The spec audit needs specs, and then pays off with more than 5 REQ-F, sensitive data or a customer who accepts.
  "spec-auditor": (f, x, s) => (!s["specifications-engineer"].run
    ? { run: false, reason: "skip: formal specs are skipped, nothing to audit" }
    : decide([countTrigger(f.req_f, AUDIT_REQ_F, "REQ-F"), factorTrigger(x, "sensitive_data"), factorTrigger(x, "external_customer")])),
  // The test plan builds on the specs' BDD scenarios; without specs the tests are named after `REQ-X-NNN ACn`.
  "test-planner": (f, x, s) => (!s["specifications-engineer"].run
    ? { run: false, reason: "skip: formal specs are skipped; tests are named after the acceptance criteria (REQ-X-NNN ACn)" }
    : decide([factorTrigger(x, "ui_flows"), countTrigger(f.req_f, TESTPLAN_REQ_F, "REQ-F"), factorTrigger(x, "external_customer")])),
  "security-auditor": (f, x) => decide([factorTrigger(x, "sensitive_data")]),
  "ux-designer": (f, x) => decide([factorTrigger(x, "ui_flows")]),
  "tech-designer": (f, x) => decide([
    factorTrigger(x, "integrations"), factorTrigger(x, "complex_state"),
    f.stack_declared
      ? { fired: false, text: f.has_profile ? "stack declared in the SDD Stack Profile" : "stack declared in a REQ-C" }
      : { fired: true, text: "no stack declared (no SDD Stack Profile test command, no REQ-C naming it)" },
  ]),
  // gap-detector compares specs with code; without specs it can still run --semantic against existing code.
  "gap-detector": (f, x, s) => {
    if (s["specifications-engineer"].run) return { run: true, reason: "run: formal specs run, gaps are checked against them" };
    if (f.has_code) return { run: true, reason: "run with --semantic: formal specs are skipped and code already exists" };
    return { run: false, reason: "skip: formal specs are skipped and there is no code yet" };
  },
};

/** facts + evaluated factors → {stages: {name: {run, reason}}} in STAGE_ORDER. */
export function decideRoute(facts, factors) {
  const s = {};
  for (const c of CORE_STAGES) s[c] = { run: true, reason: "core" };
  for (const o of OPTIONAL_STAGES) s[o] = RULES[o](facts, factors, s);
  return Object.fromEntries(STAGE_ORDER.map((k) => [k, s[k]]));
}

/** Minutes the skipped stages took on the measured run (0 for stages that do not run by default). */
export function savedMinutes(stages) {
  return Object.entries(stages).reduce((n, [k, v]) => n + (!v.run ? MEASURED_MINUTES[k] || 0 : 0), 0);
}

/** Reads a question set's thresholds (scripts/jev/route.json), falling back to the defaults. */
export function loadThresholds(file) {
  try {
    const t = JSON.parse(readFileSync(file, "utf8")).thresholds || {};
    return { yes: typeof t.yes === "number" ? t.yes : DEFAULT_THRESHOLDS.yes, no: typeof t.no === "number" ? t.no : DEFAULT_THRESHOLDS.no };
  } catch { return { ...DEFAULT_THRESHOLDS }; }
}
