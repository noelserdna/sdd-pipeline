---
paths:
  - "{app_dir}/src/app/**/*.tsx"
  - "{app_dir}/src/app/**/actions.ts"
  - "{app_dir}/src/components/**/*.tsx"
---

# Pages, components and Server Actions

- Server Components by default; `"use client"` only on small interactive leaves, never on a whole page.
- UI mutations are Server Actions in `actions.ts` (`"use server"`), one per operation; forms use `<form action={...}>` so they work without JavaScript.
- Actions stay thin: read and validate `FormData` on the server, call the domain layer, then `revalidatePath` and `redirect` (outside `try/catch`, it throws). On validation failure return error state for `useActionState`.
- `params` and `searchParams` are Promises: `await` them. Pages that read the database render dynamically (`await connection()`).
- Keep query state such as the active filter in the URL and pass it through hidden inputs in every form.
- Semantic HTML with labels; roles, accessible names and texts required by the specification verbatim.
- No client state libraries, UI frameworks or extra bundler configuration.
- Pages and forms never call the app's own Route Handlers.
