---
paths:
  - "{app_dir}/src/{lib,domain,server}/**"
---

# Domain and data access

- Business rules, validation and state transitions live here, not in components, pages or actions.
- One module per resource exposing typed functions; pages, Server Actions and Route Handlers call them.
- Normalize input before validating it; return typed errors for expected validation failures instead of throwing.
- Validation messages are the texts required by the specification.
- Import the single Prisma client instance built with the driver adapter; never create a client per request.
- Reusable query helpers for filters and ordering; select only the fields callers need.
- Required data is enforced in the schema too, not only in validation.
- Unit-test each rule with Vitest.
