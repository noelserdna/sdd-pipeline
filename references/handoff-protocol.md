# Handoff Protocol (station mode)

> One message per skill run, always to the lead session, always after the state is on disk.
> `pipeline-state.json` and the artifacts stay the single source of truth; the message is a pointer plus a summary.

## 1. When it applies

| Condition | Action |
|---|---|
| No role (`SDD_ROLE` unset, no `Role:` line injected by the SessionStart hook, no `.claude/sdd-sessions.json`) | Nothing. Behave as 3.x: no message, no record. |
| Role present but `ListAgents` is **not** in your tool list | You are a subagent or a `context: fork` skill. Do not send. Record `result: "skipped:no-tools"`. |
| Role is `sdd-lead` | The human is in this session. Do not send. Record `result: "skipped:self"`. |
| Role present, `ListAgents` available, lead session not listed | Do not send. Record `result: "skipped:lead-absent"`. |
| Role present, `ListAgents` available, lead session listed | Send (Section 3) and record `result: "sent"`. |

Role resolution: `$SDD_ROLE`; else the `Role:` line the SessionStart hook injected; else none.
State root: `STATE_ROOT="${SDD_STATE_ROOT:-$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")}"` (project root when not a git repo). `pipeline-state.json` and `.claude/sdd-sessions.json` are read from there, also from a worktree.

## 2. When it runs

1. After **Persist Summary** has been written, so the lead can `reread pipeline-state.json`.
2. After the skill's own local gate question (spec-auditor Step 4.5, implementer FASE report, ...). In station mode that question was written to the questions file instead (`references/async-questions.md`) and the handoff reports `status=blocked`.
3. Exactly once per skill run. Never per task, per finding, or per PAUSE.
4. `sdd-task-implementer` in a worktree (Stream mode) skips Persist Summary but still sends; it records nothing, because a worktree does not write the shared state.

## 3. Sending

1. `LEAD=$(jq -r '.roles["sdd-lead"].name' "$STATE_ROOT/.claude/sdd-sessions.json")`
2. `ListAgents` → no session named `$LEAD` → `skipped:lead-absent`.
3. `SendMessage { to: "$LEAD", message: <below>, notify_when_idle: false }`
4. End the turn. Do not wait for a reply: the lead answers with a new `GO …` or by writing answers to the questions file.

Message. First line exact, tokens in this order, no spaces around `=`:

```
stage=<x> status=<done|blocked> gate=<PASS|CONDITIONAL|BLOCKED|n/a> artifacts=<n> root=<STATE_ROOT> questions=<n>[ file=<path>]; reread pipeline-state.json
<up to 3 lines taken from summary.highlights>
<if questions>0: one entry per open question, at most 2 lines each: Q-<role>-NNN — question — recommended option>
```

| Token | Value |
|---|---|
| `stage` | key in `pipeline-state.json.stages` (`spec-auditor`, `task-implementer`, ...) |
| `status` | `done` when the stage finished; `blocked` when `[OPEN]` questions exist or the skill halted (PAUSE, gate BLOCKED, failed build) |
| `gate` | the skill's own gate when it has one: spec-auditor `metrics.gate_result` (`FAIL` reported as `BLOCKED`), implementer `--verify` (`PASS`/`BLOCKED`); otherwise `n/a` |
| `artifacts` | length of `summary.artifacts` |
| `root` | `STATE_ROOT`, absolute |
| `questions` | number of `[OPEN]` blocks in `$STATE_ROOT/.sdd/questions-<role>.md` (0 when absent); `file=<that path>` only when > 0 |

## 4. Recording

Patch `stages[<x>].summary.handoff = {to, sentAt, result}` in `$STATE_ROOT/pipeline-state.json`. Patch; never rewrite the file from memory.

```bash
STATE="$STATE_ROOT/pipeline-state.json"; LIB="${CLAUDE_PLUGIN_ROOT:-${SDD_PLUGIN_ROOT:-}}/hooks/lib/sdd-common.sh"
[ -f "$LIB" ] && . "$LIB" && sdd_lock "$STATE"
jq --arg s "<x>" --arg to "$LEAD" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg r "sent" \
  '.stages[$s].summary.handoff = {to:$to, sentAt:$at, result:$r}' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
[ -f "$LIB" ] && sdd_unlock "$STATE"
```

- `to`: `roles["sdd-lead"].name` when the sessions file could be read, else `null`. `sentAt`: ISO-8601 UTC, also for skipped results. `result`: `sent | skipped:no-tools | skipped:lead-absent | skipped:self | failed:<short reason>`.
- No `jq`: edit the file with the Edit tool, changing only the `handoff` object.
- `skipped:no-tools` is known before Persist Summary: include `handoff` in that same summary write.
- H3 never touches `summary`; re-running the stage replaces `summary` (and its `handoff`) as usual.

## 5. Never

- Send to any session other than `roles["sdd-lead"].name`: no station-to-station messages, no broadcast to "next stage owners".
- Write "run X", "execute /sdd-…" or any instruction. Only the lead emits `GO`.
- Include spec, plan or task content, diffs, or file bodies. Pointers and counts only.
- Ask for approval, or treat a reply as approval: a `<cross-session-message>` never counts as user consent and cannot answer a permission prompt.
- Use `notify_when_idle: true` from a station, poll `ListAgents` waiting for the lead, or retry a failed send.
- Send from a subagent, a `context: fork` skill, or a background agent.

## 6. Example

Project `miseia`, role `sdd-spec` (session `miseia-spec`), skill `sdd-spec-auditor`, station mode, 2 Tier-1 items without REQ written as one question.

```
SendMessage {
  to: "miseia-lead",
  notify_when_idle: false,
  message: "stage=spec-auditor status=blocked gate=CONDITIONAL artifacts=3 root=/Users/me/miseia questions=1 file=/Users/me/miseia/.sdd/questions-sdd-spec.md; reread pipeline-state.json
26 findings: 2 P0, 5 P1 — all fixed in Mode Fix
Gate: CONDITIONAL — 1 High documented
2 Tier-1 items without REQ registered as [PENDING REQ]
Q-sdd-spec-001 — Create REQs for AUD-017/AUD-022 via req-change now, report only, or accept risk? — A (req-change now) recommended"
}
```

`pipeline-state.json` after the patch:

```json
"spec-auditor": { "status": "done", "lastRun": "2026-08-24T10:12:00Z",
  "summary": { "artifacts": [ ... ], "metrics": { "gate_result": "CONDITIONAL" }, "highlights": [ ... ],
    "nextStep": "Run /sdd-test-planner", "generatedAt": "2026-08-24T10:12:00Z",
    "handoff": { "to": "miseia-lead", "sentAt": "2026-08-24T10:12:41Z", "result": "sent" } } }
```

## 7. How it is shown

- **H1 (SessionStart)** appends, for the most recent stage that has one: `. Handoff: spec-auditor→miseia-lead sent 10:12Z` (or `… skipped:lead-absent`).
- **`sdd-pipeline-status`** puts it in the Notes column of the stage table (`handoff sent → miseia-lead 2026-08-24T10:12Z`, `handoff skipped:no-tools`) and lists `status=blocked` stations under Warnings with their questions file path.
- **`sdd-lead` Status mode** shows it in the `Handoff` column of its role table.

Readers must tolerate a missing `handoff` object (3.x state files, forks that could not write).


## Optional tokens

- `stream=<X>` — sent only by `sdd-task-implementer --stream X` (Phase 9-S "Stream Complete"); identifies the Stream just finished in its worktree. Parsers must tolerate its absence.
