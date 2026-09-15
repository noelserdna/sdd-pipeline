# Todo app (fixture: Rails en la raíz, Minitest en test/)

## SDD Stack Profile
<!-- sdd-stack-profile v1 kit=rails -->
- stack: rails
- app_dir: .
- code_paths: app, lib, config, db
- test_paths: test
- test: bin/rails test
- test_file: bin/rails test {}
- db_reset_safe: RAILS_ENV=test bin/rails db:reset
