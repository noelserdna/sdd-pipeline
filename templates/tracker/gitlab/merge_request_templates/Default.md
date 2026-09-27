<!--
SDD merge request (issues are #N, merge requests !N). Generate the body instead of filling this in by hand:
  node .claude/sdd/sdd.mjs pr-body --fase N --issue M > .sdd/pr-body.md     (FASE)
  node .claude/sdd/sdd.mjs pr-body --change CHG-ID --issue M > .sdd/pr-body.md   (requirement change)
  glab mr create --description "$(cat .sdd/pr-body.md)"
-->
## Summary

## Requirements and evidence

<!-- Output of `node .claude/sdd/sdd.mjs gate --md` (add --fase N for a FASE). -->

## Tasks

<!--
FASE MR: `Refs #N` — the FASE issue is closed when the customer accepts the increment (tag fase-N-accepted), not on merge.
Change MR: `Closes #N`.
-->
Refs #

Merge method: merge commit (no squash/rebase — per-task trailers must survive)
