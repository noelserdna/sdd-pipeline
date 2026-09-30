---
paths:
  - "{app_dir}/test/**/*.rb"
  - "{app_dir}/test/fixtures/**/*.yml"
---

# Tests (Minitest)

- Minitest and fixtures only; no second test framework and no factory libraries.
- Model tests for validations, scopes and state transitions; controller or integration tests for requests, redirects and statuses.
- Name tests after the behavior and start the name with the scenario id of spec/tests/BDD-*.md (e.g. `test "AC-001-02 <behavior>"`): `sdd accept` binds JUnit results to acceptance criteria by that id.
- JUnit for `sdd accept` (profile key `test_report`): gem `minitest-reporters` in the `:test` group and `Minitest::Reporters.use! if ENV["MINITEST_REPORTER"]` in `test/test_helper.rb`, so plain `bin/rails test` output stays unchanged.
- One file: `bin/rails test test/models/x_test.rb`; one test: append `:LINE` or `-n "/pattern/"`.
- Browser journeys assert the criterion's text and save one capture per criterion under `evidencias/FASE-N/` (profile key `evidence_dir`), named with its id. They live in the shared acceptance suite when the profile declares `acceptance`, otherwise in `test/system/`.
- A port to an external system (LLM, payments, mail) has its double for unit tests and a `CONTRACT-<port>` test in `test/contract/` that runs the same cases on the double and on the real adapter with a fake transport.
- Tests are independent: no order dependence, no leftover data; fixtures stay minimal and valid.
- Assert outcomes (`assert_redirected_to`, `assert_response`, `assert_difference`), not implementation details.
