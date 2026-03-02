import type { GraphIndex, TraceabilityGraph } from "../graph-loader.js";
export declare const TRACE_TOOL: {
    name: string;
    description: string;
    inputSchema: {
        type: "object";
        properties: {
            artifact_id: {
                type: string;
                description: string;
            };
        };
        required: string[];
    };
};
interface TraceArgs {
    artifact_id: string;
}
export declare function executeTrace(args: TraceArgs, graph: TraceabilityGraph, index: GraphIndex): string;
export {};
//# sourceMappingURL=trace.d.ts.map