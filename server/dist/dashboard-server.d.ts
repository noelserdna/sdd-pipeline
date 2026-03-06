export interface DashboardEvent {
    id: number;
    timestamp: string;
    type: "session-start" | "session-stop" | "session-end" | "artifact-changed" | "agent-start" | "agent-stop" | "task-completed";
    stage: string | null;
    detail: {
        filePath?: string;
        toolName?: string;
        agentType?: string;
        agentId?: string;
        taskId?: string;
        taskSubject?: string;
        sessionId?: string;
        message: string;
    };
}
export declare function startDashboardServer(port: number): void;
//# sourceMappingURL=dashboard-server.d.ts.map