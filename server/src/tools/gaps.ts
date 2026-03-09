import { readFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { getNextStepHint } from "../hints.js";

// ---------------------------------------------------------------------------
// Types for gap-analysis.json
// ---------------------------------------------------------------------------

interface GapFinding {
  id: string;
  category: "missing" | "orphan" | "mismatch";
  severity: string;
  artifact?: string;
  description: string;
  recommendation?: string;
  source?: string;
  target?: string;
}

interface GapAnalysis {
  generatedAt: string;
  projectName?: string;
  summary: {
    total: number;
    missing: number;
    orphan: number;
    mismatch: number;
  };
  findings: GapFinding[];
}

// ---------------------------------------------------------------------------
// Tool definition
// ---------------------------------------------------------------------------

export const GAPS_TOOL = {
  name: "sdd_gaps",
  description:
    "Read gap analysis results from .sdd/gap-analysis.json. Filters by category (missing, orphan, mismatch) and returns summary or detailed findings. Use after running /sdd-gap-detector.",
  inputSchema: {
    type: "object" as const,
    properties: {
      category: {
        type: "string",
        description:
          'Filter by gap category: "missing" | "orphan" | "mismatch" | "all" (default: "all")',
      },
      format: {
        type: "string",
        description:
          'Output format: "summary" (stats + top issues) or "detail" (all findings). Default: "summary"',
      },
    },
  },
};

// ---------------------------------------------------------------------------
// Args
// ---------------------------------------------------------------------------

interface GapsArgs {
  category?: "missing" | "orphan" | "mismatch" | "all";
  format?: "summary" | "detail";
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * Walk up from startDir looking for `.sdd/gap-analysis.json`.
 */
function findGapAnalysisFile(startDir: string): string | null {
  let dir = startDir;
  for (let i = 0; i < 6; i++) {
    const candidate = join(dir, ".sdd", "gap-analysis.json");
    if (existsSync(candidate)) return candidate;
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

function loadGapAnalysis(cwd?: string): GapAnalysis | null {
  const searchDir = cwd ?? process.cwd();
  const filePath = findGapAnalysisFile(searchDir);
  if (!filePath) return null;

  try {
    const raw = readFileSync(filePath, "utf-8");
    return JSON.parse(raw) as GapAnalysis;
  } catch {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Execution
// ---------------------------------------------------------------------------

export function executeGaps(args: GapsArgs): string {
  const { category = "all", format = "summary" } = args;

  const data = loadGapAnalysis();
  if (!data) {
    return JSON.stringify({
      error: true,
      message:
        "No gap analysis found. Run /sdd-gap-detector first.",
    });
  }

  // Filter findings by category
  const findings =
    category === "all"
      ? data.findings
      : data.findings.filter((f) => f.category === category);

  if (format === "detail") {
    const output = {
      generatedAt: data.generatedAt,
      projectName: data.projectName ?? null,
      filter: category,
      totalFindings: findings.length,
      summary: data.summary,
      findings: findings.map((f) => ({
        id: f.id,
        category: f.category,
        severity: f.severity,
        artifact: f.artifact ?? null,
        description: f.description,
        recommendation: f.recommendation ?? null,
        source: f.source ?? null,
        target: f.target ?? null,
      })),
    };

    return JSON.stringify(output) + getNextStepHint("sdd_gaps", args);
  }

  // Summary mode: stats table + top issues (up to 10)
  const bySeverity: Record<string, number> = {};
  for (const f of findings) {
    bySeverity[f.severity] = (bySeverity[f.severity] ?? 0) + 1;
  }

  // Top issues: highest severity first, then alphabetical
  const severityOrder: Record<string, number> = {
    critical: 0,
    high: 1,
    medium: 2,
    low: 3,
    info: 4,
  };
  const sorted = [...findings].sort((a, b) => {
    const sa = severityOrder[a.severity.toLowerCase()] ?? 5;
    const sb = severityOrder[b.severity.toLowerCase()] ?? 5;
    return sa - sb;
  });

  const output = {
    generatedAt: data.generatedAt,
    projectName: data.projectName ?? null,
    filter: category,
    stats: {
      total: data.summary.total,
      missing: data.summary.missing,
      orphan: data.summary.orphan,
      mismatch: data.summary.mismatch,
      filtered: findings.length,
    },
    bySeverity,
    topIssues: sorted.slice(0, 10).map((f) => ({
      id: f.id,
      category: f.category,
      severity: f.severity,
      description: f.description,
    })),
  };

  return JSON.stringify(output) + getNextStepHint("sdd_gaps", args);
}
