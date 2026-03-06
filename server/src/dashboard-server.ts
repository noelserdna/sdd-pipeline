// SDD Dashboard Server — HTTP + SSE server for real-time dashboard updates.
// Receives hook events via POST, broadcasts to connected browsers via SSE.
// Uses only node:http (zero external dependencies).

import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { readFileSync, existsSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { addClient, broadcast, clientCount } from "./sse.js";
import { pathToStage, pathToHumanLabel, toRelativePath } from "./path-mapper.js";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface DashboardEvent {
  id: number;
  timestamp: string;
  type:
    | "session-start"
    | "session-stop"
    | "session-end"
    | "artifact-changed"
    | "agent-start"
    | "agent-stop"
    | "task-completed";
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

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

const MAX_EVENTS = 200;
let events: DashboardEvent[] = [];
let nextEventId = 1;
let projectDir: string = process.cwd();
let persistInterval: ReturnType<typeof setInterval> | null = null;

function addEvent(
  type: DashboardEvent["type"],
  stage: string | null,
  detail: DashboardEvent["detail"]
): DashboardEvent {
  const event: DashboardEvent = {
    id: nextEventId++,
    timestamp: new Date().toISOString(),
    type,
    stage,
    detail,
  };

  events.push(event);
  if (events.length > MAX_EVENTS) {
    events = events.slice(-MAX_EVENTS);
  }

  // Broadcast to SSE clients
  broadcast(type, event as unknown as Record<string, unknown>);

  return event;
}

// ---------------------------------------------------------------------------
// Route handlers
// ---------------------------------------------------------------------------

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    req.on("data", (chunk: Buffer) => chunks.push(chunk));
    req.on("end", () => resolve(Buffer.concat(chunks).toString()));
    req.on("error", reject);
  });
}

function json(res: ServerResponse, status: number, data: unknown): void {
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
  });
  res.end(JSON.stringify(data));
}

async function handleHookPost(
  req: IncomingMessage,
  res: ServerResponse,
  hookType: string
): Promise<void> {
  let body: Record<string, unknown> = {};
  try {
    const raw = await readBody(req);
    if (raw) body = JSON.parse(raw);
  } catch {
    json(res, 400, { error: "Invalid JSON" });
    return;
  }

  const cwd = (body.cwd as string) ?? projectDir;

  switch (hookType) {
    case "session-start": {
      addEvent("session-start", null, {
        sessionId: body.session_id as string,
        message: `Session started (${(body.source as string) ?? "startup"})`,
      });
      break;
    }

    case "artifact-changed": {
      const toolInput = body.tool_input as Record<string, unknown> | undefined;
      const filePath = (toolInput?.file_path as string) ?? "";
      const toolName = (body.tool_name as string) ?? "Write";
      const relPath = toRelativePath(filePath, cwd);
      const stage = relPath ? pathToStage(relPath) : null;
      const label = relPath ? pathToHumanLabel(relPath) : filePath;

      addEvent("artifact-changed", stage, {
        filePath: relPath ?? filePath,
        toolName,
        message: `${toolName === "Edit" ? "Edited" : "Wrote"} ${label}`,
      });
      break;
    }

    case "agent-event": {
      const eventName = body.hook_event_name as string;
      const isStart = eventName === "SubagentStart";
      const agentType = (body.agent_type as string) ?? "unknown";
      const agentId = (body.agent_id as string) ?? "";

      addEvent(isStart ? "agent-start" : "agent-stop", null, {
        agentType,
        agentId,
        message: isStart
          ? `Agent started: ${agentType}`
          : `Agent finished: ${agentType}`,
      });
      break;
    }

    case "task-completed": {
      const taskId = (body.task_id as string) ?? "";
      const taskSubject = (body.task_subject as string) ?? "";
      addEvent("task-completed", "task-implementer", {
        taskId,
        taskSubject,
        message: `Task completed: ${taskSubject || taskId}`,
      });
      break;
    }

    case "session-stop": {
      addEvent("session-stop", null, {
        message: "Session stopping",
      });
      break;
    }

    case "session-end": {
      addEvent("session-end", null, {
        message: `Session ended (${(body.reason as string) ?? "unknown"})`,
      });
      break;
    }

    default: {
      json(res, 404, { error: `Unknown hook type: ${hookType}` });
      return;
    }
  }

  json(res, 200, { ok: true });
}

function handleApiStatus(_req: IncomingMessage, res: ServerResponse): void {
  json(res, 200, {
    sseClients: clientCount(),
    eventCount: events.length,
    events: events.slice(-50),
    serverUpSince: serverStartTime,
  });
}

function handleApiGraph(_req: IncomingMessage, res: ServerResponse): void {
  const graphPath = join(projectDir, "dashboard", "traceability-graph.json");
  if (!existsSync(graphPath)) {
    json(res, 404, { error: "traceability-graph.json not found" });
    return;
  }
  try {
    const raw = readFileSync(graphPath, "utf-8");
    res.writeHead(200, {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    });
    res.end(raw);
  } catch {
    json(res, 500, { error: "Failed to read graph" });
  }
}

function serveStaticFile(
  res: ServerResponse,
  filename: string,
  contentType: string
): void {
  const filePath = join(projectDir, "dashboard", filename);
  if (!existsSync(filePath)) {
    json(res, 404, { error: `${filename} not found` });
    return;
  }
  try {
    const content = readFileSync(filePath, "utf-8");
    res.writeHead(200, {
      "Content-Type": contentType,
      "Access-Control-Allow-Origin": "*",
    });
    res.end(content);
  } catch {
    json(res, 500, { error: `Failed to read ${filename}` });
  }
}

// ---------------------------------------------------------------------------
// Persistence (activity log)
// ---------------------------------------------------------------------------

function persistEvents(): void {
  const logPath = join(projectDir, "dashboard", "activity-log.json");
  try {
    writeFileSync(logPath, JSON.stringify(events.slice(-100), null, 2));
  } catch {
    // Silent — dashboard dir may not exist yet
  }
}

function loadPersistedEvents(): void {
  const logPath = join(projectDir, "dashboard", "activity-log.json");
  if (!existsSync(logPath)) return;
  try {
    const raw = readFileSync(logPath, "utf-8");
    const loaded = JSON.parse(raw) as DashboardEvent[];
    if (Array.isArray(loaded)) {
      events = loaded;
      nextEventId = Math.max(...events.map((e) => e.id), 0) + 1;
    }
  } catch {
    // Ignore corrupted log
  }
}

// ---------------------------------------------------------------------------
// Server
// ---------------------------------------------------------------------------

let serverStartTime: string;

export function startDashboardServer(port: number): void {
  serverStartTime = new Date().toISOString();
  projectDir = process.env.SDD_PROJECT_DIR ?? process.cwd();

  loadPersistedEvents();

  const server = createServer(async (req, res) => {
    const url = req.url ?? "/";
    const method = req.method ?? "GET";

    // CORS preflight
    if (method === "OPTIONS") {
      res.writeHead(204, {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
      });
      res.end();
      return;
    }

    // Route
    if (method === "POST" && url.startsWith("/hooks/")) {
      const hookType = url.replace("/hooks/", "");
      await handleHookPost(req, res, hookType);
      return;
    }

    if (method === "GET") {
      switch (url) {
        case "/":
        case "/index.html":
          serveStaticFile(res, "index.html", "text/html");
          return;
        case "/guide.html":
          serveStaticFile(res, "guide.html", "text/html");
          return;
        case "/events":
          addClient(res);
          return;
        case "/api/status":
          handleApiStatus(req, res);
          return;
        case "/api/graph":
          handleApiGraph(req, res);
          return;
      }
    }

    json(res, 404, { error: "Not found" });
  });

  // Persist events every 30 seconds
  persistInterval = setInterval(persistEvents, 30_000);

  server.on("close", () => {
    if (persistInterval) clearInterval(persistInterval);
    persistEvents(); // Final persist on shutdown
  });

  server.listen(port, () => {
    console.log(`SDD Dashboard Server listening on http://localhost:${port}`);
    console.log(`  Project: ${projectDir}`);
    console.log(`  Dashboard: http://localhost:${port}/`);
    console.log(`  SSE stream: http://localhost:${port}/events`);
    console.log(`  API status: http://localhost:${port}/api/status`);
  });
}
