# Tasks: FASE-4 — Extraction

> **Critical path:** TASK-F4-001 → TASK-F4-002 → TASK-F4-003 → TASK-F4-004

## Stream Ownership

| Stream | Tasks | Owns (write-set) | Runs in |
|--------|-------|------------------|---------|
| base | — | — | main checkout, before worktrees (checkpoint `fase-4-foundation`) |
| A | TASK-F4-001, TASK-F4-002, TASK-F4-003 | src/extraction/**, tests/extraction/**, tests/doubles/**, tests/contract/** | worktree `feat/fase-4-a` |
| integración | — | — | main checkout, after `--integrate --fase 4` |
| verificación | TASK-F4-004 | — | main checkout, Phase 9 |

### Rollback Checkpoints

| Checkpoint | After Task | Tag | Runs in |
|-----------|------------|-----|---------|
| Verified | TASK-F4-004 | `fase-4-verified` | main checkout |

## Slices

### UC-012 — Extract a CV

- [ ] TASK-F4-001 Extract the CV with the LLM port and its fake, test-first | `src/extraction/extract.ts`, `src/extraction/llm-client.ts`, `tests/doubles/llm-fake.ts`, `tests/extraction/extract.test.ts`
  - **Commit:** `feat(extraction): extract a CV through the LlmClient port`
  - **Acceptance:** Test first: `REQ-F-078 AC1` extraction fills name and email from the fake's answer
  - **Refs:** FASE-4, REQ-F-078, UC-012

- [ ] TASK-F4-002 Anthropic adapter for LlmClient, test-first | `src/extraction/anthropic-llm.ts`, `tests/extraction/anthropic-llm.test.ts`
  - blocked-by: TASK-F4-001
  - **Commit:** `feat(extraction): Anthropic adapter for LlmClient`
  - **Acceptance:** Test first: reads the model and key from config, never from constants
  - **Refs:** FASE-4, REQ-F-078, ADR-004

- [ ] TASK-F4-003 Contract test LlmClient: double and real provider agree | `tests/contract/llm-client.contract.test.ts`
  - blocked-by: TASK-F4-001, TASK-F4-002
  - **Commit:** `test(extraction): contract test for the LlmClient double and its real provider`
  - **Acceptance:** Test first: `CONTRACT-LlmClient REQ-F-078 AC1` runs the same assertions on the double and on the real provider driven through a fake transport that captures the request; observable: the request carries the extraction instructions, the CV text and the model from config
  - **Refs:** FASE-4, REQ-F-078, PLAN-FASE-4 §4.3

## Verification

- [ ] TASK-F4-004 Journey FASE-4: upload a CV and see the extracted fields | `acceptance/tests/fase-4.journey.spec.ts`
  - blocked-by: TASK-F4-003
  - **Commit:** `test(extraction): FASE-4 journey from the user's route with captures`
  - **Acceptance:**
    - Test first: named `REQ-F-078 AC1 …`
    - Enters through Demo step 1 (`/candidates/new`), never an internal entry point
    - Asserts the example text on the element that shows it (`toHaveText('Ada Lovelace')`), not the container's visibility
    - Saves `evidencias/FASE-4/REQ-F-078-AC1.png` and `evidencias/FASE-4/FASE-4.webm`, attached to the test
  - **Refs:** FASE-4, REQ-F-078
