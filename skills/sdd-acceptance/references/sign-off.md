# Sign-off: question, record, tag

Acceptance must be checkable later (who accepted what, when, at which commit, through which channel), so it lives in
`acceptance/decisions.jsonl` and in an annotated tag, not in the conversation. Tag and branch rules: plugin-root
`references/git-conventions.md`.

## 1. Question

Ask with `AskUserQuestion`, after showing the report path, the goal line, any waived Musts, the open challenges of
the adversarial round (`node "$SDD" accept challenge list --open`, whatever `adversarial_gate` says) and, for a FASE,
its video and captures (`evidencias/FASE-N/`):

- Question: "Accept FASE {N} at commit {sha7}? Must {v}/{t} verified{, {w} waived}."
  (release: "Accept release {NAME} at commit {sha7}? …")
- Options: **Accept** · **Accept with observations (say which)** · **Reject (say why)**. When the gate is not met
  (exit 1 or 2), or a Must has an open challenge under `adversarial_gate: enforce` (exit 4), say so and offer only
  **Reject**: acceptance needs a met gate, a rejection does not. Exit 4 clears when the loop fixes the challenge or a
  person dismisses it (`accept record challenge-dismissal`); with `warn` the challenges are shown and the approver
  decides with them in view.
- Also ask, if unknown: the approver's name and role, the channel (e.g. "demo call 2026-09-27", "email") and the demo
  id when a demo was run.

A subagent cannot ask the customer: it reports the sign-off as pending with the gate result and stops.

## 2. Record

```bash
node "$SDD" accept record fase-acceptance --fase N --result accepted|observations|rejected \
  --channel "demo call 2026-09-27" [--demo DEMO-3] --by "Ana Pérez" --role "Product owner"
node "$SDD" accept --report acceptance/ACCEPTANCE-REPORT.md --fase N
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
Acceptance: Must {v}/{t} verified, {w} waived ({ids}); gate exit {0|3}; open challenges {n, only under adversarial_gate warn}
EOF
```

The tool guard asks before creating the tag. Never move or delete an existing acceptance tag: reports and issues point
at it; a re-acceptance after changes is a new decision on a later FASE or release. Push (`git push origin
fase-N-accepted`) only when the user agrees.

## 4. Evidence pack (FASE accepted)

`evidencias/` is not versioned, so after the tag the FASE's captures and videos would live only on this machine:

```bash
node "$SDD" accept pack --fase N     # → .sdd/entregas/FASE-N-evidencias.tar.gz
```

The archive holds `evidencias/FASE-N/` and a `manifest.json` (path, `sha256`, bytes, criterion, `evaluated_sha`), so
anyone can later check that a file is the one the ledger saw. Tell the team where it is; handing it to the customer
or storing it elsewhere is their decision.

## 5. Release

A release has no tag kind of its own and no `fase-acceptance` record (that record is per FASE). Use the tag or
platform release the project already uses (`v1.4.0`, a GitHub or GitLab release), created only after the approver's
explicit Accept, and make its annotated message (or release notes) the record: the approver lines of §3 (Accepted-by,
Approver-role, Channel, Demo, Commit) followed by the output of `node "$SDD" gate --md`. When the release closes FASEs that
were never accepted one by one, record their `fase-acceptance` first (§2).
