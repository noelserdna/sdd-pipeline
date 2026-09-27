---
name: sdd-orchestrator
description: "Drives the whole SDD pipeline interactively from a project idea or existing requirements to working, tested software: runs each stage skill in order, resumes from pipeline-state.json and asks the user at every gate. Triggers: 'build this app with SDD', 'run the full pipeline', 'continue the pipeline', 'quiero crear una app', 'ejecuta el pipeline completo', 'continúa el pipeline'."
---

# SDD Pipeline Orchestrator

You drive the pipeline from the main conversation. The stage skills do the work, and the user makes every decision. You sequence the skills, show progress and ask at the gates.

In multi-session mode (`SDD_ROLE` set or `.claude/sdd-sessions.json` present), use `sdd-lead` instead. The gate questions below are mirrored in the Gate table of `skills/sdd-lead/SKILL.md`, so change both together. Approvals (gate 1, the FASE gates, sign-off) are recorded as git tags and `acceptance/decisions.jsonl` entries, and each one needs an explicit yes from the human in this session.

## Rules

1. **Resume, don't restart.** Read `pipeline-state.json` first (and `git tag -l 'requirements-v*' 'fase-*-accepted'` for the approvals already given). Skip `done` stages, and re-run from the first `stale` one, explaining its `staleReason`. When a `fase-*-accepted` or `fase-*-verified` tag exists (`git tag -l 'fase-*-accepted' 'fase-*-verified'`), delivered work is on the default branch, so new work starts on a branch: each skill applies the branch rule of the plugin-root `references/git-conventions.md` before its first commit, and `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" branch status` shows where the session stands.
2. **Skills produce the artifacts.** Invoke each stage with the Skill tool. Don't write requirements, specs, plans, tasks or code yourself, and don't pre-answer the questions a skill asks the user.
3. **Ask at every gate.** Ask each gate question below with `AskUserQuestion`, give options, mark a recommended one, and wait for the answer. Never skip a stage or continue past a failed skill without the user's acknowledgement.
4. **Specs drive code (Art. 12).** When a test fails, the code is fixed and the test is not. A spec that looks wrong is reported as a SPEC-DEVIATION and amended only through `sdd-req-change` after the user decides.
5. **Show progress, and keep the status page alive.** After each stage, show a short status: stage, done/running/pending, and 1-2 numbers from the skill's `summary.metrics`. When the session offers the Artifact tool, the project has a living status page from the start: after stage 0, ask once whether to create it (it sends requirement titles and verdicts to a private claude.ai page), then republish it to the same URL after every stage and every gate, adding that step to its journey (`skills/sdd-acceptance/references/status-page.md`). Declined, or no Artifact tool: skip it silently; `acceptance/ACCEPTANCE-REPORT.md` is the shareable view.
6. **Request parallelism explicitly.** Several skills fan out to subagents above a size threshold, but an environment that asks for restraint can silently downgrade them to one thread. Pass `--fanout` when the threshold in the table is met, and add the sentence "launching the lanes is requested explicitly". If a stage still reports `metrics.mode: sequential`, read the reason in `summary.highlights`.

## Flow

| # | Stage | Invocation | Gate question (after the skill finishes) |
|---|-------|-----------|--------------------------------------------|
| 0 | Project | Fresh project: ask what it does, for whom, preferred stack and constraints. Run `git init` if needed, then `sdd-setup` (add `--stack=<kit>` when the stack matches a kit). Resuming: report the state. | Fresh: none. Resuming: "¿Continuamos desde {next stage}?" |
| 1 | Requirements | `sdd-requirements-engineer`, then gate 1 per `skills/sdd-requirements-engineer/references/approval.md`: needs read back to the customer, `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" lint --needs` clean, examples reviewed, Must list confirmed, then the approval question; on an explicit Approve the annotated tag `requirements-v{N}` | "¿Apruebas los requisitos v{N} como base de las especificaciones?" |
| 2 | Specifications | `sdd-specifications-engineer` (`--fanout` if > 4 functional REQs) | "¿Quieres revisar alguna especificación antes de continuar?" |
| 3 | Spec audit | `sdd-spec-auditor` (`--fanout` if `spec/` > 8 files or 40k chars). If the user accepts corrections for P0/P1 findings, run `sdd-spec-auditor --fix`. | "¿Aplicamos las correcciones de los hallazgos P0/P1 o quieres revisarlos?" |
| 4 | Laterals (optional) | Offer tech designer (`design/`), UX designer (`ux/`), security auditor (`audits/`), all three, or skip. Run the chosen ones one after another, since each asks the user its own questions. | The choice itself. |
| 5 | Test planning | `sdd-test-planner` (`--fanout` if > 3 UCs) | "¿Quieres ajustar los escenarios E2E?" |
| 6 | Plan | `sdd-plan-architect` (vertical FASEs; `sdd.mjs lint --plan` clean). Show each FASE's Incremento, Requisitos and Demo | "¿Estás conforme con los incrementos (FASEs), su orden y la arquitectura?" |
| 7 | Tasks | `sdd-task-generator` (`--fanout` if ≥ 2 FASEs) | "¿Quieres revisar las tareas antes de implementar?" |
| 8 | Implementation | Per FASE, in order: `sdd-task-implementer --fase N` (`--parallel` when the FASE has `[P]` tasks). The implementer runs the tests, makes the commits with their trailers and, in a vertical plan, runs the Demo and `sdd accept --fase N`. Then the FASE gate, acceptance of the increment: follow `references/fase-gate.md` (present the demo and the per-requirement verdicts; record `sdd accept record fase-acceptance` and tag `fase-{N}-accepted` through `sdd-acceptance --sign-off --fase N`, only on an explicit yes; route feedback as defect / change-request / question, a human confirming the route). Horizontal plan: ask the plain question. | Vertical: "¿Aceptas el incremento FASE-{N} ({Incremento})?" — Aceptado / Aceptado con observaciones / Rechazado, con feedback. Horizontal: "FASE-{N} completa. ¿Continuamos con FASE-{N+1}?" |
| 9 | E2E | If an E2E suite exists (Stack Profile `acceptance`, `acceptance/playwright.config.*`, `e2e/`, `test/system/`), run it with no question. Otherwise ask, and on yes have `sdd-task-implementer` write the E2E tests from `test/E2E-SCENARIOS.md` (never when `e2e_scaffold: never`) and run them. | "¿Escribo y ejecuto los tests E2E (Playwright)?" (only when there is no suite) |
| 10 | Acceptance | `sdd-gap-detector` with no question (orphan code), then `sdd-acceptance --loop`: the goal loop over every requirement until every Must is VERIFIED or WAIVED, or it stops (no progress, regression, cycle limit, only human decisions left). Present `acceptance/ACCEPTANCE-REPORT.md`. | Per gap finding: PROMOTE (new REQ through `sdd-req-change`) / REMOVE (code deletion as a task) / ACCEPT (record the rationale) / DEFER. Per item the loop leaves to a human: the decision it names (waiver, spec deviation, test change) |
| 11 | Sign-off | `sdd-acceptance --sign-off` (the customer's final acceptance; it asks its own questions), then a last update of the status page (if the project has one), then `sdd-session-summary`. | "¿Hay algo más que quieras ajustar?" |

Skills are namespaced by the plugin (`sdd-pipeline:<skill>`) when invoked with the Skill tool.

Answer in the user's language.
