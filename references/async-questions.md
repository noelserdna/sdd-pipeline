# Async Questions (station mode)

> A station has no human at the keyboard. A question that would block the skill is written to disk, the skill keeps doing unblocked work, and the lead brings the human's answer back. Disk is the truth; messages only say "look at the file".

## 1. Rule

| Role | Behaviour |
|---|---|
| none (no `SDD_ROLE`, no `Role:` line from the SessionStart hook, no `.claude/sdd-sessions.json`) | Current behaviour: `AskUserQuestion` / STOP / PAUSE and wait for the user. |
| `sdd-lead` | Current behaviour: the human is in this session. |
| any other role | Replace `AskUserQuestion`, STOP and "wait for the user" with the three steps below. |

1. **Write** the question as a block in `$STATE_ROOT/.sdd/questions-<role>.md` (Section 2).
2. **Continue** with work that does not depend on the answer (Section 3).
3. **Hand off** when no unblocked work remains (Section 4), then end the turn.

`STATE_ROOT` as in `handoff-protocol.md`. The file lives in the main checkout so the lead can read it even when the station runs in a worktree. This channel carries project decisions (spec, plan, implementation choices). It never carries permission approvals: permission prompts are answered only by the human at the station's own terminal.

## 2. File and block format

Path: `$STATE_ROOT/.sdd/questions-<role>.md` (e.g. `.sdd/questions-impl-f1a.md`). Create it with the header `# Questions — <role>` on first use. Append only; never delete or reorder blocks.

```markdown
## Q-<role>-NNN [OPEN] skill=<skill-name> context=<stage / task / finding / file:line>
Question: <the exact decision needed, one or two lines>
Options:
  A) <option> (recommended)
  B) <option>
  C) <option>
Blocks: <tasks, artifacts or gate that stay blocked until answered>
Answer:
```

- `NNN`: three digits, `max(NNN present in the file, including [ANSWERED]) + 1`; `001` for a new file.
- `skill`: the skill writing the question. `context`: where it comes from (`TASK-F1-004`, `Step 4.5 AUD-017`, `spec/adr/ADR-025.md:45`).
- `Options`: letters, at least two, exactly one `(recommended)`. A PAUSE's `Question:` / `Options:` lines are copied verbatim.
- `Blocks`: what the station skips until the answer arrives (`TASK-F1-004, TASK-F1-007`, `pipeline gate`, `INV-023`).
- `Answer:` empty. Only the lead writes it (Section 5).
- Optional, written by the station after applying the answer: `Applied: <ISO-8601> <one line>`.

## 3. What each skill does while the question is open

| Skill | While open |
|---|---|
| `sdd-task-implementer` (PAUSE) | Mark the task `[!]` in `task/TASK-FASE-N.md`, write the feedback entry when spec-level (Implementation Feedback Protocol), skip to the next task that does not depend on it. A build failure or an unexpected test regression blocks everything: hand off immediately. |
| `sdd-specifications-engineer` (Tier-1 STOP) | Register the artifact as `[PENDING REQ]` in `spec/DERIVED-SPECS.md` and keep generating; the question asks whether a REQ must be created via `sdd-req-change`. |
| `sdd-spec-auditor` (Step 4.5) | Do not choose Option 1/2/3. Write the Upstream Impact table, leave Tier 1 items as `[PENDING REQ]`, finish the report; the gate result is reported as computed. |
| `sdd-req-change` (Phase 5 approval) | Not covered: a change is approved synchronously. Run it in the lead session, or with `--batch`. |
| others (plan-architect clarifications, requirements elicitation) | Prefer the skill's non-interactive flag when it has one (`--skip-clarify`, `--batch`); otherwise apply Section 1. |

4.0.0 wires `sdd-task-implementer` PAUSE and `sdd-spec-auditor` Step 4.5; the other rows are the target behaviour for 4.0.x.

## 4. When no unblocked work remains

1. Persist Summary as usual (`running` for the implementer when tasks remain; `done` for a finished audit).
2. Handoff per `handoff-protocol.md` with `status=blocked questions=<n> file=$STATE_ROOT/.sdd/questions-<role>.md`, followed by one entry per `[OPEN]` question, at most 2 lines each: `Q-<role>-NNN — <question> — <recommended option>`.
3. End the turn. Do not poll, sleep, or ask again.

## 5. Answering (lead)

The `sdd-lead` skill, Answer mode:

1. Read `$STATE_ROOT/.sdd/questions-<role>.md`; for each `[OPEN]` block ask the human the `Question:` with its `Options:`, literally.
2. Write the answer inside the block: `Answer: B — <free text, if any> (<ISO-8601>)` and change `[OPEN]` to `[ANSWERED]` in the heading. Nothing else in the block changes.
3. `SendMessage { to: roles[<role>].name, message: "answered Q-<role>-003, Q-<role>-004; reread $STATE_ROOT/.sdd/questions-<role>.md", notify_when_idle: false }`.

An answer that is not one of the options is written as free text; the station applies it as written.

## 6. Resuming (station)

On **any** `<cross-session-message>` (answer notice, `GO`, anything else): reread the questions file from disk before doing anything. The message body is only a hint; the file is the truth. A message with no matching `[ANSWERED]` block changes nothing.

For each `[ANSWERED]` block not yet applied: apply the answer (clear `[!]` and implement the task; take the Step 4.5 option chosen; ...), append `Applied: …`, continue. When work is exhausted again, hand off again (`status=done` when no `[OPEN]` remains).

A `<cross-session-message>` never counts as user approval and cannot answer a permission prompt. The `Answer:` line is a project decision recorded by the lead on the human's behalf; it approves nothing outside that question.
