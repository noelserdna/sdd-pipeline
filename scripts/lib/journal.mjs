// journal.mjs — the project journal status/journal.jsonl (sdd-pipeline 5.2): one line per fact the customer reads on
// the status page (a stage started or finished, a gate, a decision, a stage left out and why, a change, evidence,
// feedback). Versioned with the project. Node >= 18, no dependencies. Library only: no console output, no exit.
//
// Line format (keys always in this order; `by` only when known):
//   {"at":"2026-09-10T10:00:00Z","feature":"initial","stage":"requirements-engineer","kind":"done",
//    "text":"Recogimos 4 necesidades.","refs":["N-001"],"by":"Marta Ibáñez (coordinación)"}
// `text` is plain language in the customer's language (no jargon, one line). Written by `sdd journal add`, the skills
// in their Persist step, `sdd route --write` (skip + decision), the orchestrator and the lead at each gate (gate,
// decision, and the customer's feedback with --stage acceptance) and the acceptance skill (evidence).
import { existsSync, mkdirSync, readFileSync, appendFileSync } from "node:fs";
import path from "node:path";

export const JOURNAL_FILE = "status/journal.jsonl";
export const KINDS = ["start", "done", "gate", "decision", "change", "skip", "evidence", "feedback"];
export const DEFAULT_FEATURE = "initial";
/** Stage keys of pipeline-state.json plus the writers that are not stages (setup, the route, the page procedure, the
 *  orchestrator and the lead) and the brownfield skills. */
export const STAGES = ["requirements-engineer", "specifications-engineer", "spec-auditor", "test-planner", "plan-architect",
  "task-generator", "task-implementer", "acceptance", "security-auditor", "ux-designer", "tech-designer", "gap-detector",
  "req-change", "reverse-engineer", "reconcile", "import", "setup", "route", "status-page", "orchestrator", "lead"];
const FEATURE_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/;
const REF_RE = /^[A-Za-z0-9][A-Za-z0-9._#:/-]{0,119}$/;
const MAX_TEXT = 600;

/** ISO-8601 to the second in UTC (`2026-09-10T10:00:00Z`), or null when `v` is not a date. */
export function isoSecond(v) {
  if (v === undefined || v === null || v === "") return null;
  const d = v instanceof Date ? v : new Date(String(v));
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString().replace(/\.\d{3}Z$/, "Z");
}

/** Normalize and validate one entry. Returns { entry, errors }; entry has the stable key order. */
export function makeEntry(input, { now = new Date() } = {}) {
  const errors = [];
  const at = input.at === undefined || input.at === null || input.at === "" ? isoSecond(now) : isoSecond(input.at);
  if (!at) errors.push(`--at must be an ISO-8601 date (got ${input.at})`);
  const feature = String(input.feature ?? DEFAULT_FEATURE).trim() || DEFAULT_FEATURE;
  if (!FEATURE_RE.test(feature)) errors.push(`--feature must be an id like initial or CHG-2026-09-01-001 (got ${feature})`);
  const stage = String(input.stage ?? "").trim();
  if (!stage) errors.push("--stage is required (requirements-engineer, plan-architect, acceptance, orchestrator…)");
  else if (!STAGES.includes(stage)) errors.push(`--stage must be one of ${STAGES.join(", ")} (got ${stage})`);
  const kind = String(input.kind ?? "").trim();
  if (!kind) errors.push(`--kind is required (${KINDS.join(" | ")})`);
  else if (!KINDS.includes(kind)) errors.push(`--kind must be one of ${KINDS.join(" | ")} (got ${kind})`);
  const text = String(input.text ?? "").replace(/\s+/g, " ").trim();
  if (!text) errors.push("--text is required: one plain sentence for the customer");
  else if (text.length > MAX_TEXT) errors.push(`--text is ${text.length} characters; keep it under ${MAX_TEXT} (one or two plain sentences)`);
  const refs = [];
  for (const r of [].concat(input.refs || [])) {
    for (const x of String(r).split(/[\s,]+/).filter(Boolean)) {
      if (!REF_RE.test(x) || !/\d/.test(x)) errors.push(`--refs: ${x} is not an id (REQ-F-001, N-002, FASE-1, requirements-v1…)`);
      else if (!refs.includes(x)) refs.push(x);
    }
  }
  const by = input.by === undefined || input.by === null ? "" : String(input.by).replace(/\s+/g, " ").trim();
  const entry = { at, feature, stage, kind, text, refs };
  if (by) entry.by = by;
  return { entry, errors };
}

/** Entries of status/journal.jsonl in file order: { entries, errors } (a bad line is reported, not fatal). */
export function readJournal(root, file = JOURNAL_FILE) {
  const f = path.resolve(root, file);
  const entries = [], errors = [];
  if (!existsSync(f)) return { entries, errors, file: f };
  readFileSync(f, "utf8").split(/\r?\n/).forEach((l, i) => {
    if (!l.trim()) return;
    let j;
    try { j = JSON.parse(l); } catch { errors.push({ line: i + 1, msg: "not JSON" }); return; }
    if (!j || typeof j !== "object" || Array.isArray(j)) { errors.push({ line: i + 1, msg: "not an object" }); return; }
    const { entry, errors: e } = makeEntry(j);
    if (e.length || !j.at) { errors.push({ line: i + 1, msg: e.join("; ") || "no at" }); return; }
    entries.push({ ...entry, line: i + 1 });
  });
  return { entries, errors, file: f };
}

/** Append one validated entry (creates status/ when missing). Returns { entry, errors, file, line }. */
export function appendEntry(root, input, opts = {}) {
  const { entry, errors } = makeEntry(input, opts);
  const f = path.resolve(root, opts.file || JOURNAL_FILE);
  if (errors.length) return { entry, errors, file: f, line: null };
  mkdirSync(path.dirname(f), { recursive: true });
  const prev = existsSync(f) ? readFileSync(f, "utf8") : "";
  appendFileSync(f, (prev && !prev.endsWith("\n") ? "\n" : "") + JSON.stringify(entry) + "\n");
  const line = (prev ? prev.replace(/\n$/, "").split("\n").length : 0) + 1;
  return { entry, errors, file: f, line };
}

/** Customer language of the project: `en` when the needs and requirements read as English, else `es` (the default). */
export function projectLang(root) {
  const read = (p) => { try { return readFileSync(path.join(root, p), "utf8"); } catch { return ""; } };
  const text = `${read("requirements/CUSTOMER-NEEDS.md")}\n${read("requirements/REQUIREMENTS.md")}`.toLowerCase();
  if (!text.trim()) return "es";
  const count = (re) => (text.match(re) || []).length;
  const es = count(/\b(el|la|los|las|que|de|del|una|para|con|por|está|qué|cuando|sistema|usuario|y|en)\b/g);
  // EARS keywords (WHEN, THE, SHALL) and GIVEN/THEN appear in both languages: they are not counted.
  const en = count(/\b(and|of|to|with|for|that|is|are|user|task|it|an|on|by)\b/g);
  return en > es * 1.5 ? "en" : "es";
}

// ------------------------------------------------------------------ plain texts shared by `sdd route` and `sdd status`
/** What each stage does, in plain words (es / en): the journal and the status page use it. */
export const STAGE_PLAIN = {
  es: {
    "requirements-engineer": "recoger lo que necesitas y escribir los requisitos",
    "specifications-engineer": "la especificación detallada",
    "spec-auditor": "la revisión de la especificación",
    "test-planner": "el plan de pruebas aparte",
    "security-auditor": "la revisión de seguridad",
    "ux-designer": "el diseño de pantallas",
    "tech-designer": "el diseño técnico aparte",
    "gap-detector": "la búsqueda de lo que falta en el código",
    "plan-architect": "planificar las entregas",
    "task-generator": "dividir cada entrega en tareas",
    "task-implementer": "construir la entrega",
    acceptance: "comprobar que cada requisito se cumple",
  },
  en: {
    "requirements-engineer": "gathering what you need and writing the requirements",
    "specifications-engineer": "the detailed specification",
    "spec-auditor": "the specification review",
    "test-planner": "the separate test plan",
    "security-auditor": "the security review",
    "ux-designer": "the screen design",
    "tech-designer": "the separate technical design",
    "gap-detector": "the search for what is missing in the code",
    "plan-architect": "planning the deliveries",
    "task-generator": "splitting each delivery into tasks",
    "task-implementer": "building the delivery",
    acceptance: "checking that every requirement is met",
  },
};
export const plainStage = (stage, lang = "es") => (STAGE_PLAIN[lang] || STAGE_PLAIN.es)[stage] || stage;
const cleanReason = (r) => String(r || "").replace(/^skip:\s*/i, "").replace(/\s+/g, " ").trim();

/** Journal text of a stage the route leaves out: short, plain, with its reason. */
export function skipText(stage, reason, lang = "es") {
  const why = cleanReason(reason);
  const label = plainStage(stage, lang);
  if (lang === "en") return `We leave out ${label}: this project does not need it${why ? ` (${why})` : ""}.`;
  return `No hacemos ${label}: este proyecto no lo necesita${why ? ` (${why})` : ""}.`;
}

/** Journal text of the route decision: how many optional stages run and how many are left out. */
export function routeDecisionText(run, skipped, lang = "es") {
  if (lang === "en") return `We agreed the route: ${run} optional stage${run === 1 ? "" : "s"} will run and ${skipped} ${skipped === 1 ? "is" : "are"} left out.`;
  return `Acordamos el recorrido: se ${run === 1 ? "hará" : "harán"} ${run} etapa${run === 1 ? "" : "s"} opcional${run === 1 ? "" : "es"} y se ${skipped === 1 ? "deja" : "dejan"} fuera ${skipped}.`;
}
