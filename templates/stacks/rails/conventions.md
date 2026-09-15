## Stack Conventions

Stack: Rails 8.x · Ruby 3.3+ · Minitest with fixtures · Hotwire (Turbo, Stimulus) · Importmap · SQLite. Profile commands run from `app_dir`; paths below are relative to it.

- **REST**: map each spec operation to `resources` with standard actions. A state change (e.g. completion) is a nested singular resource (`create`/`destroy`) or an `update` of the state attribute; prefer standard actions over custom member routes.
- **Without JavaScript**: `button_to ..., method: :delete` or `:patch` works through Rack::MethodOverride. `link_to` for GET navigation, never `button_to ... method: :get` (it drops the query string). Keep query params such as the active filter with hidden fields or URL helpers.
- **Responses**: after a mutation `redirect_to ..., status: :see_other`; on validation errors `render :new` or `:edit` with `status: :unprocessable_content`. Turbo needs both.
- **Hotwire**: Turbo Drive by default; Frames for inline editing when useful; Streams only with an HTML fallback in `respond_to`. Stimulus for small sprinkles only.
- **Layers**: thin controllers with strong parameters; rules, validations and state transitions in models; database constraints mirror validations. Migrations are reversible; never edit an applied migration.
- **Text**: user-visible messages through I18n (set `config.i18n.default_locale` when the UI is not English); texts required by the spec verbatim.
- **Tests**: model, controller and integration tests with fixtures; `bin/rails test path/to/file_test.rb:LINE` or `-n "/pattern/"`. No system tests when a shared acceptance suite exists (`acceptance` key).
- **Lint**: `bin/rubocop` on the changed files.
- **Git**: an app generated with `--skip-git` has no `.gitignore`; add one covering `/log/*`, `/tmp/*`, `/storage/*`, `/.bundle` and `/config/master.key`.
