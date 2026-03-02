import type { GraphIndex, TraceabilityGraph } from "../graph-loader.js";
export declare const IMPACT_TOOL: {
    name: string;
    description: string;
    inputSchema: {
        type: "object";
        properties: {
            artifact_id: {
                type: string;
                description: string;
            };
            direction: {
                type: string;
                enum: string[];
                description: string;
            };
            maxDepth: {
                type: string;
                description: string;
            };
        };
        required: string[];
    };
};
interface ImpactArgs {
    artifact_id: string;
    direction: "upstream" | "downstream";
    maxDepth?: number;
}
export declare function executeImpact(args: ImpactArgs, graph: TraceabilityGraph, index: GraphIndex): string;
export {};
//# sourceMappingURL=impact.d.ts.map