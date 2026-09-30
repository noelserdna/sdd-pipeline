---
paths:
  - "{app_dir}/src/**/*.test.ts"
  - "{app_dir}/src/**/*.test.tsx"
  - "{app_dir}/tests/**"
  - "{app_dir}/vitest.config.*"
---

# Tests (Vitest)

- Vitest only; no second test framework and no factory libraries: small local helpers build test data.
- Unit-test domain rules; test Server Actions and data functions against an isolated SQLite test database migrated with `npx prisma migrate deploy`.
- Mock `next/navigation` and `next/cache` when an action under test calls `redirect` or `revalidatePath`.
- Name tests after the behavior and start the name with the scenario id of spec/tests/BDD-*.md (e.g. `it("AC-001-02 <behavior>")`): `sdd accept` binds JUnit results to acceptance criteria by that id.
- Per task: `npx vitest run <file>` (`-t "<pattern>"` to focus), then `npx tsc --noEmit` and `npx eslint <files>`.
- Vitest never drives a browser. E2E journeys, which assert the criterion's text and save one capture per criterion under `evidencias/FASE-N/` (profile key `evidence_dir`), live in the shared acceptance suite when the profile declares `acceptance`, otherwise in the Playwright project under `{app_dir}/tests/e2e/`.
- A port to an external system (LLM, payments, mail) has its double for unit tests and a `CONTRACT-<port>` test in `{app_dir}/tests/contract/` that runs the same cases on the double and on the real adapter with a fake transport.
- Tests are independent: no order dependence, no leftover rows. Assert outcomes with `expect`, not implementation details.
