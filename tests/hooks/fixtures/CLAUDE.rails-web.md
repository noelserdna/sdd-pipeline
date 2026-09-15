# Todo app (fixture: Rails en web/)

Instrucciones del proyecto. El bloque de ejemplo de abajo NO es el perfil (está dentro de un fence):

```
## SDD Stack Profile
- app_dir: fence-no-cuenta
```

## SDD Stack Profile
<!-- sdd-stack-profile v1 kit=rails -->
- stack: rails
- app_dir: web
- code_paths: web/app, web/lib , web/config/ ,web/db
- test_paths: web/test
- install: cd web && bundle install && bin/rails db:prepare
- test: bin/rails test
- test_file: bin/rails test {}
- test_name: bin/rails test {} -n "/{name}/"
- lint_files: bin/rubocop {}
- build:
- db_reset_safe: RAILS_ENV=test bin/rails db:reset
- server: bin/rails server -p {port}
- port: 3000
- acceptance: bin/rails test:system && echo "done: ok"

## Otra sección
- stack: no-debe-leerse
- after_section: nunca
