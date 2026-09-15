---
paths:
  - "{app_dir}/app/views/**/*.erb"
  - "{app_dir}/app/helpers/**/*.rb"
  - "{app_dir}/app/javascript/**/*.js"
  - "{app_dir}/config/locales/**/*.yml"
---

# Views and Hotwire

- Server-rendered HTML is the source of truth: every flow works with full page loads and without custom JavaScript.
- `link_to` for GET navigation; `button_to ... method: :patch` or `:delete` for mutations (Rack::MethodOverride, no JS needed). Never `button_to ... method: :get`: it drops the query string.
- Carry query params such as the active filter through hidden fields or URL helpers in every form and link.
- Turbo Drive by default. Turbo Frames only for inline editing when the full-page flow still works; Turbo Streams only with an HTML fallback.
- Stimulus only for small sprinkles; Importmap, no bundler, no extra client framework.
- Semantic elements with labels; roles, accessible names and texts required by the specification verbatim.
- User-visible text through `t(...)`; render validation errors next to the form from `record.errors`.
- Extract repeated markup into partials.
