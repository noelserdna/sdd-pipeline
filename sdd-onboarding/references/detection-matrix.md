# Detection Matrix — Project Scenario Classification

> Catálogo de señales, pesos y algoritmo de clasificación para determinar el escenario de un proyecto. Utilizado por la Fase 5 de `sdd-onboarding`.

---

## 1. Signal Catalog

### Category A: SDD Artifacts

| ID | Signal | Detection Method |
|----|--------|-----------------|
| A1 | `pipeline-state.json` exists | File exists check |
| A2 | `requirements/REQUIREMENTS.md` exists with REQ-XXX IDs | File + regex scan |
| A3 | `spec/` directory with domain, use-cases, contracts | Directory + file count |
| A4 | `audits/AUDIT-BASELINE.md` exists | File exists check |
| A5 | `test/TEST-PLAN.md` exists | File exists check |
| A6 | `plan/ARCHITECTURE.md` exists | File exists check |
| A7 | `task/TASK-FASE-*.md` files exist | Glob pattern |
| A8 | Traceability markers in code (`Refs: REQ-XXX`) | Grep in src/ |
| A9 | SDD artifacts have recent modifications (< 30 days) | File mtime check |
| A10 | Pipeline state shows stages beyond `pending` | JSON parse |

### Category B: Non-SDD Documentation

| ID | Signal | Detection Method |
|----|--------|-----------------|
| B1 | OpenAPI/Swagger files exist | Glob `*.openapi.*`, `swagger.*`, `openapi.yaml` |
| B2 | README.md with feature/API documentation | File exists + content length > 500 lines |
| B3 | `docs/` directory with structured content | Directory + file count |
| B4 | ADR directory exists (`adr/`, `ADR/`, `decisions/`) | Directory exists |
| B5 | Jira/project management exports | Glob `*.jira.*`, CSV in docs/ |
| B6 | Architecture diagrams (`.drawio`, `.puml`, `.mermaid`) | Glob pattern |
| B7 | Postman collections or API Blueprint | Glob `*.postman_collection.json`, `*.apib` |
| B8 | Notion exports (markdown with metadata headers) | Content pattern scan |
| B9 | GraphQL schema files | Glob `*.graphql`, `schema.graphql` |
| B10 | Wiki references (`.github/wiki/`, wiki links in README) | Pattern scan |

### Category C: Code Signals

| ID | Signal | Detection Method |
|----|--------|-----------------|
| C1 | Source code exists (> 10 files) | Count src files by extension |
| C2 | Multiple architectural layers detected | Directory structure analysis |
| C3 | Database schema/migrations exist | Glob `migrations/`, `*.schema.*`, ORM config |
| C4 | Configuration files (env, config) | Glob `.env*`, `config/`, `*.config.*` |
| C5 | Entry points identified (main, index, app) | Pattern matching |
| C6 | Monorepo structure detected | `workspaces`, `lerna.json`, `nx.json`, `turbo.json` |
| C7 | Microservices structure (multiple service dirs) | Directory analysis |
| C8 | Code comments density > 10% | Sample scan of source files |
| C9 | Type definitions/interfaces present | Language-specific scan |
| C10 | Git history > 100 commits | `git rev-list --count HEAD` |

### Category D: Test Signals

| ID | Signal | Detection Method |
|----|--------|-----------------|
| D1 | Test files exist (> 5 files) | Glob `*.test.*`, `*.spec.*`, `test_*` |
| D2 | Test framework configured | Package/config scan for Jest, pytest, JUnit, etc. |
| D3 | Test-to-source ratio > 0.5 | File count ratio |
| D4 | Integration/e2e tests exist | Glob `e2e/`, `integration/`, Cypress, Playwright config |
| D5 | Coverage configuration exists | Glob `.nycrc`, `jest.config` with coverage, `.coveragerc` |
| D6 | Tests have descriptive names (BDD-like) | Scan for `describe`/`it`/`should`/`given`/`when`/`then` |
| D7 | Test coverage > 60% (if config found) | Coverage report scan |
| D8 | CI runs tests (test commands in CI config) | CI config scan |

### Category E: Infrastructure & Quality Signals

| ID | Signal | Detection Method |
|----|--------|-----------------|
| E1 | CI/CD configuration exists | Glob `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile` |
| E2 | Linter configuration exists | Glob `.eslintrc*`, `.pylintrc`, `clippy.toml`, etc. |
| E3 | Type checking enabled (strict mode) | Config scan for `strict: true`, mypy config |
| E4 | Docker/containerization present | `Dockerfile`, `docker-compose.yml` |
| E5 | Git hooks configured (husky, pre-commit) | `.husky/`, `.pre-commit-config.yaml` |
| E6 | Multiple contributors (> 3) | `git shortlog -sn` |
| E7 | Fork indicator (remote origin differs from upstream) | `git remote -v` analysis |
| E8 | Recent activity (commits in last 30 days) | `git log --since` |

---

## 2. Signal → Scenario Weight Matrix

Each cell contains the weight (0-3) of a signal for a given scenario:
- **3** = Strong indicator
- **2** = Moderate indicator
- **1** = Weak indicator
- **0** = Not relevant
- **-2** = Counter-indicator (presence argues against this scenario)

| Signal | Greenfield | Brownfield Bare | SDD Drift | Partial SDD | Brownfield+Docs | Tests-as-Spec | Multi-team | Fork |
|--------|-----------|----------------|-----------|-------------|-----------------|---------------|-----------|------|
| A1 (pipeline-state) | -2 | -2 | 3 | 3 | -2 | -2 | 1 | -2 |
| A2 (requirements) | -2 | -2 | 2 | 3 | -2 | -2 | 1 | -2 |
| A3 (spec/) | -2 | -2 | 3 | 2 | -2 | -2 | 1 | -2 |
| A4 (audit) | -2 | -2 | 2 | 1 | -2 | -2 | 0 | -2 |
| A5 (test plan) | -2 | -2 | 2 | 1 | -2 | -2 | 0 | -2 |
| A6 (architecture) | -2 | -2 | 2 | 1 | -2 | -2 | 0 | -2 |
| A7 (tasks) | -2 | -2 | 2 | 1 | -2 | -2 | 0 | -2 |
| A8 (trace markers) | -2 | -2 | 3 | 2 | -2 | -2 | 1 | -2 |
| A9 (recent SDD) | -2 | -2 | -1 | 2 | -2 | -2 | 0 | -2 |
| A10 (pipeline active) | -2 | -2 | 2 | 3 | -2 | -2 | 1 | -2 |
| B1 (OpenAPI) | 0 | 0 | 0 | 0 | 3 | 0 | 1 | 1 |
| B2 (rich README) | 0 | 0 | 0 | 0 | 2 | 0 | 1 | 1 |
| B3 (docs/) | 0 | 0 | 0 | 0 | 3 | 0 | 1 | 1 |
| B4 (ADR) | 0 | 0 | 0 | 0 | 2 | 0 | 1 | 0 |
| B5 (Jira exports) | 0 | 0 | 0 | 0 | 3 | 0 | 1 | 0 |
| B6 (diagrams) | 0 | 0 | 0 | 0 | 2 | 0 | 1 | 0 |
| B7 (Postman) | 0 | 0 | 0 | 0 | 2 | 0 | 1 | 0 |
| C1 (code exists) | -2 | 3 | 2 | 2 | 3 | 3 | 2 | 2 |
| C2 (layers) | -2 | 2 | 1 | 1 | 2 | 2 | 2 | 2 |
| C3 (DB/migrations) | -2 | 2 | 1 | 1 | 2 | 1 | 1 | 1 |
| C6 (monorepo) | 0 | 0 | 0 | 0 | 0 | 0 | 3 | 0 |
| C7 (microservices) | 0 | 0 | 0 | 0 | 0 | 0 | 3 | 0 |
| C10 (git history) | -2 | 2 | 2 | 1 | 2 | 2 | 2 | 2 |
| D1 (test files) | -2 | -1 | 1 | 1 | 1 | 3 | 1 | 1 |
| D2 (test framework) | -2 | -1 | 1 | 1 | 1 | 3 | 1 | 1 |
| D3 (test ratio) | -2 | -2 | 0 | 0 | 0 | 3 | 0 | 0 |
| D6 (BDD-like tests) | -2 | -2 | 0 | 0 | 0 | 3 | 0 | 0 |
| E6 (contributors) | 0 | 0 | 1 | 1 | 1 | 0 | 3 | 1 |
| E7 (fork) | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 3 |

---

## 3. Classification Algorithm

```
FUNCTION classify_scenario(signals):
    scores = {}
    FOR EACH scenario IN [greenfield, brownfield_bare, sdd_drift, partial_sdd,
                          brownfield_docs, tests_as_spec, multi_team, fork]:
        scores[scenario] = 0
        FOR EACH signal IN detected_signals:
            scores[scenario] += weight_matrix[signal][scenario]

    # Normalize to 0-100 percentage
    max_possible = sum of all positive weights for each scenario
    FOR EACH scenario:
        scores[scenario] = (scores[scenario] / max_possible[scenario]) * 100

    # Sort by score descending
    ranked = sort(scores, descending)

    # Confidence assessment
    top_score = ranked[0].score
    second_score = ranked[1].score
    gap = top_score - second_score

    IF top_score > 75 AND gap > 20:
        confidence = HIGH
    ELIF top_score > 50 AND gap > 10:
        confidence = MEDIUM
    ELSE:
        confidence = LOW

    RETURN {
        primary: ranked[0],
        secondary: ranked[1] if confidence != HIGH,
        confidence: confidence,
        all_scores: ranked,
        evidence: list of signals that contributed to top scenario
    }
```

### Tiebreaker Rules

When two scenarios score within 5 points of each other:

1. **SDD artifacts present** → prefer SDD-aware scenarios (drift, partial) over non-SDD (brownfield)
2. **Code exists + docs exist** → prefer `brownfield_docs` over `brownfield_bare`
3. **Strong test suite** → prefer `tests_as_spec` over `brownfield_bare`
4. **Monorepo detected** → prefer `multi_team` over any single-module scenario
5. **Fork remote detected** → prefer `fork` over `brownfield`
6. **If still tied** → ask user to confirm

---

## 4. Language/Framework Detection Heuristics

| File/Pattern | Language | Framework |
|-------------|----------|-----------|
| `package.json` | JavaScript/TypeScript | Check dependencies for React, Next, Express, etc. |
| `tsconfig.json` | TypeScript | — |
| `pyproject.toml`, `setup.py`, `requirements.txt` | Python | Check for Django, Flask, FastAPI |
| `Cargo.toml` | Rust | Check for Actix, Axum, Rocket |
| `go.mod` | Go | Check for Gin, Echo, Fiber |
| `pom.xml`, `build.gradle` | Java/Kotlin | Check for Spring, Quarkus |
| `*.sln`, `*.csproj` | C# | Check for ASP.NET, Blazor |
| `Gemfile` | Ruby | Check for Rails, Sinatra |
| `mix.exs` | Elixir | Check for Phoenix |
| `composer.json` | PHP | Check for Laravel, Symfony |

---

## 5. Confidence Scoring

### Per-Signal Confidence

Each detected signal has its own confidence:

| Confidence | Criteria |
|-----------|----------|
| **DEFINITE** | File/directory exists (binary check) |
| **HIGH** | Content matches expected patterns |
| **MEDIUM** | Partial match or ambiguous content |
| **LOW** | Inferred from indirect signals |

### Aggregated Confidence

The overall scenario confidence combines:
1. Signal weight score (from matrix)
2. Individual signal confidence levels
3. Counter-indicator strength
4. Gap between top two scenarios

Formula: `confidence = (weighted_score * avg_signal_confidence) / max_possible`
