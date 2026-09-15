---
paths:
  - "{app_dir}/db/migrate/**/*.rb"
  - "{app_dir}/db/schema.rb"
---

# Migrations and schema

- Generate migrations with `bin/rails generate migration`; never write timestamps by hand.
- Migrations are reversible: one `change` method, or `up` and `down` when an operation cannot be reversed automatically.
- Never edit a migration that has already run; add a new one.
- Mirror model validations: `null: false`, defaults, unique indexes for uniqueness rules, `references` with `foreign_key: true`.
- Index the columns used by filters and ordering.
- `db/schema.rb` is generated: change it only through `bin/rails db:migrate` and commit it with its migration.
- Recreate the local database with the profile's `db_reset_safe` command.
