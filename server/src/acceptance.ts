import { readFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";

// ---------------------------------------------------------------------------
// Reader for .sdd/acceptance.json (sdd-acceptance-v1), written by `sdd accept` (scripts/lib/acceptance.mjs).
// When it exists, sdd_coverage and sdd_context report the verdict per requirement from it instead of inferring
// status from graph links: a link says a test exists, the ledger says it passes on the evaluated commit.
// ---------------------------------------------------------------------------

export type Verdict = "VERIFIED" | "FAILING" | "MISSING" | "WAIVED" | "DEPRECATED";

export interface AcceptanceCriterion {
  n: number;
  text: string | null;
  scenarios: string[];
  state: "pass" | "fail" | "missing" | "stale";
  evidence: Array<Record<string, unknown>>;
}

export interface AcceptanceRequirement {
  id: string;
  type: string;
  title: string;
  priority: string | null;
  needs: string[];
  verification: string | null;
  verdict: Verdict;
  criteria: AcceptanceCriterion[];
  criteria_total: number;
  criteria_passing: number;
  waiver: { line: number; reason: string | null; by: string | null; role: string | null; followUp: string | null; valid: boolean } | null;
  stale_evidence: boolean;
  in_scope?: boolean;
}

export interface AcceptanceSummary {
  active: number;
  deprecated: number;
  by_verdict: Record<Verdict, number>;
  by_priority: Record<string, Record<string, number>>;
  must_total: number;
  must_verified: number;
  must_waived: number;
  goal: boolean;
  waived_musts: string[];
  stale_evidence: number;
  stale_decisions?: number;
}

export interface AcceptanceLedger {
  $schema: string;
  evaluated_sha: string | null;
  dirty: boolean | null;
  generatedAt: string;
  scope: { fase: number; requirements: string[] } | null;
  requirements: AcceptanceRequirement[];
  summary: AcceptanceSummary;
  summary_all?: AcceptanceSummary;
  stale_decisions?: Array<Record<string, unknown>>;
}

export const ACCEPTANCE_SCHEMA = "sdd-acceptance-v1";

/** Nearest `.sdd/acceptance.json` walking up from `startDir` (the project root, next to dashboard/). */
export function findAcceptanceFile(startDir: string): string | null {
  let dir = startDir;
  for (let i = 0; i < 6; i++) {
    const candidate = join(dir, ".sdd", "acceptance.json");
    if (existsSync(candidate)) return candidate;
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return null;
}

/** The ledger, or null when absent, unreadable or of another schema (callers fall back to graph links). */
export function loadAcceptance(cwd?: string): { path: string; ledger: AcceptanceLedger } | null {
  const file = findAcceptanceFile(cwd ?? process.cwd());
  if (!file) return null;
  try {
    const ledger = JSON.parse(readFileSync(file, "utf-8")) as AcceptanceLedger;
    if (ledger?.$schema !== ACCEPTANCE_SCHEMA || !Array.isArray(ledger.requirements)) return null;
    return { path: file, ledger };
  } catch {
    return null;
  }
}

export function acceptanceHeader(path: string, ledger: AcceptanceLedger) {
  return {
    source: "acceptance",
    ledger: path,
    evaluated_sha: ledger.evaluated_sha,
    dirty: ledger.dirty,
    generatedAt: ledger.generatedAt,
    scope: ledger.scope,
    note: "Verdicts are valid for evaluated_sha; after new commits run `sdd accept` (or /sdd-acceptance --check) again.",
  };
}

export function criteriaLabel(r: AcceptanceRequirement): string {
  return `${r.criteria_passing}/${r.criteria_total}`;
}
