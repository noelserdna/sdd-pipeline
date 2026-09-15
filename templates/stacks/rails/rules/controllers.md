---
paths:
  - "{app_dir}/app/controllers/**/*.rb"
  - "{app_dir}/config/routes.rb"
  - "{app_dir}/test/controllers/**/*.rb"
  - "{app_dir}/test/integration/**/*.rb"
---

# Controllers and routes

- Declare routes with `resources` or `resource` and the standard actions, limited with `only:`.
- A state change is a nested singular resource (`resource :completion, only: %i[create destroy]`) or an `update` of the state attribute; avoid custom member routes.
- Thin controllers: load the record, call the model, respond. Strong parameters (`params.expect` or `require`/`permit`) for all input.
- On success `redirect_to ..., status: :see_other`; on validation errors `render :new` or `:edit` with `status: :unprocessable_content`.
- Preserve query params such as the active filter in redirects through URL helpers.
- Turbo Stream responses only inside `respond_to` next to an HTML response.
- Cover each action with controller or integration tests: status, redirect target, flash and the record change.
