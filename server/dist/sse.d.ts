import type { ServerResponse } from "node:http";
/**
 * Initialize a new SSE connection. Sets headers, sends initial comment,
 * and registers the client for future broadcasts.
 */
export declare function addClient(res: ServerResponse): void;
/**
 * Broadcast an event to all connected SSE clients.
 * Failed writes (disconnected clients) are silently cleaned up.
 */
export declare function broadcast(eventType: string, data: Record<string, unknown>): void;
/** Number of currently connected SSE clients. */
export declare function clientCount(): number;
//# sourceMappingURL=sse.d.ts.map