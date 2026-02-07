# Commit Conventions & Reversibility Patterns

> Reference for conventional commit generation and revert strategy design.
> Each task produces exactly one commit. Each commit must be independently revertible.

---

## Conventional Commit Format

```
{type}({scope}): {description}

{body — optional, for complex changes}

Refs: {FASE-N}, {UC-XXX}, {ADR-XXX}, {INV-XXX-XXX}
Task: {TASK-ID}
```

### Types

| Type | When to Use | Example |
|------|-------------|---------|
| `feat` | New feature, endpoint, entity, service | `feat(extraction): add PDF upload endpoint` |
| `fix` | Bug fix discovered during implementation | `fix(auth): correct token expiry calculation` |
| `refactor` | Code restructure, no behavior change | `refactor(domain): extract base entity class` |
| `test` | Test files only | `test(matching): add property tests for score calculation` |
| `chore` | Build, deps, config, tooling | `chore(bootstrap): configure wrangler.toml` |
| `docs` | Documentation only | `docs(api): add OpenAPI annotations` |
| `ci` | CI/CD pipeline changes | `ci(deploy): add staging workflow` |
| `perf` | Performance optimization | `perf(extraction): cache model responses` |
| `style` | Formatting, whitespace (no logic) | `style(contracts): fix linting errors` |

### Scopes (Derived from FASE Bounded Contexts)

Scopes are **not hardcoded** — they are derived dynamically from each project's FASE plan. Use the bounded context name of the FASE as the scope.

**Derivation algorithm:**

1. Read `plan/fases/FASE-{N}.md` and extract its `Bounded Context` or title.
2. Convert the bounded context name to a short, lowercase, kebab-case slug (e.g., "Payment Processing" becomes `payment`; "User Authentication & Authorization" becomes `auth`).
3. If the commit touches cross-cutting infrastructure not owned by a single FASE, use one of the generic scopes listed below.

**Generic scopes (always available, regardless of project):**

| Scope | When to Use |
|-------|-------------|
| `bootstrap` | Project scaffolding, initial setup (typically FASE-0) |
| `domain` | Domain model changes (entities, VOs) not tied to one FASE |
| `events` | Event bus, domain event infrastructure |
| `security` | Security infrastructure (cross-cutting) |
| `audit` | Audit logging (cross-cutting) |
| `db` | Database migrations |
| `api` | API infrastructure (versioning, middleware, error handling) |

**Project-specific scopes** are derived from the FASE plan at task generation time. For example, if a project has:
- FASE-1 titled "PDF Extraction" --> scope: `extraction`
- FASE-2 titled "Data Analysis" --> scope: `data-analysis`
- FASE-3 titled "User Management" --> scope: `user-mgmt`

The task generator should include a project-specific scope table in each `TASK-FASE-*.md` file so that committers know the correct scope for that FASE.

### Description Rules

1. **Imperative mood**: "add", "create", "implement", "configure" (not "added", "creates")
2. **Lowercase**: No capital letter at start
3. **No period**: No trailing period
4. **Max 72 chars**: Subject line fits in git log
5. **Specific**: Include the entity/endpoint/service name

### Body Rules (Optional)

Use body for:
- Complex changes needing context
- Breaking changes: prefix with `BREAKING CHANGE:`
- Multi-file changes: list affected files

```
feat(auth): add rate limiting middleware

Implement token bucket algorithm using Cloudflare KV.
Burst: 100 req/min/session, Sustained: 1000 req/h/user.
Returns 429 with Retry-After header per RN-289.

Refs: FASE-0, ADR-025, INV-SEC-003
Task: TASK-F0-012
```

---

## Revert Strategy Design

### Revert Safety Categories

| Category | Symbol | Meaning | Git Command |
|----------|--------|---------|-------------|
| `SAFE` | `SAFE` | Revert independently, no side effects | `git revert <sha>` |
| `COUPLED` | `COUPLED` | Must revert with related tasks | Revert in reverse commit order |
| `MIGRATION` | `MIGRATION` | Has database schema change | Run down migration, then revert |
| `CONFIG` | `CONFIG` | Changes runtime configuration | Redeploy after revert |

### Determining Revert Category

```
IF task creates a new file that nothing else imports yet:
  → SAFE

IF task modifies an existing interface used by other tasks:
  → COUPLED (list the dependent tasks)

IF task creates or modifies database schema:
  → MIGRATION

IF task modifies wrangler.toml, env vars, or deploy config:
  → CONFIG

IF task adds an entity that later tasks reference:
  → COUPLED if later tasks are committed
  → SAFE if later tasks are NOT yet committed
```

### Revert Entry Format

```markdown
- **Revert:** {CATEGORY} — {impact description}
  - Revert with: {specific tasks if COUPLED}
  - Recovery: {steps after revert, e.g., "run down migration"}
```

### Examples

**SAFE revert:**
```markdown
- **Revert:** SAFE — health endpoint becomes unavailable, no other impact
```

**COUPLED revert:**
```markdown
- **Revert:** COUPLED — must revert with TASK-F0-014 (handler uses this middleware)
  - Revert order: TASK-F0-014 first, then TASK-F0-012
```

**MIGRATION revert:**
```markdown
- **Revert:** MIGRATION — users table will be dropped
  - Recovery: run `wrangler d1 execute DB --command "DROP TABLE users"` before revert
  - Data loss: existing user records will be lost
```

**CONFIG revert:**
```markdown
- **Revert:** CONFIG — KV namespace binding removed from wrangler.toml
  - Recovery: redeploy after revert to remove stale binding
```

---

## Rollback Checkpoints

Checkpoints are git tags placed at stable points within a FASE's implementation. They enable reverting to a known-good state without reverting individual commits.

### When to Place Checkpoints

| After Phase | Tag Format | Verification |
|------------|------------|-------------|
| Setup complete | `fase-{N}-setup` | Project builds |
| Foundation complete | `fase-{N}-foundation` | Smoke tests pass |
| Domain complete | `fase-{N}-domain` | Domain unit tests pass |
| Contracts complete | `fase-{N}-contracts` | Contract tests pass |
| Integration complete | `fase-{N}-integration` | Integration tests pass |
| Tests complete | `fase-{N}-tests` | Full test suite green |
| Verification complete | `fase-{N}-verified` | All FASE criteria met |

### Checkpoint Commands

```bash
# Place checkpoint
git tag -a fase-0-foundation -m "FASE-0 foundation phase complete"

# Rollback to checkpoint
git revert --no-commit HEAD..fase-0-foundation
git commit -m "revert: rollback to FASE-0 foundation checkpoint"

# Or hard reset on feature branch (destructive)
git reset --hard fase-0-foundation
```

---

## Branch and PR Conventions

### Branch Naming

```
feat/fase-{N}-{slug}
```

Examples:
- `feat/fase-0-bootstrap`
- `feat/fase-1-extraction`
- `feat/fase-3-multi-org`

### PR Format

```markdown
## feat: implement FASE-{N} - {Title}

### Summary
- {count} atomic commits
- Implements: {list of UCs}
- Satisfies: {list of INVs}

### Commits
1. `{commit-message-1}` (TASK-F{N}-001)
2. `{commit-message-2}` (TASK-F{N}-002)
...

### Verification
- [ ] All FASE-{N} Criterios de Exito pass
- [ ] All invariants enforced
- [ ] No regressions in previous FASEs

### Rollback
To revert this entire FASE:
\```bash
git revert --no-commit {first-sha}..{last-sha}
git commit -m "revert: rollback FASE-{N}"
\```
```

---

## Anti-Patterns

### Commits to Avoid

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| "WIP" commits | Not atomic, not reviewable | Split into real tasks |
| "fix review comments" | Loses traceability | Amend the original or create new task |
| "misc changes" | No scope, no traceability | One commit per concern |
| Commit touching 10+ files | Unreviewable diff | Split into smaller tasks |
| Commit with unrelated changes | Not atomic | Separate tasks |
| Squash merge of 50 commits | Loses atomicity | Merge commit or rebase |
