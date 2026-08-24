// Smoke test del bundle: arranca dist/server.js por stdio como lo haría Claude Code y comprueba el contrato público.
import { test } from "node:test";
import assert from "node:assert/strict";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const DIST = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "dist", "server.js");
const EXPECTED_TOOLS = ["sdd_context", "sdd_coverage", "sdd_gaps", "sdd_impact", "sdd_query", "sdd_trace"];

async function connect(cwd: string) {
  const transport = new StdioClientTransport({ command: process.execPath, args: [DIST], cwd });
  const client = new Client({ name: "smoke", version: "0.0.0" });
  await client.connect(transport);
  return client;
}

test("dist/server.js expone las 6 tools, recursos y prompts", { timeout: 15_000 }, async () => {
  const client = await connect(os.tmpdir());
  try {
    const tools = (await client.listTools()).tools.map((t) => t.name).sort();
    assert.deepEqual(tools, EXPECTED_TOOLS);
    assert.ok((await client.listResources()).resources.length >= 5, "recursos sdd://");
    assert.ok((await client.listPrompts()).prompts.length >= 2, "prompts");
    assert.equal(client.getServerVersion()?.name, "sdd");
    assert.notEqual(client.getServerVersion()?.version, "0.0.0", "la versión se inyecta en el build");
  } finally {
    await client.close();
  }
});

test("sin dashboard/traceability-graph.json las tools responden sin fallar", { timeout: 15_000 }, async () => {
  const client = await connect(os.tmpdir());
  try {
    const result = await client.callTool({ name: "sdd_query", arguments: { query: "REQ" } });
    assert.ok(result, "sdd_query devuelve resultado con grafo vacío");
  } finally {
    await client.close();
  }
});

test("con un grafo en dashboard/ las tools devuelven artefactos", { timeout: 15_000 }, async () => {
  const fixture = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "fixtures", "proj");
  const client = await connect(fixture);
  try {
    const result = (await client.callTool({ name: "sdd_query", arguments: { query: "REQ-001" } })) as {
      content: Array<{ type: string; text?: string }>;
    };
    const text = result.content.map((c) => c.text ?? "").join("\n");
    assert.match(text, /REQ-001/);
    assert.match(text, /Crear tarea/);
  } finally {
    await client.close();
  }
});
