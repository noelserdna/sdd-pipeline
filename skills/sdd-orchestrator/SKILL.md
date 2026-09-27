---
name: sdd-orchestrator
description: "Drives the whole SDD pipeline interactively from a project idea or existing requirements to working, tested software: runs each stage skill in order, resumes from pipeline-state.json and asks the user at every gate. Triggers: 'build this app with SDD', 'run the full pipeline', 'continue the pipeline', 'quiero crear una app', 'ejecuta el pipeline completo', 'continúa el pipeline'."
---

# SDD Pipeline Orchestrator

You drive the pipeline from the main conversation. The stage skills do the work, and the user makes every decision. You sequence the skills, show progress and ask at the gates.

In multi-session mode (`SDD_ROLE` set or `.claude/sdd-sessions.json` present), use `sdd-lead` instead. The gate questions below are mirrored in the Gate table of `skills/sdd-lead/SKILL.md`, so change both together.

## Rules

1. **Resume, don't restart.** Read `pipeline-state.json` first. Skip `done` stages, and re-run from the first `stale` one, explaining its `staleReason`.
2. **Skills produce the artifacts.** Invoke each stage with the Skill tool. Don't write requirements, specs, plans, tasks or code yourself, and don't pre-answer the questions a skill asks the user.
3. **Ask at every gate.** Ask each gate question below with `AskUserQuestion`, give options, mark a recommended one, and wait for the answer. Never skip a stage or continue past a failed skill without the user's acknowledgement.
4. **Specs drive code (Art. 12).** When a test fails, the code is fixed and the test is not. A spec that looks wrong is reported as a SPEC-DEVIATION and amended only through `sdd-req-change` after the user decides.
5. **Show progress.** After each stage, show a short status: stage, done/running/pending, and 1-2 numbers from the skill's `summary.metrics`.
6. **Request parallelism explicitly.** Several skills fan out to subagents above a size threshold, but an environment that asks for restraint can silently downgrade them to one thread. Pass `--fanout` when the threshold in the table is met, and add the sentence "launching the lanes is requested explicitly". If a stage still reports `metrics.mode: sequential`, read the reason in `summary.highlights`.

## Flow

| # | Stage | Invocation | Gate question (after the skill finishes) |
|---|-------|-----------|--------------------------------------------|
| 0 | Project | Fresh project: ask what it does, for whom, preferred stack and constraints. Run `git init` if needed, then `sdd-setup` (add `--stack=<kit>` when the stack matches a kit). Resuming: report the state. | Fresh: none. Resuming: "¿Continuamos desde {next stage}?" |
| 1 | Requirements | `sdd-requirements-engineer` | "¿Estás conforme con los requisitos o quieres ajustar algo?" |
| 2 | Specifications | `sdd-specifications-engineer` (`--fanout` if > 4 functional REQs) | "¿Quieres revisar alguna especificación antes de continuar?" |
| 3 | Spec audit | `sdd-spec-auditor` (`--fanout` if `spec/` > 8 files or 40k chars). If the user accepts corrections for P0/P1 findings, run `sdd-spec-auditor --fix`. | "¿Aplicamos las correcciones de los hallazgos P0/P1 o quieres revisarlos?" |
| 4 | Laterals (optional) | Offer tech designer (`design/`), UX designer (`ux/`), security auditor (`audits/`), all three, or skip. Run the chosen ones one after another, since each asks the user its own questions. | The choice itself. |
| 5 | Test planning | `sdd-test-planner` (`--fanout` if > 3 UCs) | "¿Quieres ajustar los escenarios E2E?" |
| 6 | Plan | `sdd-plan-architect` | "¿Estás conforme con las FASEs y la arquitectura?" |
| 7 | Tasks | `sdd-task-generator` (`--fanout` if ≥ 2 FASEs) | "¿Quieres revisar las tareas antes de implementar?" |
| 8 | Implementation | Per FASE, in order: `sdd-task-implementer --fase N` (`--parallel` when the FASE has `[P]` tasks). The implementer runs the tests and makes the commits with their trailers. | "FASE-{N} completa. ¿Continuamos con FASE-{N+1}?" |
| 9 | E2E | If an E2E suite exists (Stack Profile `acceptance`, `acceptance/playwright.config.*`, `e2e/`, `test/system/`), run it with no question. Otherwise ask, and on yes have `sdd-task-implementer` write the E2E tests from `test/E2E-SCENARIOS.md` (never when `e2e_scaffold: never`) and run them. | "¿Escribo y ejecuto los tests E2E (Playwright)?" (only when there is no suite) |
| 10 | Gaps | `sdd-gap-detector` (add `--semantic` to check requirement coverage in the code). Present `audits/GAP-ANALYSIS-REVIEW.md`. | Per finding: PROMOTE (new REQ through `sdd-req-change`) / REMOVE (code deletion as a task) / ACCEPT (record the rationale) / DEFER |
| 11 | Verification | Refresh the traceability graph with no question (`python3 "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd-graph.py"`, skipped when python3 is missing), then `sdd-pipeline-status` and `sdd-traceability-check` | — |
| 12 | Wrap-up | Summary: REQs implemented, tests and pass rate, traceability coverage, gap decisions. Then `sdd-session-summary`. | "¿Hay algo más que quieras ajustar?" |

Skills are namespaced by the plugin (`sdd-pipeline:<skill>`) when invoked with the Skill tool.

Answer in the user's language.
