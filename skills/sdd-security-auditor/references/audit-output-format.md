# Security Audit Output Format (`audits/SECURITY-AUDIT-BASELINE.md`)

Section headings and field labels stay as below; prose follows the user's language.

````markdown
# Security Audit: {Repository Name}

> Date: YYYY-MM-DD · Spec version: X.Y.Z · Security docs analysed: {N} · Total docs: {N} · OWASP ASVS 4.0.3

## Security Posture Scorecard

| # | Dimension | Score | Grade | Findings (C/H/M/L) |
|---|---|---|---|---|
| D1 | Authentication Completeness | {0-100} | {A-F} | {N}/{N}/{N}/{N} |
| … one row per D1-D10 … |
| **GLOBAL** | Weighted average | **{0-100}** | **{A-F}** | **{N}/{N}/{N}/{N}** |

ASVS chapters assessed: {list} → `owasp_coverage` {N}%

## Summary by Category

| Category | Total | Crítico (P0) | Alto (P1) | Medio (P2) | Bajo (P3) |
|---|---|---|---|---|---|
| SEC-CAT-01 … SEC-CAT-10 (one row each) | | | | | |
| **TOTAL** | | | | | |

## Baseline Delta

Compared against: {previous run date or "N/A (first audit)"} — new {N} · persistent {N} · regression {N} ·
resolved since last run {N} · excluded by baseline {N}

## Threat Surface

| Surface | Elements | Covered | Uncovered |
|---|---|---|---|
| Operations / endpoints · Sensitive fields · External integrations · Trust boundaries (one row each) | | | |

## Traceability

| Chain | Total | Complete | Incomplete |
|---|---|---|---|
| Security REQ / SEC row → INV or ADR | | | |
| Security REQ / SEC row → UC → BDD | | | |
| Security ADR → runbook (when an operation is required) | | | |

## Findings by Category

### SEC-CAT-NN: {name}

#### {PREFIX}-{NNN}: {title}
(finding table from SKILL.md § Finding format)

## Remediation

Findings are fixed through `/sdd-req-change` (one CR per finding or group; the CR's `Refs:` cites the finding IDs).
Order: P0 before implementation → P1 → P2 backlog → P3 continuous improvement.
- P0: {ID} — {title} — {threat}

## Baseline

| ID | Title | Status | Decided by / date | Re-evaluate on | Reason |
|---|---|---|---|---|---|

Status ∈ Accepted · Won't fix · Deferred (with Re-evaluate on) · Resolved. Rows are carried forward on every run;
the human edits Status; the auditor moves findings to Resolved when the gap is closed.
````
