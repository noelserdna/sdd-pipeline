# Sign-off: question, record, tag

Acceptance must be checkable later (who accepted what, when, at which commit, through which channel), so it lives in
`acceptance/decisions.jsonl` and in an annotated tag, not in the conversation. Tag and branch rules: plugin-root
`references/git-conventions.md`.

## 1. Question

Ask with `AskUserQuestion`, after showing the report path, the goal line and any waived Musts:

- Question: "Accept FASE {N} at commit {sha7}? Must {v}/{t} verified{, {w} waived}."
  (release: "Accept release {NAME} at commit {sha7}? …")
- Options: **Accept** · **Accept with observations (say which)** · **Reject (say why)**. When the gate is not met
  (exit 1 or 2), say so and offer only **Reject**: acceptance needs a met gate, a rejection does not.
- Also ask, if unknown: the approver's name and role, the channel (e.g. "demo call 2026-09-27", "email") and the demo
  id when a demo was run.

A subagent cannot ask the customer: it reports the sign-off as pending with the gate result and stops.

## 2. Record

```bash
$SDD accept record fase-acceptance --fase N --result accepted|observations|rejected \
  --channel "demo call 2026-09-27" [--demo DEMO-3] --by "Ana Pérez" --role "Product owner"
$SDD accept --report acceptance/ACCEPTANCE-REPORT.md --fase N
git add acceptance/decisions.jsonl acceptance/ACCEPTANCE-REPORT.md
git commit -m "docs(acceptance): accept FASE-N" --trailer "Refs: FASE-N, REQ-F-001, REQ-F-002"
```

The tool guard asks before `accept record`: confirm it only because the approver just answered. The record carries
the commit and a hash of each requirement's text, so a later change to the code of the FASE or to a requirement shows
the acceptance as no longer current.

## 3. Tag (FASE accepted, with or without observations)

```bash
N={FASE number}; SHA=$(git rev-parse HEAD)
git rev-parse -q --verify "refs/tags/fase-$N-accepted" >/dev/null && echo "fase-$N-accepted exists: stop"
SIGN=-a; [ -n "$(git config user.signingkey)" ] && SIGN=-s
git tag $SIGN "fase-$N-accepted" -F - <<EOF
FASE-$N accepted

Accepted-by: {name}
Approver-role: {role}
Channel: {channel}
Demo: {demo id or none}
Commit: $SHA
Acceptance: Must {v}/{t} verified, {w} waived ({ids}); gate exit {0|3}
EOF
```

The tool guard asks before creating the tag. Never move or delete an existing acceptance tag: reports and issues point
at it; a re-acceptance after changes is a new decision on a later FASE or release. Push (`git push origin
fase-N-accepted`) only when the user agrees.

## 4. Release

A release has no tag kind of its own and no `fase-acceptance` record (that record is per FASE). Use the tag or
platform release the project already uses (`v1.4.0`, a GitHub or GitLab release), created only after the approver's
explicit Accept, and make its annotated message (or release notes) the record: the approver lines of §3 (Accepted-by,
Approver-role, Channel, Demo, Commit) followed by the output of `$SDD gate --md`. When the release closes FASEs that
were never accepted one by one, record their `fase-acceptance` first (§2).
