/**
 * Next-step hints appended to tool responses (GitNexus pattern).
 * Guides the user/agent toward the most useful follow-up action.
 */

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function getNextStepHint(toolName: string, args?: any): string {
  switch (toolName) {
    case "sdd_query":
      return "\n\n---\n**Next:** Use `sdd_context` with an artifact ID for a full 360-degree view.";
    case "sdd_context":
      return `\n\n---\n**Next:** Use \`sdd_impact({ artifact_id: "${args?.artifact_id ?? "..."}", direction: "downstream" })\` to see blast radius before making changes.`;
    case "sdd_impact":
      return "\n\n---\n**Next:** Review depth=1 first (WILL_BREAK). Run `/sdd:req-change` to manage the change formally.";
    case "sdd_coverage":
      return "\n\n---\n**Next:** For each gap, use `sdd_trace` to understand why coverage is missing.";
    case "sdd_trace":
      return "\n\n---\n**Next:** Broken links? Run `/sdd:traceability-check` for full chain verification.";
    default:
      return "";
  }
}
