import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { loadGraph, emptyGraph } from "./graph-loader.js";
import type { TraceabilityGraph, GraphIndex } from "./graph-loader.js";
import { executeQuery } from "./tools/query.js";
import { executeImpact } from "./tools/impact.js";
import { executeContext } from "./tools/context.js";
import { executeCoverage } from "./tools/coverage.js";
import { executeTrace } from "./tools/trace.js";
import { readResource } from "./resources.js";
import { getPrompt } from "./prompts.js";

function getGraphOrEmpty(): { graph: TraceabilityGraph; index: GraphIndex } {
  const loaded = loadGraph();
  if (loaded) return loaded;

  const graph = emptyGraph();
  return {
    graph,
    index: {
      byId: new Map(),
      byType: new Map(),
      byFile: new Map(),
      relBySource: new Map(),
      relByTarget: new Map(),
      codeRefsByFile: new Map(),
    },
  };
}

export function createSDDServer(): McpServer {
  const server = new McpServer({
    name: "sdd",
    version: "1.0.0",
  });

  // -----------------------------------------------------------------------
  // Tools
  // -----------------------------------------------------------------------

  server.tool(
    "sdd_query",
    "Search SDD artifacts by text, ID, type, or domain. Returns matching artifacts with relevance scores.",
    {
      query: z.string().describe("Search text — matches against artifact ID, title, file path, and code/test refs"),
      type: z.string().optional().describe("Filter by artifact type: REQ, UC, WF, API, BDD, INV, ADR, NFR, RN, FASE, TASK"),
      domain: z.string().optional().describe("Filter by business domain"),
      limit: z.number().optional().describe("Max results (default: 20)"),
    },
    async (args) => {
      const { graph, index } = getGraphOrEmpty();
      const result = executeQuery(args, graph, index);
      return { content: [{ type: "text" as const, text: result }] };
    }
  );

  server.tool(
    "sdd_impact",
    "Analyze blast radius of changing an artifact. BFS by depth: d1=WILL_BREAK, d2=LIKELY_AFFECTED, d3=MAY_NEED_REVIEW.",
    {
      artifact_id: z.string().describe("The artifact ID to analyze (e.g. REQ-AUTH-001)"),
      direction: z.enum(["upstream", "downstream"]).describe("Traversal direction"),
      maxDepth: z.number().optional().describe("Maximum depth (default: 3)"),
    },
    async (args) => {
      const { graph, index } = getGraphOrEmpty();
      const result = executeImpact(args, graph, index);
      return { content: [{ type: "text" as const, text: result }] };
    }
  );

  server.tool(
    "sdd_context",
    "360-degree view of an artifact: definition, upstream/downstream, code/test/commit refs, and coverage gaps.",
    {
      artifact_id: z.string().describe("The artifact ID (e.g. REQ-AUTH-001, UC-003)"),
    },
    async (args) => {
      const { graph, index } = getGraphOrEmpty();
      const result = executeContext(args, graph, index);
      return { content: [{ type: "text" as const, text: result }] };
    }
  );

  server.tool(
    "sdd_coverage",
    "Analyze traceability coverage gaps by business domain and technical layer.",
    {
      domain: z.string().optional().describe("Filter by business domain"),
      layer: z.string().optional().describe("Filter by technical layer"),
    },
    async (args) => {
      const { graph, index } = getGraphOrEmpty();
      const result = executeCoverage(args, graph, index);
      return { content: [{ type: "text" as const, text: result }] };
    }
  );

  server.tool(
    "sdd_trace",
    "Trace the complete chain: REQ->UC->WF->API->BDD->INV->ADR->TASK->COMMIT->CODE->TEST. Reports breaks and status.",
    {
      artifact_id: z.string().describe("The artifact ID to trace"),
    },
    async (args) => {
      const { graph, index } = getGraphOrEmpty();
      const result = executeTrace(args, graph, index);
      return { content: [{ type: "text" as const, text: result }] };
    }
  );

  // -----------------------------------------------------------------------
  // Resources
  // -----------------------------------------------------------------------

  server.resource("Pipeline Status", "sdd://pipeline/status", async (uri) => {
    const { graph, index } = getGraphOrEmpty();
    return readResource(uri.href, graph, index);
  });

  server.resource("Pipeline Stages", "sdd://pipeline/stages", async (uri) => {
    const { graph, index } = getGraphOrEmpty();
    return readResource(uri.href, graph, index);
  });

  server.resource("Graph Schema", "sdd://graph/schema", async (uri) => {
    const { graph, index } = getGraphOrEmpty();
    return readResource(uri.href, graph, index);
  });

  server.resource("Graph Statistics", "sdd://graph/stats", async (uri) => {
    const { graph, index } = getGraphOrEmpty();
    return readResource(uri.href, graph, index);
  });

  server.resource("Coverage Gaps", "sdd://coverage/gaps", async (uri) => {
    const { graph, index } = getGraphOrEmpty();
    return readResource(uri.href, graph, index);
  });

  server.resource("Artifacts by Type", "sdd://artifacts/{type}", async (uri) => {
    const { graph, index } = getGraphOrEmpty();
    return readResource(uri.href, graph, index);
  });

  server.resource("Artifact Detail", "sdd://artifacts/{type}/{id}", async (uri) => {
    const { graph, index } = getGraphOrEmpty();
    return readResource(uri.href, graph, index);
  });

  // -----------------------------------------------------------------------
  // Prompts
  // -----------------------------------------------------------------------

  server.prompt(
    "analyze_impact",
    "Pre-change workflow: context, blast radius, chain integrity, and cascade recommendation.",
    { artifact_id: z.string().describe("The artifact ID to analyze before changing") },
    async (args) => {
      return getPrompt("analyze_impact", args);
    }
  );

  server.prompt(
    "generate_status_report",
    "Pipeline health report: state, coverage, priority actions, and assessment.",
    async () => {
      return getPrompt("generate_status_report");
    }
  );

  return server;
}
