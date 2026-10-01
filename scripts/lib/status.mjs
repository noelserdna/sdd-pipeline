// status.mjs — the living status page (sdd-pipeline 5.2): `sdd journal add|list`, `sdd status page …` and
// `sdd status build`. Node >= 18, no dependencies. Called from scripts/sdd.mjs; returns an exit code.
//
// The page is deterministic: a fixed template of the plugin (templates/status-page/index.html) plus the data.json this
// file builds, contract `sdd-status-v1` (docs/design/plan-5.2-status-page.md). Nothing here recomputes what another
// command owns: requirements and needs come from the parsers of sdd-jev.mjs, verdicts and evidence from the acceptance
// ledger (buildLedger, read only: .sdd/acceptance.json is never written), FASEs from parseFase (plan-lint.mjs), tasks
// from `sdd tasks status` (passed in by sdd.mjs), commits from git-log.mjs, web links from detectProvider + webUrl.
//
// Files: status/journal.jsonl (journal.mjs) and status/page.json (the page registry: url, createdAt, declined,
// features, assets by sha256) are versioned; the output (.sdd/status-page/: index.html, data.json, evidencias/) is not.
// The output never holds code, secrets, `.env` content or Playwright traces: only the texts of the SDD artifacts, test
// names, commit subjects and the images and videos of the evidence dir whose sha256 still matches.
import { existsSync, readFileSync, writeFileSync, mkdirSync, readdirSync, statSync, copyFileSync, rmSync, unlinkSync } from "node:fs";
import { createHash } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { git, isRepo, readCommits, effectiveCommits, commitsFor } from "./git-log.mjs";
import { parseRequirements, parseNeeds, checkNeedCoverage, VERIFICATION_METHODS } from "../sdd-jev.mjs";
import { parseFase } from "./plan-lint.mjs";
import { buildLedger, gateCode } from "./acceptance-cli.mjs";
import {
  DECISIONS_FILE, readDecisions, effectivePriority, evidenceSettings, scanEvidence, nameHasId, describeFile,
  adversarialGate, faseVideoIds,
} from "./acceptance.mjs";
import { detectProvider, webUrl, changeSource } from "./tracker.mjs";
import { stateFile } from "./route.mjs";
import {
  JOURNAL_FILE, KINDS, DEFAULT_FEATURE, makeEntry, readJournal, appendEntry, projectLang, isoSecond, plainStage,
  skipText, routeDecisionText,
} from "./journal.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const SCHEMA = "sdd-status-v1";
export const PAGE_FILE = "status/page.json";
export const OLD_PAGE_FILE = ".sdd/status-page.json";
export const DEFAULT_OUT = ".sdd/status-page";
export const TEMPLATE = path.join(HERE, "..", "..", "templates", "status-page", "index.html");
export const MARKER = "<!--SDD-DATA-->";
export const PHASES = ["understand", "agree", "design", "plan", "build", "verify", "deliver"];
export const MAX_FILE_BYTES = 15 * 1024 * 1024;
const DESIGN_STAGES = ["specifications-engineer", "spec-auditor", "test-planner"];
const DESIGN_ALL = [...DESIGN_STAGES, "tech-designer", "ux-designer"];
const FEATURE_RE = /^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$/;

class Exit extends Error { constructor(code) { super(`exit ${code}`); this.code = code; } }
let PROG = "sdd";
const out = (s) => console.log(s);
const usage = (msg) => { console.error(`${PROG}: ${msg} (see --help)`); throw new Exit(2); };
const die = (msg, code = 2) => { console.error(`${PROG}: ${msg}`); throw new Exit(code); };

// ------------------------------------------------------------------ args
const VALUED = new Set(["repo", "stage", "kind", "text", "feature", "refs", "by", "at", "out", "template", "url", "id",
  "title", "chg", "summary", "sha256"]);
const MULTI = new Set(["refs"]);
const FLAGS = new Set(["json", "help"]);
function parse(argv) {
  const o = { _: [], refs: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith("--") || a === "--") { o._.push(a); continue; }
    const eq = a.match(/^--([a-z0-9-]+)=(.*)$/s);
    const k = eq ? eq[1] : a.slice(2);
    if (FLAGS.has(k)) { o[k] = true; continue; }
    if (!VALUED.has(k)) usage(`unknown option --${k}`);
    let v;
    if (eq) v = eq[2];
    else { if (i + 1 >= argv.length) usage(`--${k} needs a value`); v = argv[++i]; }
    if (MULTI.has(k)) {
      o[k].push(v);
      while (!eq && i + 1 < argv.length && !argv[i + 1].startsWith("-")) o[k].push(argv[++i]);
    } else o[k] = v;
  }
  return o;
}
const rootOf = (o) => path.resolve(o.repo || ".");
const readText = (f) => { try { return readFileSync(f, "utf8"); } catch { return ""; } };
const readJson = (f) => { try { return JSON.parse(readFileSync(f, "utf8")); } catch { return null; } };

// ------------------------------------------------------------------ journal commands
function cmdJournal(o) {
  const sub = o._.shift();
  const root = rootOf(o);
  if (sub === "add") {
    if (o._.length) usage(`unexpected argument ${o._[0]}`);
    const r = appendEntry(root, { stage: o.stage, kind: o.kind, text: o.text, feature: o.feature, refs: o.refs, by: o.by, at: o.at });
    if (r.errors.length) { for (const e of r.errors) console.error(`${PROG}: journal add: ${e}`); return 2; }
    if (o.json) out(JSON.stringify({ file: JOURNAL_FILE, line: r.line, entry: r.entry }, null, 2));
    else out(`journal: ${r.entry.kind} ${r.entry.stage} added at ${JOURNAL_FILE}:${r.line}`);
    return 0;
  }
  if (sub === "list") {
    if (o._.length) usage(`unexpected argument ${o._[0]}`);
    const { entries, errors } = readJournal(root);
    const list = entries.filter((e) => !o.feature || e.feature === o.feature).map(({ line, ...e }) => e);
    if (o.json) { out(JSON.stringify({ file: JOURNAL_FILE, count: list.length, entries: list, errors }, null, 2)); return 0; }
    for (const e of list) out(`${e.at}  ${e.feature}  ${e.stage}  ${e.kind}  ${e.text}${e.refs.length ? `  [${e.refs.join(", ")}]` : ""}${e.by ? `  — ${e.by}` : ""}`);
    for (const e of errors) console.error(`${PROG}: ${JOURNAL_FILE}:${e.line}: ${e.msg}`);
    out(`journal: ${list.length} entr${list.length === 1 ? "y" : "ies"}${o.feature ? ` (feature ${o.feature})` : ""}`);
    return 0;
  }
  usage(`unknown journal command ${sub ?? "(none)"}: use add or list`);
}

// ------------------------------------------------------------------ page registry (status/page.json)
/** The registry with its keys in a stable order: {url, createdAt, declined?, features, assets}. */
function normPage(p) {
  const page = { url: p?.url || null, createdAt: isoSecond(p?.createdAt) || isoSecond(new Date()) };
  if (p?.declined) page.declined = true;
  page.features = (Array.isArray(p?.features) ? p.features : []).filter((f) => f && FEATURE_RE.test(String(f.id || ""))).map((f) => {
    const x = { id: String(f.id), title: String(f.title || f.id), createdAt: isoSecond(f.createdAt) || page.createdAt };
    if (f.chg) x.chg = String(f.chg);
    if (f.summary) x.summary = String(f.summary);
    return x;
  });
  page.assets = {};
  for (const [k, v] of Object.entries(p?.assets && typeof p.assets === "object" ? p.assets : {})) {
    const h = normSha(k);
    if (h && isAssetRef(v)) page.assets[h] = v;
  }
  return page;
}
function normSha(v) {
  const m = String(v || "").trim().toLowerCase().match(/^(?:sha256:)?([0-9a-f]{64})$/);
  return m ? `sha256:${m[1]}` : null;
}
export function readPage(root) {
  const f = path.join(root, PAGE_FILE);
  if (!existsSync(f)) return null;
  const j = readJson(f);
  if (!j || typeof j !== "object") die(`${PAGE_FILE} is not valid JSON`);
  return normPage(j);
}
function writePage(root, page) {
  const f = path.join(root, PAGE_FILE);
  mkdirSync(path.dirname(f), { recursive: true });
  writeFileSync(f, JSON.stringify(normPage(page), null, 2) + "\n");
}
/** Move .sdd/status-page.json (5.1: {url, publishedAt, sha, assets}) into status/page.json; returns true when moved. */
function migratePage(root) {
  const old = path.join(root, OLD_PAGE_FILE);
  if (!existsSync(old)) return false;
  const j = readJson(old);
  if (!j || typeof j !== "object") { console.error(`${PROG}: ${OLD_PAGE_FILE} is not valid JSON: left in place`); return false; }
  const cur = readPage(root) || normPage({ createdAt: j.publishedAt || j.createdAt });
  if (!cur.url && j.url) cur.url = String(j.url);
  cur.assets = { ...normPage({ assets: j.assets }).assets, ...cur.assets };
  writePage(root, cur);
  unlinkSync(old);
  return true;
}
const isHttps = (u) => /^https:\/\/[^\s/]+\/\S*$/.test(String(u || ""));
/** Where a published evidence file lives: its URL, its path inside the page (evidencias/…) or `withheld` (a person kept
 *  it off the page: personal data). */
export const WITHHELD = "withheld";
const isAssetRef = (v) => typeof v === "string" && /^\S{1,2048}$/.test(v) && !v.startsWith("..");

/** `status page --json`: the registry with `declined` always present (false when absent). */
function pageView(page) {
  const p = page || { url: null, createdAt: null, features: [], assets: {} };
  return { url: p.url, declined: Boolean(p.declined), createdAt: p.createdAt, features: p.features, assets: p.assets };
}

function cmdPage(o, root) {
  const moved = migratePage(root);
  if (moved && !o.json) out(`status page: moved ${OLD_PAGE_FILE} into ${PAGE_FILE}`);
  const sub = o._.shift();
  const done = (page, msg) => { writePage(root, page); if (o.json) out(JSON.stringify(pageView(readPage(root)), null, 2)); else out(msg); return 0; };
  if (sub === undefined) {
    const page = readPage(root);
    if (o.json) out(JSON.stringify(pageView(page), null, 2));
    else if (!page) out(`status page: none yet (${PAGE_FILE} does not exist)`);
    else out(`status page: ${page.url || (page.declined ? "declined" : "not published")} · ${page.features.length} feature(s) · ${Object.keys(page.assets).length} asset(s)`);
    return 0;
  }
  const page = readPage(root) || normPage({});
  if (sub === "set") {
    if (o._.length) usage(`unexpected argument ${o._[0]}`);
    if (!isHttps(o.url)) usage("status page set needs --url https://…");
    page.url = o.url; delete page.declined;
    return done(page, `status page: url ${o.url}`);
  }
  if (sub === "decline") {
    if (o._.length) usage(`unexpected argument ${o._[0]}`);
    page.declined = true;
    return done(page, "status page: declined (recorded in status/page.json)");
  }
  if (sub === "asset") {
    if (o._.length) usage(`unexpected argument ${o._[0]}`);
    const h = normSha(o.sha256);
    if (!h) usage("status page asset needs --sha256 <64 hex> (with or without the sha256: prefix)");
    if (!isAssetRef(o.url)) usage("status page asset needs --url <published path or URL> (or withheld: kept off the page)");
    page.assets[h] = o.url;
    return done(page, `status page: asset ${h.slice(0, 19)}… → ${o.url}`);
  }
  if (sub === "feature") {
    const act = o._.shift();
    if (act !== "add") usage("use status page feature add --id ID --title T [--chg CHG] [--summary S]");
    if (o._.length) usage(`unexpected argument ${o._[0]}`);
    if (!o.id || !FEATURE_RE.test(o.id)) usage("--id must be a feature id like CHG-2026-09-01-001 or pagos");
    if (!String(o.title || "").trim()) usage("--title is required");
    const f = { id: o.id, title: String(o.title).trim(), createdAt: isoSecond(new Date()) };
    if (o.chg) f.chg = o.chg;
    if (o.summary) f.summary = String(o.summary).trim();
    const i = page.features.findIndex((x) => x.id === o.id);
    if (i >= 0) page.features[i] = { ...page.features[i], ...f, createdAt: page.features[i].createdAt };
    else page.features.push(f);
    return done(page, `status page: feature ${o.id} ${i >= 0 ? "updated" : "added"}`);
  }
  usage(`unknown status page command ${sub}: use set, decline, feature add or asset`);
}

// ------------------------------------------------------------------ plain texts (es / en)
const TEXT = {
  es: {
    now: {
      understand: () => "Estamos entendiendo lo que necesitas.",
      agree: () => "Hemos escrito los requisitos y esperan tu aprobación.",
      design: () => "Estamos diseñando cómo lo construiremos y cómo lo comprobaremos.",
      plan: () => "Estamos planificando las entregas.",
      build: (f) => (f ? `Estamos construyendo la entrega ${f.n} de ${f.of}: ${f.title}.` : "Estamos construyendo."),
      verify: (f) => (f ? `Estamos comprobando la entrega ${f.n} de ${f.of}: ${f.title}.` : "Estamos comprobando lo construido."),
      deliver: (f) => (f ? `La entrega ${f.n} de ${f.of} está lista para que la pruebes.` : "Lo construido está listo para que lo pruebes."),
      done: () => "Todo lo acordado está entregado y aceptado.",
    },
    next: {
      understand: "Escribir los requisitos y repasarlos contigo.",
      agree: "Cuando los apruebes, diseñamos y planificamos las entregas.",
      design: "Planificar las entregas.",
      plan: "Empezar a construir la primera entrega.",
      build: "Comprobar la entrega con pruebas, capturas y vídeo.",
      verify: "Enseñarte la entrega para que la aceptes.",
      deliver: "Que pruebes la entrega y nos digas si la aceptas.",
      done: null,
    },
    nowStage: (s) => `Estamos trabajando en ${s}.`,
    approve: "Revisar y aprobar los requisitos y sus ejemplos.",
    confirmNeed: (id) => `Confirmar que ${id} recoge bien lo que nos dijiste.`,
    tryFase: (n) => `Probar la entrega ${n} y decirnos si la aceptas.`,
    designSkipped: (labels) => `El recorrido acordado deja fuera ${labels.join(", ")}.`,
    initialSummary: (n, r) => `Lo que nos pediste al empezar: ${n} necesidad${n === 1 ? "" : "es"} y ${r} requisito${r === 1 ? "" : "s"}.`,
    reqApproved: (v) => `Aprobaste los requisitos (versión ${v}).`,
    faseVerified: (n) => `La entrega ${n} quedó construida y comprobada.`,
    faseAccepted: (n) => `Aceptaste la entrega ${n}.`,
    faseResult: { accepted: (n) => `Aceptaste la entrega ${n}.`, observations: (n) => `Aceptaste la entrega ${n} con observaciones.`, rejected: (n) => `Rechazaste la entrega ${n}; la corregimos.` },
    waiver: (id, why) => `Acordamos aplazar ${id}${why ? `: ${why}` : ""}.`,
    record: { demo: (id) => `Se comprobó ${id} en una demostración.`, inspection: (id) => `Se revisó ${id} a mano.`, measurement: (id) => `Se midió ${id}.` },
    dismissal: (id) => `Se descartó un aviso del revisor independiente sobre ${id}.`,
    literalException: (id) => `Se aceptó que la prueba de ${id} construye el texto exacto con una ayuda.`,
    change: (t) => `Pediste un cambio: ${t}.`,
  },
  en: {
    now: {
      understand: () => "We are understanding what you need.",
      agree: () => "The requirements are written and wait for your approval.",
      design: () => "We are designing how we will build it and how we will check it.",
      plan: () => "We are planning the deliveries.",
      build: (f) => (f ? `We are building delivery ${f.n} of ${f.of}: ${f.title}.` : "We are building."),
      verify: (f) => (f ? `We are checking delivery ${f.n} of ${f.of}: ${f.title}.` : "We are checking what we built."),
      deliver: (f) => (f ? `Delivery ${f.n} of ${f.of} is ready for you to try.` : "What we built is ready for you to try."),
      done: () => "Everything we agreed is delivered and accepted.",
    },
    next: {
      understand: "Write the requirements and go through them with you.",
      agree: "Once you approve them, we design and plan the deliveries.",
      design: "Plan the deliveries.",
      plan: "Start building the first delivery.",
      build: "Check the delivery with tests, screenshots and video.",
      verify: "Show you the delivery so you can accept it.",
      deliver: "You try the delivery and tell us whether you accept it.",
      done: null,
    },
    nowStage: (s) => `We are working on ${s}.`,
    approve: "Review and approve the requirements and their examples.",
    confirmNeed: (id) => `Confirm that ${id} captures what you told us.`,
    tryFase: (n) => `Try delivery ${n} and tell us whether you accept it.`,
    designSkipped: (labels) => `The agreed route leaves out ${labels.join(", ")}.`,
    initialSummary: (n, r) => `What you asked for at the start: ${n} need${n === 1 ? "" : "s"} and ${r} requirement${r === 1 ? "" : "s"}.`,
    reqApproved: (v) => `You approved the requirements (version ${v}).`,
    faseVerified: (n) => `Delivery ${n} is built and checked.`,
    faseAccepted: (n) => `You accepted delivery ${n}.`,
    faseResult: { accepted: (n) => `You accepted delivery ${n}.`, observations: (n) => `You accepted delivery ${n} with observations.`, rejected: (n) => `You rejected delivery ${n}; we are fixing it.` },
    waiver: (id, why) => `We agreed to defer ${id}${why ? `: ${why}` : ""}.`,
    record: { demo: (id) => `${id} was checked in a demo.`, inspection: (id) => `${id} was reviewed by hand.`, measurement: (id) => `${id} was measured.` },
    dismissal: (id) => `A finding of the independent reviewer on ${id} was dismissed.`,
    literalException: (id) => `We accepted that the test of ${id} builds the exact text with a helper.`,
    change: (t) => `You asked for a change: ${t}.`,
  },
};
const GATE_LABELS = { 0: "goal met", 1: "goal not met", 2: "stale evidence", 3: "goal met with waived Musts", 4: "open adversarial challenge on a Must" };

// ------------------------------------------------------------------ sources
const posix = (p) => p.split(path.sep).join("/");
const headerValue = (h) => (h ? h.text.replace(/^>?\s*/, "").replace(/^\*{0,2}[^:*]+\*{0,2}\s*:\s*\*{0,2}\s*/, "").trim() : "");

function projectName(root, reqText, needsText) {
  const m = (needsText.match(/^>?\s*\*\*Project:?\*\*:?\s*(.+)$/m) || reqText.match(/^>?\s*\*\*Project:?\*\*:?\s*(.+)$/m) || [])[1];
  if (m && m.trim()) return m.trim();
  const pkg = readJson(path.join(root, "package.json"));
  if (pkg && typeof pkg.name === "string" && pkg.name) return pkg.name;
  return path.basename(root);
}

function readTags(root) {
  const r = git(root, ["for-each-ref", "refs/tags", "--sort=creatordate", "--format=%(refname:short)%1f%(creatordate:iso-strict)%1f%(taggername)%1f%(taggeremail)"]);
  if (r.status !== 0) return [];
  return r.stdout.split("\n").filter(Boolean).map((l) => {
    const [name, date, by] = l.split("\x1f");
    return { name, date: isoSecond(date), by: by || null };
  });
}

function readFases(root) {
  const dir = path.join(root, "plan", "fases");
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter((f) => /^FASE-\d+.*\.md$/i.test(f)).map((f) => {
    const file = path.join(dir, f);
    const text = readFileSync(file, "utf8");
    const p = parseFase(text, file);
    const lines = text.split(/\r?\n/);
    const end = lines.findIndex((l, i) => i > 0 && /^##\s/.test(l));
    const head = lines.slice(0, end < 0 ? 40 : end);
    const wfLine = head.find((l) => /\bWorkflows\b[*\s]*:/i.test(l));
    const heading = ((text.match(/^#\s+(.+)$/m) || [])[1] || `FASE ${p.fase}`).trim();
    return {
      n: p.fase, file: `plan/fases/${f}`, title: heading.replace(/^FASE[\s-]*\d+\s*[:—–-]\s*/i, "").trim() || heading,
      increment: headerValue(p.incremento), requirements: p.requisitos?.ids || [],
      needs: [...new Set((headerValue(p.necesidades).match(/\bN-\d{3,}\b/g) || []))],
      workflows: wfLine ? [...new Set((wfLine.match(/\bWF-\d{3,}\b/gi) || []).map((x) => x.toUpperCase()))] : null,
      demo: (p.demo?.rows || []).map((r) => ({ step: r.n, action: r.cells[1] || "", expected: r.cells[2] || "" })),
    };
  }).filter((f) => Number.isInteger(f.n)).sort((a, b) => a.n - b.n);
}

/** The ledger (read only) or null; never writes .sdd/acceptance.json. */
function ledgerOf(root, fase) {
  try { return buildLedger({ repo: root, junit: [], paths: [], attach: [], evidence: [], _: [], ...(fase !== undefined ? { fase } : {}) }).ledger; }
  catch (e) { if (e && typeof e.code === "number") return null; throw e; }
}

/** Issue number of FASE n from a branch or merge named `{N}-fase-{n}-…` (the `sdd branch start --issue` prefix). */
function faseIssues(root, commits) {
  const r = git(root, ["for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes"]);
  const names = [...(r.status === 0 ? r.stdout.split("\n").filter(Boolean) : []), ...commits.map((c) => c.subject)];
  const map = new Map();
  for (const s of names) for (const m of s.matchAll(/(?:^|[\s'/])(\d+)-fase-(\d+)-/g)) if (!map.has(Number(m[2]))) map.set(Number(m[2]), Number(m[1]));
  return map;
}

// ------------------------------------------------------------------ build
/**
 * Build the sdd-status-v1 data of the project at `root`. Returns { data, files } where files are the evidence copies
 * to make: [{ abs, out, sha256 }]. opts: { taskProgress(root) → tasks | null, now: Date }.
 */
export function buildStatus(root, { taskProgress = () => null, now = new Date() } = {}) {
  const lang = projectLang(root);
  const T = TEXT[lang];
  const generatedAt = isoSecond(now);
  const repo = isRepo(root);
  const headR = repo ? git(root, ["rev-parse", "-q", "--verify", "HEAD"]) : null;
  const head = headR && headR.status === 0 ? headR.stdout.trim() : null;
  let prov = null;
  if (repo) { try { prov = detectProvider(root); } catch { prov = null; } }
  const provider = prov?.provider || null;
  const W = (args) => (provider ? webUrl(prov, args) : null);

  // pipeline-state.json (the file sdd-state.sh resolves: the main checkout when worktrees are used)
  const st = stateFile(root);
  const state = st.exists ? readJson(st.file) : null;
  const stages = state && state.stages && typeof state.stages === "object" ? state.stages : {};

  // requirements and needs
  const reqText = readText(path.join(root, "requirements", "REQUIREMENTS.md"));
  const needsText = readText(path.join(root, "requirements", "CUSTOMER-NEEDS.md"));
  const reqs = reqText ? parseRequirements(reqText) : [];
  const needs = needsText ? parseNeeds(needsText) : [];
  const coverage = checkNeedCoverage(needs, reqs, reqText);
  const active = reqs.filter((r) => !r.deprecated);
  const name = projectName(root, reqText, needsText);

  // registry, journal, tags, commits, tasks, plan
  let page = null;
  try { page = readPage(root); } catch { page = null; }
  const oldPage = !page ? readJson(path.join(root, OLD_PAGE_FILE)) : null;
  const { entries: written } = readJournal(root);
  const tags = repo ? readTags(root) : [];
  const tagUrl = (t) => W({ kind: "tag", tag: t });
  let commits = [];
  if (repo && head) { try { commits = effectiveCommits(readCommits(root, { rev: "HEAD" })).filter((c) => c.effective); } catch { commits = []; } }
  const tasks = taskProgress(root) || [];
  const faseDocs = readFases(root);
  const issues = repo ? faseIssues(root, commits) : new Map();

  // features: the initial one first, then those of status/page.json; requirements of a change belong to its feature
  const featureOfReq = new Map();
  const features = [];
  const pf = page?.features || [];
  const initial = pf.find((f) => f.id === DEFAULT_FEATURE);
  const firstCommit = commits.length ? isoSecond(git(root, ["show", "-s", "--format=%cI", commits[commits.length - 1].sha]).stdout.trim()) : null;
  features.push({ id: DEFAULT_FEATURE, title: initial?.title || name, createdAt: initial?.createdAt || page?.createdAt || firstCommit || generatedAt,
    summary: initial?.summary || T.initialSummary(needs.length, active.length) });
  for (const f of pf.filter((x) => x.id !== DEFAULT_FEATURE)) {
    let src = null;
    if (f.chg) { try { src = changeSource(root, f.chg); } catch { src = null; } }
    for (const id of src?.requisitos || []) if (!featureOfReq.has(id)) featureOfReq.set(id, f.id);
    features.push({ id: f.id, title: f.title, createdAt: f.createdAt, summary: f.summary || (src ? src.title.replace(/^[^:]+:\s*/, "") : "") });
  }
  const featureOf = (id) => featureOfReq.get(id) || DEFAULT_FEATURE;

  // ledgers: global and one per FASE (videos and scoped goal)
  const ledger = active.length || reqs.length ? ledgerOf(root, undefined) : null;
  const ledReq = new Map((ledger?.requirements || []).map((r) => [r.id, r]));
  const settings = evidenceSettings(root);
  const evDir = (ledger?.evidence_dir || settings.dir).replace(/\/+$/, "");
  const decisions = readDecisions(path.join(root, DECISIONS_FILE)).records;
  const recByLine = new Map(decisions.map((r) => [r.line, r]));

  // evidence files: one entry per source file, copied when present with a matching sha256 (never traces)
  const fileCache = new Map();
  const evFiles = new Map(); // abs → { path, sha256, bytes, kind, criteria:Set, present, expect }
  const outNames = new Set();
  const outPathOf = (rel, sha) => {
    const under = rel === evDir || rel.startsWith(evDir + "/");
    let p = under ? `evidencias/${rel.slice(evDir.length + 1)}` : `evidencias/adjuntos/${path.posix.basename(rel)}`;
    if (!under && outNames.has(p)) p = `evidencias/adjuntos/${String(sha || "x").replace(/^sha256:/, "").slice(0, 8)}-${path.posix.basename(rel)}`;
    outNames.add(p);
    return p;
  };
  const addFile = (att, crit) => {
    if (!att || (att.kind !== "image" && att.kind !== "video")) return null;
    const abs = path.resolve(root, att.path);
    const rel = posix(path.relative(root, abs));
    if (!rel || rel.startsWith("..") || path.isAbsolute(rel)) return null; // only files of the project
    let f = evFiles.get(abs);
    if (!f) {
      const now = describeFile(root, abs, fileCache);
      const expect = att.sha256 || now.sha256;
      f = { abs, path: outPathOf(rel, expect), sha256: expect, bytes: now.bytes ?? att.bytes ?? 0, kind: att.kind, criteria: new Set(),
        present: Boolean(now.present && att.present !== false && now.sha256 === expect) };
      evFiles.set(abs, f);
    }
    if (crit) f.criteria.add(crit);
    return f;
  };
  const allVideos = settings.visual === "off" ? [] : scanEvidence(root, evDir).filter((x) => x.kind === "video");

  // FASEs: tasks, per-FASE ledger, status
  const faseLedgers = new Map();
  for (const f of faseDocs) faseLedgers.set(f.n, ledger ? ledgerOf(root, f.n) : null);
  const accByFase = new Map((ledger?.fase_acceptances || []).map((a) => [a.fase, a]));
  const recAccByFase = new Map();
  for (const r of decisions) if (r.type === "fase-acceptance") recAccByFase.set(r.fase, r);
  const hasTag = (n) => tags.find((t) => t.name === n) || null;
  const verdictOf = (id) => ledReq.get(id)?.verdict || null;

  const fases = faseDocs.map((f) => {
    const ts = tasks.filter((t) => t.fase === f.n);
    const fl = faseLedgers.get(f.n);
    const acc = accByFase.get(f.n) || (ledger ? null : recAccByFase.get(f.n)) || null;
    const accepted = hasTag(`fase-${f.n}-accepted`);
    const verifiedTag = hasTag(`fase-${f.n}-verified`);
    const inScope = (fl?.requirements || []).filter((r) => r.in_scope && r.verdict !== "DEPRECATED");
    let status;
    if (acc && !acc.stale) status = acc.result === "accepted" ? "accepted" : acc.result === "observations" ? "observations" : "rejected";
    else if (accepted && !acc) status = "accepted";
    else if (verifiedTag || (fl && inScope.length && fl.summary.goal)) status = "verified";
    else if (ts.some((t) => t.done) || f.requirements.some((id) => ["VERIFIED", "FAILING"].includes(verdictOf(id)))) status = "building";
    else status = "pending";
    const issueN = issues.get(f.n);
    const videos = (fl?.videos?.found || []).map((p) => addFile({ path: p, kind: "video" }, null)).filter(Boolean);
    return {
      n: f.n, title: f.title, increment: f.increment, requirements: f.requirements, needs: f.needs,
      feature: (() => { const fs = [...new Set(f.requirements.map(featureOf))]; return fs.length === 1 ? fs[0] : DEFAULT_FEATURE; })(),
      workflows: f.workflows || faseVideoIds(root, f.n).filter((x) => /^WF-/.test(x)),
      demo: f.demo,
      videos: videos.map((v) => ({ path: v.path, _f: v })),
      tasks: { done: ts.filter((t) => t.done).length, total: ts.length },
      status,
      acceptance: acc ? { by: acc.by || null, role: acc.role || null, at: isoSecond(acc.at), channel: acc.channel || null } : null,
      issue: issueN ? { number: issueN, url: W({ kind: "issue", number: issueN }) } : null,
      tags: tags.filter((t) => new RegExp(`^fase-${f.n}-`).test(t.name)).map((t) => ({ name: t.name, date: t.date, url: tagUrl(t.name) })),
      _missingVideos: fl?.videos?.missing || [],
    };
  });
  const faseOfReq = (id) => fases.find((f) => f.requirements.includes(id)) || null;

  // requirements
  const SHOWN = new Set();
  const requirements = reqs.map((req) => {
    const lr = ledReq.get(req.id);
    const fase = faseOfReq(req.id);
    const verdict = req.deprecated ? "DEPRECATED" : lr?.verdict || "MISSING";
    let status;
    if (verdict === "DEPRECATED") status = "deprecated";
    else if (verdict === "WAIVED") status = "deferred";
    else if (verdict === "FAILING") status = "failing";
    else if (verdict === "VERIFIED") status = "shown";
    else {
      const mine = fases.filter((f) => f.requirements.includes(req.id));
      const building = mine.some((f) => ["building", "verified", "observations", "rejected"].includes(f.status) || f.tasks.done > 0);
      status = building ? "building" : "pending";
    }
    if (status === "shown") SHOWN.add(req.id);
    const crit = lr && lr.criteria.length ? lr.criteria : req.criteria.map((text, i) => ({ n: i + 1, text, state: "missing", tests: [], records: [], evidence: [], scenarios: [] }));
    const warnings = [];
    const criteria = crit.map((c) => {
      const tests = (c.tests || []).filter((t) => t.status !== "skip");
      let cs = c.state;
      if (cs === "missing" && !tests.length && !(c.records || []).length) cs = "pending";
      if (req.deprecated) cs = "pending";
      const key = `${req.id}#${c.n}`;
      const caps = [];
      for (const e of c.evidence || []) for (const a of e.attachments || []) {
        if (a.kind !== "image") continue;
        const f = addFile(a, key);
        if (f && !caps.includes(f)) caps.push(f);
      }
      const m = (c.evidence || []).find((e) => e.kind === "measurement");
      const recEv = (c.evidence || []).find((e) => e.kind === "demo" || e.kind === "inspection");
      let record = null;
      if (recEv) {
        const line = Number(String(recEv.ref || "").split(":").pop());
        const r = recByLine.get(line) || {};
        record = { type: recEv.kind, by: r.by ? `${r.by}${r.role ? ` (${r.role})` : ""}` : recEv.by || null, at: isoSecond(r.at), note: r.note || r.observed || recEv.note || recEv.observed || null };
      }
      if (!req.deprecated && verdict !== "WAIVED") {
        if (cs === "unshown") warnings.push({ code: "unshown", text: `AC${c.n}: passing test without a screenshot`, ac: c.n });
        if (cs === "weakened") {
          const g = (c.literal_gaps || [])[0];
          warnings.push({ code: "weakened", text: `AC${c.n}: test lacks the criterion's literal${g?.literal ? ` "${g.literal}"` : g?.code === "Q-02" ? " (quote not current)" : ""}`, ac: c.n });
        }
        if (cs === "stale") warnings.push({ code: "stale", text: `AC${c.n}: evidence older than the code`, ac: c.n });
        if (cs === "fail") warnings.push({ code: "failing", text: `AC${c.n}: ${tests.some((t) => t.status === "fail" || t.status === "error") ? "test fails" : "check failed"}`, ac: c.n });
      }
      return {
        n: c.n, text: c.text || "", status: cs,
        captures: caps.map((f) => ({ path: f.path, _f: f })),
        tests: { pass: tests.filter((t) => t.fresh && t.status === "pass").length, total: tests.length, names: [...new Set(tests.map((t) => t.name))] },
        measurement: m ? { metric: m.metric, observed: m.observed, op: m.op, threshold: m.threshold } : null,
        record,
      };
    });
    for (const ch of lr?.challenges || []) if (ch.state === "open") warnings.push({ code: "challenge", text: `${ch.id} ${ch.category}: "${String(ch.quote || "").slice(0, 120)}"`, ac: ch.ac ?? null });
    if (fase && req.type === "F" && !req.deprecated && verdict !== "WAIVED") for (const id of fase._missingVideos) warnings.push({ code: "missing_video", text: `FASE-${fase.n}: video ${id} missing`, ac: null });
    // videos: those of its FASE plus any named after the requirement or one of its scenarios
    const scen = crit.flatMap((c) => c.scenarios || []);
    const vids = [...fase?.videos.map((v) => v._f) || []];
    for (const v of allVideos) if (nameHasId(v.rel, req.id) || scen.some((s) => nameHasId(v.rel, s))) {
      const f = addFile(describeFile(root, v.abs, fileCache), null);
      if (f && !vids.includes(f)) vids.push(f);
    }
    // commits: trailers naming the requirement, plus the commits of the tasks that reference it
    const taskIds = new Set(tasks.filter((t) => (t.refs || []).includes(req.id)).map((t) => t.id));
    const cs = [...new Map([...commitsFor(commits, req.id), ...commits.filter((c) => c.tasks.some((t) => taskIds.has(t)))].map((c) => [c.sha, c])).values()];
    const pr = effectivePriority(req);
    const waiver = lr?.waiver?.valid ? { reason: lr.waiver.reason, by: `${lr.waiver.by}${lr.waiver.role ? ` (${lr.waiver.role})` : ""}`, followUp: lr.waiver.followUp || null, at: isoSecond(lr.waiver.at) } : null;
    return {
      id: req.id, kind: req.type === "NF" || req.type === "C" ? req.type : "F", title: req.title, plain: req.plain || null,
      statement: req.statement, priority: pr === "Nice" ? "Could" : ["Must", "Should", "Could", "Won't"].includes(pr) ? pr : null,
      feature: featureOf(req.id), needs: req.needs || [], fase: fase ? fase.n : null, status,
      verification: VERIFICATION_METHODS.includes(req.verification) ? req.verification : null,
      criteria, videos: vids.map((f) => ({ path: f.path, _f: f })), warnings, waiver,
      links: {
        commits: cs.slice(0, 30).map((c) => ({ sha: c.sha.slice(0, 7), url: W({ kind: "commit", sha: c.sha }), subject: c.subject })),
        issue: fase?.issue || null,
      },
    };
  });

  // needs
  const reqFeature = new Map(requirements.map((r) => [r.id, r.feature]));
  const needsOut = needs.map((n) => {
    const by = coverage.coveredBy[n.id] || [];
    const feats = [...new Set(by.map((id) => reqFeature.get(id) || DEFAULT_FEATURE))];
    const x = { id: n.id, quote: n.quote, who: n.who || null, when: n.when || null,
      status: ["captured", "confirmed", "out-of-scope"].includes(n.status) ? n.status : "captured" };
    if (n.decision) x.decision = n.decision;
    x.feature = feats.length === 1 ? feats[0] : DEFAULT_FEATURE;
    x.requirements = by;
    return x;
  });

  // journal: the written lines plus the facts derived from tags, the route, decisions.jsonl and change reports
  const journal = deriveJournal({ root, T, lang, written, tags, state, decisions, features: page?.features || [], reqs });

  // where
  const reqTag = tags.some((t) => /^requirements-v\d+$/.test(t.name));
  const open = fases.find((f) => !["accepted", "observations"].includes(f.status)) || null;
  // design = the formal specs, their audit and the test plan, plus the technical and UX design when the route runs them
  const routeStages = state?.route?.stages || null;
  const designWanted = routeStages
    ? DESIGN_ALL.filter((k) => routeStages[k]?.run && stages[k]?.status !== "skipped")
    : DESIGN_STAGES.filter((k) => stages[k]?.status !== "skipped");
  const designSkipped = DESIGN_STAGES.every((k) => stages[k]?.status === "skipped") && !designWanted.length;
  const designPending = () => !state || designWanted.some((k) => stages[k]?.status !== "done");
  let phase;
  if (!active.length) phase = "understand";
  else if (!reqTag) phase = "agree";
  else if (fases.length && !open) phase = "done";
  else if (!fases.length) phase = designPending() ? "design" : "plan";
  else if (open.status === "verified") phase = "deliver";
  else if (open.status === "pending" && !open.tasks.total) phase = "plan";
  else if (open.tasks.total && open.tasks.done === open.tasks.total && open.status !== "rejected") phase = "verify";
  else if (stages.acceptance?.status === "running" && open.status !== "pending") phase = "verify";
  else phase = "build";
  const at = phase === "done" ? PHASES.length : PHASES.indexOf(phase);
  const phases = PHASES.map((id, i) => {
    if (id === "design" && designSkipped) {
      return { id, state: "skipped", reason: T.designSkipped(DESIGN_STAGES.map((k) => plainStage(k, lang))) };
    }
    return { id, state: i < at ? "done" : i === at ? "current" : "pending" };
  });
  const faseNow = open && phase !== "done" && ["build", "verify", "deliver"].includes(phase) ? { n: open.n, of: fases.length, title: open.increment || open.title } : null;
  const openStart = [...written].reverse().find((e) => e.kind === "start" && !written.some((d) => d.kind === "done" && d.stage === e.stage && d.at >= e.at));
  const running = Object.entries(stages).find(([, v]) => v && v.status === "running");
  const nowText = openStart ? openStart.text : running ? T.nowStage(plainStage(running[0], lang)) : T.now[phase](faseNow);
  const needFromYou = [];
  if (phase === "agree") needFromYou.push({ text: T.approve, anchor: active[0].id });
  for (const n of needsOut) if (n.status === "captured") needFromYou.push({ text: T.confirmNeed(n.id), anchor: n.id });
  for (const f of fases) if (f.status === "verified") needFromYou.push({ text: T.tryFase(f.n), anchor: `FASE-${f.n}` });

  // evidence: copy decisions
  const files = [];
  const assets = page?.assets || {};
  for (const f of evFiles.values()) {
    let reason = null;
    if (!f.present) reason = "missing";
    else if (f.sha256 && assets[f.sha256] === WITHHELD) reason = "personal-data";
    else if ((f.bytes || 0) > MAX_FILE_BYTES) reason = "too-large";
    f.published = reason === null;
    f.reason = reason;
    if (f.published) files.push({ abs: f.abs, out: f.path, sha256: f.sha256 });
  }
  const strip = (list) => list.map((x) => ({ path: x.path, published: x._f.published }));
  for (const r of requirements) { r.videos = strip(r.videos); for (const c of r.criteria) c.captures = strip(c.captures); }
  for (const f of fases) { f.videos = strip(f.videos); delete f._missingVideos; }
  const packDir = path.join(root, ".sdd", "entregas");
  const packs = existsSync(packDir) ? readdirSync(packDir).map((x) => x.match(/^FASE-(\d+)-evidencias\.tar\.gz$/)).filter(Boolean).sort((a, b) => Number(b[1]) - Number(a[1])) : [];

  const data = {
    $schema: SCHEMA,
    generatedAt,
    project: { name, lang, repo: { provider, web: provider && prov.host && prov.path ? `https://${prov.host}/${prov.path}` : null } },
    sha: head ? head.slice(0, 7) : null,
    where: { phase, phases, fase: faseNow, now: nowText, next: T.next[phase] ?? null, needFromYou },
    features,
    needs: needsOut,
    requirements,
    fases,
    journal,
    evidence: {
      // inAssets: the sha256 is already in status/page.json assets (published before, or withheld): upload only the others
      files: [...evFiles.values()].map((f) => ({ path: f.path, sha256: f.sha256, bytes: f.bytes || 0, kind: f.kind, criteria: [...f.criteria].sort(),
        published: f.published, reason: f.reason, inAssets: Boolean(f.sha256 && assets[f.sha256]) })),
      pack: packs.length ? `.sdd/entregas/${packs[0][0]}` : null,
    },
    technical: {
      sha: head,
      gate: ledger ? (() => { const code = gateCode(ledger, adversarialGate(root)); return { code, label: GATE_LABELS[code] }; })() : null,
      tags: tags.map((t) => ({ name: t.name, date: t.date, url: tagUrl(t.name) })),
      report: existsSync(path.join(root, "acceptance", "ACCEPTANCE-REPORT.md")) ? "acceptance/ACCEPTANCE-REPORT.md" : null,
      pipeline: Object.entries(stages).filter(([, v]) => v && typeof v === "object").map(([k, v]) => ({ stage: k, status: v.status || "pending", lastRun: v.lastRun || null })),
    },
    page: { url: page?.url || oldPage?.url || null, comments: true },
  };
  return { data, files };
}

/** Journal of the page: written lines (derived: false) plus derived facts not already written, oldest first. */
function deriveJournal({ root, T, lang, written, tags, state, decisions, features }) {
  const derived = [];
  const add = (e) => { const { entry, errors } = makeEntry(e); if (!errors.length) derived.push(entry); };
  for (const t of tags) {
    if (!t.date) continue;
    let m;
    if ((m = t.name.match(/^requirements-v(\d+)$/))) add({ at: t.date, stage: "requirements-engineer", kind: "gate", text: T.reqApproved(m[1]), refs: [t.name], by: t.by });
    else if ((m = t.name.match(/^fase-(\d+)-verified$/))) add({ at: t.date, stage: "task-implementer", kind: "evidence", text: T.faseVerified(m[1]), refs: [`FASE-${m[1]}`, t.name] });
    else if ((m = t.name.match(/^fase-(\d+)-accepted$/))) add({ at: t.date, stage: "acceptance", kind: "gate", text: T.faseAccepted(m[1]), refs: [`FASE-${m[1]}`, t.name], by: t.by });
  }
  const route = state?.route;
  if (route && route.decidedAt && route.stages) {
    const keys = Object.keys(route.stages);
    for (const k of keys) if (route.stages[k] && route.stages[k].run === false) add({ at: route.decidedAt, stage: k, kind: "skip", text: skipText(k, route.stages[k].reason, lang) });
    const run = keys.filter((k) => route.stages[k]?.run).length;
    add({ at: route.decidedAt, stage: "route", kind: "decision", text: routeDecisionText(run, keys.length - run, lang), by: route.confirmedBy || undefined });
  }
  for (const r of decisions) {
    if (!r.at) continue;
    const by = r.by ? `${r.by}${r.role ? ` (${r.role})` : ""}` : undefined;
    if (r.type === "fase-acceptance") add({ at: r.at, stage: "acceptance", kind: "gate", text: (T.faseResult[r.result] || T.faseResult.accepted)(r.fase), refs: [`FASE-${r.fase}`], by });
    else if (r.type === "waiver") add({ at: r.at, stage: "acceptance", kind: "decision", text: T.waiver(r.req, r.reason), refs: [r.req], by });
    else if (T.record[r.type]) add({ at: r.at, stage: "acceptance", kind: "evidence", text: T.record[r.type](r.req), refs: [r.req], by });
    else if (r.type === "challenge-dismissal") add({ at: r.at, stage: "acceptance", kind: "decision", text: T.dismissal(r.req || r.challenge), refs: [r.req, r.challenge].filter(Boolean), by });
    else if (r.type === "literal-exception") add({ at: r.at, stage: "acceptance", kind: "decision", text: T.literalException(r.req), refs: [r.req], by });
  }
  for (const dir of ["changes", path.join("changes", "applied")]) {
    const d = path.join(root, dir);
    if (!existsSync(d)) continue;
    for (const f of readdirSync(d)) {
      const m = f.match(/^CHANGE-REPORT-(.+)\.md$/);
      if (!m) continue;
      let src = null;
      try { src = changeSource(root, m[1]); } catch { src = null; }
      if (!src) continue;
      const rel = posix(path.join(dir, f));
      const g = isRepo(root) ? git(root, ["log", "--diff-filter=A", "--format=%cI", "--", rel]).stdout.trim().split("\n").pop() : "";
      const dm = m[1].match(/^CHG-(\d{4}-\d{2}-\d{2})-/);
      const at = isoSecond(g) || (dm ? `${dm[1]}T00:00:00Z` : isoSecond(statSync(path.join(d, f)).mtime));
      const feature = features.find((x) => x.chg === m[1])?.id || DEFAULT_FEATURE;
      add({ at, feature, stage: "req-change", kind: "change", text: T.change(src.title.replace(/^[^:]+:\s*/, "")), refs: [m[1]] });
    }
  }
  const DAY = 86400000;
  const dup = (d) => written.some((e) => e.kind === d.kind && (
    (d.kind === "skip" || d.stage === "route") ? e.stage === d.stage
      : e.refs.some((r) => d.refs.includes(r)) && Math.abs(Date.parse(e.at) - Date.parse(d.at)) <= DAY));
  const seen = new Set();
  const list = [
    ...written.map(({ line, ...e }) => ({ ...e, derived: false })),
    ...derived.filter((d) => !dup(d)).filter((d) => { const k = `${d.kind}\0${d.stage}\0${d.at}\0${d.refs.join(",")}`; if (seen.has(k)) return false; seen.add(k); return true; })
      .map((e) => ({ ...e, derived: true })),
  ];
  return list.map((e, i) => ({ e, i })).sort((a, b) => (a.e.at < b.e.at ? -1 : a.e.at > b.e.at ? 1 : a.i - b.i)).map((x) => x.e);
}

// ------------------------------------------------------------------ output
/** JSON for an inline <script>: every `<` as \u003c, so no `</script` or `<!--` in the data can close or confuse
 *  the element (JSON.parse reads it back unchanged). */
export function embedJson(data) {
  return JSON.stringify(data).replace(/</g, "\\u003c");
}
const escHtml = (s) => String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
/** `Estado · <name>` (es) or `Status · <name>` (en): two to four words, the name cut to its first two words and 32
 *  characters. */
export function pageTitle(data) {
  let name = String(data?.project?.name || "").trim().split(/\s+/).slice(0, 2).join(" ");
  if (name.length > 32) name = `${name.slice(0, 31).trimEnd()}…`;
  const head = data?.project?.lang === "en" ? "Status" : "Estado";
  return name ? `${head} · ${name}` : head;
}
/** Template with the data in `<script type="application/json" id="sdd-data">`: the marker is either inside that element
 *  (its content is replaced) or alone (it becomes the element). */
export function renderPage(template, data) {
  template = template.replace(/<title>[\s\S]*?<\/title>/i, () => `<title>${escHtml(pageTitle(data))}</title>`);
  const json = embedJson(data);
  const inside = /(<script\b[^>]*\bid=["']sdd-data["'][^>]*>)\s*<!--SDD-DATA-->\s*(<\/script>)/i;
  if (inside.test(template)) return template.replace(inside, (_, a, b) => `${a}${json}${b}`);
  if (!template.includes(MARKER)) return null;
  return template.replace(MARKER, () => `<script type="application/json" id="sdd-data">${json}</script>`);
}

function sha256File(abs) {
  try { return "sha256:" + createHash("sha256").update(readFileSync(abs)).digest("hex"); } catch { return null; }
}

function cmdBuild(o, root, taskProgress) {
  if (o._.length) usage(`unexpected argument ${o._[0]}`);
  const tpl = o.template ? path.resolve(o.template) : TEMPLATE;
  if (!existsSync(tpl)) die(`status build: template not found: ${tpl}`);
  const template = readFileSync(tpl, "utf8");
  const { data, files } = buildStatus(root, { taskProgress });
  const outDir = path.resolve(root, o.out || DEFAULT_OUT);
  const html = renderPage(template, data);
  if (html === null) die(`status build: ${tpl} has no ${MARKER} marker`);
  mkdirSync(outDir, { recursive: true });
  rmSync(path.join(outDir, "evidencias"), { recursive: true, force: true });
  let copied = 0;
  for (const f of files) {
    // copy only what still has the sha256 the ledger recorded
    if (sha256File(f.abs) !== f.sha256) {
      const e = data.evidence.files.find((x) => x.path === f.out);
      if (e) { e.published = false; e.reason = "missing"; }
      continue;
    }
    const dest = path.join(outDir, ...f.out.split("/"));
    mkdirSync(path.dirname(dest), { recursive: true });
    copyFileSync(f.abs, dest);
    copied++;
  }
  // keep the per-card flags in line with any copy that failed above
  const pub = new Map(data.evidence.files.map((x) => [x.path, x.published]));
  for (const r of data.requirements) { for (const v of r.videos) v.published = pub.get(v.path) ?? false; for (const c of r.criteria) for (const x of c.captures) x.published = pub.get(x.path) ?? false; }
  for (const f of data.fases) for (const v of f.videos) v.published = pub.get(v.path) ?? false;
  writeFileSync(path.join(outDir, "data.json"), JSON.stringify(data, null, 2) + "\n");
  writeFileSync(path.join(outDir, "index.html"), renderPage(template, data));
  const rel = posix(path.relative(process.cwd(), outDir) || ".");
  if (o.json) out(JSON.stringify(data, null, 2));
  else {
    const shown = data.requirements.filter((r) => r.status === "shown").length;
    const act = data.requirements.filter((r) => r.status !== "deprecated").length;
    out(`status build: ${rel}/index.html · phase ${data.where.phase} · ${shown}/${act} requirements shown · ${data.fases.length} FASE(s) · ${copied} evidence file(s) copied · ${data.journal.length} journal line(s)`);
  }
  return 0;
}

// ------------------------------------------------------------------ entry
export function runStatus(cmd, argv, { prog = "sdd", taskProgress = () => null } = {}) {
  PROG = prog;
  try {
    const o = parse(argv);
    if (cmd === "journal") return cmdJournal(o);
    const sub = o._.shift();
    const root = rootOf(o);
    if (sub === "page") return cmdPage(o, root);
    if (sub === "build") return cmdBuild(o, root, taskProgress);
    usage(`unknown status command ${sub ?? "(none)"}: use page or build`);
  } catch (e) {
    if (e instanceof Exit) return e.code;
    throw e;
  }
}

export { KINDS };
