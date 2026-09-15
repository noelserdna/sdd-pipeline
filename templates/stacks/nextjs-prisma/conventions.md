## Stack Conventions

Stack: Next.js 15/16 App Router · TypeScript · Prisma 7 with a driver adapter · SQLite · Vitest. Profile commands run from `app_dir`; paths below are relative to it.

- **Mutations**: Server Actions (`"use server"`). A `<form action={action}>` rendered by a Server Component works without JavaScript; `useActionState` shows validation errors. On success `revalidatePath(...)`, then `redirect(...)` outside any `try/catch`.
- **HTTP APIs**: Route Handlers (`route.ts`) only for APIs the spec explicitly requires, never as the backend of the app's own forms.
- **Rendering**: `params` and `searchParams` are Promises (`await` them). Pages that read the database render dynamically (`await connection()` from `next/server`), never from a stale build-time cache. Keep active filters in hidden inputs so actions preserve them.
- **Components**: Server Components by default; `"use client"` only for small interactive pieces. Semantic HTML with labels; texts required by the spec verbatim.
- **Domain**: rules, validation and state transitions in `src/domain` or `src/lib`; pages and actions stay thin and call them.
- **Prisma 7**: one client singleton built with the driver adapter (`@prisma/adapter-better-sqlite3`) from the generated client. `npx prisma generate` after every schema change; `npx prisma migrate dev --name <change>` while developing; `npx prisma migrate deploy` to rebuild a database. Never edit an applied migration.
- **Database reset**: only the profile's `db_reset_safe` (deletes the local SQLite files in `app_dir`, then applies the migrations). Never run Prisma's destructive reset commands and never set its AI-safety override variables.
- **Checks per task**: `npx vitest run <file>`, `npx tsc --noEmit`, `npx eslint <files>`. `npm run build` only for final verification.
- **Server**: iterate with `npx next dev`; final verification builds once and serves with `npx next start -p <port> -H 127.0.0.1`.
