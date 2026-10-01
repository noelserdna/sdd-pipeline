// shape.mjs — checks a data.json against the sdd-status-v1 contract (docs/design/plan-5.2-status-page.md): every key,
// its type and its enum. Usage: node tests/status/shape.mjs data.json → prints the problems, exit 1 when there is any.
import { readFileSync } from "node:fs";

const data = JSON.parse(readFileSync(process.argv[2], "utf8"));
const errs = [];
const at = (p, msg) => errs.push(`${p}: ${msg}`);
const T = {
  str: (v) => typeof v === "string",
  strN: (v) => v === null || typeof v === "string",
  num: (v) => typeof v === "number" && Number.isFinite(v),
  int: (v) => Number.isInteger(v),
  intN: (v) => v === null || Number.isInteger(v),
  bool: (v) => typeof v === "boolean",
  arr: (v) => Array.isArray(v),
  obj: (v) => v !== null && typeof v === "object" && !Array.isArray(v),
  objN: (v) => v === null || (typeof v === "object" && !Array.isArray(v)),
  iso: (v) => typeof v === "string" && !Number.isNaN(Date.parse(v)),
  isoN: (v) => v === null || (typeof v === "string" && !Number.isNaN(Date.parse(v))),
};
const oneOf = (list) => (v) => list.includes(v);
const oneOfN = (list) => (v) => v === null || list.includes(v);
/** Exact keys: `spec` maps key → check; keys ending in `?` are optional. Extra keys are reported. */
function shape(p, v, spec) {
  if (!T.obj(v)) { at(p, "not an object"); return false; }
  for (const [k0, check] of Object.entries(spec)) {
    const opt = k0.endsWith("?"), k = opt ? k0.slice(0, -1) : k0;
    if (!(k in v)) { if (!opt) at(p, `missing key ${k}`); continue; }
    if (typeof check === "function" && !check(v[k])) at(`${p}.${k}`, `bad value ${JSON.stringify(v[k])?.slice(0, 80)}`);
  }
  for (const k of Object.keys(v)) if (!(k in spec) && !(`${k}?` in spec)) at(p, `unexpected key ${k}`);
  return true;
}
const PH = ["understand", "agree", "design", "plan", "build", "verify", "deliver", "done"];
const KINDS = ["start", "done", "gate", "decision", "change", "skip", "evidence", "feedback"];
const file = (p, f) => shape(p, f, { path: T.str, published: T.bool });

shape("$", data, { $schema: (v) => v === "sdd-status-v1", generatedAt: T.iso, project: T.obj, sha: T.strN, where: T.obj, features: T.arr,
  needs: T.arr, requirements: T.arr, fases: T.arr, journal: T.arr, evidence: T.obj, technical: T.obj, page: T.obj });
shape("project", data.project, { name: T.str, lang: oneOf(["es", "en"]), repo: T.obj });
shape("project.repo", data.project.repo, { provider: oneOfN(["github", "gitlab"]), web: T.strN });
const w = data.where;
shape("where", w, { phase: oneOf(PH), phases: T.arr, fase: T.objN, now: T.str, next: T.strN, needFromYou: T.arr });
if (w.phases.map((x) => x.id).join() !== PH.slice(0, 7).join()) at("where.phases", "ids out of order");
w.phases.forEach((x, i) => shape(`where.phases[${i}]`, x, { id: T.str, state: oneOf(["done", "current", "pending", "skipped"]), "reason?": T.str }));
if (w.fase) shape("where.fase", w.fase, { n: T.int, of: T.int, title: T.str });
w.needFromYou.forEach((x, i) => shape(`where.needFromYou[${i}]`, x, { text: T.str, anchor: T.str }));
if (!data.features.length || data.features[0].id !== "initial") at("features", "the initial feature must come first");
data.features.forEach((x, i) => shape(`features[${i}]`, x, { id: T.str, title: T.str, createdAt: T.iso, summary: T.str }));
data.needs.forEach((x, i) => shape(`needs[${i}]`, x, { id: T.str, quote: T.str, who: T.strN, when: T.strN,
  status: oneOf(["captured", "confirmed", "out-of-scope"]), "decision?": T.str, feature: T.str, requirements: T.arr }));
data.requirements.forEach((r, i) => {
  const p = `requirements[${i}]`;
  shape(p, r, { id: T.str, kind: oneOf(["F", "NF", "C"]), title: T.str, plain: T.strN, statement: T.str,
    priority: oneOfN(["Must", "Should", "Could", "Won't"]), feature: T.str, needs: T.arr, fase: T.intN,
    status: oneOf(["pending", "building", "shown", "failing", "deferred", "deprecated"]),
    verification: oneOfN(["test", "demo", "measurement", "inspection"]), criteria: T.arr, videos: T.arr, warnings: T.arr,
    waiver: T.objN, links: T.obj });
  r.criteria.forEach((c, j) => {
    const q = `${p}.criteria[${j}]`;
    shape(q, c, { n: T.int, text: T.str, status: oneOf(["pending", "pass", "fail", "missing", "unshown", "weakened", "stale"]),
      captures: T.arr, tests: T.obj, measurement: T.objN, record: T.objN });
    c.captures.forEach((x, k) => file(`${q}.captures[${k}]`, x));
    shape(`${q}.tests`, c.tests, { pass: T.int, total: T.int, names: T.arr });
    if (c.measurement) shape(`${q}.measurement`, c.measurement, { metric: T.str, observed: T.num, op: T.str, threshold: T.num });
    if (c.record) shape(`${q}.record`, c.record, { type: oneOf(["demo", "inspection"]), by: T.strN, at: T.isoN, note: T.strN });
  });
  r.videos.forEach((x, k) => file(`${p}.videos[${k}]`, x));
  r.warnings.forEach((x, k) => shape(`${p}.warnings[${k}]`, x, {
    code: oneOf(["unshown", "weakened", "challenge", "missing_video", "stale", "failing"]), text: T.str, ac: T.intN }));
  if (r.waiver) shape(`${p}.waiver`, r.waiver, { reason: T.strN, by: T.strN, followUp: T.strN, at: T.isoN });
  shape(`${p}.links`, r.links, { commits: T.arr, issue: T.objN });
  r.links.commits.forEach((x, k) => shape(`${p}.links.commits[${k}]`, x, { sha: T.str, url: T.strN, subject: T.str }));
  if (r.links.issue) shape(`${p}.links.issue`, r.links.issue, { number: T.int, url: T.strN });
});
data.fases.forEach((f, i) => {
  const p = `fases[${i}]`;
  shape(p, f, { n: T.int, title: T.str, increment: T.str, requirements: T.arr, needs: T.arr, feature: T.str, workflows: T.arr, demo: T.arr,
    videos: T.arr, missingVideos: T.arr, tasks: T.obj, status: oneOf(["pending", "building", "verified", "accepted", "rejected", "observations"]),
    acceptance: T.objN, issue: T.objN, tags: T.arr });
  f.demo.forEach((x, k) => shape(`${p}.demo[${k}]`, x, { step: T.int, action: T.str, expected: T.str }));
  f.videos.forEach((x, k) => file(`${p}.videos[${k}]`, x));
  shape(`${p}.tasks`, f.tasks, { done: T.int, total: T.int });
  if (f.acceptance) shape(`${p}.acceptance`, f.acceptance, { by: T.strN, role: T.strN, at: T.isoN, channel: T.strN });
  if (f.issue) shape(`${p}.issue`, f.issue, { number: T.int, url: T.strN });
  f.tags.forEach((x, k) => shape(`${p}.tags[${k}]`, x, { name: T.str, date: T.isoN, url: T.strN }));
});
data.journal.forEach((e, i) => shape(`journal[${i}]`, e, { at: T.iso, feature: T.str, stage: T.str, kind: oneOf(KINDS), text: T.str,
  refs: T.arr, "by?": T.str, derived: T.bool }));
for (let i = 1; i < data.journal.length; i++) if (data.journal[i - 1].at > data.journal[i].at) at("journal", "not in chronological order");
shape("evidence", data.evidence, { files: T.arr, pack: T.strN });
data.evidence.files.forEach((x, i) => shape(`evidence.files[${i}]`, x, { path: T.str, sha256: T.strN, bytes: T.int, kind: oneOf(["image", "video"]),
  criteria: T.arr, published: T.bool, reason: oneOfN(["too-large", "personal-data", "missing"]), inAssets: T.bool }));
shape("technical", data.technical, { sha: T.strN, gate: T.objN, tags: T.arr, report: T.strN, pipeline: T.arr });
if (data.technical.gate) shape("technical.gate", data.technical.gate, { code: T.int, label: T.str });
data.technical.tags.forEach((x, i) => shape(`technical.tags[${i}]`, x, { name: T.str, date: T.isoN, url: T.strN }));
data.technical.pipeline.forEach((x, i) => shape(`technical.pipeline[${i}]`, x, { stage: T.str, status: T.str, lastRun: T.strN }));
shape("page", data.page, { url: T.strN, comments: T.bool });
// anchors: every link points at something on the page
const ids = new Set([...data.needs.map((n) => n.id), ...data.requirements.map((r) => r.id), ...data.fases.map((f) => `FASE-${f.n}`)]);
for (const x of w.needFromYou) if (!ids.has(x.anchor)) at("where.needFromYou", `anchor ${x.anchor} is not on the page`);
for (const r of data.requirements) for (const n of r.needs) if (!data.needs.some((x) => x.id === n) && data.needs.length) at(r.id, `need ${n} is not on the page`);
for (const n of data.needs) for (const id of n.requirements) if (!data.requirements.some((r) => r.id === id)) at(n.id, `requirement ${id} is not on the page`);
for (const r of data.requirements) if (r.fase !== null && !data.fases.some((f) => f.n === r.fase)) at(r.id, `FASE-${r.fase} is not on the page`);
const paths = new Set(data.evidence.files.map((f) => f.path));
for (const r of data.requirements) for (const x of [...r.videos, ...r.criteria.flatMap((c) => c.captures)]) if (!paths.has(x.path)) at(r.id, `${x.path} is not in evidence.files`);

for (const e of errs) console.log(e);
process.exit(errs.length ? 1 : 0);
