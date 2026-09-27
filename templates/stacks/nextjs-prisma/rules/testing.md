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
- No browser tests when the project has a shared acceptance suite (profile key `acceptance`).
- Tests are independent: no order dependence, no leftover rows. Assert outcomes with `expect`, not implementation details.
