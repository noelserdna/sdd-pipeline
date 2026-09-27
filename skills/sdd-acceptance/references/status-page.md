# Status page (`--publish`)

A one-page view of where the project stands, for the customer and anyone following it. It replaces the old local
HTML dashboard: it is built from the project's data, published as a private Claude Artifact, and shared only when
the owner decides.

It is a **living page**: created right after setup (the orchestrator asks once) and republished to the same URL after
every stage and every gate, so its journey grows with the project. Early on it shows only the journey and the
customer needs; the increments and the verdicts appear as the plan and the tests exist.

## Data (read, never recompute)

| Source | Used for |
|---|---|
| `.sdd/acceptance.json` (run `node "$SDD" accept` first if stale) | verdict per requirement, `evaluated_sha`, summary, waived Musts |
| `plan/fases/FASE-*.md` headers + `## Demo` | increments, their requirements and demo steps |
| `acceptance/decisions.jsonl` via the report | FASE acceptances (who, when), demo records |
| `requirements/CUSTOMER-NEEDS.md` | needs covered per increment |
| `sdd issue` / `sdd pr-body` (when `tracker` is set) | links to the FASE and change issues and open PRs |
| `pipeline-state.json` stages (`lastRun`, `summary.highlights`, `summary.metrics`) and `git tag -l --format='%(refname:short) %(creatordate:iso)'` | the journey: one entry per stage or gate, in order, with time, duration, outcome and tags |

The page shows titles, verdicts, dates and links. It never includes code, secrets, file contents, emails of third
parties or anything from `.env`-like files.

## Content

1. Header: project name, `evaluated_sha` (short) and date, and one sentence on the goal ("7 of 9 Must requirements
   verified; 1 waived; next: FASE-2 demo"). When any human record was signed by a test proxy, say so above the fold.
2. Journey: the stages and gates so far, oldest first — time, duration, what the step left (numbers from its
   metrics, the tags it created) and what went wrong in it; the step in progress is marked as such.
3. Four tiles: Must verified · failing · missing · waived (waived Musts always visible, with their follow-up issue).
4. Increments: one row per FASE — increment, status (planned / in progress / verified / accepted / rejected),
   acceptance date and approver role, link to its issue.
5. Requirements: id, title, priority, verdict, evidence kind, criteria k/n, customer needs.
6. Open decisions: stale acceptances after a requirement changed, pending human dispositions from the last loop.

## Build and publish

1. Load the `artifact-design` skill (and `dataviz` for the tiles and any chart) before writing the page; follow its
   contract (title of two to four words, colour tokens with dark mode, phone width, no external scripts except the
   allowed CDNs).
2. Write the page to `.sdd/status-page/index.html` (ignored by git).
3. First publish of the project: ask, then publish with the Artifact tool (`icon: "chart"`) and store the returned URL
   in `.sdd/status-page.json` (`{"url": …, "publishedAt": …, "sha": …}`).
4. Later publishes: pass that `url` so the same link is updated, and refresh the stored `sha`. If the stored URL is
   refused, publish a new one and say so.
5. Report the link in one line. Pinning or sharing is the owner's decision.

Updating the same URL and reading viewer comments are not yet verified end to end in this plugin; if an update fails,
fall back to a new artifact and tell the user.
