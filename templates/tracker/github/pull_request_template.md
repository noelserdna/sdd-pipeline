<!--
SDD pull request. Generate the body instead of filling this in by hand:
  node .claude/sdd/sdd.mjs pr-body --fase N --issue M > .sdd/pr-body.md     (FASE)
  node .claude/sdd/sdd.mjs pr-body --change CHG-ID --issue M > .sdd/pr-body.md   (requirement change)
  gh pr create --body-file .sdd/pr-body.md
-->
## Summary

## Requirements and evidence

<!-- Output of `node .claude/sdd/sdd.mjs gate --md` (add --fase N for a FASE). -->

## Tasks

<!--
FASE PR: `Refs #N` — the FASE issue is closed when the customer accepts the increment (tag fase-N-accepted), not on merge.
Change PR: `Closes #N`.
-->
Refs #

Merge method: merge commit (no squash/rebase — per-task trailers must survive)
