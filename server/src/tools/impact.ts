import type { GraphIndex, TraceabilityGraph } from "../graph-loader.js";
import { getNextStepHint } from "../hints.js";

export const IMPACT_TOOL = {
  name: "sdd_impact",
  description:
    "Analyze blast radius of changing an artifact. Uses BFS by depth to classify impact: depth 1 = WILL_BREAK, depth 2 = LIKELY_AFFECTED, depth 3 = MAY_NEED_REVIEW. When code intelligence is available, uses call graph for deeper analysis.",
  inputSchema: {
    type: "object" as const,
    properties: {
      artifact_id: {
        type: "string",
        description: "The artifact ID to analyze (e.g. REQ-AUTH-001, UC-003)",
      },
      direction: {
        type: "string",
        enum: ["upstream", "downstream"],
        description: "Direction to traverse: upstream (what does this depend on) or downstream (what depends on this)",
      },
      maxDepth: {
        type: "number",
        description: "Maximum traversal depth (default: 3)",
      },
    },
    required: ["artifact_id", "direction"],
  },
};

interface ImpactArgs {
  artifact_id: string;
  direction: "upstream" | "downstream";
  maxDepth?: number;
}

interface AffectedArtifact {
  id: string;
  type: string;
  title: string;
  file: string;
  viaRelationship: string;
}

const DEPTH_LABELS: Record<number, string> = {
  1: "WILL_BREAK",
  2: "LIKELY_AFFECTED",
  3: "MAY_NEED_REVIEW",
};

export function executeImpact(
  args: ImpactArgs,
  graph: TraceabilityGraph,
  index: GraphIndex
): string {
  const { artifact_id, direction, maxDepth = 3 } = args;

  const root = index.byId.get(artifact_id);
  if (!root) {
    return JSON.stringify({
      error: `Artifact "${artifact_id}" not found`,
      hint: `Use sdd_query to search for the correct ID.`,
    });
  }

  // BFS by depth
  const visited = new Set<string>([artifact_id]);
  const byDepth: Record<number, AffectedArtifact[]> = {};
  let currentLevel = [artifact_id];

  for (let depth = 1; depth <= maxDepth; depth++) {
    const nextLevel: string[] = [];
    byDepth[depth] = [];

    for (const nodeId of currentLevel) {
      // Choose relationship direction
      const rels =
        direction === "downstream"
          ? index.relByTarget.get(nodeId) ?? []
          : index.relBySource.get(nodeId) ?? [];

      for (const rel of rels) {
        const neighborId =
          direction === "downstream" ? rel.source : rel.target;
        if (visited.has(neighborId)) continue;
        visited.add(neighborId);

        const neighbor = index.byId.get(neighborId);
        if (neighbor) {
          byDepth[depth].push({
            id: neighbor.id,
            type: neighbor.type,
            title: neighbor.title,
            file: neighbor.file,
            viaRelationship: rel.type,
          });
        }
        nextLevel.push(neighborId);
      }
    }

    currentLevel = nextLevel;
    if (currentLevel.length === 0) break;
  }

  // Determine affected pipeline stages
  const affectedStages = new Set<string>();
  for (const items of Object.values(byDepth)) {
    for (const item of items) {
      const art = index.byId.get(item.id);
      if (art?.stage) affectedStages.add(art.stage);
    }
  }

  // Risk assessment
  const totalAffected = Object.values(byDepth).reduce(
    (sum, arr) => sum + arr.length,
    0
  );
  let risk: string;
  if ((byDepth[1]?.length ?? 0) > 5 || totalAffected > 20) risk = "HIGH";
  else if ((byDepth[1]?.length ?? 0) > 2 || totalAffected > 10) risk = "MEDIUM";
  else risk = "LOW";

  // Code intelligence enrichment (if available)
  let codeImpact: Record<string, unknown> | undefined;
  if (graph.codeIntelligence?.indexed) {
    const ci = graph.codeIntelligence;
    const relatedSymbols = ci.symbols.filter(
      (s) =>
        s.artifactRefs.includes(artifact_id) ||
        s.inferredRefs.includes(artifact_id)
    );
    if (relatedSymbols.length > 0) {
      const callerSet = new Set<string>();
      for (const sym of relatedSymbols) {
        for (const caller of sym.callers) callerSet.add(caller);
      }
      codeImpact = {
        directSymbols: relatedSymbols.map((s) => ({
          name: s.name,
          file: s.filePath,
          type: s.type,
        })),
        transitiveCallers: [...callerSet],
        totalCallChainDepth: relatedSymbols.length + callerSet.size,
      };
    }
  }

  const output = {
    artifact: {
      id: root.id,
      type: root.type,
      title: root.title,
    },
    direction,
    maxDepth,
    risk,
    totalAffected,
    byDepth: Object.fromEntries(
      Object.entries(byDepth).map(([d, items]) => [
        d,
        {
          label: DEPTH_LABELS[Number(d)] ?? `DEPTH_${d}`,
          count: items.length,
          artifacts: items,
        },
      ])
    ),
    affectedStages: [...affectedStages],
    ...(codeImpact ? { codeImpact } : {}),
  };

  return JSON.stringify(output) + getNextStepHint("sdd_impact", args);
}
