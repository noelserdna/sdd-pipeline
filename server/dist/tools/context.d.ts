import type { GraphIndex, TraceabilityGraph } from "../graph-loader.js";
export declare const CONTEXT_TOOL: {
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
interface ContextArgs {
    artifact_id: string;
}
export declare function executeContext(args: ContextArgs, graph: TraceabilityGraph, index: GraphIndex): string;
export {};
//# sourceMappingURL=context.d.ts.map