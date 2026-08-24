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
for (const f of readdirSync(agentsDir).filter((f) => f.endsWith(".md"))) {
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
    const m = h.command?.match(/\$\{CLAUDE_PLUGIN_ROOT\}\/(\S+)/);
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
    const m = arg.match(/\$\{CLAUDE_PLUGIN_ROOT\}\/(\S+)/);
    if (m && !existsSync(path.join(ROOT, m[1]))) errors.push(`.mcp.json ${name}: no existe ${m[1]} (¿npm run build?)`);
  }
}

// 6. Resumen
console.log(`plugin ${plugin.name}@${plugin.version}: ${skillCount} skills, ${agentCount} agentes, ${hookCount} hooks, ${Object.keys(mcp.mcpServers ?? {}).length} MCP`);
for (const w of warnings) console.log(`WARN  ${w}`);
for (const e of errors) console.log(`ERROR ${e}`);
if (errors.length) { console.log(`${errors.length} errores`); process.exit(1); }
console.log("validate-plugin: ok");
