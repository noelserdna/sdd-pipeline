# Verification Prompt Template

This document defines the structured prompt template used by `sdd-verify-coverage` Phase 3 to verify whether a source code file implements a given requirement.

## Prompt Template

```
VERIFICATION CHECK
==================
Requirement: {REQ-ID}: "{requirement_text}"
File: {file_path}
File content (first 200 lines):
---
{content}
---

Does this file contain code that directly implements the above requirement?

Answer in EXACTLY this JSON format:
{
  "implements": true|false,
  "evidence": "Brief quote or description of the implementing code (or 'No matching implementation found')",
  "confidence": 0.0-1.0
}
```

## Confidence Scoring Guidelines

### 0.9 - 1.0: Clear, Direct Implementation

The file contains code that **directly and unambiguously** implements the requirement. Indicators:

- Function/class names match the requirement's action (e.g., `encryptPII()` for "encrypt PII at rest")
- Business logic mirrors the requirement's behavior specification
- EARS syntax elements (WHEN trigger, SHALL behavior) are directly traceable to code branches
- Tests or validation logic confirm the behavior

**Example — Good response at 0.95:**
```json
{
  "implements": true,
  "evidence": "Line 45-62: encryptAtRest() applies AES-256-GCM to all fields marked as PII in the user schema, matching the requirement's 'encrypt all PII at rest' specification",
  "confidence": 0.95
}
```

### 0.7 - 0.8: Indirect Implementation

The file contains code that **partially or indirectly** implements the requirement. Indicators:

- Helper functions that contribute to the requirement but don't fully satisfy it alone
- Shared utilities used by the implementing code (e.g., a crypto library used for PII encryption)
- Partial coverage — some aspects of the requirement are addressed but not all
- Configuration or setup code needed for the requirement to work

**Example — Good response at 0.75:**
```json
{
  "implements": true,
  "evidence": "Line 12-30: CryptoService class provides encrypt/decrypt methods using AES-256-GCM. This is the underlying service used for PII encryption, though the PII-specific logic may reside elsewhere",
  "confidence": 0.75
}
```

### 0.5 - 0.6: Possible but Ambiguous

The file contains code that **might** relate to the requirement but the connection is unclear. Indicators:

- Generic code that could serve multiple purposes, one of which is the requirement
- Data models that include fields mentioned in the requirement but no behavior
- Import/dependency of a library relevant to the requirement without usage
- Comments referencing the requirement's domain but no clear implementation

**Example — Good response at 0.55:**
```json
{
  "implements": true,
  "evidence": "Line 8: imports '@encryption/aes' module and Line 22: UserSchema includes a 'piiFields' array, but no encryption logic is applied in this file",
  "confidence": 0.55
}
```

### Below 0.5: Unlikely Match

The file does **not appear** to implement the requirement. Indicators:

- No relevant function names, variables, or logic
- Different domain entirely
- Only tangential relationship (e.g., same module but different feature)

**Example — Good response at 0.2:**
```json
{
  "implements": false,
  "evidence": "No matching implementation found. This file handles user authentication (login/logout) with no references to encryption or PII handling",
  "confidence": 0.2
}
```

## Examples of Bad Responses

### Bad: Vague evidence
```json
{
  "implements": true,
  "evidence": "The file seems related",
  "confidence": 0.8
}
```
**Why bad**: Evidence must cite specific lines, functions, or code patterns. "Seems related" is not actionable.

### Bad: Confidence mismatch
```json
{
  "implements": true,
  "evidence": "No direct implementation found but the file is in the right directory",
  "confidence": 0.9
}
```
**Why bad**: Being in the right directory warrants 0.3-0.4 at best, not 0.9. Evidence contradicts confidence.

### Bad: Over-scoped evidence
```json
{
  "implements": true,
  "evidence": "Lines 1-200: The entire file implements various security features including encryption, authentication, authorization, rate limiting, and CORS configuration",
  "confidence": 0.85
}
```
**Why bad**: Evidence should pinpoint the specific lines/functions relevant to the requirement, not describe the entire file.

### Bad: Missing JSON format
```
Yes, this file implements the requirement. The encrypt function on line 45 handles PII encryption.
```
**Why bad**: Must use the exact JSON format specified. Free-text answers cannot be parsed programmatically.

## Edge Cases

### Utility Files and Shared Libraries

Files like `src/utils/crypto.ts` or `src/lib/validators.ts` may contain generic utilities used by multiple requirements.

**Handling**: Score at 0.7-0.8 if the utility directly provides the capability specified in the requirement (e.g., encryption functions for an encryption requirement). Score at 0.5-0.6 if the utility is generic and only incidentally useful.

### Test Files

Test files (`tests/`, `__tests__/`, `*.test.*`, `*.spec.*`) should NOT be considered as implementations of requirements. They verify implementations.

**Handling**: If a test file is encountered as a candidate, score `implements: false` with evidence noting "This is a test file that verifies the implementation, not the implementation itself." The verification targets `src/` files only, but if a test file appears in candidates due to keyword matching, reject it.

### Configuration Files

Files like `config/*.json`, `*.env`, `docker-compose.yml` may contain settings related to requirements (e.g., encryption key configuration).

**Handling**: Score at 0.5-0.6 maximum. Configuration enables a requirement but does not implement it. Note in evidence: "Configuration supporting the requirement, not implementation."

### Index/Barrel Files

Files like `src/index.ts` or `src/modules/auth/index.ts` that re-export from other modules.

**Handling**: Score `implements: false`. These files are structural, not behavioral. The actual implementation is in the re-exported files.

### Generated Code

Files with headers like `// AUTO-GENERATED` or `// DO NOT EDIT` are generated from schemas or specs.

**Handling**: Score normally based on content, but note in evidence that the file is auto-generated. The generated code may still implement requirements.

### Large Files (> 200 lines)

Only the first 200 lines are read. The implementation may exist beyond line 200.

**Handling**: If the first 200 lines show the file is in the right domain (correct imports, related class/module) but no specific implementation is visible, score at 0.5-0.6 with evidence noting "File appears relevant based on imports and structure, but implementation may be beyond the 200-line read limit."

### Multi-file Implementations

Some requirements are implemented across multiple files (e.g., route handler + service + repository).

**Handling**: Each file is checked independently. A service file that handles business logic scores 0.9+. A route file that delegates to the service scores 0.7-0.8. A repository file that stores data scores 0.7 if the requirement is about data persistence, lower otherwise. The consumer of verification results can aggregate across files.

## Prompt Customization

The base template should NOT be modified during execution. However, the skill may optionally append domain-specific hints when available:

```
Additional context:
- This requirement is in the "{domain}" domain
- Related use cases: {UC-IDs}
- Related BDD scenarios: {BDD-IDs}
```

This additional context helps disambiguate generic code by providing domain anchoring, but it must not bias the binary judgment.
