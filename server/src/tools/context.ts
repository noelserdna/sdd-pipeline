import type { GraphIndex, TraceabilityGraph } from "../graph-loader.js";
import { getNextStepHint } from "../hints.js";
import { loadAcceptance, acceptanceHeader, criteriaLabel } from "../acceptance.js";
import type { AcceptanceRequirement } from "../acceptance.js";

export const CONTEXT_TOOL = {
  name: "sdd_context",
  description:
    "Get a 360-degree view of an artifact: its definition, all upstream/downstream connections, code references, test references, commit references, and coverage gaps. For a requirement with .sdd/acceptance.json present, status is its acceptance verdict with per-criterion evidence. Essential before modifying any artifact.",
  inputSchema: {
    type: "object" as const,
    properties: {
      artifact_id: {
        type: "string",
        description: "The artifact ID (e.g. REQ-AUTH-001, UC-003, TASK-F01-003)",
      },
    },
    required: ["artifact_id"],
  },
};

interface ContextArgs {
  artifact_id: string;
}

function acceptanceView(r: AcceptanceRequirement) {
  return {
    verdict: r.verdict,
    ...(r.reason ? { reason: r.reason } : {}),
    priority: r.priority,
    verification: r.verification,
    needs: r.needs,
    criteria: criteriaLabel(r),
    stale_evidence: r.stale_evidence,
    waiver: r.waiver,
    perCriterion: r.criteria.map((c) => ({ n: c.n, text: c.text, state: c.state, ...(c.visual ? { visual: c.visual } : {}), scenarios: c.scenarios, evidence: c.evidence })),
    ...(r.challenges?.length ? { challenges: r.challenges } : {}),
  };
}

/** Open adversarial challenges are gaps whatever the verdict: they question a criterion a green test counts as met.
 *  A confirmed one routes to adversarial-finding (a fix); an inconclusive one to a person (needs-human), as in sdd loop. */
function challengeGaps(r: AcceptanceRequirement): string[] {
  if (r.verdict === "DEPRECATED") return [];
  return (r.challenges ?? []).filter((c) => c.state === "open")
    .map((c) => `CHALLENGED_AC${c.ac}: ${c.id} ${c.category} (${c.counter}) — "${c.quote}" at ${c.evidence.map((e) => (e.line ? `${e.path}:${e.line}` : e.path)).join(", ")} (${c.counter === "inconclusive" ? "needs-human" : "adversarial-finding"})`);
}

function acceptanceGaps(r: AcceptanceRequirement): string[] {
  if (r.verdict === "VERIFIED" || r.verdict === "WAIVED" || r.verdict === "DEPRECATED") return challengeGaps(r);
  const gaps: string[] = [];
  if (!r.verification) gaps.push("NO_VERIFICATION_METHOD: the requirement has no valid Verification line");
  for (const c of r.criteria) {
    if (c.state === "fail") gaps.push(`FAILING_AC${c.n}: evidence fails${c.text ? ` — ${c.text}` : ""}`);
    else if (c.state === "stale") gaps.push(`STALE_AC${c.n}: evidence older than the code — re-run the tests or re-record`);
    else if (c.state === "unshown") gaps.push(`UNSHOWN_AC${c.n}: passes without a screenshot — run the journey again with capture (capture-evidence)`);
    else if (c.state === "missing" && r.verification === "test" && !c.scenarios.length) gaps.push(`NO_SCENARIO_AC${c.n}: no BDD scenario carries [${r.id} AC${c.n}]`);
    else if (c.state === "missing") gaps.push(`MISSING_AC${c.n}: no passing ${r.verification ?? ""} evidence`.replace("  ", " "));
  }
  return [...gaps, ...challengeGaps(r)];
}

export function executeContext(
  args: ContextArgs,
  graph: TraceabilityGraph,
  index: GraphIndex,
  cwd?: string
): string {
  const { artifact_id } = args;

  const acc = loadAcceptance(cwd);
  const accReq = acc?.ledger.requirements.find((r) => r.id === artifact_id) ?? null;

  const artifact = index.byId.get(artifact_id);
  if (!artifact && accReq && acc) {
    // Requirement known to the ledger but not to the graph (no dashboard graph, or an old one).
    return JSON.stringify({
      artifact: { id: accReq.id, type: "REQ", category: accReq.type, title: accReq.title, priority: accReq.priority },
      coverageStatus: accReq.verdict,
      acceptance: { ...acceptanceHeader(acc.path, acc.ledger), ...acceptanceView(accReq) },
      upstream: [],
      downstream: [],
      gaps: acceptanceGaps(accReq),
    }) + getNextStepHint("sdd_context", args);
  }
  if (!artifact) {
    return JSON.stringify({
      error: `Artifact "${artifact_id}" not found`,
      hint: `Use sdd_query to search for the correct ID.`,
    });
  }

  // Upstream: relationships where this artifact is the source
  const upstreamRels = index.relBySource.get(artifact_id) ?? [];
  const upstream = upstreamRels.map((rel) => {
    const target = index.byId.get(rel.target);
    return {
      id: rel.target,
      type: target?.type ?? "unknown",
      title: target?.title ?? "unknown",
      relationship: rel.type,
      file: rel.sourceFile,
    };
  });

  // Downstream: relationships where this artifact is the target
  const downstreamRels = index.relByTarget.get(artifact_id) ?? [];
  const downstream = downstreamRels.map((rel) => {
    const source = index.byId.get(rel.source);
    return {
      id: rel.source,
      type: source?.type ?? "unknown",
      title: source?.title ?? "unknown",
      relationship: rel.type,
      file: rel.sourceFile,
    };
  });

  // Gaps analysis: from the acceptance ledger when it knows this requirement, else from graph links.
  const gaps: string[] = accReq ? acceptanceGaps(accReq) : [];
  if (artifact.type === "REQ" && !accReq) {
    if (upstream.length === 0 && downstream.length === 0) {
      gaps.push("ORPHAN: No relationships found — this REQ is isolated");
    }
    const hasUC = downstream.some((d) => d.type === "UC");
    const hasBDD = downstream.some((d) => d.type === "BDD");
    const hasTask = downstream.some((d) => d.type === "TASK");
    if (!hasUC) gaps.push("MISSING_UC: No use case implements this requirement");
    if (!hasBDD) gaps.push("MISSING_BDD: No BDD scenario verifies this requirement");
    if (!hasTask) gaps.push("MISSING_TASK: No task decomposes this requirement");
    if ((artifact.codeRefs?.length ?? 0) === 0)
      gaps.push("MISSING_CODE: No code references found");
    if ((artifact.testRefs?.length ?? 0) === 0)
      gaps.push("MISSING_TESTS: No test references found");
    if ((artifact.commitRefs?.length ?? 0) === 0)
      gaps.push("MISSING_COMMITS: No commit references found");
  }

  // Determine coverage status
  const codeCount = artifact.codeRefs?.length ?? 0;
  const testCount = artifact.testRefs?.length ?? 0;
  const commitCount = artifact.commitRefs?.length ?? 0;
  const hasUCLink = downstream.some((d) => d.type === "UC") || upstream.some((u) => u.type === "UC");
  const hasBDDLink = downstream.some((d) => d.type === "BDD") || upstream.some((u) => u.type === "BDD");

  let coverageStatus: string;
  if (accReq) coverageStatus = accReq.verdict;
  else if (hasUCLink && hasBDDLink && codeCount > 0 && testCount > 0)
    coverageStatus = "Complete";
  else if (hasUCLink && (codeCount > 0 || testCount > 0))
    coverageStatus = "In Progress";
  else if (hasUCLink) coverageStatus = "Specified";
  else coverageStatus = "Not Started";

  // Separate code refs by origin for clarity
  const allCodeRefs = artifact.codeRefs ?? [];
  const directCodeRefs = allCodeRefs.filter((cr) => (cr.origin ?? "direct") === "direct");
  const inferredCodeRefs = allCodeRefs.filter((cr) => cr.origin && cr.origin !== "direct");

  const output = {
    artifact: {
      id: artifact.id,
      type: artifact.type,
      category: artifact.category,
      title: artifact.title,
      file: artifact.file,
      line: artifact.line,
      priority: artifact.priority,
      stage: artifact.stage,
      classification: artifact.classification,
    },
    coverageStatus,
    ...(accReq && acc ? { acceptance: { ...acceptanceHeader(acc.path, acc.ledger), ...acceptanceView(accReq) } } : {}),
    upstream,
    downstream,
    codeRefs: directCodeRefs,
    inferredCodeRefs: inferredCodeRefs.map((cr) => ({
      ...cr,
      inferencePath: cr.inferredFrom
        ? `via commit:${cr.inferredFrom.commitSha}${cr.inferredFrom.taskId ? ` → ${cr.inferredFrom.taskId}` : ""}`
        : undefined,
    })),
    testRefs: artifact.testRefs ?? [],
    commitRefs: artifact.commitRefs ?? [],
    gaps,
  };

  return JSON.stringify(output) + getNextStepHint("sdd_context", args);
}
