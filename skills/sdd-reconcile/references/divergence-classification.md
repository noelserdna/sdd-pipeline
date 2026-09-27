# Divergence Classification Rules

> Used by Phase 4 of `sdd-reconcile`. Each divergence gets one type and one confidence level, both justified by cited evidence.

## 1. Algorithm

```
classify(spec_artifact, code_feature):

  code exists, spec does not:
    tests exist and pass (run this session)        → NEW_FUNCTIONALITY
    called by other modules, or added in a commit  → NEW_FUNCTIONALITY
    otherwise (dead code? experiment?)             → AMBIGUOUS

  spec exists, code does not:
    git history shows the implementation was removed      → REMOVED_FEATURE
    no implementation ever existed in history             → NOT_IMPLEMENTED
    history unclear (accidental removal vs. intentional)  → AMBIGUOUS

  both exist, behaviour differs:
    tests pass and assert the code's behaviour     → BEHAVIORAL_CHANGE
    tests fail against the spec'd behaviour        → BUG_OR_DEFECT
    no tests, recent commit explains the change    → BEHAVIORAL_CHANGE
    otherwise                                      → AMBIGUOUS

  both exist, behaviour equivalent:
    path/name/file moved, or internals changed with the same contract → REFACTORING
```

`NOT_IMPLEMENTED` is a missing implementation, not drift: code never drives specs (Art. 12). It is never deprecated or auto-resolved; the report lists it as a gap for `sdd-task-generator --fase=N --incremental`.

## 2. Confidence — evidence rules

Confidence comes from which evidence is present, not from arithmetic.

| Level | Rule | Effect |
|---|---|---|
| **HIGH** | Decisive evidence for the type is present and nothing contradicts it. Decisive = a test result from a run in this session, or a commit that shows the addition / removal / rename / change | Auto types apply after the summary |
| **MEDIUM** | Only indirect evidence (usage by other modules, naming, recency, comments) and nothing contradicts it | Auto types are listed individually in the summary so the user can veto |
| **LOW** | Evidence conflicts, or is missing | Becomes `AMBIGUOUS` and is asked |

Counter-signals lower the level by one: a TODO/FIXME at the divergence, a feature flag or A/B variant around it, signals pointing to different types. Tests that were not run are not evidence.

Useful evidence per type:

- **NEW_FUNCTIONALITY:** passing tests; imported/called elsewhere; error handling and doc comments (intended to stay).
- **REMOVED_FEATURE:** deletion commit; related tests removed in the same change; the spec depends on a library or API that no longer exists.
- **NOT_IMPLEMENTED:** no symbol, route or test ever matched in `git log -S`/`git log --follow`; the REQ has no `Refs:` in any commit.
- **BEHAVIORAL_CHANGE:** tests updated to the new behaviour; commit message states the change; the spec was not touched in the same period.
- **REFACTORING:** tests pass unmodified; git records a rename; same signature under a new name.
- **BUG_OR_DEFECT:** failing tests; validation weaker than the spec; missing error handling the spec requires; crashes.

## 3. Edge Cases

| Case | Classification |
|---|---|
| Entity partially implemented (spec 5 fields, code 3) | Missing fields never existed → `NOT_IMPLEMENTED`; removed → `REMOVED_FEATURE` or ask; extra code fields → `NEW_FUNCTIONALITY` |
| Feature behind a flag that is off, spec says active | `BEHAVIORAL_CHANGE`; ask whether the flag is temporary |
| Two variants (A/B) where the spec describes one | `BEHAVIORAL_CHANGE`; ask whether to document both or the winner |
| Migration exists but not applied | Not a divergence; note as operational |
| Third-party API changed, code adapted, spec references the old contract | `BEHAVIORAL_CHANGE` with external trigger; ask the user and recommend option (A) |
