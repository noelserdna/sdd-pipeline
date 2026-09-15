---
paths:
  - "{app_dir}/app/models/**/*.rb"
  - "{app_dir}/test/models/**/*.rb"
---

# Models

- Domain rules, validations and state transitions live in models; controllers and views call model methods and never duplicate the rules.
- Normalize input before validating it (`normalizes` or `before_validation`).
- Model state as an explicit attribute (boolean, timestamp or `enum`) with one intention-revealing method per transition.
- Reusable queries such as state filters are chainable scopes.
- Every validation that protects data has a database constraint too: `null: false`, defaults, unique indexes, foreign keys.
- Validation messages come from I18n; texts required by the specification are used verbatim.
- Concerns only for behavior shared by several models; no service object for logic that belongs to one model.
- Test each rule in `test/models` with fixtures: the valid case, each invalid case and each transition.
