/**
 * Named workflow prompts for the SDD MCP server.
 * These guide multi-step interactions using the server's tools.
 */
export declare function listPrompts(): {
    prompts: ({
        name: string;
        description: string;
        arguments: {
            name: string;
            description: string;
            required: boolean;
        }[];
    } | {
        name: string;
        description: string;
        arguments?: undefined;
    })[];
};
export declare function getPrompt(name: string, args?: Record<string, string>): {
    description: string;
    messages: Array<{
        role: "user";
        content: {
            type: "text";
            text: string;
        };
    }>;
};
//# sourceMappingURL=prompts.d.ts.map