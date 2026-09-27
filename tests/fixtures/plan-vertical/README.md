# plan-vertical fixture

Two vertical plans (`Plan-Style: vertical`) for `sdd lint --plan` (`tests/plan/run.sh`), written with the rules of
`skills/sdd-plan-architect/references/phase-assignment-rules.md`:

- `todo/` — the worked example of the rules on `examples/todo-app` (the test copies `examples/todo-app/requirements/`
  next to it): FASE-0-SKELETON (add + list + persistence + coverage), FASE-1-LIFECYCLE (done + rm), FASE-2-FILTER
  (Should), FASE-3-HARDENING (measured latency). `task/TASK-FASE-0.md` shows Slices grouped under `### UC-NNN`
  sub-headings and cites every scenario of the FASE (V-20).
- `web/` — login + three CRUD entities (customers, vehicles, appointments) + an admin report + a measured NFR.

Each run copies a plan to a temporary directory and mutates it to produce every failure the lint reports.
`tests/fixtures/plan-mini/` stays the horizontal Streams fixture.
