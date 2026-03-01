import type { TraceabilityGraph, GraphIndex } from "./graph-loader.js";

/**
 * Resource URI handlers for sdd:// protocol.
 * Each handler returns { contents: [{ uri, mimeType, text }] }.
 */

export function listResources() {
  return {
    resources: [
      {
        uri: "sdd://pipeline/status",
        name: "Pipeline Status",
        description: "Current pipeline stage, staleness, and next recommended action",
        mimeType: "application/json",
      },
      {
        uri: "sdd://pipeline/stages",
        name: "Pipeline Stages",
        description: "All 7 pipeline stages with status and timestamps",
        mimeType: "application/json",
      },
      {
        uri: "sdd://graph/schema",
        name: "Graph Schema",
        description: "Documentation of the traceability graph schema (v3)",
        mimeType: "text/plain",
      },
      {
        uri: "sdd://graph/stats",
        name: "Graph Statistics",
        description: "Artifact counts, coverage percentages, and classification breakdown",
        mimeType: "application/json",
      },
      {
        uri: "sdd://coverage/gaps",
        name: "Coverage Gaps",
        description: "Top traceability gaps ordered by severity",
        mimeType: "application/json",
      },
    ],
  };
}

export function listResourceTemplates() {
  return {
    resourceTemplates: [
      {
        uriTemplate: "sdd://artifacts/{type}",
        name: "Artifacts by Type",
        description: "List artifacts of a given type (REQ, UC, WF, API, BDD, INV, ADR, NFR, RN, FASE, TASK)",
        mimeType: "application/json",
      },
      {
        uriTemplate: "sdd://artifacts/{type}/{id}",
        name: "Artifact Detail",
        description: "Full detail of a specific artifact including all relationships",
        mimeType: "application/json",
      },
    ],
  };
}

export function readResource(
  uri: string,
  graph: TraceabilityGraph,
  index: GraphIndex
): { contents: Array<{ uri: string; mimeType: string; text: string }> } {
  // sdd://pipeline/status
  if (uri === "sdd://pipeline/status") {
    const currentStage = graph.pipeline.currentStage;
    const stages = graph.pipeline.stages;
    const current = stages.find((s) => s.name === currentStage);
    const staleStages = stages.filter((s) => s.status === "stale");
    const doneStages = stages.filter((s) => s.status === "done");

    // Determine next action
    let nextAction = "Run /sdd:requirements-engineer to start the pipeline";
    const pendingStage = stages.find((s) => s.status === "pending" || s.status === "running");
    if (pendingStage) {
      nextAction = `Continue with /sdd:${pendingStage.name}`;
    }
    if (staleStages.length > 0) {
      nextAction = `Re-run /sdd:${staleStages[0].name} (stale)`;
    }

    return {
      contents: [
        {
          uri,
          mimeType: "application/json",
          text: JSON.stringify({
            currentStage,
            currentStatus: current?.status ?? "unknown",
            lastRun: current?.lastRun ?? null,
            progress: `${doneStages.length}/${stages.length} stages complete`,
            staleStages: staleStages.map((s) => s.name),
            nextAction,
            generatedAt: graph.generatedAt,
          }),
        },
      ],
    };
  }

  // sdd://pipeline/stages
  if (uri === "sdd://pipeline/stages") {
    return {
      contents: [
        {
          uri,
          mimeType: "application/json",
          text: JSON.stringify(graph.pipeline),
        },
      ],
    };
  }

  // sdd://graph/schema
  if (uri === "sdd://graph/schema") {
    return {
      contents: [
        {
          uri,
          mimeType: "text/plain",
          text: [
            "SDD Traceability Graph Schema v3",
            "",
            "Root: { $schema, generatedAt, projectName, pipeline, artifacts[], relationships[], statistics, adoption?, codeIntelligence? }",
            "",
            "Artifact types: REQ, UC, WF, API, BDD, INV, ADR, NFR, RN, FASE, TASK",
            "Relationship types: implements, orchestrates, verifies, guarantees, decides, decomposes, implemented-by, implemented-by-code, tested-by, implemented-by-commit, reads-from, traces-to",
            "",
            "Each artifact has: id, type, category, title, file, line, priority, stage, classification?, codeRefs[], testRefs[], commitRefs[]",
            "",
            "codeIntelligence (optional, from /sdd:code-index): symbols[], callGraph[], processes[], stats",
            "",
            "Full schema: see skills/dashboard/references/graph-schema.md",
          ].join("\n"),
        },
      ],
    };
  }

  // sdd://graph/stats
  if (uri === "sdd://graph/stats") {
    return {
      contents: [
        {
          uri,
          mimeType: "application/json",
          text: JSON.stringify(graph.statistics),
        },
      ],
    };
  }

  // sdd://coverage/gaps
  if (uri === "sdd://coverage/gaps") {
    const reqs = index.byType.get("REQ") ?? [];
    const gaps: Array<{
      id: string;
      title: string;
      severity: string;
      missing: string[];
    }> = [];

    for (const req of reqs) {
      const downstream = index.relByTarget.get(req.id) ?? [];
      const hasUC = downstream.some((r) => index.byId.get(r.source)?.type === "UC");
      const hasBDD = downstream.some((r) => index.byId.get(r.source)?.type === "BDD");
      const hasCode = (req.codeRefs?.length ?? 0) > 0;
      const hasTests = (req.testRefs?.length ?? 0) > 0;

      const missing: string[] = [];
      if (!hasUC) missing.push("UC");
      if (!hasBDD) missing.push("BDD");
      if (!hasCode) missing.push("Code");
      if (!hasTests) missing.push("Tests");

      if (missing.length > 0) {
        let severity: string;
        if (missing.length >= 4) severity = "CRITICAL";
        else if (missing.length >= 3) severity = "HIGH";
        else if (missing.length >= 2) severity = "MEDIUM";
        else severity = "LOW";

        gaps.push({ id: req.id, title: req.title, severity, missing });
      }
    }

    gaps.sort((a, b) => {
      const order = { CRITICAL: 0, HIGH: 1, MEDIUM: 2, LOW: 3 };
      return (
        (order[a.severity as keyof typeof order] ?? 4) -
        (order[b.severity as keyof typeof order] ?? 4)
      );
    });

    return {
      contents: [
        {
          uri,
          mimeType: "application/json",
          text: JSON.stringify({
            totalGaps: gaps.length,
            bySeverity: {
              critical: gaps.filter((g) => g.severity === "CRITICAL").length,
              high: gaps.filter((g) => g.severity === "HIGH").length,
              medium: gaps.filter((g) => g.severity === "MEDIUM").length,
              low: gaps.filter((g) => g.severity === "LOW").length,
            },
            gaps: gaps.slice(0, 30),
          }),
        },
      ],
    };
  }

  // sdd://artifacts/{type}
  const typeMatch = uri.match(/^sdd:\/\/artifacts\/([A-Z]+)$/);
  if (typeMatch) {
    const type = typeMatch[1];
    const artifacts = index.byType.get(type) ?? [];
    return {
      contents: [
        {
          uri,
          mimeType: "application/json",
          text: JSON.stringify({
            type,
            count: artifacts.length,
            artifacts: artifacts.map((a) => ({
              id: a.id,
              title: a.title,
              file: a.file,
              category: a.category,
              hasCode: (a.codeRefs?.length ?? 0) > 0,
              hasTests: (a.testRefs?.length ?? 0) > 0,
            })),
          }),
        },
      ],
    };
  }

  // sdd://artifacts/{type}/{id}
  const detailMatch = uri.match(/^sdd:\/\/artifacts\/([A-Z]+)\/(.+)$/);
  if (detailMatch) {
    const id = detailMatch[2];
    const artifact = index.byId.get(id);
    if (!artifact) {
      return {
        contents: [
          { uri, mimeType: "application/json", text: JSON.stringify({ error: `Artifact ${id} not found` }) },
        ],
      };
    }

    const upstream = (index.relBySource.get(id) ?? []).map((r) => ({
      target: r.target,
      type: r.type,
    }));
    const downstream = (index.relByTarget.get(id) ?? []).map((r) => ({
      source: r.source,
      type: r.type,
    }));

    return {
      contents: [
        {
          uri,
          mimeType: "application/json",
          text: JSON.stringify({
            ...artifact,
            upstream,
            downstream,
          }),
        },
      ],
    };
  }

  return {
    contents: [
      {
        uri,
        mimeType: "application/json",
        text: JSON.stringify({ error: `Unknown resource URI: ${uri}` }),
      },
    ],
  };
}
