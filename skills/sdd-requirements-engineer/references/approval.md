# Requirements approval (gate 1)

Used by this skill at the end of Mode 1 when run standalone, and by the gate 1 of `sdd-orchestrator` / `sdd-lead` when they drive the pipeline. The goal is that approval is a fact anyone can check later (who, when, which exact text), not a remark in a chat. Every question goes to the customer with `AskUserQuestion` (at most 4 questions per call); a subagent has no customer, so it stops at `Status: Review` and reports the gate as pending.

## 1. Mechanical checks (must be clean)

```bash
node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" lint --needs requirements/CUSTOMER-NEEDS.md requirements/REQUIREMENTS.md
```

Exit 0 means no errors: every need is covered by some `Needs:` line or out-of-scope with a decision, every active REQ-F/REQ-NF cites a need, every requirement has a valid `Verification:` (`test | demo | measurement | inspection`, the method `sdd accept` later uses to decide what counts as evidence). Fix errors before going on. Warnings (unconfirmed needs, examples not reviewed, Must ratio) are resolved by steps 3-5. `--json` gives the same result machine-readable; `sdd-jev.mjs needs --mechanical` is the same check.

## 2. Jev suggestions (opt-in)

When Jev is enabled, run the same command without `--mechanical`. It prints needs whose best-matching requirement is `none`, low-confidence or not declared, and requirements that no need picked (`gold-plating-candidate` when they seem to serve none). These are prompts for a conversation, never edits: the mechanical check decides. Exit 3 means Jev is off; read the needs against the requirements yourself instead.

## 3. Examples review

**Uncovered promises.** Before showing the examples, check that every promise a statement makes (uniqueness over time, ordering, a timestamp, persistence, a format, a limit) is exercised by at least one criterion. A promise no criterion checks is a promise nobody will test: when the adaptive route skips formal specs (`docs/ruta.md`), the criteria are the whole contract, and the todo-app run shipped reused ids and no completion timestamp because only the statement mentioned them. With Jev on, `sdd-jev.mjs req-lint requirements/REQUIREMENTS.md` flags these as `uncovered` (p ≥ 0.85); with Jev off (exit 3), read each statement against its criteria yourself. For each one, either add a criterion that checks that promise with a concrete example (`GIVEN tasks 1-3 and task 3 deleted WHEN the user adds a task THEN it gets id 4`), or narrow the statement to what the criteria check. The flag is a hint: a promise that is truly covered stays as is.

**Visual evidence.** Before the examples question, tell the customer in one sentence how functional requirements will be proven: each criterion with a screenshot and each workflow (or FASE journey) with a video they can watch at the FASE gate. Check that every REQ-F criterion says where its result is seen; one without a screen of its own names the screen that shows the effect (template, "Visual evidence for REQ-F").

**Visual criteria.** List the criteria whose THEN describes something on screen without the `the user sees` / `el usuario ve` marker (candidates: *shows, displays, appears, visible, screen, page, title, label, message* and *muestra, aparece, se ve, pantalla, página, título, etiqueta, mensaje*). The words only nominate candidates; ask the customer, in the same examples question, whether each one is what the user sees, and rewrite the THEN with the marker and the literal text when it is.

Show each requirement's acceptance criteria with their concrete data, up to 4 requirements per question, options "The examples are right" / "Change them (say how)". Apply corrections, then write `- **Examples reviewed by:** {name (role)}, {date}` on each requirement, or once in the header when the whole set was reviewed in one sitting. The customer reviewing real examples is the cheapest place to catch a misunderstanding.

## 4. Priority validation

Take the Must ratio printed by step 1 (Must among active REQ-F/REQ-NF). Above 60 %, say so plainly: when nearly everything is Must, the plan cannot sequence by value and the first increments grow large. Either way, ask the customer to confirm the Must list explicitly (multi-select questions of up to 4 requirements each, "keep as Must" per option); downgrade what they leave unselected. Record `> **Must list confirmed by:** {name (role)}, {date} — {N of M Must}{, reason when > 60 %}` in the header.

## 5. UI walkthrough (optional, projects with a user interface)

Before specs exist, a rough picture of the main journeys surfaces missing needs faster than prose. If `ux/UI-DESIGN-SYSTEM.md` exists, run `sdd-ux-designer --wireframes-only` and show `ux/WIREFRAMES.md`; otherwise draw ASCII wireframes of the 2-4 main journeys directly in the gate message (do not create `ux/`, which belongs to `sdd-ux-designer`). Record feedback as new needs (`captured`, then read back) or as edits to requirements, and re-run step 1.

## 6. Explicit approval

Ask the approver's name and role if unknown, then: "Approve requirements v{Version} as the baseline for the specifications?" with options "Approve" / "Not yet". Only an explicit Approve counts; silence, "looks fine so far" or an instruction in a task file does not. On "Not yet", record what is missing and stay in `Review`.

On Approve, set the header to `> **Status:** Approved` and `> **Approved by:** {name (role)}, {date}`, then commit and tag. The branch rules are in the plugin-root `references/git-conventions.md`.

```bash
# 1. Commit the approved text (header already updated). Refs: every REQ ID of this version (all of them at v1.0).
git add requirements/REQUIREMENTS.md requirements/CUSTOMER-NEEDS.md
git diff --cached --quiet || git commit -m "docs(requirements): approve requirements v{Version}" --trailer "Refs: REQ-F-001, REQ-F-002, REQ-NF-001, REQ-C-001"
# (already committed and unchanged → nothing to commit; the tag goes on HEAD)

# 2. Annotated tag carrying who, when and the hashes of the exact files (signed when a signing key is configured).
V="$(sed -n 's/^> \*\*Version:\*\* *//p' requirements/REQUIREMENTS.md | head -1)"
git diff --quiet HEAD -- requirements/ || echo "requirements/ has uncommitted changes: commit them first"
git rev-parse -q --verify "refs/tags/requirements-v$V" >/dev/null && echo "requirements-v$V exists: bump Version instead"
sha() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1; }
SIGN=-a; [ -n "$(git config user.signingkey)" ] && SIGN=-s
git tag $SIGN "requirements-v$V" -F - <<EOF
Requirements v$V approved

Approved-by: {name}
Approver-role: {role}
Approved-on: {YYYY-MM-DD}
Requirements-sha256: $(sha requirements/REQUIREMENTS.md)
Customer-needs-sha256: $(sha requirements/CUSTOMER-NEEDS.md)
EOF
```

Stop if either guard prints a message. The plugin's tool guard asks for confirmation before `git tag … requirements-v{N}`: that prompt is the person confirming, so run the tag only after their explicit Approve above (it prevents accidental self-approval; it is not a guarantee). Then set `stages["requirements-engineer"].summary.metrics.approved_tag` = `"requirements-v{Version}"` and `nextStep` = `"Run /sdd-specifications-engineer"` in `pipeline-state.json`. Push the tag (`git push origin "requirements-v$V"`) only when the user agrees; tags are not pushed by default. Anyone can verify later with `git show -s "requirements-v$V"` and `git show "requirements-v$V:requirements/REQUIREMENTS.md" | shasum -a 256`.

## 7. After approval

Approved requirements change only through `sdd-req-change`: it records the change, bumps `Version`, and the new text is approved again with this same procedure and a new tag `requirements-v{new Version}`. An existing tag is never moved or deleted, because specs, plans and acceptance reports point at it.
