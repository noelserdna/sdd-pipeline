---
paths:
  - "{app_dir}/src/app/**/route.ts"
---

# Route Handlers

- Create a `route.ts` only for an HTTP API the specification explicitly requires: path, methods, status codes and bodies come from the contract.
- The app's own pages and forms use Server Actions, not these handlers.
- Export one function per HTTP method (`GET`, `POST`, ...); `params` is a Promise.
- Validate and normalize the request body on the server; answer with `Response.json(body, { status })` in the contract's error format.
- Delegate rules to the domain layer shared with the Server Actions; never duplicate them here.
- GET handlers are dynamic by default (Next.js 15+); do not add caching to handlers that read the database.
- Test handlers in Vitest by calling the exported functions with a `Request`.
