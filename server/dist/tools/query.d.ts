import type { GraphIndex, TraceabilityGraph } from "../graph-loader.js";
export declare const QUERY_TOOL: {
    name: string;
    description: string;
    inputSchema: {
        type: "object";
        properties: {
            query: {
                type: string;
                description: string;
            };
            type: {
                type: string;
                description: string;
            };
            domain: {
                type: string;
                description: string;
            };
            limit: {
                type: string;
                description: string;
            };
        };
        required: string[];
    };
};
interface QueryArgs {
    query: string;
    type?: string;
    domain?: string;
    limit?: number;
}
export declare function executeQuery(args: QueryArgs, graph: TraceabilityGraph, index: GraphIndex): string;
export {};
//# sourceMappingURL=query.d.ts.map