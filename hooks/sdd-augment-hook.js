#!/usr/bin/env node

/**
 * SDD Context Augment Hook — PreToolUse
 *
 * Intercepts Grep/Glob/Read/Edit/Write calls and injects SDD traceability
 * context as additionalContext. Pattern adapted from GitNexus.
 *
 * Input (stdin): JSON with { hook_event_name, tool_name, tool_input, cwd }
 * Output (stdout): JSON with { hookSpecificOutput: { additionalContext: string } }
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
      for (const cr of art.codeRefs || []) {
        const norm = cr.file.replace(/\\/g, "/");
        if (!codeRefsByFile.has(norm)) codeRefsByFile.set(norm, []);
        codeRefsByFile.get(norm).push({ artifact: art, ref: cr });
      }
    }

    for (const rel of graph.relationships || []) {
      if (!relBySource.has(rel.source)) relBySource.set(rel.source, []);
      relBySource.get(rel.source).push(rel);
      if (!relByTarget.has(rel.target)) relByTarget.set(rel.target, []);
      relByTarget.get(rel.target).push(rel);
    }

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

function matchByFile(filePath, index) {
  if (!filePath) return [];

  const norm = filePath.replace(/\\/g, "/");
  const results = [];

  // Direct code ref match
  for (const [file, refs] of index.codeRefsByFile) {
    if (norm.includes(file) || file.includes(norm.replace(/^.*?src\//, "src/"))) {
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
// Code Intelligence helpers (Fase 5: merged SDD + GitNexus context)
// ---------------------------------------------------------------------------

function findSymbolsForFile(filePath, codeIntel) {
  if (!codeIntel || !codeIntel.symbols) return [];
  const norm = filePath.replace(/\\/g, "/");
  return codeIntel.symbols.filter(
    (s) => norm.includes(s.filePath) || s.filePath.includes(norm.replace(/^.*?src\//, "src/"))
  );
}

function findSymbolsForArtifact(artifactId, codeIntel) {
  if (!codeIntel || !codeIntel.symbols) return [];
  return codeIntel.symbols.filter(
    (s) =>
      (s.artifactRefs || []).includes(artifactId) ||
      (s.inferredRefs || []).includes(artifactId)
  );
}

function findProcessesForArtifact(artifactId, codeIntel) {
  if (!codeIntel || !codeIntel.processes) return [];
  return codeIntel.processes.filter((p) =>
    (p.artifactRefs || []).includes(artifactId)
  );
}

// ---------------------------------------------------------------------------
// Format context output (with optional code intelligence)
// ---------------------------------------------------------------------------

function formatContext(matches, index, codeIntel) {
  if (matches.length === 0) return null;

  // Deduplicate by artifact ID
  const seen = new Set();
  const unique = [];
  for (const m of matches) {
    if (!seen.has(m.artifact.id)) {
      seen.add(m.artifact.id);
      unique.push(m);
    }
  }

  const lines = ["SDD Traceability Context:"];

  for (const m of unique.slice(0, 5)) {
    const art = m.artifact;
    const chain = buildChainString(art.id, index);
    const coverage = getCoverageStatus(art, index);

    if (m.ref) {
      lines.push(
        `  ${m.ref.file}:${m.ref.symbol}() implements ${art.id} (${art.title})`
      );
    } else {
      lines.push(`  ${art.id}: ${art.title}`);
    }
    lines.push(`  Chain: ${chain}`);
    lines.push(`  Coverage: ${coverage}`);

    // Last commit
    if (art.commitRefs && art.commitRefs.length > 0) {
      const last = art.commitRefs[art.commitRefs.length - 1];
      lines.push(`  Last commit: ${last.sha} (${last.date ? last.date.split("T")[0] : "unknown"})`);
    }

    // Code Intelligence (when codeIntelligence block is available)
    if (codeIntel && codeIntel.indexed) {
      const symbols = findSymbolsForArtifact(art.id, codeIntel);
      if (symbols.length > 0) {
        lines.push("  Code Intelligence:");
        for (const sym of symbols.slice(0, 3)) {
          const callersStr = (sym.callers || []).slice(0, 3).join(", ");
          const calleesStr = (sym.callees || []).slice(0, 3).join(", ");
          lines.push(`    ${sym.name}() [${sym.type}] @ ${sym.filePath}:${sym.startLine}`);
          if (callersStr) lines.push(`    Called by: ${callersStr}`);
          if (calleesStr) lines.push(`    Calls: ${calleesStr}`);
        }

        const processes = findProcessesForArtifact(art.id, codeIntel);
        if (processes.length > 0) {
          const procNames = processes.map((p) => p.name).join(", ");
          lines.push(`    Flows: ${procNames}`);
        }

        if (symbols.length > 3) {
          lines.push(`    ... and ${symbols.length - 3} more symbols`);
        }
      }
    }

    lines.push("");
  }

  // File-level code intelligence (when searching by file path)
  if (codeIntel && codeIntel.indexed && unique.length > 0) {
    const filePatterns = unique
      .filter((m) => m.ref)
      .map((m) => m.ref.file);

    if (filePatterns.length > 0) {
      const fileSymbols = findSymbolsForFile(filePatterns[0], codeIntel);
      const uncoveredInFile = fileSymbols.filter(
        (s) => (s.artifactRefs || []).length === 0 && (s.inferredRefs || []).length === 0
      );
      if (uncoveredInFile.length > 0) {
        lines.push(`  Uncovered symbols in file: ${uncoveredInFile.map((s) => s.name).slice(0, 5).join(", ")}`);
      }
    }
  }

  if (unique.length > 5) {
    lines.push(`  ... and ${unique.length - 5} more artifacts`);
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

    const { graph, index } = loaded;
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

    // Pass code intelligence data if available (Fase 5: merged context)
    const codeIntel = graph.codeIntelligence || null;
    const context = formatContext(matches, index, codeIntel);
    if (!context) {
      process.stdout.write(JSON.stringify({}));
      return;
    }

    process.stdout.write(
      JSON.stringify({
        hookSpecificOutput: {
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
