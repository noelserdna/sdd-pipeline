---
name: sdd-security-auditor
description: "Audits spec security posture per OWASP ASVS 4.0.3 and CWE: threat models, auth, data, crypto, validation, incident response, compliance. 10-dimension Scorecard with OWASP/CWE refs. Triggers: 'security audit', 'security review', 'threat model', 'OWASP', 'security posture', 'auditoria de seguridad', 'revisar seguridad', 'vulnerabilities in specs'."
---

# SDD Security Auditor

Validates that every threat to the specified system has a specified mitigation. Output: a 10-dimension Security
Posture Scorecard plus findings with OWASP ASVS 4.0.3 and CWE references, in `audits/SECURITY-AUDIT-BASELINE.md`.
Report prose follows the user's language; IDs, field labels and technical terms stay as defined here.

## Principles

1. **Threat-driven.** A finding states "attacker can {action} because {gap in spec}" or asks "what must happen when
   {attack scenario}?". "Could be more secure" or "best practice is X" is not a finding.
2. **No implementation.** Name what the spec must specify (the algorithm for field F, the rate limit for operation
   O), never how to build it (no "add a WAF", "use AES-256-GCM").
3. **Complementary to `sdd-spec-auditor`.** Glossary violations (its CAT-04), ambiguities without security impact
   (CAT-01) and invariants without security implication (CAT-07) belong to it. `SEC-CAT-10` here is unrelated to
   its CAT-10 (it distinguishes the two).
4. **Decisions are respected.** A control decided in an ADR with its trade-offs, or a business rule in
   `spec/CLARIFICATIONS.md`, is not a defect even if a stronger option exists.

## Where security lives in the spec

The forward pipeline (`sdd-requirements-engineer`, `sdd-specifications-engineer`) does not use a separate security
ID family. Security items are:
- **Requirements:** `REQ-NF-NNN` (and occasionally `REQ-F-NNN`) whose subject is a security control, in
  `requirements/REQUIREMENTS.md`.
- **Controls:** `SEC-NNN` rows in `spec/nfr/SECURITY.md` (one table; non-applicable areas are one
  `Not applicable (ADR-NNN)` row).
- **Invariants:** `INV-{AREA}-NNN` rows in `spec/domain/05-INVARIANTS.md` that enforce isolation, ownership,
  retention, audit integrity or similar (area names are project-specific).
- Plus `contracts/PERMISSIONS-MATRIX.md`, auth/validation clauses in `contracts/API-*.md`, sensitive-field marks in
  `domain/02-ENTITIES.md`, security ADRs, `runbooks/RB-*.md`, and negative scenarios in `tests/BDD-UC-*.md`.

## Categories and dimensions

| SEC-CAT | Prefix | Covers | ASVS 4.0.3 | Dimension (weight) |
|---|---|---|---|---|
| 01 Threats without model | THR- | exposed operations, data flows, integrations, actors without threat analysis or trust boundary | V1 | D9 Threat Model Coverage (5%) |
| 02 Incomplete authentication | AUTH- | operations without authn, no brute-force protection, token lifecycle gaps (refresh, revocation), MFA without recovery, sessions without timeout | V2, V3 | D1 Authentication (15%) |
| 03 Insufficient authorization | AUTHZ- | operations missing from the matrix, no tenant isolation, privilege escalation, roles without scope, no row-level rule | V4 | D2 Authorization (15%) |
| 04 Unprotected data | DATA- | sensitive fields without protection, sensitive data in logs/errors, transit/at-rest policy missing, cross-tenant sharing | V8 (+V6) | D3 Data Protection (15%) |
| 05 Missing input validation | INPUT- | inputs without schema, uploads without type/size limits, injection surface, unbounded free text | V5, V12, V13 | D4 Input Validation (10%) |
| 06 Weak/incomplete crypto | CRYPTO- | unnamed or deprecated algorithms, key lifecycle, IV/nonce reuse, key derivation, encryption without integrity | V6 | D5 Cryptographic Rigor (10%) |
| 07 Incomplete incident response | INCIDENT- | no security-event taxonomy, alerts without threshold/escalation, missing runbook, log retention, audit trail | V7 | D6 Incident Readiness (10%) |
| 08 Incomplete regulatory compliance | COMPLY- | data-subject rights without UC, consent collection/withdrawal, retention enforcement, cross-border transfer (cite the regulation article) | — | D7 Regulatory Compliance (10%) |
| 09 Missing security tests | STEST- | security requirements without BDD, authz without negative test, validation without property test | — | D8 Security Test Coverage (5%) |
| 10 Security decision without ADR | SADR- | crypto, auth strategy, trust boundaries, security trade-offs decided without ADR | V1 | D10 Security Decision Documentation (5%) |

Score per dimension: `max(0, 100 − 25·Crítico − 15·Alto − 5·Medio − 2·Bajo)`. Global = Σ score × weight.
Grades: A 90-100 · B 75-89 · C 50-74 · D 25-49 · F 0-24. The scorecard always lists all 10 dimensions, even with
zero findings.

`owasp_coverage` = percentage of the ASVS chapters in the table above (V1-V8, V12, V13) for which the audit found at
least one applicable spec element or an explicit `Not applicable (ADR-NNN)` row.

## Severity

One rule, applied after the signal filters. Each severity maps to the spec-auditor priority scale so downstream
readers (plan-architect, task-implementer, req-change) can rank findings uniformly.

| Severity | Priority | Rule |
|---|---|---|
| Crítico | P0 | Exploitable threat with **no** mitigation specified that exposes sensitive data or allows auth bypass |
| Alto | P1 | Exploitable gap that blocks safe implementation: no mitigation for a lesser threat, or a partial mitigation that still leaves the attack open |
| Medio | P2 | Mitigation specified but a defense-in-depth layer is missing; not exploitable on its own |
| Bajo | P3 | Documentation or test gap only, no immediate threat |

A partial mitigation therefore caps severity at Alto; note it in the finding.

### Signal filters

1. **Concrete threat** — no threat scenario, no finding.
2. **Evidence** — a *presence* finding (something specified is insufficient or contradictory) cites at least two
   documents: the one with the gap and the one that makes it exploitable (e.g. a UC that exposes the operation).
   An *absence* finding cites the document that should hold the control (per § Where security lives), the missing
   element, and the surface that needs it. "Not specified" alone is not enough.
3. **ADRs and business rules** — check `spec/adr/` and `spec/CLARIFICATIONS.md` first (Principle 4).

## Process

### Phase 0 — Baseline

Read `audits/SECURITY-AUDIT-BASELINE.md` if it exists. Excluded from this run (counted as "excluded by baseline"):
findings in the Baseline table with status **Accepted**, **Won't fix**, or **Deferred** whose re-evaluation date has
not passed. Expired Deferred findings are re-reported. Resolved findings that reappear are `regression`. The
previous findings section is the reference for classifying each finding as `new`, `persistent` or `regression`.
No file → first audit, all findings `new`.

### Phase 1 — Inventory

List the security documents (§ Where security lives) and the security-touching ones: all API contracts, UCs with
authz or sensitive data, domain entities, BDD files. Record counts.

### Phase 2 — Threat surface

Map operations (public / authenticated / admin), sensitive fields and their flows, external integrations
(LLM, OAuth/SSO, third-party APIs, uploads), and trust boundaries (client→API, API→storage, service→service,
API→external). Read `references/security-checklists.md` § 2 for the per-surface checks.

### Phase 3 — Coverage

For each surface element, find its specified mitigation using `references/security-checklists.md` § 1: authn and
role per operation (matrix), tenant isolation and ownership (invariants), protection per sensitive field, key
rotation (ADR + runbook), retention, input schemas and upload limits.

### Phase 4 — Depth

Check each security document is internally complete per § 1 of the checklist (SECURITY.md rows, matrix
completeness and deny-by-default, ADR threat/consequence, runbook steps/rollback/escalation).

### Phase 5 — Traceability

Chain: security requirement / `SEC-NNN` row → `INV-*` or ADR → UC flow → BDD scenario → runbook when an operation is
required. Method in `references/security-checklists.md` § 3.

### Phase 6 — Scorecard

Count findings per dimension (table above), compute scores, global and grade, name the weakest dimensions.

### Phase 7 — Write the report

Read `references/audit-output-format.md`, then write `audits/SECURITY-AUDIT-BASELINE.md`: the first run creates it;
later runs replace the report sections and carry the Baseline table forward (moving closed gaps to Resolved).

## Finding format

```markdown
#### {PREFIX}-{NNN}: {title}

| Field | Value |
|---|---|
| **Severity** | Crítico (P0) / Alto (P1) / Medio (P2) / Bajo (P3) |
| **Status** | new / persistent / regression |
| **Category** | SEC-CAT-{NN}: {name} |
| **OWASP ASVS** | V{N}.{N}.{N} (4.0.3) |
| **CWE** | CWE-{NNN} |
| **Where** | {spec file}:{line or section} |
| **Threat** | {attacker} can {action} because {gap} |
| **What** | {the defect in the spec} |
| **Fix** | {what the spec must specify — a question or the missing element, never an implementation} |
| **Evidence** | {docs cited per signal filter 2} |
| **Existing mitigation** | {partial: …} / none |
```

Example of the precision expected: "AUTH-003: UC-015 login lacks account lockout — `nfr/SECURITY.md` SEC-002
specifies credential hashing but no lockout; UC-015 exposes the operation publicly."

## Remediation path

`sdd-spec-auditor` Mode Fix reads only `audits/AUDIT-BASELINE.md`, so it does not apply these findings. Spec changes
for security findings go through `/sdd-req-change` (one CR per finding or group, citing the finding IDs); the human
decides each one (Art. 12). Record in the report which findings were handed to req-change.

## Parallel mode

For large specs, split the audit into four agents by dimension, each with its own prefixes and ID range 001-099:

| Agent | Prefixes | Reads |
|---|---|---|
| Identity | AUTH-, AUTHZ- | SECURITY.md authn/authz rows, PERMISSIONS-MATRIX, API contracts, UCs with authz, identity/role invariants |
| Data | DATA-, CRYPTO- | SECURITY.md crypto rows, entities/value objects with sensitive fields, crypto ADRs, data invariants, key runbooks |
| Compliance | COMPLY-, INCIDENT- | SECURITY.md audit/incident rows, regulation-related ADRs and UCs, CLARIFICATIONS, incident runbooks |
| Assurance | STEST-, THR-, SADR-, INPUT- | all BDD and property tests, all security ADRs, UC input schemas, API validation, LIMITS.md |

Consolidate: merge; same location + same threat = duplicate (keep the most complete, mark `[CROSS-VALIDATED]` when
two agents found it independently); renumber per prefix; keep the source agent; then build the scorecard.

## Persist summary

After writing the report, update `pipeline-state.json` (if absent, create it from the plugin's
`templates/pipeline-state.template.json` as `sdd-setup` does):
- `stages["security-auditor"]` (lateral key, add if absent): `status: "done"`, `lastRun` = now (ISO-8601).
- `summary`: `artifacts` (e.g. `{"file": "audits/SECURITY-AUDIT-BASELINE.md", "label": "Security Audit Baseline"}`),
  `metrics` `{ total_findings, critical, high, medium, low, global_score, grade, owasp_coverage }`, `highlights` (3-5),
  `nextStep` (`"Resolve P0 security findings via /sdd-req-change before implementation"` or
  `"No P0 security findings — continue the pipeline"`), `generatedAt`.

Commit the report (`git add audits/SECURITY-AUDIT-BASELINE.md`), then `docs(security): …` with `Refs:` the spec ids
with P0/P1 findings, skipped when nothing is staged (plugin-root `references/git-conventions.md` § Stage outputs are committed).

Show the summary table to the user. Handoff: follow the plugin-root `references/handoff-protocol.md` (station mode
only; never from a subagent).
