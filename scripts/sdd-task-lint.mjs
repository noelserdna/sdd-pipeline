#!/usr/bin/env node
// sdd-task-lint.mjs — parse, lint and query task/TASK-FASE-*.md (sdd-pipeline). Node >= 18, no dependencies.
// Alias of scripts/sdd.mjs kept for existing projects: `lint` = `sdd lint`, `json|status|index` = `sdd tasks …`.
//
// Usage (paths are relative to --repo when given, else to the current directory):
//   node sdd-task-lint.mjs lint   [--dir task] [--fase N] [--json] [file.md ...]
//       V-19 task-line grammar (also flags `### TASK-` headings, `**TASK-…**` bold ids and unindented field lines),
//       V-09 id format + uniqueness, V-05/V-06 Commit/Acceptance present, V-16 `## Stream Ownership` vs tasks
//       (only when the table exists). Prints `file:line V-xx message` (warnings: `file:line V-xx warning: message`)
//       and a summary line; exit 1 on errors. Files whose title carries [RETROACTIVE] are skipped with a warning.
//   node sdd-task-lint.mjs json   [--dir task] [--fase N] [file.md ...]
//       Task list as JSON (id, fase, parallel, description, paths, checked, state, blocked, line, file, shape, phase,
//       stream, blockedBy, refs, revert). Legacy shapes (headings, bold ids) are parsed too.
//   node sdd-task-lint.mjs status [--dir task] [--fase N] [--repo DIR] [--rev HEAD] [--state checkbox|trailers]
//                                 [--json] [--require-done]
//       done = a `Task:` trailer in a commit reachable from --rev that is not reverted ("This reverts commit <sha>";
//       a revert of a revert restores it). Also the checkbox state, blocked (`[!]`) and divergences:
//       checked-without-trailer, trailer-without-checkbox. --state defaults to `task_state` of `## SDD Stack Profile`
//       in <repo>/CLAUDE.md, else checkbox; with `trailers` an unchecked box is expected and not a divergence.
//       --require-done exits 1 when a selected task is not done.
//   node sdd-task-lint.mjs index  [--dir task] [--fase N] [file.md ...]
//       Derived TASK-INDEX.md (Summary by FASE, flat task list, traceability matrix from Refs) to stdout.
// Exit codes: 0 ok · 1 lint errors or --require-done unmet · 2 usage error, no task files, git failure.
//
// Task line grammar (V-19), one line per task, continuation lines indented two spaces:
//   ^- \[( |x|!)\] TASK-F\d+-\d{3,4}( \[P\])? .+ \| `[^`]+`(, `[^`]+`)*$
import { run } from "./sdd.mjs";

process.exitCode = run(process.argv.slice(2), { prog: "sdd-task-lint", helpUrl: import.meta.url, legacy: true });
