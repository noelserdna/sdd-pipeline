// Path-to-stage mapper — shared utility for mapping file paths to pipeline stages.
// Used by the dashboard server to classify incoming hook events.
const STAGE_MAP = [
    [/^requirements\//, "requirements-engineer", "Requirements"],
    [/^spec\//, "specifications-engineer", "Specification"],
    [/^audits\//, "spec-auditor", "Audit"],
    [/^test\//, "test-planner", "Test Plan"],
    [/^design\//, "tech-designer", "Technical Design"],
    [/^ux\//, "ux-designer", "UX Design"],
    [/^plan\//, "plan-architect", "Architecture Plan"],
    [/^task\//, "task-generator", "Task"],
    [/^src\//, "task-implementer", "Source Code"],
    [/^tests\//, "task-implementer", "Test Code"],
    [/^feedback\//, "task-implementer", "Feedback"],
    [/^dashboard\//, "dashboard", "Dashboard"],
    [/^reconciliation\//, "reconcile", "Reconciliation"],
    [/^findings\//, "reverse-engineer", "Findings"],
    [/^onboarding\//, "onboarding", "Onboarding"],
    [/^import\//, "import", "Import"],
];
/**
 * Map a relative file path to its pipeline stage name.
 * Returns null if the path doesn't belong to any known stage.
 */
export function pathToStage(relativePath) {
    const normalized = relativePath.replace(/\\/g, "/");
    for (const [pattern, stage] of STAGE_MAP) {
        if (pattern.test(normalized))
            return stage;
    }
    return null;
}
/**
 * Map a relative file path to a human-readable label.
 * Example: "spec/DOMAIN-MODEL.md" → "Specification: DOMAIN-MODEL.md"
 */
export function pathToHumanLabel(relativePath) {
    const normalized = relativePath.replace(/\\/g, "/");
    for (const [pattern, , label] of STAGE_MAP) {
        if (pattern.test(normalized)) {
            const filename = normalized.split("/").pop() ?? normalized;
            return `${label}: ${filename}`;
        }
    }
    return relativePath;
}
/**
 * Extract a relative path from an absolute path given a project root.
 * Returns null if the path is not under the project root.
 */
export function toRelativePath(absolutePath, projectRoot) {
    const normAbs = absolutePath.replace(/\\/g, "/");
    const normRoot = projectRoot.replace(/\\/g, "/").replace(/\/$/, "");
    if (normAbs.startsWith(normRoot + "/")) {
        return normAbs.slice(normRoot.length + 1);
    }
    return null;
}
//# sourceMappingURL=path-mapper.js.map