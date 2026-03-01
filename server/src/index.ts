#!/usr/bin/env node

import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { createSDDServer } from "./server.js";

async function main() {
  const server = createSDDServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error("SDD MCP Server fatal error:", error);
  process.exit(1);
});
