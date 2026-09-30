# Jev screens (advisory only)

Two question sets help a human look where it matters. They never decide a verdict, a waiver, a sign-off, the loop's
stop or anything that runs in CI; the CLI's verdict always stands. Jev is opt-in (`TYPESAFE_API_KEY`, `SDD_JEV` not
`off`) and the state text (criteria, test code, demo output) is sent to `api.typesafe.ai`: skip it on projects where
that is not allowed. Thresholds live in each JSON file; read them from there.

## Test adequacy — `scripts/jev/test-adequacy.json`

Does a passing test assert the THEN of its criterion and exercise its WHEN?

1. From `.sdd/acceptance.json`, take the Must requirements with `verification: test` and, per criterion in state
   `pass`, its bound tests (name and scenario id).
2. Find each test's body: search `test_paths` for the test name (`grep -rn --fixed-strings "<name>"`), and take the
   block from that line to its end (≤ 80 lines). Unfound tests are skipped and listed.
3. One JSONL item per (criterion, test):
   `{"id": "REQ-F-001/AC2/<test name>", "state": {"criterion": {"text": "<GIVEN/WHEN/THEN line>"}, "scenario": {"id": "AC-001-02", "text": "<Scenario line>"}, "test": {"name": "...", "code": "..."}}}`
4. `node "$SDD_PLUGIN_ROOT/scripts/sdd-jev.mjs" judge --questions "$SDD_PLUGIN_ROOT/scripts/jev/test-adequacy.json" --items .sdd/jev/adequacy.jsonl --out .sdd/jev/adequacy.json`
5. Flag an item when `asserts_then` or `exercises_when` is below `thresholds.review_below`. Read each flagged test
   yourself against the criterion and say what it misses; if it really does not verify the criterion, that is a
   finding for the human (a test edit to approve, or a missing test for the loop), never a verdict change.

**Jev off (exit 3) at `--sign-off`:** give the same items for the Must criteria to one independent subagent (Agent
tool, fresh context, no implementation history, read-only), asking both questions literally as yes/no with a
one-line reason per item. Its answers are advisory in the same way.

### Pre-pass for the adversarial round

`--adversarial` uses the same question set as a cheap pass over the whole universe before the verifiers start:

1. Items as in steps 2-3 above, but for **every** criterion in scope with a bound test, whatever its verdict,
   priority or method (`.sdd/adversarial-plan.json` lists them with their tests), written to
   `.sdd/jev/adversarial.jsonl`; judge them into `.sdd/jev/adversarial.json`.
2. Priority of a criterion = the lowest `asserts_then` or `exercises_when` over its tests. The verifiers get their
   criteria in ascending order, and the clean verdicts counter-verified are the lowest-scored ones
   (`adversarial-protocol.md` §2, §4).

That is all it does. The verifiers read every criterion whatever it scored, a high score marks nothing clean, and
the scores never reach `challenges.jsonl`, the gate or CI. Jev reads text only, so it says nothing about the
captures and videos of `evidencias/`; the verifiers read the captures. With Jev off (exit 3) the main thread orders
the criteria from their text and test names, with the same limits.

## Demo evidence — `scripts/jev/evidence.json`

Before asking a human to confirm a demo (`needs-human` route), screen the captured output:

- item: `{"id": "REQ-F-002/AC1", "state": {"criterion": {"text": "..."}, "observed": {"command": "...", "output": "<captured output, ≤ 20 000 chars>"}}}`
- `shows_then` is a Score over 0 not shown · 1 partial · 2 shown. Below `thresholds.flag_below`, tell the person which
  part of the THEN the output does not seem to show. Either way the person decides `--pass true|false`; record what
  they say, not what Jev scored.
