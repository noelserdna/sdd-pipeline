# Divergence Classification Rules

> Algoritmo y reglas para clasificar divergencias entre especificaciones SDD y código. Utilizado por la Fase 4 de `sdd-reconcile`.

---

## 1. Classification Algorithm

```
FUNCTION classify_divergence(spec_artifact, code_feature):

    IF code_feature EXISTS and spec_artifact NOT EXISTS:
        # Code has something specs don't mention
        IF code_feature.has_tests AND tests_pass:
            RETURN NEW_FUNCTIONALITY (confidence: HIGH)
        ELIF code_feature.is_actively_used (called by other modules):
            RETURN NEW_FUNCTIONALITY (confidence: MEDIUM)
        ELIF code_feature.recent_commits (< 90 days):
            RETURN NEW_FUNCTIONALITY (confidence: MEDIUM)
        ELSE:
            RETURN AMBIGUOUS (confidence: LOW)
            # Could be dead code, experimental feature, or undocumented feature

    ELIF spec_artifact EXISTS and code_feature NOT EXISTS:
        # Specs describe something code doesn't have
        IF spec_artifact.was_previously_implemented (git history shows removal):
            RETURN REMOVED_FEATURE (confidence: HIGH)
        ELIF no_code_ever_existed (no git history of implementation):
            RETURN REMOVED_FEATURE (confidence: MEDIUM)
            # Spec describes planned but never-implemented feature
        ELSE:
            RETURN AMBIGUOUS (confidence: LOW)
            # Could be bug (accidental removal) or intentional removal

    ELIF both_exist AND behavior_differs:
        # Both exist but do different things
        IF tests_exist AND tests_pass_with_current_code:
            IF tests_match_code_behavior (not spec):
                RETURN BEHAVIORAL_CHANGE (confidence: HIGH)
                # Code and tests agree, spec is outdated
            ELSE:
                RETURN AMBIGUOUS (confidence: LOW)
        ELIF tests_exist AND tests_fail:
            RETURN BUG_OR_DEFECT (confidence: HIGH)
            # Tests enforce spec behavior, code violates it
        ELIF no_tests:
            IF code_change_is_recent (< 30 days):
                RETURN BEHAVIORAL_CHANGE (confidence: MEDIUM)
            ELSE:
                RETURN AMBIGUOUS (confidence: LOW)

    ELIF both_exist AND behavior_equivalent:
        # Structure changed but outcome is the same
        IF api_path_changed OR method_renamed OR file_moved:
            RETURN REFACTORING (confidence: HIGH)
        ELIF internal_structure_changed BUT api_contract_same:
            RETURN REFACTORING (confidence: HIGH)
        ELSE:
            RETURN REFACTORING (confidence: MEDIUM)
```

---

## 2. Signal Details by Type

### NEW_FUNCTIONALITY

| Signal | Weight | Description |
|--------|--------|-------------|
| Code feature has passing tests | 3 | Strong evidence of intentional feature |
| Feature is imported/called by other modules | 2 | It's integrated into the system |
| Recent git commits added this feature | 2 | Actively developed |
| Feature has error handling | 1 | Developer cared about quality |
| Feature has documentation comments | 1 | Developer intended it to stay |
| No spec mentions this feature at all | Required | Base condition |

**Auto-resolution:** Update specs to document the new functionality.

### REMOVED_FEATURE

| Signal | Weight | Description |
|--------|--------|-------------|
| Git history shows code deletion | 3 | Clear evidence of intentional removal |
| No code references the spec artifact | 2 | Nothing implements it |
| Related tests were also removed | 2 | Removal was deliberate |
| Spec references a deprecated API/library | 1 | Feature became impossible |
| Time since last code for this feature > 180 days | 1 | Long-abandoned |

**Auto-resolution:** Mark spec artifacts as deprecated.

### BEHAVIORAL_CHANGE

| Signal | Weight | Description |
|--------|--------|-------------|
| Tests pass with current (changed) behavior | 3 | Tests were updated to match new behavior |
| Change was in a recent commit with clear message | 2 | Intentional modification |
| Change affects API response shape | 2 | Contract change |
| Change affects validation rules | 2 | Business rule change |
| Spec was not updated in same timeframe | 1 | Spec lagged behind |

**User decision required.** Present both spec and code versions.

### REFACTORING

| Signal | Weight | Description |
|--------|--------|-------------|
| API response/behavior unchanged | 3 | Black-box equivalent |
| Tests still pass without modification | 3 | Behavioral preservation confirmed |
| File renamed/moved (git tracks rename) | 2 | Structural change only |
| Method/function renamed but signature equivalent | 2 | Naming change |
| Internal implementation changed, interface same | 2 | Encapsulation respected |

**Auto-resolution:** Update technical references in specs (paths, names).

### BUG_OR_DEFECT

| Signal | Weight | Description |
|--------|--------|-------------|
| Tests exist and FAIL | 3 | Regression detected |
| Code contradicts spec in data-critical area | 2 | Data integrity risk |
| Error handling missing where spec requires it | 2 | Reliability gap |
| Validation weaker than spec requires | 2 | Security/data risk |
| Code crashes or throws unexpected errors | 3 | Obvious defect |

**User decision required.** Ask whether to fix code or update spec.

### AMBIGUOUS

| Signal | Weight | Description |
|--------|--------|-------------|
| Could be new feature OR dead code | — | No tests, unclear usage |
| Could be removal OR bug | — | No git history of removal |
| Behavioral difference but no tests to confirm | — | Unclear intent |
| Feature flag involved | — | May be experimental |
| A/B test variant | — | May be temporary |

**User decision required.** Present evidence and ask for classification.

---

## 3. Auto-Resolution Rules

### Rules for `NEW_FUNCTIONALITY` (auto-resolve)

1. Generate a new requirement in EARS syntax
2. Add to the appropriate requirement group based on:
   - Directory/module → business domain
   - Feature type → functional/non-functional
3. Generate corresponding use case entry
4. If it's an API endpoint, add to contracts
5. Mark with `[RECONCILED]` tag and source reference

### Rules for `REMOVED_FEATURE` (auto-resolve)

1. Mark requirement as: `[DEPRECATED] — Code removed, detected {date}`
2. Update use case status to `deprecated`
3. Do NOT delete the spec entry — preserve for traceability
4. Add note: "Feature no longer present in codebase as of reconciliation {date}"
5. If requirement has downstream traces (UC, WF, BDD), mark those as deprecated too

### Rules for `REFACTORING` (auto-resolve)

1. Update file path references: `src/old/path.ts` → `src/new/path.ts`
2. Update method/function name references
3. Update API path if it changed (but behavior is same)
4. Preserve all traceability links (just update the target)
5. Do NOT change requirement text or use case description (behavior unchanged)

---

## 4. Edge Cases

### Partial Implementation

**Scenario:** Spec describes 5 fields on an entity, code only implements 3.
**Classification:** `BEHAVIORAL_CHANGE` if the missing fields were once present, `NEW_FUNCTIONALITY` + `REMOVED_FEATURE` split if code has extra fields not in spec.
**Resolution:** Present to user — may be incomplete implementation.

### Feature Flags

**Scenario:** Code has a feature behind a feature flag that's currently OFF.
**Classification:** If spec describes the feature as active → `BEHAVIORAL_CHANGE` (feature is disabled).
**Resolution:** Ask user — is the flag temporary or is the feature being rolled out?

### A/B Tests

**Scenario:** Code has two implementations of the same feature (variant A and B).
**Classification:** `BEHAVIORAL_CHANGE` if spec only describes one variant.
**Resolution:** Ask user — document both variants or just the winner?

### Database Migration Pending

**Scenario:** Spec describes a new field, migration exists but hasn't run, code references it.
**Classification:** Not a divergence — spec and code agree, migration is an operational concern.
**Resolution:** Skip (note as operational TODO if migration detection is possible).

### Third-Party API Change

**Scenario:** External API changed, code adapted, spec still references old API contract.
**Classification:** `BEHAVIORAL_CHANGE` with external trigger.
**Resolution:** Auto-resolve toward code (external change is authoritative).

---

## 5. Confidence Thresholds

| Confidence | Action |
|-----------|--------|
| **HIGH** (>80%) | Apply classification and resolution rule automatically |
| **MEDIUM** (50-80%) | Apply classification but flag for review in report |
| **LOW** (<50%) | Classify as `AMBIGUOUS` and ask user |

### Upgrading Confidence

- If test evidence exists → +20% confidence
- If git history confirms the pattern → +15% confidence
- If multiple signals agree → +10% per additional signal
- If naming/comments explain the change → +10% confidence

### Downgrading Confidence

- If conflicting signals exist → -20% confidence
- If the change is in a complex area (many dependencies) → -10% confidence
- If the code has TODO/FIXME near the divergence → -15% confidence
