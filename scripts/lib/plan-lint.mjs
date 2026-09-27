// plan-lint.mjs — `sdd lint --plan`: mechanical checks of a vertical plan (plan/PLAN.md `Plan-Style: vertical`).
// Node >= 18, no dependencies. Called from scripts/sdd.mjs; returns an exit code (never calls process.exit).
//
// Checks (rules: skills/sdd-plan-architect/references/phase-assignment-rules.md, template: fase-template.md):
//   P-HEADER  each FASE header (before the first `## `) has `Requisitos:` with REQ ids and `Escenarios:` with scenario
//             ids (AC-NNN-NN, or `REQ-X-NNN ACn` for requirements without a BDD scenario); `Incremento:` and
//             `Necesidades:` missing → warning.
//   P-AC      every REQ id in `Requisitos:` exists in requirements/REQUIREMENTS.md; every scenario id cited in
//             `Escenarios:` or in the Demo exists in spec/tests/BDD-*.md (a `REQ ACn` pair: the REQ has criterion n).
//   V8        `## Criterios de Éxito` has criteria backed by a REQ or scenario id (a criterion without one → warning),
//             and `## Demo` has 1-10 numbered rows, each citing a scenario id.
//   V9        every active Must REQ-F / REQ-NF appears in some `Requisitos:` line (REQ-C constraints apply to every
//             FASE and are not assigned).
//   P-SIZE    warning when a FASE spans more than 3 use cases, or its task/TASK-FASE-N.md has more than 15 tasks.
//   V-20      (task file present) warning for each scenario of `Escenarios:` that no task of task/TASK-FASE-N.md cites
//             (sdd-task-generator treats it as an error in its own validation).
// A plan without the marker is horizontal (legacy): skipped with a note, exit 0. A mixed plan
// (`Plan-Style: vertical (from FASE-4)`) checks FASE-4 onward; REQ ids cited in the earlier FASEs count for V9.
import { existsSync, readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import { loadScenarios, effectivePriority } from "./acceptance.mjs";
import { parseRequirements } from "../sdd-jev.mjs";

class Exit extends Error { constructor(code) { super(`exit ${code}`); this.code = code; } }
let PROG = "sdd";
const out = (s) => console.log(s);
const usage = (msg) => { console.error(`${PROG}: ${msg} (see --help)`); throw new Exit(2); };

export const MAX_UCS = 3;
export const MAX_TASKS = 15;
export const MAX_DEMO_STEPS = 10;
const REQ_RE = /\bREQ-[A-Z]+(?:-[A-Z0-9]+)*-\d+\b/g;
const AC_RE = /\bAC-(\d{3,})-(\d{2,})(?!\d)/g;
const REQ_AC_RE = /\b(REQ-[A-Z]+(?:-[A-Z0-9]+)*-\d+)\s+AC(\d+)\b/g;
const UC_RE = /\bUC-\d{3,}\b/g;
const isBacked = (t) => /\bREQ-[A-Z]+(?:-[A-Z0-9]+)*-\d+\b/.test(t) || /\bAC-\d{3,}-\d{2,}/.test(t);
const MARKER_RE = /Plan-Style\s*:?\**\s*:?\s*`?([A-Za-z-]+)/i;

function parse(argv) {
  const o = { _: [], dir: "plan", json: false };
  for (let i = 0; i < argv.length; i++) {
    let a = argv[i], v;
    const eq = a.match(/^(--[a-z-]+)=(.*)$/s);
    if (eq) { a = eq[1]; v = eq[2]; }
    const take = () => { if (v !== undefined) return v; if (i + 1 >= argv.length) usage(`${a} needs a value`); return argv[++i]; };
    if (a === "--plan") continue;
    else if (a === "--dir") o.dir = take();
    else if (a === "--repo") o.repo = take();
    else if (a === "--requirements") o.requirements = take();
    else if (a === "--json") o.json = true;
    else if (a.startsWith("-")) usage(`unknown option ${a} for lint --plan`);
    else o._.push(a);
  }
  return o;
}

/** `vertical` | `horizontal` | null (no PLAN.md). The marker is `> **Plan-Style:** vertical` in plan/PLAN.md. */
export function planStyle(planDir) {
  return planMarker(planDir).style;
}
/** {style, from}: `from` = first vertical FASE of a mixed plan (`Plan-Style: vertical (from FASE-4)`), else 0. */
export function planMarker(planDir) {
  const f = path.join(planDir, "PLAN.md");
  if (!existsSync(f)) return { style: null, from: 0 };
  const line = readFileSync(f, "utf8").split(/\r?\n/).find((l) => MARKER_RE.test(l));
  const m = line && line.match(MARKER_RE);
  if (!m || m[1].toLowerCase() !== "vertical") return { style: "horizontal", from: 0 };
  const from = line.match(/from\s+FASE-?(\d+)/i);
  return { style: "vertical", from: from ? Number(from[1]) : 0 };
}

const canonAc = (m) => `AC-${m[1]}-${m[2]}`;
function scenarioRefs(text) {
  const acs = [...String(text).matchAll(AC_RE)].map(canonAc);
  const reqAcs = [...String(text).matchAll(REQ_AC_RE)].map((m) => ({ req: m[1], ac: Number(m[2]) }));
  return { acs: [...new Set(acs)], reqAcs };
}
const headerLine = (head, label) => head.find((h) => new RegExp(`\\b(?:${label})\\b[*\\s]*:`, "i").test(h.text));

/** Parse one FASE file into header lines, criteria and demo rows (all with line numbers). */
export function parseFase(text, file) {
  const lines = String(text).split(/\r?\n/).map((t, i) => ({ text: t, line: i + 1 }));
  const n = (path.basename(file).match(/^FASE-0*(\d+)/i) || [])[1];
  const end = lines.findIndex((l, i) => i > 0 && /^##\s/.test(l.text));
  const head = lines.slice(0, end < 0 ? lines.length : end);
  const sections = new Map();
  let cur = null;
  for (const l of lines) {
    const h = l.text.match(/^##\s+(.+?)\s*$/);
    if (h) { cur = { title: h[1], line: l.line, lines: [] }; sections.set(h[1].toLowerCase(), cur); continue; }
    if (cur) cur.lines.push(l);
  }
  const find = (re) => [...sections.values()].find((s) => re.test(s.title));
  const crit = find(/^criterios de [ée]xito|^success criteria/i);
  const demo = find(/^demo\b/i);
  let group = null;
  const criteria = [];
  for (const l of crit ? crit.lines : []) {
    const g = l.text.match(/^###\s+(.+)$/);
    if (g) { group = g[1].trim(); continue; }
    if (/^\s*[-*]\s+\[[ xX]\]\s+/.test(l.text)) criteria.push({ ...l, group });
  }
  const demoRows = [];
  for (const l of demo ? demo.lines : []) {
    const cells = l.text.trim().match(/^\|(.*)\|$/);
    if (!cells) continue;
    const c = cells[1].split("|").map((s) => s.trim());
    if (/^\d+$/.test(c[0])) demoRows.push({ ...l, n: Number(c[0]), cells: c });
  }
  const req = headerLine(head, "Requisitos|Requirements");
  const esc = headerLine(head, "Escenarios|Scenarios");
  return {
    file, fase: n === undefined ? null : Number(n),
    requisitos: req ? { line: req.line, ids: [...new Set(req.text.match(REQ_RE) || [])] } : null,
    escenarios: esc ? { line: esc.line, ...scenarioRefs(esc.text) } : null,
    incremento: headerLine(head, "Incremento|Increment") || null,
    necesidades: headerLine(head, "Necesidades|Needs") || null,
    criteria: crit ? { line: crit.line, items: criteria } : null,
    demo: demo ? { line: demo.line, rows: demoRows } : null,
  };
}

function taskFile(root, fase) {
  const f = path.join(root, "task", `TASK-FASE-${fase}.md`);
  if (!existsSync(f)) return null;
  const text = readFileSync(f, "utf8");
  return { text, tasks: text.split(/\r?\n/).filter((l) => /^- \[( |x|!)\] TASK-F\d+-\d{3,4}\b/.test(l)).length };
}

/** Lint a vertical plan. Returns {style, fases, errors, warnings, notes}. */
export function lintPlan(root, { dir = "plan", requirements } = {}) {
  const planDir = path.resolve(root, dir);
  const rel = (f) => path.relative(root, f) || f;
  const errors = [], warnings = [], notes = [];
  const err = (file, line, check, message) => errors.push({ file, line, check, message });
  const warn = (file, line, check, message) => warnings.push({ file, line, check, message });
  const { style, from } = planMarker(planDir);
  if (style !== "vertical") {
    notes.push(style === null ? `${rel(path.join(planDir, "PLAN.md"))} not found: nothing to lint`
      : `${rel(path.join(planDir, "PLAN.md"))} has no \`Plan-Style: vertical\` marker: horizontal (legacy) plan, skipped`);
    return { style, fases: [], errors, warnings, notes };
  }
  const fasesDir = path.join(planDir, "fases");
  const files = existsSync(fasesDir) ? readdirSync(fasesDir).filter((f) => /^FASE-\d+.*\.md$/i.test(f)).sort((a, b) =>
    Number(a.match(/\d+/)[0]) - Number(b.match(/\d+/)[0]) || a.localeCompare(b)) : [];
  if (!files.length) err(rel(fasesDir), 0, "V8", "no FASE-N-*.md files");

  const reqFile = path.resolve(root, requirements || "requirements/REQUIREMENTS.md");
  const reqs = existsSync(reqFile) ? parseRequirements(readFileSync(reqFile, "utf8")) : null;
  if (!reqs) notes.push(`${rel(reqFile)} not found: REQ ids and V9 not checked`);
  const reqById = new Map((reqs || []).map((r) => [r.id, r]));
  const hasSpecTests = existsSync(path.join(root, "spec", "tests"));
  const scenarioIds = new Set(loadScenarios(root).map((s) => s.id));
  if (!hasSpecTests) notes.push("spec/tests/ not found: scenario ids not checked against BDD files");

  const checkScenario = (file, line, where, refs) => {
    if (hasSpecTests) for (const id of refs.acs) if (!scenarioIds.has(id)) err(file, line, "P-AC", `${where}: ${id} is not a scenario of spec/tests/BDD-*.md`);
    if (reqs) for (const { req, ac } of refs.reqAcs) {
      const r = reqById.get(req);
      if (!r) err(file, line, "P-AC", `${where}: ${req} is not in ${rel(reqFile)}`);
      else if (ac < 1 || ac > r.criteria.length) err(file, line, "P-AC", `${where}: ${req} has no acceptance criterion ${ac}`);
    }
  };

  const fases = [];
  const assigned = new Set();
  const legacy = [];
  for (const f of files) {
    const abs = path.join(fasesDir, f);
    const file = rel(abs);
    const text = readFileSync(abs, "utf8");
    const fz = parseFase(text, f);
    if (fz.fase !== null && fz.fase < from) {
      legacy.push(file);
      for (const id of text.match(REQ_RE) || []) assigned.add(id);
      continue;
    }
    const summary = { file, fase: fz.fase, requirements: [], scenarios: 0, criteria: 0, demoSteps: 0, useCases: [], tasks: null };
    fases.push(summary);

    // Header
    if (!fz.requisitos || !fz.requisitos.ids.length) err(file, fz.requisitos ? fz.requisitos.line : 1, "P-HEADER", "header has no `> **Requisitos:** REQ-…` line (sdd gate --fase reads it)");
    else {
      summary.requirements = fz.requisitos.ids;
      for (const id of fz.requisitos.ids) {
        assigned.add(id);
        if (reqs && !reqById.has(id)) err(file, fz.requisitos.line, "P-AC", `Requisitos: ${id} is not in ${rel(reqFile)}`);
      }
    }
    const escRefs = fz.escenarios || { acs: [], reqAcs: [] };
    if (!fz.escenarios || (!escRefs.acs.length && !escRefs.reqAcs.length)) err(file, fz.escenarios ? fz.escenarios.line : 1, "P-HEADER", "header has no `> **Escenarios:** AC-…` line");
    else checkScenario(file, fz.escenarios.line, "Escenarios", escRefs);
    summary.scenarios = escRefs.acs.length + escRefs.reqAcs.length;
    if (!fz.incremento) warn(file, 1, "P-HEADER", "header has no `> **Incremento:**` line (the user journey this FASE delivers)");
    if (!fz.necesidades) warn(file, 1, "P-HEADER", "header has no `> **Necesidades:** N-…` line");

    // V8: criteria and demo
    const crit = fz.criteria;
    if (!crit) err(file, 1, "V8", "no `## Criterios de Éxito` section");
    else {
      const backed = crit.items.filter((c) => isBacked(c.text));
      summary.criteria = crit.items.length;
      if (!backed.length) err(file, crit.line, "V8", "no success criterion cites a REQ or scenario id");
      for (const c of crit.items) {
        if (!isBacked(c.text) && backed.length) warn(file, c.line, "V8", "criterion cites no REQ or scenario id");
      }
    }
    if (!fz.demo) err(file, 1, "V8", "no `## Demo` section");
    else {
      const rows = fz.demo.rows;
      summary.demoSteps = rows.length;
      if (!rows.length) err(file, fz.demo.line, "V8", "`## Demo` has no numbered rows (| # | Acción | Resultado esperado | Escenario |)");
      if (rows.length > MAX_DEMO_STEPS) err(file, fz.demo.line, "V8", `demo has ${rows.length} steps (max ${MAX_DEMO_STEPS})`);
      for (const r of rows) {
        const refs = scenarioRefs(r.cells.slice(1).join(" | "));
        if (!refs.acs.length && !refs.reqAcs.length) err(file, r.line, "V8", `demo step ${r.n} cites no scenario id`);
        else checkScenario(file, r.line, `demo step ${r.n}`, refs);
      }
    }

    // P-SIZE
    const ucs = new Set([...escRefs.acs.map((a) => `UC-${a.split("-")[1]}`)]);
    for (const c of crit ? crit.items : []) for (const u of (c.group || "").match(UC_RE) || []) ucs.add(u);
    summary.useCases = [...ucs].sort();
    if (ucs.size > MAX_UCS) warn(file, 1, "P-SIZE", `${ucs.size} use cases (${summary.useCases.join(", ")}); a FASE carries at most ${MAX_UCS}`);
    const tf = fz.fase !== null ? taskFile(root, fz.fase) : null;
    if (tf) {
      const tfile = `task/TASK-FASE-${fz.fase}.md`;
      summary.tasks = tf.tasks;
      if (tf.tasks > MAX_TASKS) warn(tfile, 1, "P-SIZE", `${tf.tasks} tasks; a FASE carries about ${MAX_TASKS}`);
      const cited = new Set([...tf.text.matchAll(AC_RE)].map(canonAc));
      for (const id of escRefs.acs) if (!cited.has(id)) warn(tfile, 1, "V-20", `scenario ${id} (Escenarios of ${file}) is cited by no task`);
      for (const { req, ac } of escRefs.reqAcs) if (!new RegExp(`\\b${req}\\b`).test(tf.text)) warn(tfile, 1, "V-20", `${req} AC${ac} (Escenarios of ${file}) is cited by no task`);
    }
  }

  if (legacy.length) notes.push(`mixed plan: ${legacy.length} horizontal FASE(s) before FASE-${from} not checked; REQ ids they cite count as assigned`);
  // V9: every active Must REQ-F / REQ-NF assigned
  if (reqs) {
    for (const r of reqs) {
      if (r.deprecated || !["F", "NF"].includes(r.type) || effectivePriority(r) !== "Must") continue;
      if (!assigned.has(r.id)) err(rel(reqFile), 0, "V9", `Must requirement ${r.id} is not in any FASE Requisitos line`);
    }
  }
  return { style, fases, errors, warnings, notes };
}

export function runPlanLint(argv, { prog = "sdd" } = {}) {
  PROG = prog;
  try {
    const o = parse(argv);
    const root = path.resolve(o.repo || ".");
    const r = lintPlan(root, o);
    if (o.json) out(JSON.stringify(r, null, 2));
    else {
      for (const n of r.notes) out(`note: ${n}`);
      const all = [...r.errors.map((e) => ({ ...e, sev: "" })), ...r.warnings.map((w) => ({ ...w, sev: "warning: " }))]
        .sort((a, b) => a.file.localeCompare(b.file) || a.line - b.line);
      for (const e of all) out(`${e.file}:${e.line} ${e.check} ${e.sev}${e.message}`);
      out(`lint --plan: ${r.style || "no plan"}, ${r.fases.length} FASE(s), ${r.errors.length} error(s), ${r.warnings.length} warning(s)`);
    }
    return r.errors.length ? 1 : 0;
  } catch (e) {
    if (e instanceof Exit) return e.code;
    throw e;
  }
}
