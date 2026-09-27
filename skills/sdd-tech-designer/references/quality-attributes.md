# Quality Attributes — ATAM-lite (Phase 2)

Output format lives in `output-templates.md` §QUALITY-ATTRIBUTES; this file holds the IDs and scoring rules.

## Attribute IDs

| ID | Attribute | ID | Attribute |
|----|-----------|----|-----------|
| QA-01 | Performance | QA-06 | Usability |
| QA-02 | Security | QA-07 | Testability |
| QA-03 | Scalability | QA-08 | Deployability |
| QA-04 | Reliability | QA-09 | Cost Efficiency |
| QA-05 | Maintainability | QA-10 | Portability |

Scenario IDs: `QA-{NN}-S{N}` (e.g. `QA-01-S1`).

## Importance score (1-5)

5 = failure causes business loss or legal exposure · 4 = significant user/ops impact · 3 = manageable with
workarounds · 2 = deferrable · 1 = not relevant.

Derive each score from evidence, in this order, and cite the source in the table:

1. Explicit target in `spec/nfr/*.md` or a REQ-NF → 4-5
2. Invariant or regulatory constraint implying the attribute → 3-5
3. Implicit need in a use case (e.g. real-time updates → Performance) → 3-4
4. User-stated priority → as stated
5. No evidence → 2, marked "assumed"

## Method

1. Score all ten attributes.
2. For each attribute scoring ≥ 3, write 1-3 scenarios (stimulus, source, environment, response, measurable
   target). Use spec values by name (`VALUE-REGISTRY.md`) when they exist.
3. Map each scenario to the decisions from Phase 3 that help or hurt it; record risk + mitigation.
4. Sensitivity points: decisions that move several attributes at once (typically database, auth model,
   caching, deployment model).
5. Trade-off points: decisions that improve one attribute by degrading another; record the resolution and
   which score justified it.
6. Present the top 3 trade-offs to the user for confirmation before writing.

## Minimum assessment

When the user wants a quick pass (or `--quality-only` on a small system): top 3 attributes, one trade-off
between the top two, one scenario for the most critical attribute.
