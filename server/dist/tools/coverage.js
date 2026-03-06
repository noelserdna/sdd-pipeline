import { getNextStepHint } from "../hints.js";
export const COVERAGE_TOOL = {
    name: "sdd_coverage",
    description: "Analyze traceability coverage gaps grouped by business domain and technical layer. Identifies uncovered requirements and top priority gaps. Use to assess pipeline completeness.",
    inputSchema: {
        type: "object",
        properties: {
            domain: {
                type: "string",
                description: "Filter by business domain (e.g. 'Security & Auth')",
            },
            layer: {
                type: "string",
                description: "Filter by technical layer: Infrastructure, Backend, Frontend, Integration/Deployment",
            },
        },
    },
};
export function executeCoverage(args, graph, index) {
    const { domain, layer } = args;
    // Get all REQs as the base for coverage analysis
    let reqs = index.byType.get("REQ") ?? [];
    if (domain) {
        const domainLower = domain.toLowerCase();
        reqs = reqs.filter((r) => r.classification?.businessDomain?.toLowerCase().includes(domainLower));
    }
    if (layer) {
        const layerLower = layer.toLowerCase();
        reqs = reqs.filter((r) => r.classification?.technicalLayer?.toLowerCase().includes(layerLower));
    }
    // Analyze each REQ
    const byDomain = {};
    const byLayer = {};
    const uncovered = [];
    const topGaps = [];
    for (const req of reqs) {
        const domainKey = req.classification?.businessDomain ?? "Unclassified";
        const layerKey = req.classification?.technicalLayer ?? "Unknown";
        // Init buckets
        if (!byDomain[domainKey])
            byDomain[domainKey] = { total: 0, covered: 0, partial: 0, uncovered: 0 };
        if (!byLayer[layerKey])
            byLayer[layerKey] = { total: 0, covered: 0, partial: 0, uncovered: 0 };
        byDomain[domainKey].total++;
        byLayer[layerKey].total++;
        // Check coverage
        const downstream = index.relByTarget.get(req.id) ?? [];
        const hasUC = downstream.some((r) => {
            const art = index.byId.get(r.source);
            return art?.type === "UC";
        });
        const hasBDD = downstream.some((r) => {
            const art = index.byId.get(r.source);
            return art?.type === "BDD";
        });
        const hasCode = (req.codeRefs?.length ?? 0) > 0;
        const hasDirectCode = req.codeRefs?.some((cr) => (cr.origin ?? "direct") === "direct") ?? false;
        const hasInferredCode = req.codeRefs?.some((cr) => cr.origin === "commit-inferred" || cr.origin === "task-inferred") ?? false;
        const hasTests = (req.testRefs?.length ?? 0) > 0;
        const missing = [];
        if (!hasUC)
            missing.push("UC");
        if (!hasBDD)
            missing.push("BDD");
        if (!hasCode)
            missing.push("Code");
        if (!hasTests)
            missing.push("Tests");
        if (missing.length === 0) {
            byDomain[domainKey].covered++;
            byLayer[layerKey].covered++;
        }
        else if (missing.length < 4) {
            byDomain[domainKey].partial++;
            byLayer[layerKey].partial++;
            if (missing.length <= 2) {
                topGaps.push({ id: req.id, title: req.title, missingLinks: missing });
            }
        }
        else {
            byDomain[domainKey].uncovered++;
            byLayer[layerKey].uncovered++;
            uncovered.push({ id: req.id, title: req.title, missingLinks: missing });
        }
    }
    // Sort top gaps by fewest missing (closest to complete)
    topGaps.sort((a, b) => a.missingLinks.length - b.missingLinks.length);
    // Code intelligence enrichment
    let codeIntelCoverage;
    if (graph.codeIntelligence?.indexed) {
        const ci = graph.codeIntelligence;
        codeIntelCoverage = {
            totalSymbols: ci.stats.totalSymbols,
            annotated: ci.stats.symbolsWithRefs,
            inferred: ci.stats.symbolsWithInferredRefs,
            uncoveredSymbols: ci.stats.uncoveredSymbols,
            annotatedPercentage: ci.stats.totalSymbols > 0
                ? Math.round((ci.stats.symbolsWithRefs / ci.stats.totalSymbols) * 100)
                : 0,
            totalCoveredPercentage: ci.stats.totalSymbols > 0
                ? Math.round(((ci.stats.symbolsWithRefs + ci.stats.symbolsWithInferredRefs) /
                    ci.stats.totalSymbols) *
                    100)
                : 0,
        };
    }
    // Code inference breakdown
    const allCodeRefs = reqs.flatMap((r) => r.codeRefs ?? []);
    const codeInferenceBreakdown = {
        directRefs: allCodeRefs.filter((cr) => (cr.origin ?? "direct") === "direct").length,
        commitInferred: allCodeRefs.filter((cr) => cr.origin === "commit-inferred").length,
        taskInferred: allCodeRefs.filter((cr) => cr.origin === "task-inferred").length,
        manualOverrides: allCodeRefs.filter((cr) => cr.origin === "manual-override").length,
        codeIndex: allCodeRefs.filter((cr) => cr.origin === "code-index").length,
    };
    const output = {
        filters: { domain: domain ?? null, layer: layer ?? null },
        totalReqs: reqs.length,
        overallCoverage: graph.statistics.traceabilityCoverage,
        codeInferenceBreakdown,
        byDomain: Object.entries(byDomain).map(([name, stats]) => ({
            domain: name,
            ...stats,
            coveragePercent: stats.total > 0
                ? Math.round((stats.covered / stats.total) * 100)
                : 0,
        })),
        byLayer: Object.entries(byLayer).map(([name, stats]) => ({
            layer: name,
            ...stats,
            coveragePercent: stats.total > 0
                ? Math.round((stats.covered / stats.total) * 100)
                : 0,
        })),
        uncovered: uncovered.slice(0, 20),
        topGaps: topGaps.slice(0, 15),
        ...(codeIntelCoverage ? { codeIntelligence: codeIntelCoverage } : {}),
    };
    return JSON.stringify(output) + getNextStepHint("sdd_coverage", args);
}
//# sourceMappingURL=coverage.js.map