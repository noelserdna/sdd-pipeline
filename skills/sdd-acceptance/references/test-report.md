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
| Playwright | `PLAYWRIGHT_JUNIT_OUTPUT_NAME="$(git rev-parse --show-toplevel)/.sdd/junit/e2e.xml" npx playwright test --reporter=junit` | Chain it after the unit suite with `;` when the project has an acceptance suite, so one failing suite does not skip the other |
| Go | `go test -v ./... 2>&1 \| go-junit-report > "$(git rev-parse --show-toplevel)/.sdd/junit/go.xml"` | Tool `go-junit-report` |

Rules that make the results usable as evidence:

- **Names carry the scenario id.** Each test starts its name with the `AC-NNN-NN` of the scenario it verifies
  (`it("AC-001-02 rejects an empty title")`, `test "AC-001-02 rejects an empty title"`); one test may name several.
  `REQ-F-001 AC2` also binds, for criteria without a scenario file. Nothing else binds a test to a criterion.
- **Whole suite, current commit.** Run the full suite at `HEAD` on a clean tree and pass `--junit-sha HEAD` to
  `sdd accept`; a partial run leaves criteria MISSING, and old XML is reported as stale evidence.
- **Failures are evidence.** A non-zero exit from the runner is expected when tests fail; the XML is what matters.
