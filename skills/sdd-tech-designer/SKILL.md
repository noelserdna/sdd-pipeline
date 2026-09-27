---
name: sdd-tech-designer
description: "Explores technical architecture across 12 dimensions (delivery, style, tech stack, data, auth, API, infra, CI/CD, observability, cost, DX, i18n) with ATAM-lite evaluation; drafts ADRs. Outputs to design/. Triggers: 'technical design', 'tech stack', 'architecture decision', 'design exploration', 'diseno tecnico', 'stack tecnologico', 'ADR'."
---

# SDD Tech Designer

Makes technical decisions explicit, documented and traceable before planning, across 12 dimensions, producing
`design/TECHNICAL-DESIGN.md`, `design/QUALITY-ATTRIBUTES.md`, `design/OPERATION-MAPPING.md` and ADR drafts.

This is an optional lateral skill. `sdd-plan-architect` works without it (its clarify phase covers basic
technical decisions) and consumes `design/` in Phase 0 when it exists. Skip it for simple CRUD apps. When this
skill was not run and a contract declares `Style: operations`, plan-architect produces
`design/OPERATION-MAPPING.md` itself with the same template (`references/output-templates.md` §OPERATION-MAPPING).

| Skill | Relationship |
|-------|-------------|
| `sdd-specifications-engineer` | Prerequisite: at least `spec/domain/` and `spec/use-cases/` exist |
| `sdd-spec-auditor` | Recommended first: audit-clean specs give better design input |
| `sdd-security-auditor` | Its findings feed dimension 5 (Auth & Security) |
| `sdd-plan-architect` | Downstream consumer of `design/` |
| `sdd-req-change` | Spec changes can invalidate design → re-run with `--update` |

## Invocation

| Command | Effect |
|---------|--------|
| `/sdd-tech-designer` | All phases, all applicable dimensions |
| `/sdd-tech-designer --dimensions=1,4,5,7` | Phase 3 only for the listed dimensions (Phases 0-2 still load context) |
| `/sdd-tech-designer --update` | Reads existing `design/`, updates only the dimensions affected by spec changes, keeps other decisions, adds a Document History entry |
| `/sdd-tech-designer --quality-only` | Phases 0-2 only; writes `design/QUALITY-ATTRIBUTES.md` |

## Process

### Phase 0 — Load context

Read `spec/**/*.md`, `requirements/REQUIREMENTS.md`, `spec/adr/ADR-*.md` (existing technology and architecture
decisions), `spec/CLARIFICATIONS.md`, `CLAUDE.md` (Active Technologies, `## SDD Stack Profile`,
`## Stack Conventions`), `audits/SECURITY-AUDIT-BASELINE.md` if present, and `design/*.md` in update mode.
Build an internal manifest (not written): system type, known decisions, constraints (budget, team, compliance),
open security findings.

### Phase 1 — System vision

Identify the system type (web app SPA/SSR/MPA, API service, data pipeline, real-time, CLI, mobile, hybrid),
technical stakeholders (actors from use cases, team from CLAUDE.md, operations from `nfr/`, external systems from
`contracts/`) and hard constraints (budget, compliance from `nfr/SECURITY.md`, platform lock-in, team expertise,
timeline). Draft the vision (type, primary users, scale, key constraint, 3-5 line narrative) and confirm it with
the user before continuing. It becomes TECHNICAL-DESIGN.md §1.

### Phase 2 — Quality attributes (ATAM-lite)

Read `references/quality-attributes.md`. Score the ten attributes from evidence in `spec/nfr/`, invariants, use
cases and the security audit; build the trade-off matrix; present the top 3 trade-offs to the user for
confirmation. Output: `design/QUALITY-ATTRIBUTES.md`.

### Phase 3 — 12-dimension analysis (interactive)

Read `references/dimension-catalog.md` (detection rules, question IDs `DIM-{d}-{nnn}`, options, red flags).

| # | Dimension | # | Dimension |
|---|-----------|---|-----------|
| 1 | Delivery Channels | 7 | Infrastructure |
| 2 | Architecture Style | 8 | CI/CD Pipeline |
| 3 | Tech Stack | 9 | Observability |
| 4 | Data Strategy | 10 | Cost & Scaling |
| 5 | Auth & Security | 11 | Developer Experience |
| 6 | API Design | 12 | i18n & Accessibility |

For each dimension: apply the detection rules; if Resolved, show the evidence and move on; if Partial or Missing,
ask the open questions one at a time, recommended answer first with alternatives; log each decision with its
rationale. The user can skip a dimension ("skip", "n/a") or end the phase ("done", "proceed"). Every decision needs
user confirmation before it is recorded — the skill recommends, the user decides.

### Phase 4 — Generate outputs

Templates: `references/output-templates.md`.

1. `design/TECHNICAL-DESIGN.md` (§TECHNICAL-DESIGN): vision, then per dimension the decision, rationale,
   alternatives, accepted trade-offs and references.
2. `design/QUALITY-ATTRIBUTES.md` (§QUALITY-ATTRIBUTES), if not already written in Phase 2.
3. `design/ADR-DRAFT-NNN-{slug}.md` (§ADR-DRAFT) only for decisions that deserve a formal record — typically
   architecture style, primary database, auth model, deployment platform. Draft numbers are local to `design/`.
4. `design/OPERATION-MAPPING.md` (§OPERATION-MAPPING) when any contract declares `Style: operations` (optional for
   `http`): every `API-` operation mapped, seeded from the stack kit conventions
   (`templates/stacks/<kit>/conventions.md`, CLAUDE.md `## Stack Conventions` / `## SDD Stack Profile`).
5. Persist the summary (below).

Artifacts may include ASCII diagrams, illustrative schema sketches and comparison tables — not implementation
code or config files (docker-compose, terraform), which belong to the implementation stages.

### Promoting ADR drafts

A draft becomes a formal ADR only when the user approves it. On approval, write
`spec/adr/ADR-{NNN}-{slug}.md` where NNN is the next free number in `spec/adr/` (highest existing + 1, three
digits), in the specifications-engineer ADR format (Template 6, Nygard short, Status Accepted), then delete the
draft or mark it `Promoted to ADR-NNN`. This is the only write this skill makes outside `design/`: it changes
`spec/`, so `spec-auditor` and every later stage become stale (re-run from `sdd-spec-auditor`). Mention that in
the closing summary.

## Write scope

- Writes: `design/**`, `pipeline-state.json`, and `spec/adr/ADR-NNN-*.md` only through an approved promotion.
- Reads only: `requirements/`, the rest of `spec/`, `audits/`, `plan/`. Business rules stay in
  `spec/CLARIFICATIONS.md`; a spec gap found here goes to the user (or `sdd-req-change`), not into the specs.

Section headers stay in English; descriptive text follows the user's language; technical terms stay in English.

## Persist summary

After writing the outputs, update `pipeline-state.json` at the project root. If it does not exist, create it from
`templates/pipeline-state.template.json` as `sdd-setup` does, then:

- `stages["tech-designer"].status = "done"`, `.lastRun` = now (ISO-8601)
- `.summary`: `artifacts` (files written in `design/`, plus promoted ADRs), `metrics`
  `{ "dimensions_analyzed", "quality_attributes", "adr_drafts", "trade_offs_evaluated" }`, `highlights` (3-5),
  `nextStep` = `"Run /sdd-plan-architect (design/ will be consumed automatically)"` — or `"Run /sdd-spec-auditor"`
  if an ADR was promoted — and `generatedAt`.

Show the summary table to the user. Handoff: follow the plugin-root `references/handoff-protocol.md` (station
mode only; never from a subagent).
