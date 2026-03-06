/**
 * Map a relative file path to its pipeline stage name.
 * Returns null if the path doesn't belong to any known stage.
 */
export declare function pathToStage(relativePath: string): string | null;
/**
 * Map a relative file path to a human-readable label.
 * Example: "spec/DOMAIN-MODEL.md" → "Specification: DOMAIN-MODEL.md"
 */
export declare function pathToHumanLabel(relativePath: string): string;
/**
 * Extract a relative path from an absolute path given a project root.
 * Returns null if the path is not under the project root.
 */
export declare function toRelativePath(absolutePath: string, projectRoot: string): string | null;
//# sourceMappingURL=path-mapper.d.ts.map