#!/usr/bin/env node
// Validación propia del plugin (claude plugin validate no cubre hooks.json ni .mcp.json).
import { readFileSync, existsSync, readdirSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const errors = [];
const warnings = [];
const json = (p) => JSON.parse(readFileSync(path.join(ROOT, p), "utf8"));

function frontmatter(file) {
  const text = readFileSync(file, "utf8");
  const m = text.match(/^---\n([\s\S]*?)\n---\n/);
  if (!m) return null;
  const fm = {};
  let key = null;
  for (const line of m[1].split("\n")) {
    const kv = line.match(/^([A-Za-z_-]+):\s*(.*)$/);
    if (kv) { key = kv[1]; fm[key] = kv[2]; }
    else if (key && /^\s+\S/.test(line)) fm[key] += " " + line.trim(); // valor plegado en varias líneas
  }
  for (const k of Object.keys(fm)) fm[k] = fm[k].replace(/^"([\s\S]*)"$/, "$1").replace(/^'([\s\S]*)'$/, "$1");
  return fm;
}

// Ficheros bajo dir, recursivo, rutas absolutas
function walk(dir) {
  const out = [];
  for (const name of readdirSync(dir)) {
    const p = path.join(dir, name);
    if (statSync(p).isDirectory()) out.push(...walk(p));
    else out.push(p);
  }
  return out;
}
const rel = (p) => path.relative(ROOT, p).split(path.sep).join("/");

// 1. Manifiestos
const plugin = json(".claude-plugin/plugin.json");
const market = json(".claude-plugin/marketplace.json");
const serverPkg = json("server/package.json");
if (!/^[a-z][a-z0-9]*(-[a-z0-9]+)*$/.test(plugin.name)) errors.push(`plugin.json: name inválido "${plugin.name}"`);
for (const k of ["version", "description", "author", "license", "repository"]) if (!plugin[k]) errors.push(`plugin.json: falta ${k}`);
const entry = market.plugins?.find((p) => p.name === plugin.name);
if (!entry) errors.push(`marketplace.json: no hay entrada para ${plugin.name}`);
if (entry && entry.version !== plugin.version) errors.push(`versión distinta: plugin.json=${plugin.version} marketplace=${entry.version}`);
if (serverPkg.version !== plugin.version) errors.push(`versión distinta: server/package.json=${serverPkg.version} plugin.json=${plugin.version}`);

// 2. Skills
const skillsDir = path.join(ROOT, "skills");
let skillCount = 0;
for (const dir of readdirSync(skillsDir)) {
  const file = path.join(skillsDir, dir, "SKILL.md");
  if (!existsSync(file)) { errors.push(`skills/${dir}: falta SKILL.md`); continue; }
  skillCount++;
  const fm = frontmatter(file);
  if (!fm) { errors.push(`skills/${dir}: sin frontmatter`); continue; }
  if (fm.name !== dir) errors.push(`skills/${dir}: name "${fm.name}" != directorio`);
  if (!fm.description) errors.push(`skills/${dir}: sin description`);
  else if (fm.description.length > 400) warnings.push(`skills/${dir}: description de ${fm.description.length} chars (> 400, coste de contexto)`);
  if (fm.version) warnings.push(`skills/${dir}: version: en frontmatter (la única fuente es plugin.json)`);
}

// 3. Agentes
const agentsDir = path.join(ROOT, "agents");
let agentCount = 0;
for (const f of existsSync(agentsDir) ? readdirSync(agentsDir).filter((f) => f.endsWith(".md")) : []) {
  agentCount++;
  const fm = frontmatter(path.join(agentsDir, f));
  if (!fm?.name) errors.push(`agents/${f}: sin name en frontmatter`);
  if (!fm?.description) errors.push(`agents/${f}: sin description`);
}

// 4. hooks.json
const hooks = json("hooks/hooks.json");
if (!hooks.hooks || typeof hooks.hooks !== "object") errors.push("hooks/hooks.json: falta el wrapper {hooks:{...}}");
if (!hooks.description) warnings.push("hooks/hooks.json: sin description");
let hookCount = 0;
for (const [event, groups] of Object.entries(hooks.hooks ?? {})) {
  for (const g of groups) for (const h of g.hooks ?? []) {
    hookCount++;
    const m = h.command?.match(/\$\{CLAUDE_PLUGIN_ROOT\}\/([^\s"']+)/);
    if (!m) { errors.push(`hooks.json ${event}: command sin \${CLAUDE_PLUGIN_ROOT}: ${h.command}`); continue; }
    const target = path.join(ROOT, m[1]);
    if (!existsSync(target)) errors.push(`hooks.json ${event}: no existe ${m[1]}`);
    else if (!(statSync(target).mode & 0o111)) errors.push(`hooks.json ${event}: ${m[1]} sin bit de ejecución`);
  }
}

// 5. .mcp.json
const mcp = json(".mcp.json");
if (!mcp.mcpServers) errors.push(".mcp.json: falta el wrapper mcpServers");
for (const [name, cfg] of Object.entries(mcp.mcpServers ?? {})) {
  for (const arg of cfg.args ?? []) {
    const m = arg.match(/\$\{CLAUDE_PLUGIN_ROOT\}\/([^\s"']+)/);
    if (m && !existsSync(path.join(ROOT, m[1]))) errors.push(`.mcp.json ${name}: no existe ${m[1]} (¿npm run build?)`);
  }
}

// 6. Resumen
const hookScripts = new Set();
for (const groups of Object.values(hooks.hooks ?? {})) for (const g of groups) for (const h of g.hooks ?? []) {
  const m = h.command?.match(/\$\{CLAUDE_PLUGIN_ROOT\}\/([^\s"']+)/); if (m) hookScripts.add(m[1]);
}
console.log(`plugin ${plugin.name}@${plugin.version}: ${skillCount} skills, ${agentCount} agentes, ${hookScripts.size} hooks (${hookCount} registros de evento), ${Object.keys(mcp.mcpServers ?? {}).length} MCP`);
// coherencia: lo que el manifiesto dice de sí mismo
const claim = (plugin.description || "").match(/(\d+)\s+skills/);
if (claim && Number(claim[1]) !== skillCount) errors.push(`plugin.json description dice ${claim[1]} skills pero hay ${skillCount}`);
const claimA = (plugin.description || "").match(/(\d+)\s+agents?/);
if (claimA && Number(claimA[1]) !== agentCount) errors.push(`plugin.json description dice ${claimA[1]} agentes pero hay ${agentCount}`);
const claimH = (plugin.description || "").match(/(\d+)\s+hooks?/);
if (claimH && Number(claimH[1]) !== hookScripts.size) errors.push(`plugin.json description dice ${claimH[1]} hooks pero hay ${hookScripts.size} scripts de hook`);

// 7. Stack kits (templates/stacks/<kit>): contrato de docs/stacks.md
const PROFILE_KEYS = ["stack", "app_dir", "code_paths", "test_paths", "install", "test", "test_file", "test_name",
  "typecheck", "lint_files", "lint", "build", "coverage", "db_reset_safe", "server", "port", "acceptance",
  "e2e_scaffold", "task_state", "task_format", "test_report", "acceptance_gate", "tracker",
  // 5.1: visual evidence, adversarial round, machine resources and post-deploy smoke (docs/design/plan-5.1.md §2.1).
  "visual_evidence", "evidence_dir", "adversarial_gate", "literal_gate", "test_slots", "staging_url", "smoke", "smoke_report_path",
  "env_required", "deploy"];
// Optional keys: valid in a profile, never required of a kit (default_branch: branch rule of references/git-conventions.md;
// test_report_path: where test_report writes JUnit when it is not .sdd/junit/, project-specific).
const OPTIONAL_PROFILE_KEYS = ["default_branch", "test_report_path"];
const REQUIRED_KEYS = ["test", "test_file", "lint", "server", "port", "db_reset_safe"];
const FORBIDDEN = [
  [/CONSENT/, "CONSENT"], [/migrate\s+reset/i, "migrate reset"], [/@restart/i, "@restart"],
  [/never\s+push/i, "Never push"], [/never\s+ask/i, "Never ask"],
];
const CONVENTIONS_MAX = 2500;
const stacksDir = path.join(ROOT, "templates", "stacks");
const strList = (v) => Array.isArray(v) && v.length > 0 && v.every((x) => typeof x === "string" && x.trim());

function rulePaths(text) {
  const fm = text.match(/^---\n([\s\S]*?)\n---\n/);
  if (!fm) return null;
  const lines = fm[1].split("\n");
  const i = lines.findIndex((l) => /^paths:/.test(l));
  if (i < 0) return [];
  const inline = lines[i].match(/^paths:\s*\[(.*)\]\s*$/);
  if (inline) return inline[1].split(",").map((s) => s.trim().replace(/^["']|["']$/g, "")).filter(Boolean);
  const out = [];
  for (const l of lines.slice(i + 1)) {
    const m = l.match(/^\s+-\s+(.+?)\s*$/);
    if (!m) break;
    out.push(m[1].replace(/^["']|["']$/g, ""));
  }
  return out;
}

if (existsSync(stacksDir)) {
  const installer = path.join(ROOT, "scripts", "install-stack-kit.sh");
  if (!existsSync(installer)) errors.push("templates/stacks existe pero falta scripts/install-stack-kit.sh");
  else if (!(statSync(installer).mode & 0o111)) errors.push("scripts/install-stack-kit.sh sin bit de ejecución");

  for (const kit of readdirSync(stacksDir).filter((d) => statSync(path.join(stacksDir, d)).isDirectory())) {
    const dir = path.join(stacksDir, kit);
    const where = `templates/stacks/${kit}`;
    if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(kit)) errors.push(`${where}: nombre de kit inválido (minúsculas, dígitos y guiones)`);

    let meta = null;
    try { meta = JSON.parse(readFileSync(path.join(dir, "kit.json"), "utf8")); }
    catch (e) { errors.push(`${where}/kit.json: ${existsSync(path.join(dir, "kit.json")) ? `JSON inválido (${e.message})` : "falta"}`); continue; }

    // kit.json
    if (meta.name !== kit) errors.push(`${where}/kit.json: name "${meta.name}" != directorio`);
    if (!/^\d+\.\d+\.\d+$/.test(String(meta.version ?? ""))) errors.push(`${where}/kit.json: version "${meta.version}" no es X.Y.Z`);
    if (!meta.detect || typeof meta.detect !== "object" || !strList(meta.detect.all)) errors.push(`${where}/kit.json: detect.all debe ser una lista no vacía de ficheros`);
    if (meta.detect?.any !== undefined && !(Array.isArray(meta.detect.any) && meta.detect.any.every((x) => typeof x === "string"))) errors.push(`${where}/kit.json: detect.any debe ser una lista de ficheros`);
    const defaults = meta.defaults && typeof meta.defaults === "object" && !Array.isArray(meta.defaults) ? meta.defaults : null;
    if (!defaults) errors.push(`${where}/kit.json: falta defaults`);
    else {
      for (const k of PROFILE_KEYS) if (typeof defaults[k] !== "string" || !defaults[k].trim()) errors.push(`${where}/kit.json: defaults.${k} ${REQUIRED_KEYS.includes(k) ? "(obligatoria) " : ""}falta o no es un string`);
      for (const k of Object.keys(defaults)) if (!PROFILE_KEYS.includes(k) && !OPTIONAL_PROFILE_KEYS.includes(k)) warnings.push(`${where}/kit.json: defaults.${k} no es una clave del Stack Profile v1`);
      if (defaults.stack !== undefined && defaults.stack !== kit) errors.push(`${where}/kit.json: defaults.stack "${defaults.stack}" != ${kit}`);
      if (defaults.port !== undefined && !/^\d{1,5}$/.test(defaults.port)) errors.push(`${where}/kit.json: defaults.port debe ser un número ("3000")`);
      if (typeof defaults.app_dir === "string" && /[{}]/.test(defaults.app_dir)) errors.push(`${where}/kit.json: defaults.app_dir no admite marcadores`);
    }
    if (!strList(meta.rules)) errors.push(`${where}/kit.json: rules debe ser una lista no vacía`);
    if (!strList(meta.layers)) errors.push(`${where}/kit.json: layers debe ser una lista ordenada no vacía`);
    if (!strList(meta.wiring)) errors.push(`${where}/kit.json: wiring debe ser una lista no vacía`);
    else for (const w of meta.wiring) if (w.startsWith("/") || w.split("/").includes("..") || /[{}]/.test(w)) errors.push(`${where}/kit.json: wiring "${w}" debe ser relativo a app_dir y sin marcadores`);

    // profile.md
    const profileFile = path.join(dir, "profile.md");
    if (!existsSync(profileFile)) errors.push(`${where}: falta profile.md`);
    else {
      const lines = readFileSync(profileFile, "utf8").replace(/\n+$/, "").split("\n");
      if (lines[0] !== "## SDD Stack Profile") errors.push(`${where}/profile.md: la primera línea debe ser "## SDD Stack Profile"`);
      if (lines[1] !== `<!-- sdd-stack-profile v1 kit=${kit} -->`) errors.push(`${where}/profile.md: la segunda línea debe ser "<!-- sdd-stack-profile v1 kit=${kit} -->"`);
      const prof = {};
      for (const l of lines.slice(2)) {
        const m = l.match(/^- ([a-z0-9_]+): (.+)$/);
        if (m) prof[m[1]] = m[2];
        else errors.push(`${where}/profile.md: línea fuera del contrato "${l}"`);
      }
      for (const k of PROFILE_KEYS) if (!(k in prof)) errors.push(`${where}/profile.md: falta la clave ${k}`);
      for (const k of Object.keys(prof)) if (!PROFILE_KEYS.includes(k) && !OPTIONAL_PROFILE_KEYS.includes(k)) warnings.push(`${where}/profile.md: clave desconocida ${k}`);
      const expect = (k, ok, msg) => { if (k in prof && !ok(prof[k])) errors.push(`${where}/profile.md: ${k} ${msg}`); };
      expect("stack", (v) => v === kit, `debe ser ${kit}`);
      expect("app_dir", (v) => v === "{app_dir}", "debe ser {app_dir}");
      expect("port", (v) => v === "{port}", "debe ser {port}");
      expect("test_file", (v) => v.includes("{file}"), "debe contener {file}");
      expect("test_name", (v) => v === "none" || v.includes("{pattern}"), "debe contener {pattern} o ser none");
      expect("lint_files", (v) => v === "none" || v.includes("{files}"), "debe contener {files} o ser none");
      expect("server", (v) => v === "none" || v.includes("{port}"), "debe contener {port} o ser none");
      expect("e2e_scaffold", (v) => ["allowed", "never"].includes(v), "debe ser allowed o never");
      expect("task_state", (v) => ["checkbox", "trailers"].includes(v), "debe ser checkbox o trailers");
      expect("task_format", (v) => ["full", "compact"].includes(v), "debe ser full o compact");
      expect("acceptance_gate", (v) => ["off", "warn", "enforce"].includes(v), "debe ser off, warn o enforce");
      expect("tracker", (v) => ["github", "gitlab", "off"].includes(v), "debe ser github, gitlab u off");
      expect("visual_evidence", (v) => ["required", "warn", "off"].includes(v), "debe ser required, warn u off");
      expect("adversarial_gate", (v) => ["off", "warn", "enforce"].includes(v), "debe ser off, warn o enforce");
      expect("literal_gate", (v) => ["off", "warn", "enforce"].includes(v), "debe ser off, warn o enforce");
      expect("test_slots", (v) => /^[1-9]\d*$/.test(v), "debe ser un entero >= 1");
      expect("staging_url", (v) => v === "none" || /^https?:\/\//.test(v), "debe ser una URL http(s) o none");
      expect("test_report", (v) => v === "none" || /\.sdd\/junit\//.test(v), "debe escribir JUnit en .sdd/junit/ (o ser none)");
      for (const k of ["code_paths", "test_paths"]) expect(k, (v) => v.split(",").every((p) => p.trim().startsWith("{app_dir}/")), ": cada ruta debe empezar por {app_dir}/");
      if (defaults) for (const k of PROFILE_KEYS) {
        if (k === "app_dir" || k === "port" || !(k in prof) || typeof defaults[k] !== "string") continue;
        if (defaults[k] !== prof[k]) errors.push(`${where}: defaults.${k} != profile.md (${JSON.stringify(defaults[k])} vs ${JSON.stringify(prof[k])})`);
      }
    }

    // conventions.md
    const convFile = path.join(dir, "conventions.md");
    if (!existsSync(convFile)) errors.push(`${where}: falta conventions.md`);
    else {
      const conv = readFileSync(convFile, "utf8");
      if (!conv.startsWith("## Stack Conventions\n")) errors.push(`${where}/conventions.md: debe empezar por "## Stack Conventions"`);
      if (conv.length > CONVENTIONS_MAX) errors.push(`${where}/conventions.md: ${conv.length} chars (> ${CONVENTIONS_MAX}; se carga en cada turno)`);
    }

    // rules/*.md
    const rulesDir = path.join(dir, "rules");
    const ruleFiles = existsSync(rulesDir) ? readdirSync(rulesDir).filter((f) => f.endsWith(".md")) : [];
    for (const r of Array.isArray(meta.rules) ? meta.rules : []) if (!ruleFiles.includes(`${r}.md`)) errors.push(`${where}/kit.json: la regla "${r}" no tiene rules/${r}.md`);
    for (const f of ruleFiles) {
      const w = `${where}/rules/${f}`;
      if (Array.isArray(meta.rules) && !meta.rules.includes(f.replace(/\.md$/, ""))) warnings.push(`${w}: no está en kit.json rules (no se instala)`);
      const text = readFileSync(path.join(rulesDir, f), "utf8");
      const paths = rulePaths(text);
      if (paths === null) { errors.push(`${w}: sin frontmatter YAML`); continue; }
      if (!paths.length) errors.push(`${w}: el frontmatter no declara paths:`);
      for (const p of paths) if (!p.startsWith("{app_dir}/")) errors.push(`${w}: el glob "${p}" debe empezar por {app_dir}/`);
      if (/^\s*(```|~~~)/m.test(text)) errors.push(`${w}: las reglas no llevan bloques de código`);
      const n = text.replace(/\n+$/, "").split("\n").length;
      if (n > 22) warnings.push(`${w}: ${n} líneas (una regla de kit ronda las 20)`);
    }

    // cadenas prohibidas en todo el kit
    for (const file of walk(dir)) {
      const text = readFileSync(file, "utf8");
      for (const [re, label] of FORBIDDEN) if (re.test(text)) errors.push(`${rel(file)}: contiene "${label}" (prohibido en un kit)`);
    }
  }
}

// 8. Flags citados en Invocation / Multi-Agent sin fila en la tabla "### Flags" de la misma skill
const skillNames = readdirSync(skillsDir).filter((d) => existsSync(path.join(skillsDir, d, "SKILL.md")));
const FLAG_RE = /(?<![\w-])--[a-z][a-z0-9-]*/g;
for (const self of skillNames) {
  const lines = readFileSync(path.join(skillsDir, self, "SKILL.md"), "utf8").split("\n");
  let fence = false, h2 = "", inFlags = false, hasFlags = false;
  const table = new Set();
  const mentioned = new Map();
  const note = (flag, n) => { if (!mentioned.has(flag)) mentioned.set(flag, n); };
  lines.forEach((line, idx) => {
    if (/^\s*(```|~~~)/.test(line)) { fence = !fence; return; }
    if (!fence) {
      const h = line.match(/^(#{1,3}) (.*)$/);
      if (h) {
        if (h[1].length <= 2) h2 = h[1].length === 2 ? h[2] : "";
        inFlags = h[1].length === 3 && /^Flags\b/.test(h[2]);
        if (inFlags) hasFlags = true;
        return;
      }
    }
    if (inFlags) { for (const m of line.match(FLAG_RE) ?? []) table.add(m); return; }
    if (!/^(Invocation|.*Multi-Agent)/i.test(h2)) return;
    if (fence) {
      if (line.trim().startsWith(`/${self}`)) for (const m of line.match(FLAG_RE) ?? []) note(m, idx + 1);
      return;
    }
    const other = [...line.matchAll(/\b(sdd-[a-z-]+)/g)].some((m) => m[1] !== self && skillNames.includes(m[1]));
    for (const span of line.matchAll(/`([^`]+)`/g)) {
      const s = span[1].trim();
      if (s.startsWith(`/${self}`) || s.startsWith(self) || (s.startsWith("--") && !other)) for (const m of s.match(FLAG_RE) ?? []) note(m, idx + 1);
    }
    if (!other) for (const m of line.replace(/`[^`]*`/g, " ").matchAll(/(?:^|[\s(,;])(--[a-z][a-z0-9-]*)/g)) note(m[1], idx + 1);
  });
  if (!hasFlags) continue;
  const missing = [...mentioned].filter(([f]) => !table.has(f));
  if (missing.length) warnings.push(`skills/${self}/SKILL.md: flags de Invocation/Multi-Agent sin fila en "### Flags": ${missing.map(([f, n]) => `${f} (l.${n})`).join(", ")}`);
}

// 9. Comandos de un stack concreto en skills/** (deben salir del Stack Profile)
// Exentos: la referencia del perfil y las líneas marcadas como ejemplo — la línea contiene "e.g.", "example"
// o "ejemplo", o está dentro de un bloque ``` cuya línea de apertura dice "example" (```bash example) o va
// precedido de <!-- example -->. Un bloque ``` o una tabla markdown precedidos de <!-- stack-specific … --> también
// están exentos: son tablas de detección que nombran a propósito el comando de cada stack detectado (sdd-setup).
const HARDCODED_RE = /npx vitest|npm run |wrangler |npm init playwright/g;
const EXAMPLE_RE = /e\.g\.|example|ejemplo/i;
const BLOCK_MARK_RE = /<!--\s*(example|stack-specific)\b[^>]*-->/i;
const HARDCODED_ALLOW = new Set(["skills/sdd-task-implementer/references/stack-profile.md"]);
const TEXT_EXT = new Set([".md", ".py", ".js", ".mjs", ".cjs", ".ts", ".sh", ".json", ".yml", ".yaml", ".txt"]);
for (const file of walk(skillsDir)) {
  const r = rel(file);
  if (HARDCODED_ALLOW.has(r) || !TEXT_EXT.has(path.extname(file))) continue;
  const lines = readFileSync(file, "utf8").split("\n");
  let fence = false, fenceExample = false, table = false, tableExempt = false, prev = "";
  const hits = [];
  const tokens = new Map();
  lines.forEach((line, idx) => {
    const f = line.match(/^\s*(```|~~~)(.*)$/);
    if (f) {
      if (!fence) fenceExample = EXAMPLE_RE.test(f[2]) || BLOCK_MARK_RE.test(prev);
      fence = !fence;
    } else {
      const isRow = !fence && /^\s*\|/.test(line);
      if (isRow && !table) tableExempt = BLOCK_MARK_RE.test(prev);
      table = isRow;
      const found = line.match(HARDCODED_RE);
      if (found && !EXAMPLE_RE.test(line) && !(fence && fenceExample) && !(table && tableExempt)) {
        hits.push(idx + 1);
        for (const t of found) tokens.set(t.trim(), (tokens.get(t.trim()) ?? 0) + 1);
      }
    }
    if (line.trim()) prev = line;
  });
  if (hits.length) {
    const lineList = hits.slice(0, 8).join(", ") + (hits.length > 8 ? ", …" : "");
    warnings.push(`${r}: hardcoded stack (${[...tokens].map(([t, n]) => `${t} ×${n}`).join(", ")}) en líneas ${lineList} — léelo del Stack Profile o márcalo como ejemplo`);
  }
}

// 10. Tamaño de SKILL.md
const SKILL_MAX = 62000;
for (const self of skillNames) {
  const size = readFileSync(path.join(skillsDir, self, "SKILL.md"), "utf8").length;
  if (size > SKILL_MAX) warnings.push(`skills/${self}/SKILL.md: ${size} chars (> ${SKILL_MAX}; muévelo a references/)`);
}

// 11. Commit templates in skills/** and references/**: trailers go through `git commit --trailer`
// (git ≥ 2.32 builds a valid trailer block; a trailer typed in a heredoc or -m body is lost after any prose or blank
// line) and only the SDD vocabulary is used. A fenced block counts as a commit template when it contains `git commit`.
const TRAILER_KEYS = new Set(["task", "refs", "change", "co-authored-by", "signed-off-by"]);
const docFiles = [...walk(skillsDir), ...(existsSync(path.join(ROOT, "references")) ? walk(path.join(ROOT, "references")) : [])]
  .filter((f) => f.endsWith(".md"));
for (const file of docFiles) {
  const lines = readFileSync(file, "utf8").split("\n");
  let start = -1;
  const blocks = [];
  lines.forEach((l, i) => {
    if (!/^\s*(```|~~~)/.test(l)) return;
    if (start < 0) start = i; else { blocks.push([start, i]); start = -1; }
  });
  for (const [a, b] of blocks) {
    const body = lines.slice(a + 1, b);
    const text = body.join("\n");
    if (!/\bgit commit\b/.test(text)) continue;
    const where = `${rel(file)}:${a + 1}`;
    const handTyped = body.findIndex((l) => /^\s*(Task|Refs|Change)\s*:/i.test(l));
    if (handTyped >= 0 && !/--trailer\b/.test(text)) {
      errors.push(`${where}: commit template writes \`${body[handTyped].trim()}\` in the message body — use git commit --trailer (references/git-conventions.md)`);
    }
    const keys = [...text.matchAll(/--trailer[= ]+["']?([A-Za-z][A-Za-z-]*)\s*[:=]/g)].map((m) => m[1]);
    for (const k of new Set(keys)) if (!TRAILER_KEYS.has(k.toLowerCase())) errors.push(`${where}: trailer \`${k}\` is not part of the SDD vocabulary (Task, Refs, Change, Co-Authored-By, Signed-off-by)`);
  }
}

// 12. Stage skills that write artifacts commit them (references/git-conventions.md § Stage outputs are committed).
const STAGE_WRITERS = ["sdd-requirements-engineer", "sdd-specifications-engineer", "sdd-spec-auditor", "sdd-test-planner",
  "sdd-plan-architect", "sdd-task-generator", "sdd-tech-designer", "sdd-ux-designer", "sdd-security-auditor",
  "sdd-gap-detector", "sdd-req-change", "sdd-reverse-engineer", "sdd-import", "sdd-reconcile", "sdd-acceptance"];
for (const s of STAGE_WRITERS) {
  const f = path.join(skillsDir, s, "SKILL.md");
  if (existsSync(f) && !readFileSync(f, "utf8").includes("Stage outputs are committed")) {
    warnings.push(`skills/${s}/SKILL.md: no remite a "Stage outputs are committed" (references/git-conventions.md) en su paso Persist`);
  }
}

for (const w of warnings) console.log(`WARN  ${w}`);
for (const e of errors) console.log(`ERROR ${e}`);
if (errors.length) { console.log(`${errors.length} errores`); process.exit(1); }
console.log("validate-plugin: ok");
