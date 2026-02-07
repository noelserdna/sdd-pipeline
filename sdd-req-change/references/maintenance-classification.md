# Maintenance Classification Reference (ISO 14764 + SWEBOK v4 Ch05)

Quick reference for classifying incoming changes by maintenance category. Use this to tag every Change Request (CR) with its ISO 14764 maintenance type, ensuring consistent triage, prioritization, and traceability throughout the sdd-req-change workflow.

---

## 1. ISO 14764 Maintenance Categories

| Category      | Definition                                                                 | Signal Phrases                                                                 |
|---------------|---------------------------------------------------------------------------|--------------------------------------------------------------------------------|
| **Corrective**  | Reactive modification to fix discovered faults.                          | "this is broken", "bug", "defect", "doesn't work as expected"                 |
| **Adaptive**    | Modification to keep software usable in a changed environment.           | "dependency updated", "API changed", "platform migration", "new regulation"   |
| **Perfective**  | Modification to improve performance, maintainability, or add features.   | "new feature", "enhancement", "improve UX", "optimize"                        |
| **Preventive**  | Modification to detect and correct latent faults before they become operational. | "tech debt", "refactor", "proactive cleanup", "reduce complexity"      |

---

## 2. Classification Decision Tree

```
Is there a defect/fault in existing behavior?
├── YES → Corrective
└── NO
    ├── Is there an external change forcing adaptation?
    │   ├── YES → Adaptive
    │   └── NO
    │       ├── Is the user requesting new capability or enhancement?
    │       │   ├── YES → Perfective
    │       │   └── NO
    │       │       └── Is this proactive improvement with no immediate user need?
    │       │           ├── YES → Preventive
    │       │           └── NO → Re-evaluate scope (may not be a maintenance request)
```

---

## 3. Mapping to sdd-req-change Types

| ISO Category  | Change Type   | Example                                            |
|---------------|---------------|----------------------------------------------------|
| Corrective    | MODIFY        | Fix incorrect behavior (e.g., wrong validation rule) |
| Adaptive      | MODIFY        | Update API contract for new external version        |
| Adaptive      | ADD           | Add support for new authentication provider         |
| Perfective    | ADD           | New feature requirement                             |
| Perfective    | MODIFY        | Enhance existing feature                            |
| Perfective    | DEPRECATE     | Simplify by removing unused feature                 |
| Preventive    | MODIFY        | Refactor spec to reduce complexity                  |
| Preventive    | DEPRECATE     | Remove tech debt source                             |

> **Note:** Corrective changes are almost always MODIFY (fixing existing behavior). ADD is rare for corrective unless a missing safeguard is the root cause. DEPRECATE is never corrective.

---

## 4. Urgency Levels (for Corrective Maintenance)

| Level          | Label     | Description                            | Expected Response |
|----------------|-----------|----------------------------------------|-------------------|
| **P0**         | Critical  | Production down, data loss risk.       | Immediate         |
| **P1**         | High      | Major feature broken, no workaround.   | Same day          |
| **P2**         | Medium    | Feature broken, workaround exists.     | Next sprint       |
| **P3**         | Low       | Minor defect, cosmetic issue.          | Backlog           |

> Urgency levels apply primarily to **Corrective** maintenance. Adaptive changes inherit urgency from the external deadline (e.g., API sunset date). Perfective and Preventive changes are prioritized through normal backlog grooming.

---

## 5. Technical Debt Register Format

Track technical debt items identified during change analysis:

```markdown
| TD-ID   | Source CR | Category           | Description                        | Impact       | Priority | Target FASE | Status    |
|---------|-----------|--------------------|------------------------------------|--------------|---------:|-------------|-----------|
| TD-001  | CR-012    | Design Debt        | Circular dependency in auth module | High         | P1       | FASE-03     | Open      |
| TD-002  | CR-015    | Test Debt          | Missing integration tests for API  | Medium       | P2       | FASE-04     | Scheduled |
```

### Rules

- Each debt item gets a **TD-NNN** identifier.
- Link to the originating CR that surfaced or created the debt.
- Categorize as one of:
  - **Design Debt** -- Architectural or design-level shortcuts.
  - **Code Debt** -- Implementation-level issues (duplication, complexity).
  - **Test Debt** -- Missing or inadequate test coverage.
  - **Documentation Debt** -- Outdated, missing, or inconsistent docs/specs.
- Track status through its lifecycle: **Open** | **Scheduled** | **Resolved**.
- Review the register at each FASE boundary to decide carry-forward vs. resolution.

---

## 6. Feature Sunset Planning Template

When a DEPRECATE change is approved, follow this 4-phase sunset plan:

### Phase 1: Announce (Sprint N)

- [ ] Mark feature as deprecated in all relevant spec documents.
- [ ] Add deprecation warnings in API responses (e.g., `Deprecation` header).
- [ ] Notify affected users/stakeholders via appropriate channels.
- [ ] Update release notes with deprecation notice.

### Phase 2: Disable New (Sprint N+1)

- [ ] Prevent new usage of the deprecated feature.
- [ ] Block new configurations that depend on the deprecated feature.
- [ ] Return informative errors for new adoption attempts.
- [ ] Update onboarding docs to exclude deprecated paths.

### Phase 3: Migrate (Sprint N+2..N+4)

- [ ] Migrate existing users/data to the replacement feature.
- [ ] Provide migration tools/scripts where applicable.
- [ ] Track migration progress (% of users/data migrated).
- [ ] Support parallel operation during migration window.

### Phase 4: Remove (Sprint N+5)

- [ ] Remove code and spec artifacts for the deprecated feature.
- [ ] Clean all traceability references (REQ, UC, WF, API, BDD).
- [ ] Archive final state for historical reference.
- [ ] Confirm zero residual dependencies.

### Sunset Checklist

Before initiating Phase 1, verify:

- [ ] Replacement feature exists and is production-ready?
- [ ] Migration path documented and reviewed?
- [ ] All affected users notified?
- [ ] Data migration tested in staging environment?
- [ ] Rollback plan exists in case of migration failure?
- [ ] Timeline approved by stakeholders?

---

## 7. Integration with Change Report

Maintenance classification appears in the Change Report under **Section 7.6**. Each CR processed by sdd-req-change includes its ISO category and urgency:

```markdown
### 7.6 Maintenance Classification (ISO 14764)

| CR-ID   | ISO Category | Urgency | Notes                                      |
|---------|--------------|---------|--------------------------------------------|
| CR-001  | Corrective   | P1      | Validation bypass in login flow             |
| CR-002  | Adaptive     | --      | OAuth provider v2 migration (deadline: Q3)  |
| CR-003  | Perfective   | --      | New dashboard export feature                |
| CR-004  | Preventive   | --      | Reduce cyclomatic complexity in auth module |
```

> Urgency is only assigned for Corrective entries. Adaptive entries may note external deadlines in the Notes column. Perfective and Preventive entries use standard backlog priority.
