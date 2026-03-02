import { readFileSync, existsSync, watchFile, unwatchFile } from "node:fs";
import { join, dirname } from "node:path";
// ---------------------------------------------------------------------------
// Graph Loader
// ---------------------------------------------------------------------------
const GRAPH_FILENAME = "traceability-graph.json";
const DASHBOARD_DIR = "dashboard";
let cachedGraph = null;
let cachedIndex = null;
let watchedPath = null;
function buildIndex(graph) {
    const idx = {
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
function findGraphFile(startDir) {
    let dir = startDir;
    for (let i = 0; i < 6; i++) {
        const candidate = join(dir, DASHBOARD_DIR, GRAPH_FILENAME);
        if (existsSync(candidate))
            return candidate;
        const parent = dirname(dir);
        if (parent === dir)
            break;
        dir = parent;
    }
    return null;
}
export function loadGraph(cwd) {
    const searchDir = cwd ?? process.cwd();
    const graphPath = findGraphFile(searchDir);
    if (!graphPath)
        return null;
    // Setup file watcher for live reload (only once per path)
    if (watchedPath !== graphPath) {
        if (watchedPath)
            unwatchFile(watchedPath);
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
        const graph = JSON.parse(raw);
        const index = buildIndex(graph);
        cachedGraph = graph;
        cachedIndex = index;
        return { graph, index };
    }
    catch {
        return null;
    }
}
/** Empty graph for graceful degradation */
export function emptyGraph() {
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
//# sourceMappingURL=graph-loader.js.map