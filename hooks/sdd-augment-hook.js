#!/usr/bin/env node

/**
 * SDD Context Augment Hook — PreToolUse
 *
 * Intercepts Grep/Glob/Read/Edit/Write calls and injects SDD traceability
 * context as additionalContext. Pattern adapted from GitNexus.
 *
 * Input (stdin): JSON with { hook_event_name, tool_name, tool_input, cwd }
 * Output (stdout): JSON with { hookSpecificOutput: { hookEventName: "PreToolUse", additionalContext: string } }
 *
 * Behavior:
 *  - Silently no-ops on any error (never breaks the tool call)
 *  - Caches the graph in memory for the process lifetime
 *  - Searches up to 5 parent directories for dashboard/traceability-graph.json
 */

const fs = require("fs");
const path = require("path");

// ---------------------------------------------------------------------------
// Graph loading (simplified — mirrors graph-loader.ts logic)
// ---------------------------------------------------------------------------

let cachedGraph = null;
let cachedIndex = null;
// Project root (parent of dashboard/) and app_dir from the SDD Stack Profile, set by loadGraph
let profileCtx = { root: "", appDir: "" };

// ---------------------------------------------------------------------------
// SDD Stack Profile (CLAUDE.md "## SDD Stack Profile", `- key: value` lines)
// Same contract as sdd_profile_get in hooks/lib/sdd-common.sh; no dependencies.
// ---------------------------------------------------------------------------

function readProfileKey(root, key) {
  for (const rel of ["CLAUDE.md", path.join(".claude", "CLAUDE.md")]) {
    let text;
    try {
      text = fs.readFileSync(path.join(root, rel), "utf-8");
    } catch {
      continue;
    }
    let inSection = false;
    let found = false;
    let fence = false;
    for (const raw of text.split("\n")) {
      const line = raw.replace(/\r$/, "");
      if (/^[ \t]*```/.test(line)) { fence = !fence; continue; }
      if (fence) continue;
      if (/^## /.test(line)) {
        if (inSection) break;
        if (line.replace(/[ \t]+$/, "") === "## SDD Stack Profile") inSection = found = true;
        continue;
      }
      if (!inSection) continue;
      const m = line.match(/^[ \t]*-[ \t]+([^:]*):(.*)$/);
      if (m && m[1].trim().toLowerCase() === key) return m[2].trim();
    }
    if (found) return "";
  }
  return "";
}

function normAppDir(v) {
  const d = (v || "").replace(/\\/g, "/").replace(/^\.\//, "").replace(/\/+$/, "");
  return d === "." ? "" : d;
}

// Repo-relative key without the app_dir/ prefix: /root/web/app/x.rb, web/app/x.rb and app/x.rb
// (app_dir web) all become app/x.rb. Absolute paths outside the root stay absolute.
function projectKey(p) {
  if (!p) return "";
  let k = p.replace(/\\/g, "/");
  if (profileCtx.root) {
    const r = profileCtx.root.replace(/\\/g, "/").replace(/\/+$/, "") + "/";
    if (k.startsWith(r)) k = k.slice(r.length);
  }
  k = k.replace(/^\.\//, "");
  const app = profileCtx.appDir;
  if (app && k.startsWith(app + "/")) k = k.slice(app.length + 1);
  return k;
}

function findGraphFile(startDir) {
  let dir = startDir;
  for (let i = 0; i < 6; i++) {
    const candidate = path.join(dir, "dashboard", "traceability-graph.json");
    if (fs.existsSync(candidate)) return candidate;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

function loadGraph(cwd) {
  if (cachedGraph && cachedIndex) return { graph: cachedGraph, index: cachedIndex };

  const graphPath = findGraphFile(cwd);
  if (!graphPath) return null;

  try {
    const raw = fs.readFileSync(graphPath, "utf-8");
    const graph = JSON.parse(raw);

    // Build indexes
    const byId = new Map();
    const codeRefsByFile = new Map();
    const relBySource = new Map();
    const relByTarget = new Map();

    for (const art of graph.artifacts || []) {
      byId.set(art.id, art);
      if (!art || typeof art !== "object" || !art.id) continue;
      for (const cr of art.codeRefs || []) {
        // codeRefs without a usable `file` (older/partial graphs) are skipped, not fatal
        if (!cr || typeof cr.file !== "string") continue;
        const norm = cr.file.replace(/\\/g, "/").replace(/^\.\//, "").trim();
        if (!norm) continue;
        if (!codeRefsByFile.has(norm)) codeRefsByFile.set(norm, []);
        codeRefsByFile.get(norm).push({ artifact: art, ref: cr });
      }
    }

    for (const rel of graph.relationships || []) {
      if (!rel || !rel.source || !rel.target) continue;
      if (!relBySource.has(rel.source)) relBySource.set(rel.source, []);
      relBySource.get(rel.source).push(rel);
      if (!relByTarget.has(rel.target)) relByTarget.set(rel.target, []);
      relByTarget.get(rel.target).push(rel);
    }

    const root = path.dirname(path.dirname(graphPath));
    profileCtx = { root, appDir: normAppDir(readProfileKey(root, "app_dir")) };

    cachedGraph = graph;
    cachedIndex = { byId, codeRefsByFile, relBySource, relByTarget };
    return { graph, index: cachedIndex };
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Extract search pattern from tool input
// ---------------------------------------------------------------------------

function extractSearchPattern(toolName, toolInput) {
  if (!toolInput) return null;

  switch (toolName) {
    case "Grep":
      return toolInput.pattern || null;
    case "Glob":
      return toolInput.pattern || null;
    case "Read":
    case "Edit":
    case "Write":
      return toolInput.file_path || null;
    case "Bash": {
      // Extract file paths or patterns from common commands
      const cmd = toolInput.command || "";
      const fileMatch = cmd.match(/(?:cat|less|head|tail|grep|rg)\s+(?:[^\s]+\s+)*([^\s|>]+)/);
      return fileMatch ? fileMatch[1] : null;
    }
    default:
      return null;
  }
}

// ---------------------------------------------------------------------------
// Build traceability chain string for an artifact
// ---------------------------------------------------------------------------

function buildChainString(artifactId, index) {
  const chain = [artifactId];
  const visited = new Set([artifactId]);

  // Walk upstream (source -> target)
  let current = artifactId;
  for (let i = 0; i < 10; i++) {
    const rels = index.relBySource.get(current) || [];
    const next = rels.find((r) => !visited.has(r.target));
    if (!next) break;
    visited.add(next.target);
    chain.push(next.target);
    current = next.target;
  }

  // Walk downstream (target -> source)
  current = artifactId;
  for (let i = 0; i < 10; i++) {
    const rels = index.relByTarget.get(current) || [];
    const next = rels.find((r) => !visited.has(r.source));
    if (!next) break;
    visited.add(next.source);
    chain.unshift(next.source);
    current = next.source;
  }

  return chain.join(" -> ");
}

// ---------------------------------------------------------------------------
// Determine coverage status
// ---------------------------------------------------------------------------

function getCoverageStatus(art, index) {
  const downstream = index.relByTarget.get(art.id) || [];
  const hasUC = downstream.some((r) => {
    const a = index.byId.get(r.source);
    return a && a.type === "UC";
  });
  const hasBDD = downstream.some((r) => {
    const a = index.byId.get(r.source);
    return a && a.type === "BDD";
  });
  const hasCode = (art.codeRefs || []).length > 0;
  const hasTests = (art.testRefs || []).length > 0;

  if (hasUC && hasBDD && hasCode && hasTests) return "Complete";
  if (hasUC && (hasCode || hasTests)) return "In Progress";
  if (hasUC) return "Specified";
  return "Not Started";
}

// ---------------------------------------------------------------------------
// Match file path against graph
// ---------------------------------------------------------------------------

// Does the tool path/pattern `norm` refer to the graph code ref `file` (repo-relative)?
// Whole path segments only: a basename-only ref (`index.ts`) matches just the file at the repo root,
// never every `index.ts`; a pattern naming a directory (`src/auth`) matches the refs below it.
function pathMatches(norm, file) {
  if (!norm || !file) return false;
  const key = projectKey(norm).replace(/\/+$/, "");
  const fk = projectKey(file);
  if (!fk) return false;
  if (key === fk) return true;
  if (!key.startsWith("/")) {
    // Relative to the project (or an absolute path under its root): exact file or a directory above it
    return key.includes("/") && !/[*?[\]{}]/.test(key) && fk.startsWith(key + "/");
  }
  // Absolute path outside the known root (no graph root match): whole trailing segments only
  return fk.includes("/") && key.endsWith("/" + fk);
}

function matchByFile(filePath, index) {
  if (!filePath) return [];

  const norm = filePath.replace(/\\/g, "/");
  const results = [];

  // Direct code ref match
  for (const [file, refs] of index.codeRefsByFile) {
    if (pathMatches(norm, file)) {
      for (const { artifact, ref } of refs) {
        results.push({ artifact, ref, matchType: "codeRef" });
      }
    }
  }

  return results;
}

// ---------------------------------------------------------------------------
// Match artifact IDs in search pattern
// ---------------------------------------------------------------------------

function matchByArtifactId(pattern, index) {
  if (!pattern) return [];

  // Common artifact ID patterns
  const idPatterns = [
    /\b(REQ-[A-Z]+-\d+)\b/g,
    /\b(UC-\d+)\b/g,
    /\b(WF-\d+)\b/g,
    /\b(API-\d+)\b/g,
    /\b(BDD-\d+)\b/g,
    /\b(INV-[A-Z]+-\d+)\b/g,
    /\b(ADR-\d+)\b/g,
    /\b(TASK-F\d+-\d+)\b/g,
  ];

  const results = [];
  for (const regex of idPatterns) {
    let match;
    while ((match = regex.exec(pattern)) !== null) {
      const art = index.byId.get(match[1]);
      if (art) results.push({ artifact: art, matchType: "artifactId" });
    }
  }
  return results;
}

// ---------------------------------------------------------------------------
// Format context output
// ---------------------------------------------------------------------------

function formatContext(matches, index) {
  if (matches.length === 0) return null;

  // Deduplicate by artifact ID; at most MAX_PER_FILE artifacts per code file (a hot file linked to
  // dozens of requirements must not flood the context of every Read/Edit)
  const MAX_PER_FILE = 2;
  const seen = new Set();
  const perFile = new Map();
  const unique = [];
  let dropped = 0;
  for (const m of matches) {
    if (seen.has(m.artifact.id)) continue;
    seen.add(m.artifact.id);
    if (m.ref) {
      const n = perFile.get(m.ref.file) || 0;
      if (n >= MAX_PER_FILE) { dropped++; continue; }
      perFile.set(m.ref.file, n + 1);
    }
    unique.push(m);
  }

  const lines = ["SDD Traceability Context:"];

  for (const m of unique.slice(0, 5)) {
    const art = m.artifact;
    const chain = buildChainString(art.id, index);
    const coverage = getCoverageStatus(art, index);

    if (m.ref) {
      const sym = m.ref.symbol ? `:${m.ref.symbol}()` : "";
      lines.push(`  ${m.ref.file}${sym} implements ${art.id} (${art.title || ""})`);
    } else {
      lines.push(`  ${art.id}: ${art.title || ""}`);
    }
    lines.push(`  Chain: ${chain}`);
    lines.push(`  Coverage: ${coverage}`);

    // Last commit
    if (art.commitRefs && art.commitRefs.length > 0) {
      const last = art.commitRefs[art.commitRefs.length - 1];
      if (last && last.sha) {
        lines.push(`  Last commit: ${last.sha} (${last.date ? String(last.date).split("T")[0] : "unknown"})`);
      }
    }

    lines.push("");
  }

  const more = Math.max(unique.length - 5, 0) + dropped;
  if (more > 0) {
    lines.push(`  ... and ${more} more artifacts`);
  }

  return lines.join("\n");
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main() {
  let input = "";
  for await (const chunk of process.stdin) {
    input += chunk;
  }

  try {
    const data = JSON.parse(input);
    const { tool_name, tool_input, cwd } = data;

    const loaded = loadGraph(cwd || process.cwd());
    if (!loaded) {
      // No graph file — silent no-op
      process.stdout.write(JSON.stringify({}));
      return;
    }

    const { index } = loaded;
    const pattern = extractSearchPattern(tool_name, tool_input);
    if (!pattern) {
      process.stdout.write(JSON.stringify({}));
      return;
    }

    // Collect matches from multiple strategies
    const matches = [
      ...matchByFile(pattern, index),
      ...matchByArtifactId(pattern, index),
    ];

    const context = formatContext(matches, index);
    if (!context) {
      process.stdout.write(JSON.stringify({}));
      return;
    }

    process.stdout.write(
      JSON.stringify({
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          additionalContext: context,
        },
      })
    );
  } catch {
    // Silent failure — never break the tool call
    process.stdout.write(JSON.stringify({}));
  }
}

main();
