import type { GraphIndex, TraceabilityGraph } from "../graph-loader.js";
import { getNextStepHint } from "../hints.js";

export const CONTEXT_TOOL = {
  name: "sdd_context",
  description:
    "Get a 360-degree view of an artifact: its definition, all upstream/downstream connections, code references, test references, commit references, and coverage gaps. Essential before modifying any artifact.",
  inputSchema: {
    type: "object" as const,
    properties: {
      artifact_id: {
        type: "string",
        description: "The artifact ID (e.g. REQ-AUTH-001, UC-003, TASK-F01-003)",
      },
    },
    required: ["artifact_id"],
  },
};

interface ContextArgs {
  artifact_id: string;
}

export function executeContext(
  args: ContextArgs,
  graph: TraceabilityGraph,
  index: GraphIndex
): string {
  const { artifact_id } = args;

  const artifact = index.byId.get(artifact_id);
  if (!artifact) {
    return JSON.stringify({
      error: `Artifact "${artifact_id}" not found`,
      hint: `Use sdd_query to search for the correct ID.`,
    });
  }

  // Upstream: relationships where this artifact is the source
  const upstreamRels = index.relBySource.get(artifact_id) ?? [];
  const upstream = upstreamRels.map((rel) => {
    const target = index.byId.get(rel.target);
    return {
      id: rel.target,
      type: target?.type ?? "unknown",
      title: target?.title ?? "unknown",
      relationship: rel.type,
      file: rel.sourceFile,
    };
  });

  // Downstream: relationships where this artifact is the target
  const downstreamRels = index.relByTarget.get(artifact_id) ?? [];
  const downstream = downstreamRels.map((rel) => {
    const source = index.byId.get(rel.source);
    return {
      id: rel.source,
      type: source?.type ?? "unknown",
      title: source?.title ?? "unknown",
      relationship: rel.type,
      file: rel.sourceFile,
    };
  });

  // Gaps analysis
  const gaps: string[] = [];
  if (artifact.type === "REQ") {
    if (upstream.length === 0 && downstream.length === 0) {
      gaps.push("ORPHAN: No relationships found — this REQ is isolated");
    }
    const hasUC = downstream.some((d) => d.type === "UC");
    const hasBDD = downstream.some((d) => d.type === "BDD");
    const hasTask = downstream.some((d) => d.type === "TASK");
    if (!hasUC) gaps.push("MISSING_UC: No use case implements this requirement");
    if (!hasBDD) gaps.push("MISSING_BDD: No BDD scenario verifies this requirement");
    if (!hasTask) gaps.push("MISSING_TASK: No task decomposes this requirement");
    if ((artifact.codeRefs?.length ?? 0) === 0)
      gaps.push("MISSING_CODE: No code references found");
    if ((artifact.testRefs?.length ?? 0) === 0)
      gaps.push("MISSING_TESTS: No test references found");
    if ((artifact.commitRefs?.length ?? 0) === 0)
      gaps.push("MISSING_COMMITS: No commit references found");
  }

  // Determine coverage status
  const codeCount = artifact.codeRefs?.length ?? 0;
  const testCount = artifact.testRefs?.length ?? 0;
  const commitCount = artifact.commitRefs?.length ?? 0;
  const hasUCLink = downstream.some((d) => d.type === "UC") || upstream.some((u) => u.type === "UC");
  const hasBDDLink = downstream.some((d) => d.type === "BDD") || upstream.some((u) => u.type === "BDD");

  let coverageStatus: string;
  if (hasUCLink && hasBDDLink && codeCount > 0 && testCount > 0)
    coverageStatus = "Complete";
  else if (hasUCLink && (codeCount > 0 || testCount > 0))
    coverageStatus = "In Progress";
  else if (hasUCLink) coverageStatus = "Specified";
  else coverageStatus = "Not Started";

  // Code intelligence enrichment
  let codeIntel: Record<string, unknown> | undefined;
  if (graph.codeIntelligence?.indexed) {
    const ci = graph.codeIntelligence;
    const symbols = ci.symbols.filter(
      (s) =>
        s.artifactRefs.includes(artifact_id) ||
        s.inferredRefs.includes(artifact_id)
    );
    if (symbols.length > 0) {
      const processes = ci.processes.filter((p) =>
        p.artifactRefs.includes(artifact_id)
      );
      codeIntel = {
        symbols: symbols.map((s) => ({
          name: s.name,
          type: s.type,
          file: s.filePath,
          lines: `${s.startLine}-${s.endLine}`,
          callers: s.callers,
          callees: s.callees,
          isInferred: s.inferredRefs.includes(artifact_id),
        })),
        processes: processes.map((p) => ({
          name: p.name,
          steps: p.steps,
          entryPoint: p.entryPoint,
        })),
      };
    }
  }

  const output = {
    artifact: {
      id: artifact.id,
      type: artifact.type,
      category: artifact.category,
      title: artifact.title,
      file: artifact.file,
      line: artifact.line,
      priority: artifact.priority,
      stage: artifact.stage,
      classification: artifact.classification,
    },
    coverageStatus,
    upstream,
    downstream,
    codeRefs: artifact.codeRefs ?? [],
    testRefs: artifact.testRefs ?? [],
    commitRefs: artifact.commitRefs ?? [],
    gaps,
    ...(codeIntel ? { codeIntelligence: codeIntel } : {}),
  };

  return JSON.stringify(output) + getNextStepHint("sdd_context", args);
}
