# Extended ID Patterns for Dashboard

Extended regex patterns for extracting artifact IDs from real SDD projects. Superset of `traceability-check/references/traceability-patterns.md` — covers compound IDs, named IDs, and range expansions.

## Definition Patterns (where IDs are defined)

| Type | Regex | Examples | Typical Files |
|------|-------|----------|---------------|
| REQ (simple) | `^#+\s*REQ-(\d{3,4})` | REQ-001, REQ-042 | `requirements/REQUIREMENTS.md` |
| REQ (categorized) | `^#+\s*REQ-([A-Z]{1,4})-(\d{3,4})` | REQ-EXT-001, REQ-CVA-002, REQ-F-001 | `requirements/REQUIREMENTS.md` |
| REQ (table) | `\|\s*REQ-([A-Z]{0,4}-?\d{3,4})\s*\|` | table cells | `requirements/`, `spec/` |
| UC | `^#+\s*UC-(\d{3,4})` | UC-001, UC-041 | `spec/use-cases/` |
| WF | `^#+\s*WF-(\d{3,4})` | WF-001, WF-015 | `spec/workflows/` |
| API (numeric) | `^#+\s*API-(\d{3,4})` | API-001, API-020 | `spec/contracts/` |
| API (named) | `^#+\s*API-([a-z][a-z0-9-]+)` | API-pdf-reader, API-auth-login | `spec/contracts/` |
| BDD (numeric) | `^#+\s*BDD-(\d{3,4})` or `Scenario:\s*BDD-(\d{3,4})` | BDD-001, BDD-042 | `spec/tests/`, `test/` |
| BDD (named) | `Scenario:\s*BDD-([a-z][a-z0-9-]+)` | BDD-extraction, BDD-login-flow | `spec/tests/`, `test/` |
| INV (simple) | `^#+\s*INV-(\d{3,4})` | INV-001, INV-015 | `spec/domain/` |
| INV (scoped) | `^#+\s*INV-([A-Z]{2,6})-(\d{3,4})` | INV-SYS-001, INV-SEC-007 | `spec/domain/` |
| INV (table) | `\|\s*INV-([A-Z]{0,6}-?\d{3,4})\s*\|` | table cells | `spec/` |
| ADR | `^#+\s*ADR-(\d{3,4})` or filename `ADR-(\d{3,4})` | ADR-001 | `spec/adr/` |
| NFR | `^#+\s*NFR-(\d{3,4})` or `\|\s*NFR-(\d{3,4})\s*\|` | NFR-001 | `spec/nfr/` |
| RN | `^#+\s*RN-(\d{3,4})` or `\|\s*RN-(\d{3,4})\s*\|` | RN-001 | `spec/` |
| FASE | `^#+\s*FASE-(\d{1,2})` or filename `FASE-(\d{1,2})` | FASE-0, FASE-3 | `plan/fases/` |
| TASK | `^#+\s*TASK-F(\d{1,2})-(\d{3,4})` | TASK-F0-001, TASK-F2-012 | `task/` |

## Reference Pattern (Universal)

Single regex to match **any** ID reference in running text:

```regex
(REQ|UC|WF|API|BDD|INV|ADR|NFR|RN|FASE|TASK)[-‑](?:[A-Z]{0,6}[-‑])?(?:[a-z][a-z0-9-]*|\d{1,4})(?:[-‑]\d{3,4})?
```

### Breakdown

| Component | Matches |
|-----------|---------|
| `(REQ\|UC\|...)` | Type prefix |
| `[-‑]` | Hyphen or non-breaking hyphen |
| `(?:[A-Z]{0,6}[-‑])?` | Optional category (EXT, SYS, SEC, CVA, F, NF) |
| `(?:[a-z][a-z0-9-]*\|\d{1,4})` | Named ID (pdf-reader) or numeric (001) |
| `(?:[-‑]\d{3,4})?` | Optional sub-number (for TASK-F0-001) |

## Range Expansion

Some documents use range notation. The dashboard must expand these:

| Pattern | Example | Expansion |
|---------|---------|-----------|
| `{ID}..{ID}` | `INV-SEC-001..007` | INV-SEC-001 through INV-SEC-007 |
| `{ID}-{ID}` in lists | `REQ-001-005` | REQ-001 through REQ-005 (only when in range context) |
| `{ID}, {ID}, {ID}` | `UC-001, UC-003, UC-005` | Three separate references |

## Type-to-Stage Mapping

| Artifact Type | Pipeline Stage | Directory |
|---------------|---------------|-----------|
| REQ | requirements-engineer | `requirements/` |
| UC, WF, API, BDD, INV, ADR, NFR, RN | specifications-engineer | `spec/` |
| AUDIT | spec-auditor | `audits/` |
| TEST | test-planner | `test/` |
| FASE | plan-architect | `plan/` |
| TASK | task-generator | `task/` |
| (code) | task-implementer | `src/`, `tests/` |

## Priority Extraction

When found in tables, extract priority from adjacent columns:

| Column Headers | Values |
|----------------|--------|
| Priority, Prioridad | Must Have, Should Have, Could Have, Won't Have |
| MoSCoW | M, S, C, W |
| Level, Nivel | Critical, High, Medium, Low |

## Code Reference Patterns

Scan `src/**/*.{ts,js,tsx,jsx,py,java,go,rs,cs}` for references to SDD artifact IDs.

### JSDoc / Block Comment Refs

```regex
Refs:\s*((?:(?:REQ|UC|INV|RN|WF|API|BDD|ADR|NFR)[-‑][A-Za-z0-9-]+(?:,\s*)?)+)
```

Matches `Refs:` lines inside JSDoc or block comments. Example:

```
/**
 * Validates PDF file size against extraction invariants.
 * Refs: UC-001, INV-EXT-005, RN-001
 */
```

### Inline Comment Refs

```regex
//\s*(REQ|UC|INV|RN|WF|API|BDD|ADR|NFR)[-‑][A-Za-z0-9-]+
```

Matches single-line comments containing artifact IDs. Example:

```typescript
const MAX_SIZE = 52_428_800; // INV-EXT-005
```

### Decorator / Annotation Refs

```regex
@(?:implements|refs|traces)\s*\(\s*['"]?(REQ|UC|INV|WF|API|BDD|ADR|NFR)[-‑][A-Za-z0-9-]+['"]?\s*\)
```

Matches decorator patterns in Python/Java/TypeScript. Example:

```python
@implements("UC-001")
def extract_text(pdf_path: str) -> str:
```

### Symbol Extraction

After finding a Ref, extract the nearest symbol from the surrounding code:

| Language | Pattern | Example |
|----------|---------|---------|
| TypeScript/JS | `export\s+(function\|class\|const\|let\|var\|interface\|type\|enum)\s+(\w+)` | `export function validateSize` |
| TypeScript/JS | `(function\|class\|const\|let\|var)\s+(\w+)` | `const MAX_SIZE` |
| Python | `def\s+(\w+)\|class\s+(\w+)` | `def extract_text` |
| Go | `func\s+(\w+)` | `func ValidateSize` |
| Rust | `fn\s+(\w+)\|struct\s+(\w+)\|enum\s+(\w+)` | `fn validate_size` |
| Java/C# | `(public\|private\|protected)?\s*(static\s+)?(class\|interface\|void\|int\|String\|boolean)\s+(\w+)` | `public void validateSize` |
| Fallback | Use `filename:lineNumber` | `pdf-validator.ts:8` |

**Symbol search scope**: Look backward from the Ref line (up to 5 lines) and forward (up to 2 lines) for the nearest symbol definition.

## Test Reference Patterns

Scan `tests/**/*.{test,spec}.{ts,js,tsx,jsx}` + `tests/**/*.py` + `test/**/*.{test,spec}.{ts,js,tsx,jsx}` for references to SDD artifact IDs.

### Test File Header Refs

Same pattern as Code JSDoc Refs. Example:

```typescript
/**
 * Unit tests for PDF extraction validation.
 * Refs: UC-001, INV-EXT-005
 */
```

### Test Block Description Refs

```regex
(describe|it|test)\(\s*['"`].*?(REQ|UC|INV|BDD|WF|API|ADR|NFR)[-‑][A-Za-z0-9-]+
```

Matches artifact IDs within test/describe/it block descriptions. Example:

```typescript
describe('PDF Validator - UC-001', () => {
  it('validates size per INV-EXT-005', () => { ... });
  it('rejects files exceeding limit per INV-EXT-005', () => { ... });
});
```

### Python Test Refs

```regex
def\s+test_\w+.*?#\s*(REQ|UC|INV|BDD)[-‑][A-Za-z0-9-]+
```

Or docstring-based:

```python
def test_validates_size():
    """Verifies INV-EXT-005: max file size 50MB."""
```

### Test-to-Code Association

Link test files to source files via:

1. **Path convention**: Strip `tests/` prefix + test suffix to find source:
   - `tests/unit/extraction/pdf-validator.test.ts` → `src/extraction/pdf-validator.ts`
   - `tests/integration/auth/login.spec.ts` → `src/auth/login.ts`

2. **Import statements**: Parse imports to find the tested module:
   ```regex
   import\s+.*?\s+from\s+['"]([^'"]+)['"]
   ```
   Example: `import { validateSize } from '../../src/extraction/validators/pdf-validator'`

3. **Test filename pattern**: `{name}.test.{ext}` or `{name}.spec.{ext}` → search for `{name}.{ext}` in `src/`

### Test Name Extraction

Extract the test name from the enclosing test block:

```regex
(?:it|test)\(\s*['"`](.*?)['"`]
```

If the test is inside a `describe` block, prepend the describe name: `"PDF Validator > validates size per INV-EXT-005"`.

### Framework Detection

Detect test framework from project configuration:

| Indicator | Framework |
|-----------|-----------|
| `vitest.config.*` or `import { describe } from 'vitest'` | vitest |
| `jest.config.*` or `import '@jest/globals'` | jest |
| `pytest.ini` or `conftest.py` | pytest |
| `*.spec.ts` + `@angular` in package.json | jasmine/karma |
| Fallback | unknown |

## Classification Taxonomy

### Business Domain (auto-inferred from REQ prefix)

Map REQ category prefixes to business domains:

| Prefixes | Business Domain |
|----------|----------------|
| EXT, CVA, VAL, PRO, DOC, PAR, OCR | Extraction & Processing |
| SEC, AUT, PRV, LOG, CRD, TOK, SSO | Security & Auth |
| UI, UX, DASH, NAV, FORM, MOD, VIS | Frontend & UI |
| DB, IDX, CAC, MIG, STO, BAK, ARC | Data & Storage |
| INT, API, WBH, NOT, MSG, EVT, SYN | Integration & APIs |
| CFG, ENV, DEP, MON, INF, OPS, CI | Infrastructure & DevOps |
| RPT, ANL, MET, KPI, EXP, AGG | Analytics & Reporting |
| USR, ROL, PER, ORG, TEN, ACC | User Management |
| *(no match)* | Other |

**Matching rule**: Use the REQ category segment (e.g., `EXT` in `REQ-EXT-001`). If no category segment exists (e.g., `REQ-001`), classify as "Other".

### Technical Layer (auto-inferred from FASE)

Map FASE numbers to technical layers:

| FASE | Technical Layer |
|------|----------------|
| FASE-0 | Infrastructure |
| FASE-1 through FASE-6 | Backend |
| FASE-7 through FASE-8 | Frontend |
| FASE-9+ | Integration/Deployment |
| *(no FASE link)* | Unknown |

**Inference rule**: For each REQ, follow the traceability chain REQ → UC → TASK → FASE. Use the FASE number to determine the layer. If a REQ maps to multiple FASEs across layers, use the primary (most frequent) layer.

### Functional Category (auto-inferred from REQ section headers)

| Section Header Keywords | Functional Category |
|-------------------------|---------------------|
| Functional, Funcional, Feature, Core | Functional |
| Non-Functional, No Funcional, Quality, Performance, NFR | Non-Functional |
| Security, Seguridad, Auth, Access | Security |
| Data, Datos, Storage, Database, Migration | Data |
| Integration, Integracion, API, External, Webhook | Integration |
| *(no match)* | Functional *(default)* |

**Inference rule**: Find the nearest H2/H3 heading above the REQ definition in `REQUIREMENTS.md`. Match its text against the keywords above.
