import type { TraceabilityGraph, GraphIndex } from "./graph-loader.js";
/**
 * Resource URI handlers for sdd:// protocol.
 * Each handler returns { contents: [{ uri, mimeType, text }] }.
 */
export declare function listResources(): {
    resources: {
        uri: string;
        name: string;
        description: string;
        mimeType: string;
    }[];
};
export declare function listResourceTemplates(): {
    resourceTemplates: {
        uriTemplate: string;
        name: string;
        description: string;
        mimeType: string;
    }[];
};
export declare function readResource(uri: string, graph: TraceabilityGraph, index: GraphIndex): {
    contents: Array<{
        uri: string;
        mimeType: string;
        text: string;
    }>;
};
//# sourceMappingURL=resources.d.ts.map