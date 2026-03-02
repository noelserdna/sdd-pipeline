import { getNextStepHint } from "../hints.js";
export const TRACE_TOOL = {
    name: "sdd_trace",
    description: "Trace the complete traceability chain for an artifact: REQ -> UC -> WF -> API -> BDD -> INV -> ADR -> TASK -> COMMIT -> CODE -> TEST. Identifies breaks in the chain and reports completeness status.",
    inputSchema: {
        type: "object",
        properties: {
            artifact_id: {
                type: "string",
                description: "The artifact ID to trace (e.g. REQ-AUTH-001, UC-003)",
            },
        },
        required: ["artifact_id"],
    },
};
/**
 * Chain order defines the expected traceability progression.
 * An artifact can appear at any level; we trace both directions.
 */
const CHAIN_ORDER = [
    "REQ",
    "UC",
    "WF",
    "API",
    "BDD",
    "INV",
    "ADR",
    "TASK",
    "COMMIT",
    "CODE",
    "TEST",
];
function collectConnected(startId, direction, index, visited) {
    const results = [];
    const queue = [startId];
    while (queue.length > 0) {
        const current = queue.shift();
        const rels = direction === "downstream"
            ? index.relByTarget.get(current) ?? []
            : index.relBySource.get(current) ?? [];
        for (const rel of rels) {
            const neighborId = direction === "downstream" ? rel.source : rel.target;
            if (visited.has(neighborId))
                continue;
            visited.add(neighborId);
            const art = index.byId.get(neighborId);
            if (art) {
                results.push({
                    id: art.id,
                    type: art.type,
                    title: art.title,
                    file: art.file,
                    rel: rel.type,
                });
                queue.push(neighborId);
            }
        }
    }
    return results;
}
export function executeTrace(args, graph, index) {
    const { artifact_id } = args;
    const root = index.byId.get(artifact_id);
    if (!root) {
        return JSON.stringify({
            error: `Artifact "${artifact_id}" not found`,
            hint: `Use sdd_query to search for the correct ID.`,
        });
    }
    const visited = new Set([artifact_id]);
    // Collect all connected artifacts in both directions
    const upstream = collectConnected(artifact_id, "upstream", index, visited);
    const downstream = collectConnected(artifact_id, "downstream", index, new Set(visited));
    // Also include code/test/commit as virtual chain levels
    const allConnected = [
        { id: root.id, type: root.type, title: root.title, file: root.file, rel: "self" },
        ...upstream,
        ...downstream,
    ];
    // Build chain organized by type level
    const chain = [];
    const breaks = [];
    const typesSeen = new Set();
    for (const level of CHAIN_ORDER) {
        const matching = allConnected.filter((a) => {
            if (level === "CODE") {
                // Code refs from any artifact in the chain
                return false; // handled separately
            }
            if (level === "COMMIT")
                return false; // handled separately
            if (level === "TEST")
                return false; // handled separately
            return a.type === level;
        });
        if (level === "CODE") {
            // Gather all code refs from all artifacts in the chain
            const codeItems = [];
            for (const a of allConnected) {
                const art = index.byId.get(a.id);
                for (const cr of art?.codeRefs ?? []) {
                    codeItems.push({
                        id: `${cr.symbol}@${cr.file}:${cr.line}`,
                        title: `${cr.symbol} (${cr.symbolType})`,
                        file: cr.file,
                    });
                }
            }
            if (codeItems.length > 0) {
                typesSeen.add("CODE");
                chain.push({
                    level: "CODE",
                    artifacts: codeItems.slice(0, 20),
                });
            }
            continue;
        }
        if (level === "COMMIT") {
            const commitItems = [];
            for (const a of allConnected) {
                const art = index.byId.get(a.id);
                for (const cr of art?.commitRefs ?? []) {
                    commitItems.push({
                        id: cr.sha,
                        title: cr.message,
                        file: cr.taskId ?? "no task",
                    });
                }
            }
            if (commitItems.length > 0) {
                typesSeen.add("COMMIT");
                chain.push({
                    level: "COMMIT",
                    artifacts: commitItems.slice(0, 20),
                });
            }
            continue;
        }
        if (level === "TEST") {
            const testItems = [];
            for (const a of allConnected) {
                const art = index.byId.get(a.id);
                for (const tr of art?.testRefs ?? []) {
                    testItems.push({
                        id: `${tr.testName}@${tr.file}:${tr.line}`,
                        title: tr.testName,
                        file: tr.file,
                    });
                }
            }
            if (testItems.length > 0) {
                typesSeen.add("TEST");
                chain.push({
                    level: "TEST",
                    artifacts: testItems.slice(0, 20),
                });
            }
            continue;
        }
        if (matching.length > 0) {
            typesSeen.add(level);
            chain.push({
                level,
                artifacts: matching.map((m) => ({
                    id: m.id,
                    title: m.title,
                    file: m.file,
                    relationship: m.rel,
                })),
            });
        }
    }
    // Detect chain breaks — look for gaps in expected sequence
    const rootTypeIndex = CHAIN_ORDER.indexOf(root.type);
    if (rootTypeIndex >= 0) {
        // Check levels before root
        for (let i = 0; i < rootTypeIndex; i++) {
            if (!typesSeen.has(CHAIN_ORDER[i])) {
                breaks.push(`Missing ${CHAIN_ORDER[i]} link upstream of ${root.type}`);
            }
        }
        // Check key levels after root
        for (let i = rootTypeIndex + 1; i < CHAIN_ORDER.length; i++) {
            const level = CHAIN_ORDER[i];
            if (!typesSeen.has(level) &&
                ["UC", "BDD", "TASK", "CODE", "TEST"].includes(level)) {
                breaks.push(`Missing ${level} link downstream of ${root.type}`);
            }
        }
    }
    // Overall status
    let status;
    if (breaks.length === 0)
        status = "COMPLETE";
    else if (breaks.length <= 2)
        status = "PARTIAL";
    else
        status = "FRAGMENTED";
    const output = {
        artifact: {
            id: root.id,
            type: root.type,
            title: root.title,
        },
        status,
        chainLength: chain.length,
        totalArtifactsInChain: allConnected.length,
        chain,
        breaks,
        typesCovered: [...typesSeen],
        typesMissing: CHAIN_ORDER.filter((t) => !typesSeen.has(t)),
    };
    return JSON.stringify(output) + getNextStepHint("sdd_trace", args);
}
//# sourceMappingURL=trace.js.map