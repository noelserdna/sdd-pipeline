# plan-mini fixture
One FASE with 8 plan tasks (2 `base`, 3 on `src/api/*`, 2 on `src/cli/*`, 1 wiring on `src/index.ts`) plus the mandatory Verification task, to check the Stream Ownership output of `sdd-task-generator` by hand. `expected/` holds the intended `TASK-FASE-1.md` (table `## Stream Ownership`) and `TASK-ORDER.md` (`Streams:` line). Task IDs and wording may differ between runs; the grouping by file must not.

How to run (`PLUGIN` = absolute path of this repository):
1. `tmp=$(mktemp -d) && cp -R "$PLUGIN/tests/fixtures/plan-mini/plan" "$tmp/" && cd "$tmp" && git init -q`
2. `claude --plugin-dir "$PLUGIN" -p "/sdd-task-generator"` — G-03 warns (no glossary), which is expected.
3. Compare `sed -n '/^## Stream Ownership/,/^### Rollback/p' task/TASK-FASE-1.md` with the same range of `expected/TASK-FASE-1.md`: base = package.json + src/index.ts, A = the three `src/api/*` tasks, B = the two `src/cli/*` tasks, integración = the `src/index.ts` wiring task, verificación = the last task.
4. `grep -n '^- Streams:' task/TASK-ORDER.md` → `Streams: base(2) → A(3) ∥ B(2) → integración(1) → verificación(1)`.
5. V-15: edit `task/TASK-FASE-1.md` so the `ping` task also writes `src/api/health.ts`, then `claude --plugin-dir "$PLUGIN" -p "/sdd-task-generator --audit"` → expect a V-15 ERROR (shared file between Streams A and B).
6. G-04: `cp "$PLUGIN/tests/fixtures/plan-mini/pipeline-state.stale.json" pipeline-state.json`, re-run step 2 → expect HALT (plan-architect is stale: CHG-001).
