export interface StageSummary {
    artifacts: {
        file: string;
        label: string;
    }[];
    metrics: Record<string, number>;
    highlights: string[];
    nextStep: string;
    generatedAt: string;
}
export interface PipelineStage {
    name: string;
    status: "done" | "stale" | "running" | "error" | "pending";
    lastRun: string | null;
    artifactCount: number;
    stageLabel?: string;
    summary?: StageSummary | null;
}
export interface Pipeline {
    currentStage: string;
    stages: PipelineStage[];
    lateralStages?: PipelineStage[];
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
    origin?: "direct" | "commit-inferred" | "task-inferred" | "manual-override" | "code-index";
    inferredFrom?: {
        commitSha: string;
        taskId?: string;
        trailerRefs?: string[];
    } | null;
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
    files?: string[];
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
    brokenReferences: Array<{
        ref: string;
        referencedIn: string;
        line: number;
    }>;
    codeStats: {
        totalFiles: number;
        totalSymbols: number;
        symbolsWithRefs: number;
    };
    testStats: {
        totalTestFiles: number;
        totalTests: number;
        testsWithRefs: number;
    };
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
export interface GraphIndex {
    byId: Map<string, Artifact>;
    byType: Map<string, Artifact[]>;
    byFile: Map<string, Artifact[]>;
    relBySource: Map<string, Relationship[]>;
    relByTarget: Map<string, Relationship[]>;
    codeRefsByFile: Map<string, Array<{
        artifact: Artifact;
        ref: CodeRef;
    }>>;
}
export declare function loadGraph(cwd?: string): {
    graph: TraceabilityGraph;
    index: GraphIndex;
} | null;
/** Empty graph for graceful degradation */
export declare function emptyGraph(): TraceabilityGraph;
//# sourceMappingURL=graph-loader.d.ts.map