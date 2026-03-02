import type { GraphIndex, TraceabilityGraph } from "../graph-loader.js";
export declare const COVERAGE_TOOL: {
    name: string;
    description: string;
    inputSchema: {
        type: "object";
        properties: {
            domain: {
                type: string;
                description: string;
            };
            layer: {
                type: string;
                description: string;
            };
        };
    };
};
interface CoverageArgs {
    domain?: string;
    layer?: string;
}
export declare function executeCoverage(args: CoverageArgs, graph: TraceabilityGraph, index: GraphIndex): string;
export {};
//# sourceMappingURL=coverage.d.ts.map