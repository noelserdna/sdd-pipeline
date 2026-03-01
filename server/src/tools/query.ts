import type { Artifact, GraphIndex, TraceabilityGraph } from "../graph-loader.js";
import { getNextStepHint } from "../hints.js";

export const QUERY_TOOL = {
  name: "sdd_query",
  description:
    "Search SDD artifacts by text, ID, type, or domain. Returns matching artifacts with relevance scores. Use to find requirements, use cases, tasks, or any pipeline artifact.",
  inputSchema: {
    type: "object" as const,
    properties: {
      query: {
        type: "string",
        description: "Search text — matches against artifact ID, title, file path, and code/test refs",
      },
      type: {
        type: "string",
        description: "Filter by artifact type: REQ, UC, WF, API, BDD, INV, ADR, NFR, RN, FASE, TASK",
      },
      domain: {
        type: "string",
        description: "Filter by business domain (e.g. 'Security & Auth', 'Frontend & UI')",
      },
      limit: {
        type: "number",
        description: "Max results to return (default: 20)",
      },
    },
    required: ["query"],
  },
};

interface QueryArgs {
  query: string;
  type?: string;
  domain?: string;
  limit?: number;
}

interface ScoredArtifact {
  artifact: Artifact;
  score: number;
  matchReasons: string[];
}

function scoreArtifact(
  art: Artifact,
  query: string,
  queryLower: string
): ScoredArtifact | null {
  let score = 0;
  const reasons: string[] = [];

  // Exact ID match
  if (art.id.toLowerCase() === queryLower) {
    score += 100;
    reasons.push("exact ID match");
  } else if (art.id.toLowerCase().includes(queryLower)) {
    score += 60;
    reasons.push("partial ID match");
  }

  // Title match
  if (art.title.toLowerCase().includes(queryLower)) {
    score += 40;
    reasons.push("title match");
  }

  // File path match
  if (art.file.toLowerCase().includes(queryLower)) {
    score += 20;
    reasons.push("file path match");
  }

  // Code ref match (file or symbol)
  for (const cr of art.codeRefs ?? []) {
    if (
      cr.file.toLowerCase().includes(queryLower) ||
      cr.symbol.toLowerCase().includes(queryLower)
    ) {
      score += 30;
      reasons.push(`code ref: ${cr.symbol} in ${cr.file}`);
      break;
    }
  }

  // Test ref match
  for (const tr of art.testRefs ?? []) {
    if (
      tr.file.toLowerCase().includes(queryLower) ||
      tr.testName.toLowerCase().includes(queryLower)
    ) {
      score += 25;
      reasons.push(`test ref: ${tr.testName}`);
      break;
    }
  }

  // Category/type match
  if (art.category?.toLowerCase().includes(queryLower)) {
    score += 15;
    reasons.push("category match");
  }

  return score > 0 ? { artifact: art, score, matchReasons: reasons } : null;
}

export function executeQuery(
  args: QueryArgs,
  graph: TraceabilityGraph,
  index: GraphIndex
): string {
  const { query, type, domain, limit = 20 } = args;
  const queryLower = query.toLowerCase();

  let candidates: Artifact[];
  if (type) {
    candidates = index.byType.get(type.toUpperCase()) ?? [];
  } else {
    candidates = graph.artifacts;
  }

  // Domain filter
  if (domain) {
    const domainLower = domain.toLowerCase();
    candidates = candidates.filter(
      (a) =>
        a.classification?.businessDomain?.toLowerCase().includes(domainLower)
    );
  }

  // Score and rank
  const scored: ScoredArtifact[] = [];
  for (const art of candidates) {
    const result = scoreArtifact(art, query, queryLower);
    if (result) scored.push(result);
  }

  scored.sort((a, b) => b.score - a.score);
  const results = scored.slice(0, limit);

  if (results.length === 0) {
    return JSON.stringify({
      query,
      matches: 0,
      results: [],
      hint: `No artifacts matched "${query}". Try broader terms or check artifact types with sdd://graph/stats.`,
    });
  }

  const output = {
    query,
    filters: { type: type ?? null, domain: domain ?? null },
    matches: results.length,
    totalCandidates: candidates.length,
    results: results.map((r) => ({
      id: r.artifact.id,
      type: r.artifact.type,
      title: r.artifact.title,
      file: r.artifact.file,
      score: r.score,
      matchReasons: r.matchReasons,
      hasCode: (r.artifact.codeRefs?.length ?? 0) > 0,
      hasTests: (r.artifact.testRefs?.length ?? 0) > 0,
      hasCommits: (r.artifact.commitRefs?.length ?? 0) > 0,
    })),
  };

  return JSON.stringify(output) + getNextStepHint("sdd_query", args);
}
