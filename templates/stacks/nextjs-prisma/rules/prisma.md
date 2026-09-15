---
paths:
  - "{app_dir}/prisma/schema.prisma"
  - "{app_dir}/prisma/migrations/**"
  - "{app_dir}/prisma.config.ts"
---

# Prisma schema and migrations

- `schema.prisma` is the source of truth: create migrations with `npx prisma migrate dev --name <change>`, never hand-written SQL.
- Never edit a migration that has been applied; create a new one.
- Run `npx prisma generate` after every schema change; import the client from the generator's configured `output`.
- Prisma 7 connects through a driver adapter (`@prisma/adapter-better-sqlite3`); the database URL comes from `prisma.config.ts` and the environment.
- Required fields are non-optional; defaults where the spec defines them; `@unique` for uniqueness rules; `@@index` for filter and order columns; relations with foreign keys.
- Rebuild the local database only with the profile's `db_reset_safe` command (migrations applied with `npx prisma migrate deploy`), never with Prisma's destructive reset commands.
- Commit `schema.prisma` together with its migration folder.
