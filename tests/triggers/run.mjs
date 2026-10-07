#!/usr/bin/env node
// Evals deterministas de enrutado (M4 nivel 1). Red de seguridad LÉXICA: compara cada prompt de cases.json con la
// description de cada skill por TF-IDF + coseno y caza colisiones evidentes (dos skills que se disputan las mismas
// palabras) y vocabulario ausente (una skill sin palabras en español, un caso que no comparte ni una palabra con su
// skill). NO mide cómo enruta el modelo: el modelo entiende sinónimos, contexto y el cuerpo de la conversación, y este
// script no. Por eso solo rompe en lo que es un contrato (cobertura de casos y los `pin`) y el resto del ranking avisa:
// optimizar las descriptions para subir este número sería optimizar un proxy.
//
// Documento por skill = nombre (sin «sdd-») ×2 + description. Texto: minúsculas, NFD sin acentos, stopwords ES/EN,
// stemming ligero de sufijos. Peso = tf · idf con idf = ln(1 + N/(1+df)).
//
// Rompe (exit 1): una skill sin un positivo ES y uno EN; un caso `pin` que no queda rank-1; un `notExpect` por encima
// de `expect` en un caso `pin`; una skill del repo sin casos o un caso con una skill que no existe; cases.json mal
// formado. Avisa (exit 0): rank-1 global, márgenes < 0,03, pares de descriptions con coseno ≥ 0,5, skill sin trigger
// en español, palabra de trigger presente en ≥ 3 skills.
//
// Uso: node tests/triggers/run.mjs [--verbose] [--root DIR] [--cases FILE]
import { readFileSync, readdirSync, existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const opt = (k, d) => { const i = args.indexOf(k); return i >= 0 ? args[i + 1] : d; };
const ROOT = path.resolve(opt("--root", path.join(HERE, "..", "..")));
const CASES = path.resolve(opt("--cases", path.join(HERE, "cases.json")));
const VERBOSE = args.includes("--verbose");
const MARGIN = 0.03, PAIR = 0.5, TRIGGER_SPREAD = 3;

const STOP = new Set((
  "a an and any are as at be by can do does for from how i in into is it its me my of on or our please the then this " +
  "that these those to us we what when where which with without you your use uses not per each every until via now " +
  "el la los las lo de del al que en y o u un una unos unas por para con sin se su sus es son esta este estos estas " +
  "eso esto ese esa como cual cuales donde cuando me mi mis nos nuestro nuestra le les ya hay muy mas pero si no " +
  "triggers trigger sdd"
).split(/\s+/));
const SUFFIXES = ["aciones", "acion", "ciones", "cion", "ing", "ies", "es", "ed", "s"];
// Two light passes: plural/inflection, then a Spanish verb ending or final vowel, so «sincroniza» and «sincronizar»,
// «requisito» and «requisitos», «generate» and «generates» meet.
const VERB = /(ar|er|ir|a|e|o)$/;
const stem = (t) => {
  for (const s of SUFFIXES) if (t.length > s.length + 3 && t.endsWith(s)) { t = t.slice(0, -s.length); break; }
  const m = t.match(VERB);
  return m && t.length - m[1].length >= 4 ? t.slice(0, -m[1].length) : t;
};
const fold = (x) => x.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
const tok = (x) => fold(x).replace(/[^a-z0-9]+/g, " ").split(" ").filter((t) => t.length > 2 && !STOP.has(t)).map(stem);
const tf = (ts) => { const m = new Map(); for (const t of ts) m.set(t, (m.get(t) || 0) + 1); return m; };

// Spanish markers for the "skill without a Spanish trigger" warning (folded, unstemmed).
const ES_WORDS = new Set((
  "el la los las de del que en y un una por para con sin desde estado requisito requisitos especificaciones " +
  "revisar auditar auditoria calidad seguridad diseno sistema componentes tareas crear generar planificar fases fase " +
  "implementar integrar programar empezar ponte resumen sesion guardar progreso iniciar configurar migrar pruebas " +
  "estrategia cobertura aceptacion ronda evidencias verificar cerrar entrega falta codigo huerfano reparte coordina " +
  "estaciones etapas quiero ejecuta continua cambiar nuevo nueva deprecar funcionalidad necesito necesidades cliente " +
  "importar sincronizar ingenieria inversa corregir arreglar tecnico tecnologico descomponer sigue"
).split(/\s+/));

function frontmatterDescription(file) {
  const m = readFileSync(file, "utf8").match(/^---\n([\s\S]*?)\n---/);
  if (!m) return null;
  const d = m[1].match(/^description:\s*(.*)$/m);
  if (!d) return null;
  let v = d[1].trim();
  if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith("'") && v.endsWith("'"))) v = v.slice(1, -1);
  return v;
}
const triggersOf = (desc) => {
  const i = desc.indexOf("Triggers:");
  // A trigger may contain an apostrophe ('what's not implemented'): it closes only before a comma, period or the end.
  return i < 0 ? [] : [...desc.slice(i).matchAll(/'(.+?)'(?=\s*[,.]|\s*$)/g)].map((m) => m[1]);
};

// ── skills ──────────────────────────────────────────────────────────────────
const skills = [];
for (const d of readdirSync(path.join(ROOT, "skills")).sort()) {
  const f = path.join(ROOT, "skills", d, "SKILL.md");
  if (!existsSync(f)) continue;
  skills.push({ name: d, desc: frontmatterDescription(f) || "" });
}
const names = skills.map((s) => s.name);
const short = (n) => n.replace(/^sdd-/, "");
const docs = new Map(skills.map((s) => { const n = tok(short(s.name).replace(/-/g, " ")); return [s.name, tf([...n, ...n, ...tok(s.desc)])]; }));
const df = new Map();
for (const d of docs.values()) for (const t of d.keys()) df.set(t, (df.get(t) || 0) + 1);
const N = docs.size;
const idf = (t) => Math.log(1 + N / (1 + (df.get(t) || 0)));
const vec = (m) => { const v = new Map(); for (const [t, f] of m) v.set(t, f * idf(t)); return v; };
const cos = (a, b) => {
  let d = 0, na = 0, nb = 0;
  for (const [t, w] of a) { na += w * w; if (b.has(t)) d += w * b.get(t); }
  for (const w of b.values()) nb += w * w;
  return na && nb ? d / Math.sqrt(na * nb) : 0;
};
const V = new Map([...docs].map(([k, m]) => [k, vec(m)]));

const errors = [], warns = [];

// ── cases ───────────────────────────────────────────────────────────────────
let cases;
try { cases = JSON.parse(readFileSync(CASES, "utf8")).cases; } catch (e) { console.error(`triggers: no puedo leer ${CASES}: ${e.message}`); process.exit(1); }
if (!Array.isArray(cases) || !cases.length) { console.error("triggers: cases.json sin array `cases`"); process.exit(1); }

const known = new Set(names);
cases.forEach((c, i) => {
  const where = `caso ${i + 1} "${c.prompt}"`;
  if (typeof c.prompt !== "string" || !c.prompt.trim()) errors.push(`caso ${i + 1}: sin prompt`);
  if (c.lang !== "es" && c.lang !== "en") errors.push(`${where}: lang debe ser es|en`);
  if (c.expect !== null && !known.has(c.expect)) errors.push(`${where}: expect "${c.expect}" no es una skill del repo`);
  for (const n of c.notExpect || []) if (!known.has(n)) errors.push(`${where}: notExpect "${n}" no es una skill del repo`);
  if (c.pin && c.expect === null) errors.push(`${where}: pin sin expect`);
});
for (const n of names) {
  const pos = cases.filter((c) => c.expect === n);
  if (!pos.length) { errors.push(`${n}: ninguna skill del repo puede quedar sin casos`); continue; }
  for (const l of ["es", "en"]) if (!pos.some((c) => c.lang === l)) errors.push(`${n}: falta un positivo ${l.toUpperCase()}`);
}

// ── ranking ─────────────────────────────────────────────────────────────────
const stat = { es: [0, 0], en: [0, 0] };
const rows = [];
for (const c of cases) {
  const pv = vec(tf(tok(c.prompt)));
  const r = names.map((n) => ({ n, s: cos(pv, V.get(n)) })).sort((a, b) => b.s - a.s || a.n.localeCompare(b.n));
  const top = `${short(r[0].n)}(${r[0].s.toFixed(2)}) ${short(r[1].n)}(${r[1].s.toFixed(2)})`;
  if (c.expect === null) { rows.push(`info  [${c.lang}] "${c.prompt}" -> ${top}`); continue; }
  const rank = r.findIndex((x) => x.n === c.expect) + 1;
  const se = r[rank - 1].s;
  const margin = rank === 1 ? r[0].s - r[1].s : se - r[0].s;
  const s = stat[c.lang]; s[1]++; if (rank === 1) s[0]++;
  const tag = rank === 1 ? "ok  " : "MISS";
  rows.push(`${tag}  r${rank} m=${margin >= 0 ? "+" : ""}${margin.toFixed(3)} [${c.lang}]${c.pin ? " pin" : ""} "${c.prompt}" -> ${top}  exp=${short(c.expect)}`);
  if (c.pin) {
    if (rank !== 1) errors.push(`pin: "${c.prompt}" espera ${c.expect} y queda rank ${rank} (gana ${r[0].n})`);
    for (const n of c.notExpect || []) {
      const sn = r.find((x) => x.n === n).s;
      if (sn >= se) errors.push(`pin: "${c.prompt}": notExpect ${n} (${sn.toFixed(3)}) ≥ ${c.expect} (${se.toFixed(3)})`);
    }
  } else if (rank !== 1) warns.push(`rank ${rank}: "${c.prompt}" espera ${short(c.expect)}, gana ${short(r[0].n)}`);
  if (rank === 1 && margin < MARGIN) warns.push(`margen ${margin.toFixed(3)} < ${MARGIN}: "${c.prompt}" (${short(c.expect)} vs ${short(r[1].n)})`);
  if (!c.pin) for (const n of c.notExpect || []) {
    const sn = r.find((x) => x.n === n).s;
    if (sn >= se) warns.push(`notExpect ${short(n)} ≥ ${short(c.expect)}: "${c.prompt}"`);
  }
}

// ── description pairs ───────────────────────────────────────────────────────
const pairs = [];
for (let i = 0; i < names.length; i++) for (let j = i + 1; j < names.length; j++) {
  const a = V.get(names[i]), b = V.get(names[j]);
  const s = cos(a, b);
  if (s < PAIR) continue;
  const shared = [...a.keys()].filter((t) => b.has(t)).sort((x, y) => a.get(y) * b.get(y) - a.get(x) * b.get(x)).slice(0, 5);
  pairs.push(`par ${short(names[i])} ~ ${short(names[j])} coseno ${s.toFixed(3)} ≥ ${PAIR} (comparten: ${shared.join(", ")})`);
}
warns.push(...pairs);

// ── triggers: Spanish presence and spread ───────────────────────────────────
const triggerTerms = new Map();
for (const s of skills) {
  const trig = triggersOf(s.desc);
  const isEs = (t) => /[áéíóúñ¿¡]/i.test(t) || fold(t).split(/[^a-z0-9]+/).some((w) => ES_WORDS.has(w));
  if (!trig.some(isEs)) warns.push(`${s.name}: sin trigger en español en la description`);
  for (const t of new Set(trig.flatMap(tok))) {
    if (!triggerTerms.has(t)) triggerTerms.set(t, new Set());
    triggerTerms.get(t).add(short(s.name));
  }
}
for (const [t, set] of [...triggerTerms].sort()) if (set.size >= TRIGGER_SPREAD) warns.push(`palabra de trigger «${t}» en ${set.size} skills: ${[...set].join(", ")}`);

// ── report ──────────────────────────────────────────────────────────────────
if (VERBOSE) { console.log("== casos"); for (const r of rows) console.log(r); console.log(); }
const pct = ([a, b]) => `${a}/${b}${b ? ` (${Math.round((100 * a) / b)}%)` : ""}`;
const pins = cases.filter((c) => c.pin).length;
console.log(`triggers: ${names.length} skills, ${cases.length} casos (${pins} pin, ${cases.filter((c) => c.expect === null).length} fuera de dominio)`);
console.log(`rank-1 global: ES ${pct(stat.es)} · EN ${pct(stat.en)} · total ${pct([stat.es[0] + stat.en[0], stat.es[1] + stat.en[1]])}`);
console.log(`colisiones (pares ≥ ${PAIR}): ${pairs.length}`);
if (warns.length) { console.log(`avisos (${warns.length}):`); for (const w of warns) console.log(`  aviso  ${w}`); }
if (errors.length) { console.log(`errores (${errors.length}):`); for (const e of errors) console.log(`  ERROR  ${e}`); console.log("tests/triggers: hay fallos"); process.exit(1); }
console.log("tests/triggers: todo ok");
