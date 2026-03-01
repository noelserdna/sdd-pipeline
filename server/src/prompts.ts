/**
 * Named workflow prompts for the SDD MCP server.
 * These guide multi-step interactions using the server's tools.
 */

export function listPrompts() {
  return {
    prompts: [
      {
        name: "analyze_impact",
        description:
          "Pre-change workflow: understand an artifact's current state, assess blast radius, verify chain integrity, and recommend cascade strategy.",
        arguments: [
          {
            name: "artifact_id",
            description: "The artifact ID to analyze before changing",
            required: true,
          },
        ],
      },
      {
        name: "generate_status_report",
        description:
          "Pipeline health report: current state, coverage gaps, priority actions, and overall assessment.",
      },
    ],
  };
}

export function getPrompt(
  name: string,
  args?: Record<string, string>
): {
  description: string;
  messages: Array<{ role: "user"; content: { type: "text"; text: string } }>;
} {
  switch (name) {
    case "analyze_impact": {
      const artifactId = args?.artifact_id ?? "ARTIFACT_ID";
      return {
        description: `Pre-change impact analysis for ${artifactId}`,
        messages: [
          {
            role: "user",
            content: {
              type: "text",
              text: [
                `Analyze the impact of changing artifact ${artifactId}:`,
                "",
                `1. First, get full context: call sdd_context({ artifact_id: "${artifactId}" })`,
                `   - Review the artifact definition, coverage status, and any gaps`,
                "",
                `2. Then assess blast radius: call sdd_impact({ artifact_id: "${artifactId}", direction: "downstream", maxDepth: 3 })`,
                `   - depth 1 = WILL_BREAK (direct dependents)`,
                `   - depth 2 = LIKELY_AFFECTED (indirect dependents)`,
                `   - depth 3 = MAY_NEED_REVIEW (transitive)`,
                "",
                `3. Verify chain integrity: call sdd_trace({ artifact_id: "${artifactId}" })`,
                `   - Check for breaks in the REQ→UC→WF→API→BDD→TASK→COMMIT→CODE→TEST chain`,
                "",
                "4. Synthesize a recommendation:",
                "   - Risk level (LOW/MEDIUM/HIGH)",
                "   - Affected pipeline stages",
                "   - Recommended cascade strategy (auto/manual/dry-run)",
                "   - Specific artifacts to review",
              ].join("\n"),
            },
          },
        ],
      };
    }

    case "generate_status_report":
      return {
        description: "Generate SDD pipeline health report",
        messages: [
          {
            role: "user",
            content: {
              type: "text",
              text: [
                "Generate a comprehensive SDD pipeline status report:",
                "",
                "1. Read pipeline status: access resource sdd://pipeline/status",
                "   - Current stage, staleness, recommended next action",
                "",
                "2. Analyze coverage: call sdd_coverage({})",
                "   - Coverage by domain and layer",
                "   - Uncovered requirements",
                "",
                "3. Read coverage gaps: access resource sdd://coverage/gaps",
                "   - Priority gaps ordered by severity",
                "",
                "4. Read graph stats: access resource sdd://graph/stats",
                "   - Total artifacts, relationships, orphans",
                "",
                "5. Synthesize the report:",
                "   - Pipeline health assessment (Healthy/Warning/Critical)",
                "   - Coverage summary per domain",
                "   - Top 5 priority actions",
                "   - Stale stages needing re-run",
              ].join("\n"),
            },
          },
        ],
      };

    default:
      return {
        description: `Unknown prompt: ${name}`,
        messages: [
          {
            role: "user",
            content: {
              type: "text",
              text: `Unknown prompt "${name}". Available prompts: analyze_impact, generate_status_report`,
            },
          },
        ],
      };
  }
}
