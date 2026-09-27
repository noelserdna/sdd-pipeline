# Verification Prompt (Phase S)

Used by `sdd-gap-detector --semantic` when you judge a (requirement, chunk) pair yourself: in the fallback when
Jev is disabled, and when a decision rule routes a requirement to you. Keep the template unchanged; the only
optional addition is the context block at the end.

## Template

```
VERIFICATION CHECK
==================
Requirement: {REQ-ID}: "{statement}"
Acceptance criteria:
{criteria, one per line}
Code: {path}:{start}-{end}
---
{chunk code}
---

Does this code directly implement the requirement's behavior (the trigger is handled and the required response is
produced), rather than just mentioning related names?

Answer in exactly this JSON format:
{
  "implements": true|false,
  "partial": true|false,
  "evidence": "path:line-line and the function/branch that implements it (or 'No matching implementation found')",
  "confidence": 0.0-1.0
}
```

`partial` is true when only part of the behavior is present, e.g. the main path but not the error cases listed in
the criteria. `confidence` is your probability that `implements` is true, on the same scale as Jev's `implements`,
so the Phase S thresholds (≥0.85 covered, ≤0.15 likely missing) apply to both.

## Confidence scale

| Range | Meaning | Typical evidence |
|-------|---------|------------------|
| 0.85-1.0 | Direct implementation | The handler/service branch that performs the SHALL behavior for the WHEN trigger; names, logic and error paths match the criteria |
| 0.6-0.84 | Indirect or partial | The service used by the implementing code, or the main path without the listed error cases (`partial: true`) |
| 0.3-0.59 | Related but unclear | Data model with the right fields but no behavior; imports of a relevant library without usage |
| 0.0-0.29 | Not this requirement | Different feature, or only the same module |

Evidence cites lines and a function or branch. "The file seems related" is not evidence, and a confidence that
the evidence contradicts (e.g. "no direct implementation, but right directory" at 0.9) is wrong: being in the right
directory is worth 0.3 at most.

## Edge cases

- **Test files** verify behavior; they do not implement it → `implements: false`. Candidate selection should
  already exclude them.
- **Configuration** (env, YAML, JSON settings) enables a requirement but does not implement it → at most 0.5.
- **Index/barrel files** only re-export → `implements: false`; judge the re-exported module instead.
- **Generated code** is judged on content; mention in evidence that it is generated.
- **Split behavior** (route → service → repository): each chunk is judged on its own. A route that only delegates
  scores 0.6-0.8, the service with the logic 0.85+. When no single chunk carries the whole behavior, say so in
  evidence; Phase S then reads the chunks together before deciding.

## Optional context block

When known, append it after the code. It anchors generic code to a domain; it must not change the binary answer.

```
Additional context:
- Business domain: {classification.businessDomain}
- Related use cases: {UC-IDs}
- Related BDD scenarios: {BDD-IDs}
```
