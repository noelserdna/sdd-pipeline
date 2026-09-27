# Security Checklists

> Project-specific items to verify in `spec/`, grouped by the document or surface that should hold them. Each unmet
> item becomes a finding only when it enables a concrete threat (SKILL.md § Signal filters). IDs in the right
> column are the SEC-CAT the finding belongs to.

## 1. Documents

| Document | Verify | SEC-CAT |
|---|---|---|
| `nfr/SECURITY.md` (`SEC-NNN` rows) | one row per control area — authn, authz, crypto, audit/logging, incident response; a category that does not apply is one row `Not applicable (ADR-NNN)` | 02-07 |
| | authn: method + parameters, credential hashing with cost, token claims/expiry, refresh rotation, revocation, lockout, MFA + recovery, service-to-service auth | 02 |
| | crypto: named algorithm (AEAD), key source, IV/nonce uniqueness, rotation period, recovery, list of encrypted fields | 06 |
| | security-event taxonomy with severity per type and event structure; log retention | 07 |
| | numeric values cited by name from `VALUE-REGISTRY.md` / `nfr/LIMITS.md`, consistent with them | 05 |
| `contracts/PERMISSIONS-MATRIX.md` | every operation in `contracts/API-*.md` and every role in `domain/02-ENTITIES.md` present; deny-by-default stated; scope qualifiers (own / org / all); destructive ops restricted; super-admin bypass bounded | 03 |
| `contracts/API-*.md` | auth requirement per operation (`Style: http`: per route); input schema per argument; error shapes leak no internals; sensitive data never in URL/query | 02, 04, 05 |
| `domain/02-ENTITIES.md`, `03-VALUE-OBJECTS.md` | PII / sensitive fields marked and classified; encrypted value objects named | 04 |
| `domain/05-INVARIANTS.md` | `INV-{AREA}-NNN` rows enforce tenant isolation, ownership (IDOR), retention, audit-trail immutability where the requirements demand them | 03, 04, 07 |
| `use-cases/UC-*.md` | authz precondition per UC; input limits; privacy-rights UCs (access, erasure, portability, restriction, consent withdrawal) when a regulation applies | 03, 05, 08 |
| `adr/ADR-*.md` | every security choice (auth strategy, crypto, trust boundaries, retention, rate limiting) has an ADR whose context names the threat and whose consequences name residual risk | 10 |
| `runbooks/RB-*.md` | exists when a REQ/NFR/ADR demands an operation: key rotation, key recovery, incident response, breach notification, audit-trail integrity; each with prerequisites, verified steps, rollback, escalation | 07 |
| `tests/BDD-UC-*.md`, `tests/PROPERTY-TESTS.md` | negative scenarios: bad/expired/revoked credential, wrong role, wrong tenant, lockout, invalid/oversized input, rate limit, privacy-rights flows; property tests for security invariants | 09 |

## 2. Attack surfaces (Phase 2)

| Surface | Verify |
|---|---|
| Public operations | authn, rate limit, input validation, CORS / content-type policy when HTTP |
| File upload/download | type allow-list, size limit, non-executable storage, access control on stored files |
| LLM integration | prompt-injection mitigation, output handling, token/cost limits, no PII sent unless decided in an ADR |
| SSO / OAuth | PKCE, state/nonce, token signature/audience/issuer validation, account-linking policy |
| Service-to-service | authentication, timing-safe secret comparison, secret rotation |

## 3. Traceability (Phase 5)

For each security-related requirement (`REQ-NF-NNN` or `REQ-F-NNN` whose subject is a security control, and each
`SEC-NNN` row): count the `INV-*` rows, ADRs and BDD scenarios that cite it. Zero BDD = SEC-CAT-09; zero INV and
zero ADR for an enforceable control = SEC-CAT-01/03/04 by subject; a security ADR demanding an operation without a
runbook = SEC-CAT-07.

## 4. CWE quick map

| SEC-CAT | Typical CWE |
|---|---|
| 01 | CWE-1053 |
| 02 | CWE-287, 306, 307, 613 |
| 03 | CWE-285, 639, 862 |
| 04 | CWE-311, 312, 532, 359 |
| 05 | CWE-20, 434, 89, 79 |
| 06 | CWE-327, 326, 330, 323 |
| 07 | CWE-778, 223 |
| 08 | CWE-359 (+ regulation article) |
| 09 | CWE-1053 / CWE of the untested control |
| 10 | CWE-1059 |
