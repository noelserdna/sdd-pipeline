export declare const GAPS_TOOL: {
    name: string;
    description: string;
    inputSchema: {
        type: "object";
        properties: {
            category: {
                type: string;
                description: string;
            };
            format: {
                type: string;
                description: string;
            };
        };
    };
};
interface GapsArgs {
    category?: "missing" | "orphan" | "mismatch" | "all";
    format?: "summary" | "detail";
}
export declare function executeGaps(args: GapsArgs): string;
export {};
//# sourceMappingURL=gaps.d.ts.map