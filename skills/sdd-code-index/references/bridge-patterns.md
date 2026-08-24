# GitNexus → SDD Bridge Patterns

Reference document for `/sdd-code-index` skill. Defines how GitNexus code intelligence entities map to SDD traceability graph structures.

## Symbol Mapping Rules

### Direct Mapping (Refs: annotations)

When a symbol has a `Refs:` comment within 10 lines above its definition:

```
// Refs: UC-AUTH-001, INV-AUTH-003
export function validateUser(email: string): boolean { ... }
```

Maps to:
```json
{
  "id": "sym-validate-user",
  "name": "validateUser",
  "type": "Function",
  "filePath": "src/auth/validator.ts",
  "startLine": 42,
  "endLine": 68,
  "isExported": true,
  "artifactRefs": ["UC-AUTH-001", "INV-AUTH-003"],
  "inferredRefs": [],
  "callers": [],
  "callees": [],
  "processes": [],
  "community": ""
}
```

### Transitive Inference Rules

When a symbol has NO `Refs:` annotation but calls an annotated symbol:

| Depth | Label | Confidence | Action |
|-------|-------|------------|--------|
| 1 (direct caller) | `inferred` | 0.9 | Add to `inferredRefs[]` |
| 2 (caller of caller) | `inferred` | 0.7 | Add to `inferredRefs[]` |
| 3+ | `suggested` | <0.7 | Do NOT add; list in report recommendations |

**Example:**
```
handleLogin() → calls validateUser()  [Refs: UC-AUTH-001]
  → handleLogin gains inferredRef: UC-AUTH-001 (confidence: 0.9)

authMiddleware() → calls handleLogin() → calls validateUser()
  → authMiddleware gains inferredRef: UC-AUTH-001 (confidence: 0.7)

app.use() → calls authMiddleware() → ...
  → TOO DEEP: listed as suggestion in report only
```

### Confidence Calculation

```
confidence = 1.0 / (depth + 0.1)
  depth=0 (direct): 1.0 (but these are artifactRefs, not inferred)
  depth=1: 0.9
  depth=2: 0.7 (approximately)
  depth=3: 0.5 (below threshold, not added)
```

## Relationship Type Mapping

| GitNexus Concept | SDD Relationship Type | Direction |
|-----------------|----------------------|-----------|
| Symbol has Refs: annotation | `implemented-by-code` | code → artifact |
| Symbol inferred from caller | `inferred-implements` | code → artifact |
| Test references artifact | `tested-by` | test → artifact |
| Process implements flow | `traces-to` | process → WF |

## Community → Domain Mapping

GitNexus assigns symbols to communities (graph clustering). Map these to SDD business domains:

1. Take all symbols in a GitNexus community
2. Collect all `artifactRefs` and `inferredRefs` from those symbols
3. Look up the REQs these artifacts trace to
4. Take the most frequent `classification.businessDomain` from those REQs
5. Assign that domain as the community label

**Fallback**: If no REQs found, use directory structure heuristics:
- `src/auth/` → "Security & Auth"
- `src/api/` → "Integration & APIs"
- `src/ui/` or `src/components/` → "Frontend & UI"
- `src/db/` or `src/data/` → "Data & Storage"

## Process → Workflow Mapping

GitNexus detects execution flows (sequences of function calls). Map these to SDD workflows:

1. For each GitNexus process, collect artifact refs from all steps
2. Find WF artifacts that reference the same UCs/APIs
3. Create `processes[]` entry linking process steps to WF artifact

**Matching heuristic:**
- Process name keywords match WF title keywords (fuzzy match)
- Process entry point matches WF trigger condition
- >50% of process steps reference artifacts in the same WF

## Ref Comment Patterns

The bridge scans for these annotation patterns:

```
// Refs: UC-001, INV-EXT-005       (JS/TS single-line)
/* Refs: REQ-AUTH-001 */            (JS/TS block comment)
# Refs: UC-001                      (Python/Ruby)
// Refs: UC-001                     (Go/Java/C#/Rust)
/// Refs: UC-001                    (Rust doc comment)
-- Refs: UC-001                     (SQL)
```

**Scan window**: 10 lines above the symbol definition. Stops at first blank line or another symbol definition.

## Symbol ID Generation

Symbol IDs are generated as:
```
sym-{kebab-case-name}-{file-hash-4chars}
```

Example: `validateUser` in `src/auth/validator.ts` → `sym-validate-user-a3f2`

This ensures uniqueness when multiple files export the same symbol name.

## Lite Mode Limitations

In Lite mode (no GitNexus), the following are unavailable:

| Feature | Full Mode | Lite Mode |
|---------|-----------|-----------|
| Symbol detection | AST-based (Tree-sitter) | Regex-based |
| Call graph | Complete | Not available |
| Transitive inference | Yes (depth 2) | No |
| Process detection | Yes | No |
| Community detection | Yes | No |
| Symbol types | Precise | Best-effort |
| Cross-file resolution | Yes | No |

Lite mode still provides value by:
- Detecting all `Refs:` annotations in source code
- Building a symbol table with file/line information
- Validating that referenced artifact IDs exist in the graph
- Reporting uncovered files (no `Refs:` annotations at all)

## Schema v4 Extensions

The `codeIntelligence` block is added to the graph root level. It is:
- **Optional**: absent by default, present only after `/sdd-code-index` runs
- **Backward compatible**: all v3 consumers ignore unknown fields
- **Self-contained**: no v3 fields are modified (only extended)

New in v4:
- `codeRefs[].inferred` (boolean): true for transitively inferred refs
- `codeRefs[].confidence` (number): 0.0-1.0 for inferred refs
- Relationship type `inferred-implements`
- `statistics.codeStats.symbolsWithInferredRefs` (number)
