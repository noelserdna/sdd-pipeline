# Test results as JUnit XML (`test_report`)

`sdd accept` reads JUnit XML, the one format every mainstream runner can write. The Stack Profile key `test_report`
is the command that runs the whole own suite and writes it; it runs from `app_dir` like `test`. Write into the repo
root's `.sdd/junit/` (git-ignored) so the default reader finds it, or declare `test_report_path`.
`$(git rev-parse --show-toplevel)` keeps the path right when `app_dir` is a subdirectory.

| Runner | `test_report` | Notes |
|---|---|---|
| Vitest | `npx vitest run --reporter=junit --outputFile="$(git rev-parse --show-toplevel)/.sdd/junit/vitest.xml"` | Built in (example: kit `nextjs-prisma`) |
| Jest | `JEST_JUNIT_OUTPUT_DIR="$(git rev-parse --show-toplevel)/.sdd/junit" npx jest --ci --reporters=default --reporters=jest-junit` | Needs the `jest-junit` dev dependency |
| Minitest (Rails) | `MINITEST_REPORTER=JUnitReporter MINITEST_REPORTERS_REPORTS_DIR="$(git rev-parse --show-toplevel)/.sdd/junit/minitest" bin/rails test` | Gem `minitest-reporters` and `Minitest::Reporters.use! if ENV["MINITEST_REPORTER"]` in `test/test_helper.rb` (kit `rails`). The reporter empties its directory, hence the subdirectory |
| pytest | `pytest --junitxml="$(git rev-parse --show-toplevel)/.sdd/junit/pytest.xml"` | Built in |
| RSpec | `bundle exec rspec --format progress --format RspecJunitFormatter --out "$(git rev-parse --show-toplevel)/.sdd/junit/rspec.xml"` | Gem `rspec_junit_formatter` |
| Playwright | `PLAYWRIGHT_JUNIT_OUTPUT_NAME="$(git rev-parse --show-toplevel)/.sdd/junit/e2e.xml" npx playwright test --reporter=junit` | Chain it after the unit suite with `;` when the project has an acceptance suite, so one failing suite does not skip the other. The acceptance suite runs with `screenshot: 'on'` and `video: 'on'`, and each test attaches its final capture (below) |
| Go | `go test -v ./... 2>&1 \| go-junit-report > "$(git rev-parse --show-toplevel)/.sdd/junit/go.xml"` | Tool `go-junit-report` |

Rules that make the results usable as evidence:

- **Names carry the scenario id.** Each test starts its name with the `AC-NNN-NN` of the scenario it verifies
  (`it("AC-001-02 rejects an empty title")`, `test "AC-001-02 rejects an empty title"`); one test may name several.
  `REQ-F-001 AC2` also binds, for criteria without a scenario file. Nothing else binds a test to a criterion.
- **Whole suite, current commit.** Run the full suite at `HEAD` on a clean tree (untracked files included) and pass
  `--junit-sha HEAD` to `sdd accept`, which refuses a dirty tree; a partial run leaves criteria MISSING, and old XML
  is reported as stale evidence.
- **Captures bind by attachment or by name.** A test of a `REQ-F` criterion saves its capture as
  `evidencias/FASE-{N}/{AC-NNN-NN | REQ-F-NNN-ACn}.png`. Playwright attaches it (`testInfo.attach(name, { path })`),
  so the XML carries `[[ATTACHMENT|path]]` in `<system-out>` and the ledger binds the image to the criteria the test
  names. Runners that write no attachments (Minitest, pytest) bind through the file name instead: an image under
  `evidence_dir` named with the criterion's id counts for it, which is why the name must carry the id exactly. The
  journey's video carries its `WF-NNN` (or `FASE-N`) in the file name, under `evidencias/FASE-{N}/` (`.webm`, `.mp4`;
  `.jpg` is read for images too). Traces are never attached.
- **Failures are evidence.** A non-zero exit from the runner is expected when tests fail; the XML is what matters.
