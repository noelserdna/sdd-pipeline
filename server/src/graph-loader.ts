import { readFileSync, existsSync, watchFile, unwatchFile } from "node:fs";
import { join, dirname } from "node:path";

// ---------------------------------------------------------------------------
// Types mirroring traceability-graph-v3 schema
// ---------------------------------------------------------------------------

export interface PipelineStage {
  name: string;
  status: "done" | "stale" | "running" | "error" | "pending";
  lastRun: string | null;
  artifactCount: number;
}

export interface Pipeline {
  currentStage: string;
  stages: PipelineStage[];
}

export interface Classification {
  businessDomain: string;
  technicalLayer: string;
  functionalCategory: string;
}

export interface CodeRef {
  file: string;
  line: number;
  symbol: string;
  symbolType: string;
  refIds: string[];
}

export interface TestRef {
  file: string;
  line: number;
  testName: string;
  framework: string;
  refIds: string[];
}

export interface CommitRef {
  sha: string;
  fullSha: string;
  message: string;
  author: string;
  date: string;
  taskId: string | null;
  refIds: string[];
}

export interface Artifact {
  id: string;
  type: string;
  category: string | null;
  title: string;
  file: string;
  line: number;
  priority: string | null;
  stage: string;
  classification: Classification | null;
  codeRefs: CodeRef[];
  testRefs: TestRef[];
  commitRefs: CommitRef[];
}

export interface Relationship {
  source: string;
  target: string;
  type: string;
  sourceFile: string;
  line: number;
}

export interface CoverageMetric {
  count: number;
  total: number;
  percentage: number;
}

export interface Statistics {
  totalArtifacts: number;
  byType: Record<string, number>;
  totalRelationships: number;
  traceabilityCoverage: Record<string, CoverageMetric>;
  orphans: string[];
  brokenReferences: Array<{ ref: string; referencedIn: string; line: number }>;
  codeStats: { totalFiles: number; totalSymbols: number; symbolsWithRefs: number };
  testStats: { totalTestFiles: number; totalTests: number; testsWithRefs: number };
  commitStats: {
    totalCommits: number;
    commitsWithRefs: number;
    commitsWithTasks: number;
    uniqueTasksCovered: number;
  };
  classificationStats: {
    byDomain: Record<string, number>;
    byLayer: Record<string, number>;
    byCategory: Record<string, number>;
  };
  adoptionStats: Record<string, unknown> | null;
}

export interface CodeIntelligence {
  indexed: boolean;
  indexedAt: string;
  engine: string;
  engineVersion: string;
  symbols: Array<{
    id: string;
    name: string;
    type: string;
    filePath: string;
    startLine: number;
    endLine: number;
    isExported: boolean;
    artifactRefs: string[];
    inferredRefs: string[];
    callers: string[];
    callees: string[];
    processes: string[];
    community: string;
  }>;
  callGraph: Array<{
    from: string;
    to: string;
    confidence: number;
    type: string;
  }>;
  processes: Array<{
    name: string;
    steps: string[];
    entryPoint: string;
    artifactRefs: string[];
  }>;
  stats: {
    totalSymbols: number;
    symbolsWithRefs: number;
    symbolsWithInferredRefs: number;
    uncoveredSymbols: number;
    totalProcesses: number;
    processesWithRefs: number;
  };
}

export interface TraceabilityGraph {
  $schema: string;
  generatedAt: string;
  projectName: string;
  pipeline: Pipeline;
  artifacts: Artifact[];
  relationships: Relationship[];
  statistics: Statistics;
  adoption?: Record<string, unknown>;
  codeIntelligence?: CodeIntelligence;
}

// ---------------------------------------------------------------------------
// Indexes built on load for fast lookups
// ---------------------------------------------------------------------------

export interface GraphIndex {
  byId: Map<string, Artifact>;
  byType: Map<string, Artifact[]>;
  byFile: Map<string, Artifact[]>;
  relBySource: Map<string, Relationship[]>;
  relByTarget: Map<string, Relationship[]>;
  codeRefsByFile: Map<string, Array<{ artifact: Artifact; ref: CodeRef }>>;
}

// ---------------------------------------------------------------------------
// Graph Loader
// ---------------------------------------------------------------------------

const GRAPH_FILENAME = "traceability-graph.json";
const DASHBOARD_DIR = "dashboard";

let cachedGraph: TraceabilityGraph | null = null;
let cachedIndex: GraphIndex | null = null;
let watchedPath: string | null = null;

function buildIndex(graph: TraceabilityGraph): GraphIndex {
  const idx: GraphIndex = {
    byId: new Map(),
    byType: new Map(),
    byFile: new Map(),
    relBySource: new Map(),
    relByTarget: new Map(),
    codeRefsByFile: new Map(),
  };

  for (const art of graph.artifacts) {
    idx.byId.set(art.id, art);

    const typeList = idx.byType.get(art.type) ?? [];
    typeList.push(art);
    idx.byType.set(art.type, typeList);

    const fileList = idx.byFile.get(art.file) ?? [];
    fileList.push(art);
    idx.byFile.set(art.file, fileList);

    for (const cr of art.codeRefs ?? []) {
      const crList = idx.codeRefsByFile.get(cr.file) ?? [];
      crList.push({ artifact: art, ref: cr });
      idx.codeRefsByFile.set(cr.file, crList);
    }
  }

  for (const rel of graph.relationships) {
    const srcList = idx.relBySource.get(rel.source) ?? [];
    srcList.push(rel);
    idx.relBySource.set(rel.source, srcList);

    const tgtList = idx.relByTarget.get(rel.target) ?? [];
    tgtList.push(rel);
    idx.relByTarget.set(rel.target, tgtList);
  }

  return idx;
}

function findGraphFile(startDir: string): string | null {
  let dir = startDir;
  for (let i = 0; i < 6; i++) {
    const candidate = join(dir, DASHBOARD_DIR, GRAPH_FILENAME);
    if (existsSync(candidate)) return candidate;
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

export function loadGraph(cwd?: string): {
  graph: TraceabilityGraph;
  index: GraphIndex;
} | null {
  const searchDir = cwd ?? process.cwd();
  const graphPath = findGraphFile(searchDir);

  if (!graphPath) return null;

  // Setup file watcher for live reload (only once per path)
  if (watchedPath !== graphPath) {
    if (watchedPath) unwatchFile(watchedPath);
    watchFile(graphPath, { interval: 2000 }, () => {
      cachedGraph = null;
      cachedIndex = null;
    });
    watchedPath = graphPath;
  }

  if (cachedGraph && cachedIndex) {
    return { graph: cachedGraph, index: cachedIndex };
  }

  try {
    const raw = readFileSync(graphPath, "utf-8");
    const graph: TraceabilityGraph = JSON.parse(raw);
    const index = buildIndex(graph);
    cachedGraph = graph;
    cachedIndex = index;
    return { graph, index };
  } catch {
    return null;
  }
}

/** Empty graph for graceful degradation */
export function emptyGraph(): TraceabilityGraph {
  return {
    $schema: "traceability-graph-v3",
    generatedAt: new Date().toISOString(),
    projectName: "unknown",
    pipeline: { currentStage: "unknown", stages: [] },
    artifacts: [],
    relationships: [],
    statistics: {
      totalArtifacts: 0,
      byType: {},
      totalRelationships: 0,
      traceabilityCoverage: {},
      orphans: [],
      brokenReferences: [],
      codeStats: { totalFiles: 0, totalSymbols: 0, symbolsWithRefs: 0 },
      testStats: { totalTestFiles: 0, totalTests: 0, testsWithRefs: 0 },
      commitStats: {
        totalCommits: 0,
        commitsWithRefs: 0,
        commitsWithTasks: 0,
        uniqueTasksCovered: 0,
      },
      classificationStats: { byDomain: {}, byLayer: {}, byCategory: {} },
      adoptionStats: null,
    },
  };
}
