#!/usr/bin/env node
// sdd.mjs — the sdd-pipeline CLI: task files, git traceability, commit verification, branches, requirements, the
// acceptance ledger, the journal and the status page data. Node >= 18, no deps.
//
// Usage (paths are relative to --repo when given, else to the current directory; every command takes --repo DIR):
//   sdd lint [--dir task] [--fase N] [--json] [file.md ...]
//       Lint task/TASK-FASE-*.md: V-19 task-line grammar (also `### TASK-` headings, `**TASK-…**` bold ids, unindented
//       field lines), V-09 id format + uniqueness, V-05/V-06 Commit/Acceptance present, V-16 `## Stream Ownership`
//       vs tasks. Prints `file:line V-xx message` and a summary line; exit 1 on errors. [RETROACTIVE] files are skipped.
//   sdd tasks json   [--dir task] [--fase N] [file.md ...]      task list as JSON (legacy shapes parsed too)
//   sdd tasks status [--dir task] [--fase N] [--rev HEAD] [--state checkbox|trailers] [--json] [--require-done]
//       done = a `Task:` trailer in a non-reverted commit reachable from --rev; plus checkbox state, blocked `[!]` and
//       divergences. --state defaults to `task_state` of `## SDD Stack Profile` in CLAUDE.md, else checkbox.
//   sdd tasks index  [--dir task] [--fase N] [file.md ...]      derived TASK-INDEX.md to stdout
//   sdd trace commits [--rev R] [--files] [--json]             commits with their Task/Refs/Change ids (reverts marked)
//   sdd trace req <ID> [--rev R] [--json]                      commits whose Task/Refs/Change contain ID exactly
//   sdd trace why <file>[:line[-line]] [--json]                blame → commit → trailers → ids (whole file: all commits)
//   sdd trace delivered <ID> [--rev R] [--json]                commits for ID → tags and branches that contain them
//   sdd verify --message FILE|- [--json]                       validate one commit message (the commit-msg hook)
//   sdd verify --range A..B [--json]                           validate every commit in a range + squash detection
//   sdd branch status [--json]                                 current branch, default branch, detached, worktree
//   sdd branch start fase <N> <slug> [--issue N] [--from-current] [--json]   fase-{N}-{slug}
//   sdd branch start change <CHG-ID> <slug> [--issue N]        change/{CHG-ID}-{slug}
//   sdd branch start audit [YYYY-MM-DD] [--issue N]            audit/fix-{date}
//   sdd branch start acceptance [YYYY-MM-DD] [--issue N]       acceptance/{date} (global acceptance loop / sign-off)
//       On the default branch: `git switch -c <name>` (uncommitted changes carry over). On another branch: stay there,
//       except fase on another FASE's branch (fase-M-*): merged into the default and clean → switch to the default and
//       create; not merged → exit 1, unless --from-current (stack FASE-N on it). Detached HEAD: exit 1.
//       Default branch = Stack Profile default_branch → origin/HEAD → init.defaultBranch → main/master.
//       --issue N prefixes the name with `{N}-`.
//   sdd lint --needs [CUSTOMER-NEEDS.md] [REQUIREMENTS.md] [--json]
//       Need coverage (same check as sdd-jev.mjs needs --mechanical): every need covered or out-of-scope with a decision,
//       every REQ-F/REQ-NF traced to a need, a valid Verification per requirement. Exit 1 on errors.
//   sdd lint --plan [--dir plan] [--requirements FILE] [--json]
//       Vertical plan (plan/PLAN.md `Plan-Style: vertical`; a legacy horizontal plan is skipped with a note): each FASE
//       header has Requisitos (REQ ids) and Escenarios (AC ids), V8 criteria backed by REQ/AC ids and a `## Demo` of
//       1-10 steps each citing a scenario, cited AC ids exist in spec/tests/BDD-*.md, V9 every Must REQ-F/REQ-NF is in
//       some Requisitos line; warns above 3 use cases or 15 tasks per FASE. Exit 1 on errors (scripts/lib/plan-lint.mjs).
//   sdd lint --quotes [--fase N] [--json] [--requirements FILE]
//       Literal letter (scripts/lib/quotes.mjs): for each criterion of requirements/REQUIREMENTS.md and each source file
//       under the Stack Profile's test_paths (default tests) whose code names it (`REQ-X-NNN ACn`, or a scenario id
//       AC-NNN-NN bound by a BDD tag of spec/tests/BDD-*.md): Q-01 warn, no quote comment `REQ-X-NNN ACn: "…"` in the
//       file · Q-02 error, the quote (whitespace and quote marks normalized, case kept, `…` elides) is not part of the
//       criterion's current text · Q-03 error, a literal of the criterion is missing from the file's code (comments do
//       not count). Literal: text between "…", '…', «…», “…” or ‘…’, and between backticks only after THEN/ENTONCES
//       (a backtick span before it is the command or route the test drives). A literal-exception record turns a Q-03
//       into `excepted`. Prints `file:line Q-0N REQ-X-NNN ACn message` and a summary; --json {findings[{code, severity,
//       req, ac, file, line, literal?, quote?, exception?, message}], summary}. Exit 1 on any error not excepted.
//   sdd lint --floor [--base REF] [--json]
//       Floor guard (scripts/lib/floor.mjs): was the bar lowered between a base commit and the working tree (plus
//       untracked files)? Base: --base REF (source flag) · else merge-base of HEAD with the default branch (merge-base;
//       not when HEAD is on the default branch) · else the nearest fase-*-accepted tag reachable from HEAD (tag) · else
//       exit 2 "no base". The base and its source are always printed. Only added/removed lines count; raising the bar
//       is never a finding. F-01 skip/only/focus/todo added under test_paths: error on a test bound to a criterion
//       (AC-NNN-NN or `REQ-X-NNN ACn` in its name) or one that existed in the base, warning on a todo or a new unbound
//       test · F-02 test file deleted, or renamed/moved out of test_paths, losing the criterion ids it named: error
//       (deleted without ids: warning) · F-04 coverage/security suppression added (istanbul|c8|v8 ignore, pragma: no
//       cover, :nocov:, nosemgrep, gitleaks:allow, Stryker disable): warning · F-07 Stack Profile gate lowered against
//       the base, only keys the base writes (literal_gate, acceptance_gate, adversarial_gate, floor_gate: enforce >
//       warn > off; visual_evidence: required > warn > off; prove_it: enforce > warn > off): error. Mode: Stack
//       Profile `floor_gate: off|warn|enforce` (default enforce) read from the base, else the tree. A
//       floor-exception record (same code, file, line text and base) turns an error into `excepted`. Prints
//       `floor: base <sha> (<source>: …)`, `file:line F-0N error|warning|excepted message`, `test edit <A|M|D|R> file`
//       and a summary; --json {base{sha, ref, source, detail}, head, mode, mode_source, findings[{code, severity, file,
//       line, text, message, kind?, criteria?, scenarios?, key?, from?, to?, exception?}], testEdits[{status, file,
//       from?}], summary, exit}. Exit 0 clean, warnings only or mode warn/off · 1 errors not excepted under enforce ·
//       2 no base, usage or git error.
//   sdd accept [--junit PATH...] [--junit-sha SHA] [--fase N] [--out .sdd/acceptance.json|-] [--no-out]
//              [--report acceptance/ACCEPTANCE-REPORT.md] [--remeasure] [--json]
//       Acceptance ledger: verdict per requirement (DEPRECATED, WAIVED, FAILING, MISSING, VERIFIED) from JUnit tests
//       named with their scenario id (AC-NNN-NN, or `REQ-X-NNN ACn`), the BDD tags of spec/tests/BDD-*.md and the records
//       of acceptance/decisions.jsonl. JUnit default: Stack Profile test_report_path, else .sdd/junit/. PATH may be a
//       file, a directory or a `dir/*.xml` glob. Evidence counts only when fresh: nothing under the Stack Profile's
//       code_paths + test_paths (default src, tests) changed since it was captured, and no untracked file sits under
//       them (listed in `untracked_paths`; see scripts/lib/acceptance.mjs). --junit-sha on uncommitted code exits 2
//       (commit first); without it, a dirty tree prints a `warning:` line on stderr. --remeasure first re-runs each
//       stale measurement whose latest record came from `accept measure` (exit 1 when one of them yields no number).
//       Visual evidence (Stack Profile `visual_evidence: required|warn|off`, default required; `evidence_dir`, default
//       evidencias): a REQ-F criterion needs a screenshot — a JUnit `[[ATTACHMENT|…]]`, a record's --attach, or a file
//       of the evidence dir named after its AC-NNN-NN or REQ-F-NNN-ACn — else it is `unshown` and the requirement
//       MISSING ("no visual evidence"); warn only reports it. The ledger counts them in summary.unshown.
//       Literal letter (Stack Profile `literal_gate: off|warn|enforce`, default enforce): each criterion lists the
//       `literal_gaps` of `sdd lint --quotes` (Q-02/Q-03 not excepted); under enforce a passing criterion of a Must with
//       one is `weakened` and the requirement MISSING ("test does not carry the criterion's literal"); warn only lists
//       them. summary.literal_gaps counts the criteria, summary.weakened the held-back ones.
//   sdd accept record <waiver|demo|measurement|inspection|fase-acceptance|challenge-dismissal|literal-exception|floor-exception> --by NAME --role ROLE [fields]
//              [--attach FILE...] [--allow-dirty]
//       Append one validated decision to acceptance/decisions.jsonl (head and reqHash are filled in). Fields:
//       waiver --req ID --reason TEXT [--follow-up #N (required for a Must)] · demo --req ID [--ac N] --observed TEXT
//       --pass true|false [--paths P...] · measurement --req ID [--ac N] --metric NAME --observed NUM
//       --op lt|le|gt|ge|eq --threshold NUM [--paths P...] · inspection --req ID --note TEXT [--paths P...] [--pass false]
//       · fase-acceptance --fase N --result accepted|rejected|observations --channel TEXT [--demo ID]
//       · challenge-dismissal --challenge CH-NNN --reason TEXT (a person decides a finding does not hold)
//       · literal-exception --req ID --ac N --literal TEXT --reason TEXT (a literal of the criterion that a helper
//       builds, so it is never verbatim in the test: its Q-03 is excepted while the requirement keeps its reqHash)
//       · floor-exception --code F-0N --file PATH --line "exact line text" --base REF --reason TEXT (no --req; a person
//       accepts one finding of `sdd lint --floor`: code F-01, F-02, F-04 or F-07, the file and the line text as the JSON
//       prints them in `text` — whitespace at both ends ignored — against that base; the record keeps code, file, text
//       and base as a full sha; a changed line or another base brings the finding back).
//       --attach stores files under evidence_dir with their sha256 (not on a waiver, a dismissal or an exception). Every
//       type but waiver, challenge-dismissal, literal-exception and floor-exception exits 2 on uncommitted changes under
//       its --paths (default the code paths, untracked files included): commit first, or --allow-dirty to store the
//       record with dirty: true.
//   sdd accept measure --req ID [--ac N] --metric NAME --command CMD --extract REGEX --op lt|le|gt|ge|eq
//              --threshold NUM [--paths P...] [--allow-dirty] [--json]
//       Machine measurement: runs CMD from the repo root, takes the first capture group of REGEX in its output as the
//       observed number and appends a measurement record with by "command", role "automated", the command and the
//       regex (re-run later by `sdd accept --remeasure`). Exit 1 when no number matches; exit 2 on uncommitted code
//       unless --allow-dirty (dirty: true). For objective metrics only (coverage, a benchmark); a value a person must
//       confirm goes through `accept record measurement`.
//   sdd accept pack --fase N [--out .sdd/entregas/FASE-N-evidencias.tar.gz] [--json]
//       Bundle {evidence_dir}/FASE-N/ with a manifest.json (path, sha256, bytes, kind, criterion, criteria from the
//       ledger, evaluated_sha) into a tar.gz, for the customer after the sign-off. Exit 1 when the FASE has no evidence.
//   sdd accept challenge add --req ID --ac N --category CAT --quote TEXT --evidence path:line... --verifier NAME
//              --counter confirmed|inconclusive [--json]
//       Append one finding of the adversarial round to acceptance/challenges.jsonl (written only by this command) with
//       id CH-NNN, HEAD, the requirement's reqHash and the cited paths. CAT: WEAKENED-ASSERT, MOCK-ONLY, UNWIRED,
//       BYPASS-PATH, CROSSING, NOT-IMPLEMENTED, SPEC-QUESTION, WRONG-CAPTURE. Evidence: committed production or test
//       code with an existing line; a capture under evidence_dir may be cited without a line (pinned by sha256).
//       Never under acceptance/, feedback/, spec/, requirements/, plan/, task/, audits/, changes/, .sdd/, nor test/
//       unless inside the Stack Profile's test_paths (Rails Minitest). --counter refuted is not recorded. Exit 2 on
//       any invalid field.
//   sdd accept challenge list [--open] [--fase N] [--json]
//       Challenges with their state: open · stale (a cited file changed since the challenge's HEAD, or the requirement
//       text changed) · dismissed (a challenge-dismissal record). JSON: counts, must_open, challenges[].
//   sdd accept adversarial plan [--fase N] [--json]
//       Mechanical coverage critic for the adversarial round: per FASE, requirements with their literal statement and
//       criteria, the tests bound to each criterion (with file), captures and candidate files (files under code_paths
//       of the commits whose Task: is TASK-F{N}-…); plus uncovered (active requirements in no FASE's Requisitos:),
//       fases_without_header, criteria_without_test and coverage_gaps. Challenges never change a verdict: the ledger
//       lists them in requirements[].challenges[] and summary.must_challenged.
//   sdd gate [--mode off|warn|enforce] [--fase N] [--ledger FILE] [--md] [--json] [accept options]
//       Exit 0 goal met (every Must VERIFIED or WAIVED) · 1 not met · 2 stale evidence or usage · 3 met with waived
//       Musts · 4 met, but a Must (not waived) has an open adversarial challenge and the Stack Profile says
//       `adversarial_gate: enforce`, the default (warn: printed, exit unchanged; off: ignored). Precedence
//       2 > 1 > 4 > 3 > 0. warn prints and exits 0; off exits 0 silently. Mode default: Stack Profile acceptance_gate,
//       else enforce. --fase N scopes to the `Requisitos:` line of plan/fases/FASE-N-*.md and, under visual_evidence
//       required, asks for a video whose name carries each WF-NNN of the FASE file's `Workflows:` header line (without
//       that line, each WF-NNN cited inside `## Demo`; with none, FASE-N). Any video under evidence_dir counts (manual
//       demo recordings too), as do JUnit attachments and record --attach files: a missing one is goal not met
//       (`missing_videos`). --md prints a PR-body block (with a visual-evidence line when one is missing).
//   sdd loop next [--state .sdd/acceptance-loop.json] [--max-cycles 3] [--reset] [accept options]
//       One acceptance-loop step as JSON {cycle, stop, progress, targets[{req, verdict, criteria, route_hint}],
//       missing_videos}; stop is null | goal | regression | needs-human | no-progress | max-cycles (cycle 1 is the
//       baseline; hard cap 5). route_hint capture-evidence: run the journey again with capture (no code task).
//       Open challenges are targets of their own {req, challenge, ac, category, counter, quote, evidence, route_hint}:
//       adversarial-finding when confirmed, needs-human when inconclusive. Under adversarial_gate enforce the stop
//       `goal` also needs no open challenge on a Must. Each missing FASE video is a target {video: WF-NNN|FASE-N, fase,
//       route_hint: capture-evidence} (under visual_evidence warn, in `others`); progress counts videos_missing, and a
//       cycle that captures one is progress like a criterion that turns VERIFIED. route_hint weakened-test: the test
//       passes without the criterion's literal (a `weakened` criterion, with its literal_gaps); the fix is a test edit
//       that a person approves (Art. 12).
//   sdd req show <REQ-ID> [--ac N] [--json] [--requirements FILE]
//       Statement and criteria of requirements/REQUIREMENTS.md verbatim (with --ac N, one line `REQ-F-001 AC1: …`), to
//       quote the criterion above its assert. Exit 1 when the id or the criterion does not exist.
//   sdd issue open   fase <N> | change <CHG-ID> [--dry-run] [--json]
//       One issue per FASE (from plan/fases/FASE-N-*.md: Incremento, Requisitos, Escenarios, Necesidades, Demo) or per
//       change (changes/CHANGE-REPORT-<ID>.md), labels sdd + sdd:fase|sdd:change, hidden marker <!-- sdd:FASE-N -->.
//       Idempotent: an issue with label sdd and the marker is reported instead of creating a duplicate.
//   sdd issue update fase <N> | change <CHG-ID> [--dry-run] [--json]
//       Rewrites only the region between <!-- sdd:begin --> and <!-- sdd:end -->: tasks done by trailers, verdicts per
//       requirement, demo records, branch and PR/MR. Text outside the region is kept byte for byte.
//   sdd issue close  fase <N> [--dry-run] [--json]    after tag fase-N-accepted exists (else exit 1): comment + close
//   sdd issue read   <N> [--json]                     title, body, labels, comments as data (sdd-req-change --issue)
//   sdd pr-body [--fase N | --change ID] [--issue N]
//       PR/MR body on stdout: summary, the `sdd gate --md` table, tasks or commits, `Refs #N` (FASE: the issue closes on
//       customer acceptance) or `Closes #N` (change), and the merge-commit reminder. Issue default: branch prefix `N-`.
//       Prints the `gh pr create` / `glab mr create` command on stderr; never runs it.
//     Tracker: Stack Profile `tracker: github|gitlab|off`, else the origin host. Uses the gh / glab CLI (gh api, glab api).
//     Exit: 0 ok · 1 not found or refused · 2 usage, CLI missing or not authenticated · 3 tracker disabled.
//     issue open|update|close write to the tracker: skills ask the human before running them.
//   sdd route [--answers FILE] [--json] [--write] [--confirm "Name (role)"] [--full] [--set stage=run|skip ...]
//       Adaptive route: which optional stages this project needs (specifications-engineer, spec-auditor, test-planner,
//       security-auditor, ux-designer, tech-designer, gap-detector; the core stages always run), each with its reason.
//       Facts are counted from requirements/REQUIREMENTS.md + CUSTOMER-NEEDS.md; seven factor probabilities come from
//       --answers ({"factors": {"external_customer": 0.1, ...}}, written by the LLM) or from Jev (scripts/jev/route.json).
//       p >= 0.65 yes, p <= 0.35 no, in between a doubt, treated as yes and listed. Rules: scripts/lib/route-rules.mjs.
//       --write stores `route` in pipeline-state.json and marks each optional stage with run:false as skipped with its
//       skipReason (never a done/running stage; never un-skips on its own: a stage needed again is listed in
//       `escalations`). --full runs every stage, --set overrides one (both are a person's choice and may un-skip).
//       Exit 0 ok · 2 usage or missing files · 3 Jev disabled or failing and no --answers.
//       --write also appends to status/journal.jsonl one `skip` line per stage it newly marks skipped and a `decision`.
//   sdd journal add --stage S --kind start|done|gate|decision|change|skip|evidence|feedback --text "…"
//              [--feature F (default initial)] [--refs ID...] [--by "Name (role)"] [--at ISO] [--json]
//       Append one plain-language line to status/journal.jsonl (versioned; created when missing), keys in a fixed order
//       {at, feature, stage, kind, text, refs, by?}. Stages: the pipeline stage keys plus setup, route, status-page,
//       req-change, orchestrator, lead. Exit 2 on an invalid field (nothing written).
//   sdd journal list [--feature F] [--json]                    the journal lines in file order
//   sdd status page [--json]                                   status/page.json {url, declined, createdAt, features,
//       assets}; moves a pre-5.2 .sdd/status-page.json into it the first time.
//   sdd status page set --url URL | decline | feature add --id ID --title T [--chg CHG] [--summary S]
//              | asset --sha256 H --url <published path | URL | withheld>
//       Write the registry: the page URL, the owner's "no", a feature added later (its own section and filter), an
//       evidence file already published (or withheld: personal data, kept off the page).
//   sdd status build [--out .sdd/status-page] [--template FILE] [--json]
//       The page data, contract sdd-status-v1 (docs/design/plan-5.2-status-page.md; scripts/lib/status.mjs): needs,
//       requirements with their «Para el cliente» line, criteria and evidence (read-only acceptance ledger), FASEs,
//       tasks, commits and web links (GitHub, GitLab), the journal plus facts derived from dated tags, the route,
//       decisions.jsonl and change reports. Writes --out/data.json, --out/index.html (templates/status-page/index.html
//       with the JSON in <script id="sdd-data">) and copies to --out/evidencias/ the captures and videos that are
//       present with their recorded sha256 (never traces; over 15 MB or withheld: listed, not copied). --json prints the
//       data (each evidence file with inAssets: already in status/page.json). Exit 2 on a missing template.
// Commit vocabulary: references/git-conventions.md. Old entry point: scripts/sdd-task-lint.mjs (alias).
// Exit codes: 0 ok · 1 findings (lint errors, invalid messages, --require-done unmet, nothing traced) · 2 usage or git error.
// (sdd gate has its own codes, above.)
//
// Task line grammar (V-19), one line per task, continuation lines indented two spaces:
//   ^- \[( |x|!)\] TASK-F\d+-\d{3,4}( \[P\])? .+ \| `[^`]+`(, `[^`]+`)*$
import { readFileSync, readdirSync, existsSync, statSync, realpathSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  GitError, git, gitOk, isRepo, topLevel, readCommits, effectiveCommits, commitsFor, originIds,
  parseMessage, trailersOf, parseTrailerLines, checkMessage, stackProfile, refExists, defaultBranch,
} from "./lib/git-log.mjs";
import { runFloor } from "./lib/floor.mjs";
import { runAcceptance } from "./lib/acceptance-cli.mjs";
import { runPlanLint } from "./lib/plan-lint.mjs";
import { runTracker } from "./lib/tracker.mjs";
import { runRoute } from "./lib/route.mjs";
import { runStatus } from "./lib/status.mjs";
import { parseRequirements } from "./sdd-jev.mjs";
import { reqHash } from "./lib/acceptance.mjs";

const GRAMMAR = /^- \[( |x|!)\] TASK-F\d+-\d{3,4}( \[P\])? .+ \| `[^`]+`(, `[^`]+`)*$/;
const ID_FORMAT = /^TASK-F\d+-\d{3,4}$/;
const LIST_RE = /^(\s*)[-*] \[([^\]])\]\s*(\*\*)?(TASK-F\d+-\d+)(\*\*)?(.*)$/;
const BOLD_NOCHECK_RE = /^(\s*)[-*]\s+\*\*(TASK-F\d+-\d+)\*\*(.*)$/;
const HEADING_TASK_RE = /^(#{1,6})\s+(?:\[([ xX!])\]\s*)?(?:✅\s*)?(\*\*)?(TASK-F\d+-\d+)(\*\*)?(.*)$/;
const FIELD_RE = /^(\s*)(?:[-*]\s+)?\*\*([A-Za-zÀ-ÿ][A-Za-zÀ-ÿ -]*?)\s*:?\s*\*\*\s*:?\s*(.*)$/;
const PHASE_WORDS = /^(setup|foundation|domain|contracts?|slices?|integration|integraci[oó]n|tests?|verification|verificaci[oó]n)\b/i;
const SPEC_ID_RE = /\b(?:REQ|UC|WF|API|BDD|INV|ADR|RN|NFR|VO|ENT)-[A-Z0-9]+(?:-[A-Z0-9]+)*\b/g;
const FIELD_NAMES = { commit: "commit", acceptance: "acceptance", "aceptación": "acceptance", aceptacion: "acceptance",
  refs: "refs", revert: "revert", review: "review", files: "files" };

let PROG = "sdd";
let HELP_URL = import.meta.url;
class Exit extends Error { constructor(code) { super(`exit ${code}`); this.code = code; } }
const exit = (code) => { throw new Exit(code); };

// ------------------------------------------------------------------ args
function parseArgs(argv) {
  const o = { args: [], files: [], json: false, requireDone: false, withFiles: false };
  for (let i = 0; i < argv.length; i++) {
    let a = argv[i], v;
    const eq = a.match(/^(--[a-z-]+)=(.*)$/);
    if (eq) { a = eq[1]; v = eq[2]; }
    const take = () => { if (v !== undefined) return v; if (i + 1 >= argv.length) usage(`${a} needs a value`); return argv[++i]; };
    switch (a) {
      case "--dir": o.dir = take(); break;
      case "--fase": o.fase = Number(String(take()).replace(/^FASE-/i, "")); break;
      case "--repo": o.repo = take(); break;
      case "--rev": o.rev = take(); break;
      case "--state": o.state = take(); break;
      case "--message": o.message = take(); break;
      case "--range": o.range = take(); break;
      case "--issue": o.issue = take(); break;
      case "--ac": o.ac = take(); break;
      case "--requirements": o.requirements = take(); break;
      case "--json": o.json = true; break;
      case "--files": o.withFiles = true; break;
      case "--require-done": o.requireDone = true; break;
      case "--from-current": o.fromCurrent = true; break;
      case "-h": case "--help": help(0); break;
      case "-": o.args.push(a); break;
      default:
        if (a.startsWith("-")) usage(`unknown option ${a}`);
        o.args.push(a);
    }
  }
  if (o.fase !== undefined && !Number.isInteger(o.fase)) usage("--fase needs a number");
  if (o.state && !["checkbox", "trailers"].includes(o.state)) usage("--state must be checkbox or trailers");
  if (o.issue !== undefined && !/^\d+$/.test(o.issue)) usage("--issue needs a number");
  return o;
}
function help(code) {
  const lines = readFileSync(new URL(HELP_URL), "utf8").split("\n").slice(1);
  const head = lines.slice(0, lines.findIndex((l) => !l.startsWith("//")));
  console.log(head.map((l) => l.replace(/^\/\/ ?/, "")).join("\n"));
  exit(code);
}
function usage(msg) { console.error(`${PROG}: ${msg} (see --help)`); exit(2); }
function die(msg) { console.error(`${PROG}: ${msg}`); exit(2); }
const out = (s) => console.log(s);
const json = (v) => console.log(JSON.stringify(v, null, 2));

// ------------------------------------------------------------------ files
function baseDir(o) { return path.resolve(o.repo || "."); }
function display(abs) {
  const rel = path.relative(process.cwd(), abs);
  return rel && !rel.startsWith("..") && !path.isAbsolute(rel) ? rel : abs;
}
function faseOfName(file) { const m = path.basename(file).match(/TASK-FASE-(\d+)/); return m ? Number(m[1]) : null; }
function taskFiles(o) {
  const base = baseDir(o);
  let list;
  if (o.files.length) list = o.files.map((f) => path.resolve(base, f));
  else {
    const dir = path.resolve(base, o.dir || "task");
    if (!existsSync(dir)) die(`no task directory: ${display(dir)}`);
    if (statSync(dir).isFile()) list = [dir];
    else list = readdirSync(dir).filter((f) => /^TASK-FASE-\d+.*\.md$/.test(f)).map((f) => path.join(dir, f));
  }
  for (const f of list) if (!existsSync(f)) die(`no such file: ${display(f)}`);
  list.sort((a, b) => (faseOfName(a) ?? 1e9) - (faseOfName(b) ?? 1e9) || a.localeCompare(b));
  if (o.fase !== undefined) list = list.filter((f) => faseOfName(f) === null || faseOfName(f) === o.fase);
  if (!list.length) die(`no TASK-FASE-*.md files in ${display(path.resolve(base, o.dir || "task"))}`);
  return list;
}

// ------------------------------------------------------------------ task parser
function splitLinePaths(rest) {
  const m = rest.match(/^(.*?)\s+\|\s+((?:`[^`]+`\s*,?\s*)+)$/);
  if (m) return { description: m[1], paths: [...m[2].matchAll(/`([^`]+)`/g)].map((x) => x[1]) };
  const idx = rest.lastIndexOf(" | ");
  if (idx >= 0) {
    const tail = rest.slice(idx + 3);
    const ticks = [...tail.matchAll(/`([^`]+)`/g)].map((x) => x[1]);
    return { description: rest.slice(0, idx), paths: ticks.length ? ticks : tail.split(",").map((s) => s.trim()).filter(Boolean) };
  }
  return { description: rest, paths: [] };
}
function phaseName(text) {
  const t = text.replace(/^Phase\s+\d+\s*[:—–-]?\s*/i, "").replace(/\s*\(.*$/, "").trim();
  return /^Phase\s+\d+/i.test(text) || PHASE_WORDS.test(t) ? t : null;
}
function idFase(id) { return Number(id.match(/^TASK-F(\d+)-/)[1]); }

function parseFile(file) {
  const lines = readFileSync(file, "utf8").split(/\r?\n/);
  const titleLine = lines.find((l) => /^# /.test(l)) || "";
  const doc = {
    file, display: display(file), fase: faseOfName(file), title: titleLine.replace(/^#\s+/, "").trim(),
    retroactive: /\[RETROACTIVE\]/.test(titleLine), tasks: [], streams: null,
  };
  let fence = null, cur = null, phase = null, inStreams = false;
  const close = () => { if (cur) doc.tasks.push(cur); cur = null; };
  const start = (t) => { close(); cur = { ...t, phase, body: [] }; };
  for (let i = 0; i < lines.length; i++) {
    const raw = lines[i], n = i + 1;
    const f = raw.match(/^\s*(```+|~~~+)/);
    if (fence || f) {
      if (!fence) fence = f[1]; else if (f && raw.trim().startsWith(fence)) fence = null;
      if (cur) cur.body.push({ n, raw, fenced: true });
      continue;
    }
    const h = raw.match(/^(#{1,6})\s+(.*)$/);
    const ht = raw.match(HEADING_TASK_RE);
    if (ht) {
      inStreams = false;
      let rest = ht[6].replace(/^\s*[:—–-]?\s*/, "");
      let state = ht[2] ? ht[2] : " ";
      const st = rest.match(/\[([ xX!])\]/);
      if (st) state = st[1];
      if (/✅/.test(rest)) state = "x";
      const parallel = /\[P\]/.test(rest);
      rest = rest.replace(/\s*[—–-]\s*(?:\[[ xX!]\]|✅)\s*\S*\s*$/, "").replace(/\[(?:P|RETROACTIVE)\]/g, "").replace(/\s+/g, " ").trim();
      const sp = splitLinePaths(rest);
      start({ id: ht[4], state, parallel, description: sp.description.replace(/[:\s]+$/, ""), linePaths: sp.paths,
        line: n, raw, shape: "heading", level: ht[1].length, indent: "" });
      continue;
    }
    if (h) {
      const level = h[1].length, text = h[2].trim();
      if (cur && (cur.shape !== "heading" || level <= cur.level)) close();
      inStreams = /^Stream Ownership\b/i.test(text);
      if (inStreams) doc.streams = { line: n, rows: [] };
      const ph = phaseName(text);
      if (level === 2) phase = ph; else if (ph && level === 3) phase = ph;
      if (cur) cur.body.push({ n, raw });
      continue;
    }
    const lm = raw.match(LIST_RE) || null;
    const bm = lm ? null : raw.match(BOLD_NOCHECK_RE);
    if (lm || bm) {
      inStreams = false;
      const id = lm ? lm[4] : bm[2];
      const bold = lm ? Boolean(lm[3] || lm[5]) : true;
      let rest = (lm ? lm[6] : bm[3]).replace(/^\*\*/, "").trim();
      const parallel = /^\[P\]/.test(rest) || /\s\[P\](\s|$)/.test(rest);
      rest = rest.replace(/^\[P\]\s*/, "").replace(/\s\[P\](?=\s|$)/g, "");
      const sp = splitLinePaths(rest);
      start({ id, state: lm ? lm[2] : " ", parallel, description: sp.description.trim(), linePaths: sp.paths, line: n, raw,
        shape: bold ? "bold" : "list", indent: (lm ? lm[1] : bm[1]) || "", checkbox: Boolean(lm) });
      continue;
    }
    if (inStreams && /^\s*\|/.test(raw)) {
      const cells = raw.trim().replace(/^\|/, "").replace(/\|$/, "").split("|").map((c) => c.trim());
      const isSep = cells.every((c) => /^:?-{2,}:?$/.test(c) || c === "");
      if (!isSep && !/^(tasks|tareas)$/i.test(cells[1] || "")) doc.streams.rows.push({ n, stream: cells[0].replace(/[`*]/g, "").trim(), cell: cells[1] || "" });
      continue;
    }
    if (cur) {
      if (cur.shape !== "heading" && (/^\s*\|/.test(raw) && !/^\s/.test(raw) || /^(-{3,}|\*{3,})\s*$/.test(raw))) { close(); continue; }
      cur.body.push({ n, raw });
    }
  }
  close();
  for (const t of doc.tasks) finishTask(t, doc);
  return doc;
}

function finishTask(t, doc) {
  t.fase = idFase(t.id);
  t.file = doc.display;
  t.retroactive = doc.retroactive || /\[RETROACTIVE\]/.test(t.raw);
  t.planGap = /\[PLAN GAP\]/.test(t.raw);
  t.fields = {};
  t.blockedBy = [];
  t.files = [];
  t.refs = [];
  t.unindentedFields = [];
  for (const b of t.body) {
    if (b.fenced) continue;
    const bb = b.raw.match(/^\s*[-*]\s+blocked-by:\s*(.*)$/i);
    if (bb) { t.blockedBy.push(...(bb[1].match(/TASK-F\d+-\d+/g) || [])); continue; }
    const fm = b.raw.match(FIELD_RE);
    if (!fm) continue;
    const name = FIELD_NAMES[fm[2].toLowerCase()];
    if (!name) continue;
    if (!t.fields[name]) t.fields[name] = { n: b.n, value: fm[3] };
    if (fm[1] === "") t.unindentedFields.push({ n: b.n, name });
    if (name === "files") t.files.push(...[...fm[3].matchAll(/`([^`]+)`/g)].map((x) => x[1]));
    if (name === "refs") t.refs.push(...(fm[3].match(SPEC_ID_RE) || []));
  }
  const rv = t.fields.revert?.value.match(/^`?(SAFE|COUPLED|MIGRATION|CONFIG|RETROACTIVE)\b/i);
  t.revert = rv ? rv[1].toUpperCase() : (t.fields.revert ? "OTHER" : null);
  t.paths = [...new Set([...t.linePaths, ...t.files])];
  t.refs = [...new Set(t.refs)];
}

// Stream Ownership table → Map(stream → ids[]) with ranges `TASK-F1-001 .. TASK-F1-013` / `TASK-F1-005 … 022`
function streamIds(cell) {
  const ids = [];
  const expanded = cell.replace(/TASK-F(\d+)-(\d+)\s*(?:\.\.\.?|…)\s*(?:TASK-F(\d+)-)?(\d+)/g, (all, f, a, f2, b) => {
    if (f2 && f2 !== f) return all;
    const o = [];
    for (let k = Number(a); k <= Number(b) && o.length < 10000; k++) o.push(`TASK-F${f}-${String(k).padStart(a.length, "0")}`);
    return o.join(", ");
  });
  for (const m of expanded.matchAll(/TASK-F\d+-\d+/g)) ids.push(m[0]);
  return ids;
}
function streamOf(doc) {
  const map = new Map();
  if (!doc.streams) return map;
  for (const r of doc.streams.rows) for (const id of streamIds(r.cell)) if (!map.has(id)) map.set(id, r.stream);
  return map;
}

// ------------------------------------------------------------------ lint
function lint(docs) {
  const errors = [], warnings = [];
  const err = (file, line, check, message) => errors.push({ file, line, check, message });
  const warn = (file, line, check, message) => warnings.push({ file, line, check, message });
  const seen = new Map();
  let count = 0;
  for (const doc of docs) {
    if (doc.retroactive) { warn(doc.display, 1, "V-19", "file marked [RETROACTIVE]: skipped"); continue; }
    if (!doc.tasks.length) warn(doc.display, 1, "V-19", "no task lines found");
    count += doc.tasks.length;
    for (const t of doc.tasks) {
      const where = [doc.display, t.line];
      const line = t.raw.replace(/\s+$/, "");
      if (!GRAMMAR.test(line)) {
        if (t.shape === "heading") err(...where, "V-19", `heading task \`${line.match(/^#+/)[0]} ${t.id}\` is forbidden: write \`- [ ] ${t.id} <Description> | \`<path>\`\``);
        else if (t.shape === "bold") err(...where, "V-19", `bold task id \`**${t.id}**\` is forbidden: write \`- [ ] ${t.id} <Description> | \`<path>\`\``);
        else if (t.indent) err(...where, "V-19", "task line must start at column 0");
        else if (!/^[ x!]$/.test(t.state)) err(...where, "V-19", `checkbox must be [ ], [x] or [!] (found [${t.state}])`);
        else if (t.planGap && !t.linePaths.length) warn(...where, "V-19", "[PLAN GAP] task without write-set path");
        else if (!/ \| `/.test(line)) err(...where, "V-19", "missing ` | `<path>`` write-set after the description");
        else err(...where, "V-19", "task line does not match the grammar `- [ ] TASK-F<N>-<SEQ> [P] <Description> | `<path>`[, `<path>`]*`");
      }
      if (t.shape !== "heading") for (const u of t.unindentedFields) err(doc.display, u.n, "V-19", `${t.id}: field line must be indented two spaces (\`  - **${u.name[0].toUpperCase() + u.name.slice(1)}:** …\`)`);
      if (!ID_FORMAT.test(t.id)) err(...where, "V-09", `${t.id}: id must be TASK-F<N>-<SEQ> with a 3-4 digit SEQ`);
      if (doc.fase !== null && t.fase !== doc.fase) err(...where, "V-09", `${t.id} belongs to FASE-${t.fase} but the file is TASK-FASE-${doc.fase}`);
      if (seen.has(t.id)) err(...where, "V-09", `duplicate id ${t.id} (first at ${seen.get(t.id)})`);
      else seen.set(t.id, `${doc.display}:${t.line}`);
      if (!t.fields.commit) err(...where, "V-05", `${t.id}: missing **Commit:**`);
      if (!t.fields.acceptance && !t.planGap) err(...where, "V-06", `${t.id}: missing **Acceptance:**`);
    }
    if (doc.streams) {
      const defined = new Set(doc.tasks.map((t) => t.id));
      const where = new Map();
      for (const r of doc.streams.rows) {
        for (const id of streamIds(r.cell)) {
          if (!defined.has(id)) { err(doc.display, r.n, "V-16", `unknown task ${id} in Stream ${r.stream}`); continue; }
          if (where.has(id) && where.get(id) !== r.stream) err(doc.display, r.n, "V-16", `${id} listed in Streams ${where.get(id)} and ${r.stream}`);
          else if (where.has(id)) err(doc.display, r.n, "V-16", `${id} listed twice in Stream ${r.stream}`);
          else where.set(id, r.stream);
        }
      }
      for (const t of doc.tasks) if (!where.has(t.id)) err(doc.display, t.line, "V-16", `${t.id} missing from ## Stream Ownership`);
    }
  }
  return { errors, warnings, count };
}

// ------------------------------------------------------------------ tasks status / index
function repoCommits(repo, rev, opts = {}) {
  if (!isRepo(repo)) die(`not a git repository: ${display(repo)}`);
  return effectiveCommits(readCommits(repo, { rev, ...opts }));
}
function status(o, docs) {
  const repo = baseDir(o);
  const rev = o.rev || "HEAD";
  const profile = stackProfile(repo);
  const state = o.state || (["checkbox", "trailers"].includes(profile.task_state) ? profile.task_state : "checkbox");
  const list = repoCommits(repo, rev);
  const done = new Map(), reverted = new Map();
  for (const c of list) for (const id of c.tasks) {
    const m = c.effective ? done : reverted;
    if (!m.has(id)) m.set(id, []);
    m.get(id).push(c.sha.slice(0, 7));
  }
  const all = docs.flatMap((d) => d.tasks);
  const known = new Set(all.map((t) => t.id));
  const tasks = all.filter((t) => o.fase === undefined || t.fase === o.fase).map((t) => {
    const isDone = done.has(t.id);
    const checkbox = /^[xX]$/.test(t.state) ? "x" : t.state === "!" ? "!" : " ";
    let divergence = null;
    if (checkbox === "x" && !isDone) divergence = "checked-without-trailer";
    else if (isDone && checkbox !== "x" && state === "checkbox") divergence = "trailer-without-checkbox";
    return { id: t.id, fase: t.fase, file: t.file, line: t.line, checkbox, done: isDone, blocked: !isDone && checkbox === "!",
      commits: done.get(t.id) || [], reverted: reverted.get(t.id) || [], divergence };
  });
  const unknownTrailers = [...done.entries()].filter(([id]) => !known.has(id)).map(([id, shas]) => ({ id, commits: shas }));
  const summary = { total: tasks.length, done: tasks.filter((t) => t.done).length, blocked: tasks.filter((t) => t.blocked).length,
    divergences: tasks.filter((t) => t.divergence).length };
  summary.pending = summary.total - summary.done - summary.blocked;
  return { repo: display(repo), rev, task_state: state, tasks, summary, unknownTrailers };
}

function cellEscape(s) { return String(s).replace(/\|/g, "\\|").replace(/\s+/g, " ").trim(); }
function faseTitle(doc) {
  return doc.title.replace(/^Tasks?\s*[:—–-]?\s*/i, "").replace(/^TASK-FASE-\d+\s*[:—–-]?\s*/i, "")
    .replace(/^FASE-\d+\s*[:—–-]?\s*/i, "").replace(/\s*\[RETROACTIVE\]\s*/, "").trim() || "—";
}
function index(docs) {
  const tasks = docs.flatMap((d) => d.tasks);
  const fases = [...new Set(tasks.map((t) => t.fase))].sort((a, b) => a - b);
  const o = ["# Task Index", "",
    "> Derived view of `task/TASK-FASE-*.md`, generated by `scripts/sdd.mjs tasks index` — do not edit by hand.",
    `> **Total tasks:** ${tasks.length} · **FASEs covered:** ${fases.map((f) => `FASE-${f}`).join(", ") || "—"}`, "",
    "## Summary by FASE", "", "| FASE | Title | Tasks | Parallelizable | Checked |", "|------|-------|-------|----------------|---------|"];
  for (const f of fases) {
    const ts = tasks.filter((t) => t.fase === f);
    const doc = docs.find((d) => d.fase === f) || docs.find((d) => d.tasks.some((t) => t.fase === f));
    const p = ts.filter((t) => t.parallel).length;
    o.push(`| FASE-${f} | ${cellEscape(faseTitle(doc))} | ${ts.length} | ${p} (${ts.length ? Math.round((100 * p) / ts.length) : 0}%) | ${ts.filter((t) => /^[xX]$/.test(t.state)).length} |`);
  }
  o.push("", "## All Tasks (Flat List)", "", "| ID | FASE | Phase | Description | Parallel | Status |", "|----|------|-------|-------------|----------|--------|");
  for (const t of tasks) o.push(`| ${t.id} | ${t.fase} | ${cellEscape(t.phase || "—")} | ${cellEscape(t.description)} | ${t.parallel ? "[P]" : "-"} | [${/^[xX]$/.test(t.state) ? "x" : t.state}] |`);
  const matrix = new Map();
  for (const t of tasks) for (const r of t.refs) { if (!matrix.has(r)) matrix.set(r, []); matrix.get(r).push(t.id); }
  const natural = (a, b) => a.localeCompare(b, "en", { numeric: true });
  o.push("", "## Traceability Matrix", "", "| Spec | Tasks |", "|------|-------|");
  for (const r of [...matrix.keys()].sort(natural)) o.push(`| ${r} | ${matrix.get(r).join(", ")} |`);
  if (!matrix.size) o.push("| — | — |");
  return o.join("\n") + "\n";
}

function cmdLint(o) {
  o.files = o.args;
  const docs = taskFiles(o).map(parseFile);
  const r = lint(docs);
  if (o.json) {
    json({ files: docs.map((d) => ({ file: d.display, fase: d.fase, tasks: d.tasks.length, skipped: d.retroactive })),
      tasks: r.count, errors: r.errors, warnings: r.warnings });
  } else {
    const all = [...r.errors.map((e) => ({ ...e, sev: "" })), ...r.warnings.map((w) => ({ ...w, sev: "warning: " }))]
      .sort((a, b) => a.file.localeCompare(b.file) || a.line - b.line);
    for (const e of all) out(`${e.file}:${e.line} ${e.check} ${e.sev}${e.message}`);
    out(`${PROG}: ${docs.length} file(s), ${r.count} task(s), ${r.errors.length} error(s), ${r.warnings.length} warning(s)`);
  }
  return r.errors.length ? 1 : 0;
}
function cmdTasks(o) {
  const sub = o.args.shift();
  if (sub === "lint") return cmdLint(o);
  if (!["json", "status", "index"].includes(sub)) usage(`unknown tasks command ${sub ?? "(none)"}: use json, status or index`);
  o.files = o.args;
  const docs = taskFiles(o).map(parseFile);
  if (sub === "json") {
    const streams = new Map(docs.map((d) => [d.display, streamOf(d)]));
    const tasks = docs.flatMap((d) => d.tasks).filter((t) => o.fase === undefined || t.fase === o.fase).map((t) => ({
      id: t.id, fase: t.fase, parallel: t.parallel, description: t.description, paths: t.paths,
      checked: /^[xX]$/.test(t.state), state: /^[xX]$/.test(t.state) ? "x" : t.state, blocked: t.state === "!",
      line: t.line, file: t.file, shape: t.shape, phase: t.phase, stream: streams.get(t.file).get(t.id) || null,
      blockedBy: t.blockedBy, refs: t.refs, revert: t.revert, retroactive: t.retroactive, planGap: t.planGap }));
    json({ files: docs.map((d) => ({ file: d.display, fase: d.fase, title: d.title, tasks: d.tasks.length,
      retroactive: d.retroactive, streamOwnership: Boolean(d.streams) })), count: tasks.length, tasks });
    return 0;
  }
  if (sub === "index") { process.stdout.write(index(docs)); return 0; }
  const s = status(o, docs);
  if (o.json) json(s);
  else {
    for (const t of s.tasks) {
      const label = t.done ? "done" : t.blocked ? "blocked" : "pending";
      const extra = [t.commits.join(","), t.divergence, t.reverted.length ? `reverted: ${t.reverted.join(",")}` : ""].filter(Boolean).join("  ");
      out(`${t.id}  ${label.padEnd(7)}  [${t.checkbox}]  ${extra}`.trimEnd());
    }
    for (const u of s.unknownTrailers) out(`trailer ${u.id} (${u.commits.join(",")}) names no task in the task files`);
    const m = s.summary;
    out(`status: ${m.total} task(s) · ${m.done} done · ${m.pending} pending · ${m.blocked} blocked · ${m.divergences} divergence(s) (task_state: ${s.task_state}, rev ${s.rev})`);
  }
  return o.requireDone && s.summary.done < s.summary.total ? 1 : 0;
}

// ------------------------------------------------------------------ trace
const short = (sha) => sha.slice(0, 7);
function commitJson(c, withFiles) {
  const j = { sha: c.sha, subject: c.subject, parents: c.parents, tasks: c.tasks, refs: c.refs, changes: c.changes,
    legacy: c.legacy, effective: c.effective, reverts: c.reverts };
  if (c.restores) j.restores = c.restores;
  if (withFiles) j.files = c.files;
  return j;
}
function commitLine(c, withFiles) {
  const ids = [...c.tasks, ...c.refs.filter((r) => !c.changes.includes(r)), ...c.changes].join(" ") || "-";
  const flags = [c.effective === false ? "[reverted]" : "", c.legacy ? "[legacy]" : ""].filter(Boolean).join(" ");
  let s = `${short(c.sha)}  ${ids}  ${c.subject}${flags ? "  " + flags : ""}`;
  if (withFiles && c.files.length) s += "\n" + c.files.map((f) => `    ${f}`).join("\n");
  return s;
}
function cmdTrace(o) {
  const sub = o.args.shift();
  const repo = baseDir(o);
  const rev = o.rev || "HEAD";
  if (sub === "commits") {
    const list = repoCommits(repo, rev, { files: o.withFiles });
    if (o.json) json({ rev, commits: list.map((c) => commitJson(c, o.withFiles)) });
    else { for (const c of list) out(commitLine(c, o.withFiles)); out(`trace: ${list.length} commit(s) from ${rev}`); }
    return 0;
  }
  if (sub === "req" || sub === "delivered") {
    const id = o.args[0];
    if (!id) usage(`trace ${sub} needs an ID`);
    const all = repoCommits(repo, rev);
    const hits = commitsFor(all, id);
    const eff = hits.filter((c) => c.effective);
    if (sub === "req") {
      if (o.json) json({ id, rev, commits: hits.map((c) => commitJson(c)), effective: eff.length, reverted: hits.length - eff.length });
      else { for (const c of hits) out(commitLine(c)); out(`trace req ${id}: ${eff.length} commit(s), ${hits.length - eff.length} reverted`); }
      return eff.length ? 0 : 1;
    }
    const first = eff[eff.length - 1], last = eff[0];
    const tagsOf = (c) => (c ? gitOk(repo, ["tag", "--contains", c.sha, "--sort=creatordate"]).split("\n").filter(Boolean) : []);
    const branchesOf = (c) => (c ? gitOk(repo, ["branch", "--format=%(refname:short)", "--contains", c.sha]).split("\n").filter(Boolean) : []);
    let deliveredIn = null;
    if (eff.length) {
      const sets = eff.map((c) => new Set(tagsOf(c)));
      deliveredIn = tagsOf(last).filter((t) => sets.every((s) => s.has(t)));
    }
    const r = { id, rev, commits: eff.length, reverted: hits.length - eff.length,
      first: first ? { sha: first.sha, subject: first.subject, tags: tagsOf(first), branches: branchesOf(first) } : null,
      last: last ? { sha: last.sha, subject: last.subject, tags: tagsOf(last), branches: branchesOf(last) } : null,
      delivered_in: deliveredIn || [] };
    if (o.json) json(r);
    else if (!eff.length) out(`trace delivered ${id}: no effective commit names ${id}`);
    else {
      out(`first  ${short(first.sha)}  ${first.subject}  tags: ${r.first.tags.join(", ") || "-"}  branches: ${r.first.branches.join(", ") || "-"}`);
      out(`last   ${short(last.sha)}  ${last.subject}  tags: ${r.last.tags.join(", ") || "-"}  branches: ${r.last.branches.join(", ") || "-"}`);
      out(r.delivered_in.length ? `trace delivered ${id}: in ${r.delivered_in.join(", ")} (earliest ${r.delivered_in[0]})`
        : `trace delivered ${id}: ${eff.length} commit(s), not in any tag yet`);
    }
    return r.delivered_in.length ? 0 : 1;
  }
  if (sub === "why") {
    const target = o.args[0];
    if (!target) usage("trace why needs <file>[:line]");
    if (!isRepo(repo)) die(`not a git repository: ${display(repo)}`);
    const m = target.match(/^(.*?):(\d+)(?:-(\d+))?$/);
    const file = m && !existsSync(path.resolve(repo, target)) ? m[1] : target;
    if (m && file === m[1]) {
      const from = Number(m[2]), to = Number(m[3] || m[2]);
      const r = git(repo, ["blame", "--porcelain", "-L", `${from},${to}`, "--", file]);
      if (r.status !== 0) die(`git blame failed: ${r.stderr.trim()}`);
      const lines = [];
      let curSha = null;
      for (const l of r.stdout.split("\n")) {
        const h = l.match(/^([0-9a-f]{40}) \d+ (\d+)/);
        if (h) { curSha = h[1]; lines.push({ line: Number(h[2]), sha: curSha }); }
      }
      const shas = [...new Set(lines.map((x) => x.sha))];
      const commits = shas.map((sha) => {
        if (/^0+$/.test(sha)) return { sha, subject: "(not committed yet)", tasks: [], refs: [], changes: [], ids: [], legacy: false, reverts: [], parents: [] };
        return originIds(repo, readCommits(repo, { rev: `${sha}^!` })[0]);
      });
      const bySha = new Map(commits.map((c) => [c.sha, c]));
      if (o.json) json({ file, from, to, lines: lines.map((x) => ({ line: x.line, sha: x.sha })), commits: commits.map((c) => commitJson(c)),
        ids: [...new Set(commits.flatMap((c) => c.ids))] });
      else for (const x of lines) out(`${file}:${x.line}  ${commitLine(bySha.get(x.sha))}`);
      return commits.some((c) => c.ids.length) ? 0 : 1;
    }
    const list = effectiveCommits(readCommits(repo, { rev, paths: [file], follow: true }));
    if (!list.length) die(`no commits touch ${file}`);
    const ids = [...new Set(list.filter((c) => c.effective).flatMap((c) => c.ids))];
    if (o.json) json({ file, commits: list.map((c) => commitJson(c)), ids });
    else { for (const c of list) out(commitLine(c)); out(`trace why ${file}: ${list.length} commit(s), ids: ${ids.join(" ") || "-"}`); }
    return ids.length ? 0 : 1;
  }
  usage(`unknown trace command ${sub ?? "(none)"}: use commits, req, why or delivered`);
}

// ------------------------------------------------------------------ verify
function codePaths(repo) {
  const prof = stackProfile(topLevel(repo));
  const list = (prof.code_paths || "").split(",").map((s) => s.trim().replace(/^\.\//, "").replace(/\/+$/, "")).filter(Boolean);
  return list.length ? list : ["src"];
}
function report(results, o, extra = {}) {
  const errors = results.reduce((n, r) => n + r.errors.length, 0) + (extra.rangeErrors || []).length;
  if (o.json) { json({ ok: errors === 0, results, ...extra }); return errors ? 1 : 0; }
  for (const r of results) {
    const where = r.sha ? short(r.sha) : r.source;
    for (const e of r.errors) out(`${where}: error: ${e}`);
    for (const w of r.warnings) out(`${where}: warning: ${w}`);
  }
  for (const e of extra.rangeErrors || []) out(`range: error: ${e}`);
  const warns = results.reduce((n, r) => n + r.warnings.length, 0);
  out(`verify: ${results.length} message(s), ${errors} error(s), ${warns} warning(s)`);
  return errors ? 1 : 0;
}
function cmdVerify(o) {
  if (!o.message === !o.range) usage("verify needs exactly one of --message FILE or --range A..B");
  const repo = baseDir(o);
  if (o.message) {
    let text;
    try { text = o.message === "-" ? readFileSync(0, "utf8") : readFileSync(path.resolve(o.message), "utf8"); }
    catch (e) { die(`cannot read ${o.message}: ${e.message}`); }
    const pm = parseMessage(text);
    const cwd = isRepo(repo) ? repo : process.cwd();
    const r = { source: o.message === "-" ? "stdin" : display(path.resolve(o.message)), ...checkMessage(pm.lines, pm.lines.length ? trailersOf(pm.message, cwd) : []) };
    return report([r], o);
  }
  if (!isRepo(repo)) die(`not a git repository: ${display(repo)}`);
  const fmt = "--format=%x1e%H%x1f%P%x1f%(trailers:only,unfold)%x1f%B%x1f";
  const raw = gitOk(repo, ["log", "--name-only", fmt, ...o.range.split(/\s+/).filter(Boolean)]);
  const code = codePaths(repo);
  const inCode = (f) => code.some((p) => f === p || f.startsWith(p + "/"));
  const results = [], perTask = {};
  let codeCommits = 0;
  for (const rec of raw.split("\x1e").slice(1)) {
    const [sha, parents = "", tr = "", body = "", tail = ""] = rec.split("\x1f");
    const lines = body.replace(/\n+$/, "").split("\n").map((text, i) => ({ n: i + 1, text }));
    const r = { sha, ...checkMessage(lines, parseTrailerLines(tr)) };
    const files = tail.split("\n").map((s) => s.trim()).filter(Boolean);
    r.code = parents.split(" ").filter(Boolean).length < 2 && files.some(inCode);
    if (r.code) codeCommits++;
    for (const t of r.trailers.Task) (perTask[t] ||= []).push(short(sha));
    results.push(r);
  }
  const rangeErrors = [];
  if (codeCommits && !Object.keys(perTask).length) {
    rangeErrors.push(`${o.range} has ${codeCommits} commit(s) touching code paths (${code.join(", ")}) but no Task: trailer — a squash or rebase merge drops the per-task commits; merge with a merge commit (git merge --no-ff) instead`);
  }
  return report(results, o, { range: o.range, code_paths: code, code_commits: codeCommits, per_task_commits: perTask, rangeErrors });
}

// ------------------------------------------------------------------ branch
function branchInfo(repo) {
  const cur = git(repo, ["symbolic-ref", "--short", "-q", "HEAD"]);
  const current = cur.status === 0 ? cur.stdout.trim() : null;
  const def = defaultBranch(repo);
  const gd = path.resolve(repo, gitOk(repo, ["rev-parse", "--git-dir"]).trim());
  const cd = path.resolve(repo, gitOk(repo, ["rev-parse", "--git-common-dir"]).trim());
  return { current, detached: current === null, default: def.name, default_source: def.source,
    is_default: current !== null && current === def.name, linked_worktree: gd !== cd, top_level: topLevel(repo) };
}
function slugify(s) { return String(s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, ""); }
function cmdBranch(o) {
  const sub = o.args.shift();
  const repo = baseDir(o);
  if (!isRepo(repo)) die(`not a git repository: ${display(repo)}`);
  const info = branchInfo(repo);
  if (sub === "status") {
    if (o.json) json(info);
    else out(info.detached ? `branch: detached HEAD (default: ${info.default ?? "unknown"})`
      : `branch: ${info.current}${info.is_default ? " (default)" : ""} · default: ${info.default ?? "unknown"} (${info.default_source ?? "-"})${info.linked_worktree ? " · linked worktree" : ""}`);
    return 0;
  }
  if (sub !== "start") usage(`unknown branch command ${sub ?? "(none)"}: use status or start`);
  const [kind, id, slugArg] = o.args;
  let name;
  if (kind === "fase") {
    const n = String(id || "").replace(/^FASE-/i, "");
    if (!/^\d+$/.test(n)) usage("branch start fase needs <N> <slug>");
    const slug = slugify(slugArg); if (!slug) usage("branch start fase needs a slug");
    name = `fase-${Number(n)}-${slug}`;
  } else if (kind === "change") {
    if (!id || !/^[A-Za-z0-9][A-Za-z0-9-]*$/.test(id)) usage("branch start change needs <CHG-ID> <slug>");
    const slug = slugify(slugArg); if (!slug) usage("branch start change needs a slug");
    name = `change/${id}-${slug}`;
  } else if (kind === "audit") {
    const date = id || new Date().toISOString().slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) usage("branch start audit takes an optional YYYY-MM-DD");
    name = `audit/fix-${date}`;
  } else if (kind === "acceptance") {
    const date = id || new Date().toISOString().slice(0, 10);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) usage("branch start acceptance takes an optional YYYY-MM-DD");
    name = `acceptance/${date}`;
  } else usage("branch start needs fase, change, audit or acceptance");
  if (o.issue) name = `${o.issue}-${name}`;
  if (git(repo, ["check-ref-format", "--branch", name]).status !== 0) usage(`invalid branch name ${name}`);
  const result = (action, code, msg) => { if (o.json) json({ action, branch: action === "refused" ? null : (action === "stayed" ? info.current : name), wanted: name, ...info, message: msg }); else out(msg); return code; };
  if (info.detached) return result("refused", 1, `branch: HEAD is detached — switch to a branch first (git switch ${info.default ?? "<default>"}), then run again`);
  if (!info.default) die("cannot detect the default branch: set `default_branch` in the SDD Stack Profile of CLAUDE.md");
  const dirty = () => git(repo, ["status", "--porcelain", "--untracked-files=no"]).stdout.trim();
  const switchTo = (from) => {
    if (refExists(repo, `refs/heads/${name}`)) {
      if (dirty()) return result("refused", 1, `branch: ${name} already exists and tracked files have uncommitted changes — commit them or run git switch ${name} yourself`);
      gitOk(repo, ["switch", "-q", name]);
      return result("resumed", 0, `branch: switched to existing ${name}`);
    }
    gitOk(repo, ["switch", "-q", "-c", name]);
    return result("created", 0, `branch: created ${name} from ${from}`);
  };
  if (!info.is_default) {
    // Another FASE's branch (fase-M-*, optionally issue-prefixed): FASE N starts from the default branch once FASE M
    // is merged there, so each FASE branch carries only its own tasks; stacking on an unmerged FASE is a deliberate
    // choice (--from-current). Any other work branch, or FASE N's own branch, keeps the "stay" rule.
    const prev = kind === "fase" ? info.current.match(/^(?:\d+-)?fase-(\d+)-/) : null;
    const n = kind === "fase" ? Number(String(id).replace(/^FASE-/i, "")) : null;
    if (prev && Number(prev[1]) !== n) {
      const m = Number(prev[1]);
      if (o.fromCurrent) return switchTo(info.current);
      const merged = refExists(repo, `refs/heads/${info.default}`)
        && git(repo, ["merge-base", "--is-ancestor", "HEAD", `refs/heads/${info.default}`]).status === 0;
      if (!merged) return result("refused", 1, `branch: FASE-${m} branch ${info.current} not merged into ${info.default}: merge it (after its acceptance) or pass --from-current to stack FASE-${n} on it`);
      if (dirty()) return result("refused", 1, `branch: FASE-${m} branch ${info.current} is merged into ${info.default} but tracked files have uncommitted changes — commit them, then run again`);
      gitOk(repo, ["switch", "-q", info.default]);
      return switchTo(info.default);
    }
    return result("stayed", 0, `branch: staying on work branch ${info.current} (default is ${info.default})`);
  }
  return switchTo(info.current);
}

// ------------------------------------------------------------------ req show
// The literal text of a requirement and its criteria, as requirements/REQUIREMENTS.md has them: what a test quotes
// above its assert (M6). Parsed with parseRequirements (sdd-jev.mjs), the same reader as the acceptance ledger.
function cmdReq(o) {
  const sub = o.args.shift();
  if (sub !== "show") usage(`unknown req command ${sub ?? "(none)"}: use show`);
  const id = String(o.args.shift() || "").toUpperCase();
  if (!id) usage("req show needs a requirement id (REQ-F-001)");
  if (o.args.length) usage(`unexpected argument ${o.args[0]}`);
  const file = path.resolve(baseDir(o), o.requirements || "requirements/REQUIREMENTS.md");
  if (!existsSync(file)) die(`${display(file)} not found`);
  const req = parseRequirements(readFileSync(file, "utf8")).find((r) => r.id === id);
  if (!req) { console.error(`${PROG}: ${id} is not in ${display(file)}`); return 1; }
  let criteria = req.criteria.map((text, i) => ({ n: i + 1, text }));
  if (o.ac !== undefined) {
    const m = String(o.ac).match(/^(?:AC)?(\d+)$/i);
    if (!m) usage("--ac must be a criterion number (2 or AC2)");
    const n = Number(m[1]);
    criteria = criteria.filter((c) => c.n === n);
    if (!criteria.length) { console.error(`${PROG}: ${id} has ${req.criteria.length} criteria; AC${n} does not exist`); return 1; }
  }
  if (o.json) {
    json({ id: req.id, type: req.type, title: req.title, statement: req.statement, priority: req.priority, needs: req.needs || [],
      verification: req.verification, deprecated: req.deprecated, criteria, ...(o.ac !== undefined ? { ac: criteria[0].n } : {}),
      reqHash: reqHash(req), file: display(file) });
    return 0;
  }
  if (o.ac !== undefined) { out(`${req.id} AC${criteria[0].n}: ${criteria[0].text}`); return 0; }
  out(`${req.id}: ${req.title}${req.deprecated ? "  [deprecated]" : ""}`);
  out(`Statement: ${req.statement}`);
  out(`Priority: ${req.priority || "—"} · Verification: ${req.verification || "—"} · Needs: ${(req.needs || []).join(", ") || "—"}`);
  for (const c of criteria) out(`AC${c.n}: ${c.text}`);
  return 0;
}

// ------------------------------------------------------------------ task progress (for `sdd status build`)
/** Every task of task/TASK-FASE-*.md under `root` with {id, fase, done, commits, refs}, or null without task files.
 *  done = a `Task:` trailer in a non-reverted commit; with task_state checkbox a checked box also counts. */
function taskProgress(root) {
  const dir = path.join(root, "task");
  if (!existsSync(dir) || !statSync(dir).isDirectory()) return null;
  const files = readdirSync(dir).filter((f) => /^TASK-FASE-\d+.*\.md$/.test(f)).map((f) => path.join(dir, f));
  if (!files.length) return null;
  const docs = files.map(parseFile);
  const refs = new Map(docs.flatMap((d) => d.tasks).map((t) => [t.id, t.refs]));
  let list = null;
  if (isRepo(root)) {
    try { const s = status({ repo: root }, docs); list = s.tasks.map((t) => ({ ...t, done: t.done || (s.task_state === "checkbox" && t.checkbox === "x") })); }
    catch (e) { if (!(e instanceof Exit) && !(e instanceof GitError)) throw e; }
  }
  if (!list) list = docs.flatMap((d) => d.tasks).map((t) => ({ id: t.id, fase: t.fase, done: /^[xX]$/.test(t.state), commits: [] }));
  return list.map((t) => ({ id: t.id, fase: t.fase, done: t.done, commits: t.commits || [], refs: refs.get(t.id) || [] }));
}

// ------------------------------------------------------------------ main
/** First positional word of argv (skipping `--repo DIR`): the command. */
function firstCommand(argv) {
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--repo") { i++; continue; }
    if (argv[i].startsWith("-")) continue;
    return { cmd: argv[i], index: i };
  }
  return { cmd: null, index: -1 };
}
/** Run the CLI; returns the exit code. `legacy` = the sdd-task-lint.mjs command set (lint|json|status|index). */
export function run(argv, { prog = "sdd", helpUrl = import.meta.url, legacy = false } = {}) {
  PROG = prog; HELP_URL = helpUrl;
  if (!legacy) {
    const first = firstCommand(argv);
    if (first.cmd === "lint" && argv.includes("--plan")) {
      if (argv.includes("--help") || argv.includes("-h")) { try { help(0); } catch (e) { if (e instanceof Exit) return e.code; throw e; } }
      return runPlanLint([...argv.slice(0, first.index), ...argv.slice(first.index + 1)], { prog });
    }
    if (first.cmd === "lint" && argv.includes("--floor")) {
      if (argv.includes("--help") || argv.includes("-h")) { try { help(0); } catch (e) { if (e instanceof Exit) return e.code; throw e; } }
      return runFloor([...argv.slice(0, first.index), ...argv.slice(first.index + 1)].filter((a) => a !== "--floor"), { prog });
    }
    if (["accept", "gate", "loop"].includes(first.cmd) || (first.cmd === "lint" && (argv.includes("--needs") || argv.includes("--quotes")))) {
      if (argv.includes("--help") || argv.includes("-h")) { try { help(0); } catch (e) { if (e instanceof Exit) return e.code; throw e; } }
      return runAcceptance(first.cmd, [...argv.slice(0, first.index), ...argv.slice(first.index + 1)].filter((a) => a !== "--needs"), { prog });
    }
    if (first.cmd === "route") {
      if (argv.includes("--help") || argv.includes("-h")) { try { help(0); } catch (e) { if (e instanceof Exit) return e.code; throw e; } }
      return runRoute([...argv.slice(0, first.index), ...argv.slice(first.index + 1)], { prog });
    }
    if (["journal", "status"].includes(first.cmd)) {
      if (argv.includes("--help") || argv.includes("-h")) { try { help(0); } catch (e) { if (e instanceof Exit) return e.code; throw e; } }
      return runStatus(first.cmd, [...argv.slice(0, first.index), ...argv.slice(first.index + 1)], { prog, taskProgress });
    }
    if (["issue", "pr-body"].includes(first.cmd)) {
      if (argv.includes("--help") || argv.includes("-h")) { try { help(0); } catch (e) { if (e instanceof Exit) return e.code; throw e; } }
      return runTracker(first.cmd, [...argv.slice(0, first.index), ...argv.slice(first.index + 1)], { prog });
    }
  }
  try {
    const o = parseArgs(argv);
    const cmd = o.args.shift();
    if (!cmd || cmd === "help") help(cmd ? 0 : 2);
    if (legacy) {
      if (cmd === "lint") return cmdLint(o);
      if (["json", "status", "index"].includes(cmd)) { o.args.unshift(cmd); return cmdTasks(o); }
      usage(`unknown command ${cmd}`);
    }
    switch (cmd) {
      case "lint": return cmdLint(o);
      case "tasks": return cmdTasks(o);
      case "trace": return cmdTrace(o);
      case "verify": return cmdVerify(o);
      case "branch": return cmdBranch(o);
      case "req": return cmdReq(o);
      default: usage(`unknown command ${cmd}`);
    }
  } catch (e) {
    if (e instanceof Exit) return e.code;
    if (e instanceof GitError) { console.error(`${PROG}: ${e.message}`); return 2; }
    throw e;
  }
}

const self = fileURLToPath(import.meta.url);
let invoked = "";
try { invoked = process.argv[1] ? realpathSync(process.argv[1]) : ""; } catch { invoked = ""; }
if (invoked === realpathSync(self)) process.exitCode = run(process.argv.slice(2));
