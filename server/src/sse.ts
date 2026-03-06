// SSE (Server-Sent Events) manager for the dashboard server.
// Maintains connected clients and broadcasts events to all of them.

import type { ServerResponse } from "node:http";

interface SSEClient {
  id: number;
  res: ServerResponse;
}

let nextClientId = 1;
const clients: SSEClient[] = [];
let heartbeatInterval: ReturnType<typeof setInterval> | null = null;

/**
 * Initialize a new SSE connection. Sets headers, sends initial comment,
 * and registers the client for future broadcasts.
 */
export function addClient(res: ServerResponse): void {
  res.writeHead(200, {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    Connection: "keep-alive",
    "Access-Control-Allow-Origin": "*",
  });

  // Initial comment to establish connection
  res.write(": connected\n\n");

  const client: SSEClient = { id: nextClientId++, res };
  clients.push(client);

  res.on("close", () => {
    removeClient(client);
  });

  // Start heartbeat if this is the first client
  if (clients.length === 1 && !heartbeatInterval) {
    heartbeatInterval = setInterval(() => {
      broadcast("heartbeat", { timestamp: new Date().toISOString() });
    }, 15_000);
  }
}

function removeClient(client: SSEClient): void {
  const idx = clients.findIndex((c) => c.id === client.id);
  if (idx !== -1) clients.splice(idx, 1);

  // Stop heartbeat if no clients
  if (clients.length === 0 && heartbeatInterval) {
    clearInterval(heartbeatInterval);
    heartbeatInterval = null;
  }
}

/**
 * Broadcast an event to all connected SSE clients.
 * Failed writes (disconnected clients) are silently cleaned up.
 */
export function broadcast(
  eventType: string,
  data: Record<string, unknown>
): void {
  const payload = `event: ${eventType}\ndata: ${JSON.stringify(data)}\n\n`;
  const dead: SSEClient[] = [];

  for (const client of clients) {
    try {
      client.res.write(payload);
    } catch {
      dead.push(client);
    }
  }

  for (const client of dead) {
    removeClient(client);
  }
}

/** Number of currently connected SSE clients. */
export function clientCount(): number {
  return clients.length;
}
