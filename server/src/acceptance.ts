import { readFileSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";

// ---------------------------------------------------------------------------
// Reader for .sdd/acceptance.json (sdd-acceptance-v1), written by `sdd accept` (scripts/lib/acceptance.mjs).
// When it exists, sdd_coverage and sdd_context report the verdict per requirement from it instead of inferring
// status from graph links: a link says a test exists, the ledger says it passes on the evaluated commit.
// ---------------------------------------------------------------------------

export type Verdict = "VERIFIED" | "FAILING" | "MISSING" | "WAIVED" | "DEPRECATED";

/** A screenshot, video or trace bound to evidence (JUnit [[ATTACHMENT|…]], `accept record --attach`, a file of the
 *  evidence dir named after the criterion). `present` is false when the file is gone or its hash changed. */
export interface AcceptanceAttachment {
  path: string;
  sha256: string | null;
  bytes: number | null;
  kind: "image" | "video" | "trace" | "other";
  present: boolean;
  changed?: boolean;
}

export interface AcceptanceCriterion {
  n: number;
  text: string | null;
  scenarios: string[];
  /** `unshown`: a REQ-F criterion that passes without a screenshot under `visual_evidence: required`. */
  state: "pass" | "fail" | "missing" | "stale" | "unshown";
  /** REQ-F only, when the visual rule is not off: whether a present screenshot shows the criterion. */
  visual?: "shown" | "missing";
  evidence: Array<Record<string, unknown> & { attachments?: AcceptanceAttachment[] }>;
}

export interface AcceptanceRequirement {
  id: string;
  type: string;
  title: string;
  priority: string | null;
  needs: string[];
  verification: string | null;
  verdict: Verdict;
  /** Why a requirement is not VERIFIED when the tests alone would say so, e.g. "no visual evidence". */
  reason?: string | null;
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
  /** REQ-F criteria passing without a screenshot (unshown under required, reported under warn). */
  unshown?: number;
  /** With a FASE scope: WF-NNN (or FASE-N) ids without a video. */
  missing_videos?: string[];
}

export interface AcceptanceLedger {
  $schema: string;
  evaluated_sha: string | null;
  dirty: boolean | null;
  /** Untracked files under the code paths: evidence read with them present is stale. */
  untracked_paths?: string[];
  generatedAt: string;
  scope: { fase: number; requirements: string[] } | null;
  requirements: AcceptanceRequirement[];
  summary: AcceptanceSummary;
  summary_all?: AcceptanceSummary;
  stale_decisions?: Array<Record<string, unknown>>;
  visual_evidence?: "required" | "warn" | "off";
  evidence_dir?: string;
  videos?: { required: string[]; found: string[]; missing: string[] } | null;
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
