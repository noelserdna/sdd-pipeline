// SDD Dashboard Server — HTTP + SSE server for real-time dashboard updates.
// Receives hook events via POST, broadcasts to connected browsers via SSE.
// Uses only node:http (zero external dependencies).
import { createServer } from "node:http";
import { readFileSync, existsSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { addClient, broadcast, clientCount } from "./sse.js";
import { pathToStage, pathToHumanLabel, toRelativePath } from "./path-mapper.js";
// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
const MAX_EVENTS = 200;
let events = [];
let nextEventId = 1;
let projectDir = process.cwd();
let persistInterval = null;
function addEvent(type, stage, detail) {
    const event = {
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
    broadcast(type, event);
    return event;
}
// ---------------------------------------------------------------------------
// Route handlers
// ---------------------------------------------------------------------------
function readBody(req) {
    return new Promise((resolve, reject) => {
        const chunks = [];
        req.on("data", (chunk) => chunks.push(chunk));
        req.on("end", () => resolve(Buffer.concat(chunks).toString()));
        req.on("error", reject);
    });
}
function json(res, status, data) {
    res.writeHead(status, {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
    });
    res.end(JSON.stringify(data));
}
async function handleHookPost(req, res, hookType) {
    let body = {};
    try {
        const raw = await readBody(req);
        if (raw)
            body = JSON.parse(raw);
    }
    catch {
        json(res, 400, { error: "Invalid JSON" });
        return;
    }
    const cwd = body.cwd ?? projectDir;
    switch (hookType) {
        case "session-start": {
            addEvent("session-start", null, {
                sessionId: body.session_id,
                message: `Session started (${body.source ?? "startup"})`,
            });
            break;
        }
        case "artifact-changed": {
            const toolInput = body.tool_input;
            const filePath = toolInput?.file_path ?? "";
            const toolName = body.tool_name ?? "Write";
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
            const eventName = body.hook_event_name;
            const isStart = eventName === "SubagentStart";
            const agentType = body.agent_type ?? "unknown";
            const agentId = body.agent_id ?? "";
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
            const taskId = body.task_id ?? "";
            const taskSubject = body.task_subject ?? "";
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
                message: `Session ended (${body.reason ?? "unknown"})`,
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
function handleApiStatus(_req, res) {
    json(res, 200, {
        sseClients: clientCount(),
        eventCount: events.length,
        events: events.slice(-50),
        serverUpSince: serverStartTime,
    });
}
function handleApiGraph(_req, res) {
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
    }
    catch {
        json(res, 500, { error: "Failed to read graph" });
    }
}
function serveStaticFile(res, filename, contentType) {
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
    }
    catch {
        json(res, 500, { error: `Failed to read ${filename}` });
    }
}
// ---------------------------------------------------------------------------
// Persistence (activity log)
// ---------------------------------------------------------------------------
function persistEvents() {
    const logPath = join(projectDir, "dashboard", "activity-log.json");
    try {
        writeFileSync(logPath, JSON.stringify(events.slice(-100), null, 2));
    }
    catch {
        // Silent — dashboard dir may not exist yet
    }
}
function loadPersistedEvents() {
    const logPath = join(projectDir, "dashboard", "activity-log.json");
    if (!existsSync(logPath))
        return;
    try {
        const raw = readFileSync(logPath, "utf-8");
        const loaded = JSON.parse(raw);
        if (Array.isArray(loaded)) {
            events = loaded;
            nextEventId = Math.max(...events.map((e) => e.id), 0) + 1;
        }
    }
    catch {
        // Ignore corrupted log
    }
}
// ---------------------------------------------------------------------------
// Server
// ---------------------------------------------------------------------------
let serverStartTime;
export function startDashboardServer(port) {
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
        if (persistInterval)
            clearInterval(persistInterval);
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
//# sourceMappingURL=dashboard-server.js.map