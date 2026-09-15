---
paths:
  - "{app_dir}/test/**/*.rb"
  - "{app_dir}/test/fixtures/**/*.yml"
---

# Tests (Minitest)

- Minitest and fixtures only; no second test framework and no factory libraries.
- Model tests for validations, scopes and state transitions; controller or integration tests for requests, redirects and statuses.
- Name tests after the behavior and put the SDD ID first when the task has one (e.g. `test "BDD-UC-001-01 <behavior>"`).
- One file: `bin/rails test test/models/x_test.rb`; one test: append `:LINE` or `-n "/pattern/"`.
- No system tests when the project has a shared acceptance suite (profile key `acceptance`).
- Tests are independent: no order dependence, no leftover data; fixtures stay minimal and valid.
- Assert outcomes (`assert_redirected_to`, `assert_response`, `assert_difference`), not implementation details.
