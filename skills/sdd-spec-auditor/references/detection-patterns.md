# Detection Patterns

> Grep patterns that surface candidate defects. A hit is a lead, not a finding: open the cited lines, apply the Signal
> Filters and the category rules of SKILL.md, then record it. Patterns are bilingual (English / Spanish); add the
> equivalents of the spec's language when it is another one.

## CAT-01: Ambiguities — vague words

```bash
# Vague qualifiers
grep -rniE '\b(appropriate|adequate|reasonable|sufficient|normal(ly)?|typical|apropiad[oa]|adecuad[oa]|razonable|suficiente|normalmente|típic[oa])\b' spec/
# Undefined time
grep -rniE '\b(soon|fast|quick(ly)?|immediate(ly)?|as soon as possible|pronto|rápid[oa]|inmediat[oa]|cuando sea posible|en breve)\b' spec/
# Undefined frequency / quantity
grep -rniE '\b(frequently|regularly|periodically|occasionally|several|some|many|few|most|frecuentemente|regularmente|periódicamente|varios|algunos|muchos|pocos|la mayoría)\b' spec/
# Ambiguous conditionals and open lists
grep -rniE '(if necessary|as needed|when appropriate|if applicable|si es necesario|cuando corresponda|según sea necesario|etc\.|and others|among others|y otros|entre otros)' spec/
# Comparatives without reference
grep -rniE '\b(better|worse|faster|slower|mejor|peor|más rápido|más lento)\b' spec/
```

| Word | Problem | Question |
|---|---|---|
| appropriate / apropiado | no criterion | What makes it appropriate? |
| reasonable / razonable | subjective | What is the number? |
| normally / normalmente | implies exceptions | What happens in the other cases? |
| should / debería | not binding | MUST or SHOULD? |
| may / can / puede | optional or capability? | MAY or CAN? |
| etc. | incomplete list | Which are all the cases? |

The canonical vague-term list for requirements is `../sdd-requirements-engineer/references/audit-checklist.md` §1.1.

## CAT-02: Implicit rules

```bash
grep -rniE '\b(valid|invalid|correct|incorrect|válid[oa]|inválid[oa]|correct[oa])\b' spec/ | grep -viE 'INV-|E_[A-Z_]+'
grep -rniE '\b(unique|duplicate|already exists|únic[oa]|duplicad[oa]|ya existe)\b' spec/ | grep -v 'INV-'
grep -rniE '\b(by default|default|por defecto)\b' spec/
grep -rniE '\b(can|cannot|has access|puede|no puede|tiene acceso)\b' spec/use-cases/
```

Typical silent assumptions: "the user enters a value" (format? uniqueness?), "the file is saved" (where? name?
permissions?), "a notification is sent" (to whom? channel? when?), "the status is updated" (who may? audited?).

## CAT-03: Dangerous silences

```bash
# UCs whose exceptions table has no rows (heading followed by header + separator only)
grep -n -A3 '^## Exceptions' spec/use-cases/*.md | grep -B1 -A2 '^--$'
# Workflow steps without timeout or retry cell
grep -n '^| [0-9]' spec/workflows/*.md | grep -E '\| *\| *\|'
# States without a failure/terminal transition
grep -niE 'failed|error|cancel|fallid|cancelad' spec/domain/04-STATES.md
```

For each operation check: failure, timeout, partial data, duplicates, no data, user cancels, concurrent access.

**Replay of a write.** Every operation with a write effect (creates, changes, deletes, sends, charges, consumes) needs a
`replay` row in the `Exceptions & errors` table of its UC (E row with condition `replay`, specifications-engineer Step 6a
question 6) stating what a second identical call keeps. A write operation without one is a CAT-03 finding, P1 (P0 when
the write moves money or consumes a limited resource), located at the operation row, fix "what does the same call with
the same input do the second time?". Without the row the retry outcome is whatever the code happens to do, and
`sdd-test-planner` can only plan a replay test with `Refs: —`.

```bash
# UC files with an Exceptions table but no replay row; then check their operations for a write effect
grep -L -iE '^\| *E[0-9]+ *\|[^|]*\| *replay' $(grep -l '^## Exceptions' spec/use-cases/*.md)
```

## CAT-04: Semantic ambiguities

```bash
# "Do not use" synonyms from the glossary, grepped over the corpus (last column of the glossary table)
awk -F'|' '/^\|/ && NR>2 {print $(NF-1)}' spec/domain/01-GLOSSARY.md | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$' |
  while read -r t; do grep -rniw -- "$t" spec/ | grep -v '01-GLOSSARY' ; done
# CamelCase / capitalised terms that may need a glossary entry
grep -rhoE '\b[A-Z][a-z]+[A-Z][A-Za-z]+\b' spec/ | sort | uniq -c | sort -rn | head -40
```

Check each glossary term for case variations (`Task` vs `task` used as the domain concept) and for the same concept
named differently across documents. The synonym list comes from the project's glossary, never from a fixed matrix.

## CAT-05: Contradictions

```bash
grep -rniE 'timeout.*[0-9]+' spec/ | sort
grep -rniE '(size|tamaño|length|longitud|max|máx).*[0-9]+' spec/ | sort
grep -rniE '(rate.?limit|límite de tasa).*[0-9]+' spec/ | sort
grep -rniE '(retention|retención).*[0-9]+' spec/ | sort
# Every registry value: the number should appear only next to its name
grep -oE '^\| *`[A-Z_]+` *\| *[0-9]+' spec/VALUE-REGISTRY.md
```

Cross the same concept across `VALUE-REGISTRY.md`, `nfr/LIMITS.md`, workflows, contracts and UCs; the divergent
document is the location (Minority Rule).

## CAT-06: Incomplete specifications

```bash
grep -rniE '\b(TODO|TBD|FIXME|PENDING|WIP)\b' spec/
grep -rn '\[NEEDS CLARIFICATION\]' spec/
# Heading immediately followed by another heading (empty section)
find spec -name '*.md' -exec awk 'FNR==1{p=""} /^#/{ if (p ~ /^#/) print FILENAME": "p" → "$0 } NF{p=$0}' {} +
# Unfilled template placeholders
grep -rnE '\[(name|title|actor|condition|step|value)\]|\{[a-z_ -]+\}' spec/
```

Required sections, from the specifications-engineer templates (`document-templates.md`):

| Document | Required |
|---|---|
| Use case (Template 2) | header table with `Refs`, `Actors`, `Trigger`; `Input / Output`; `Preconditions`; `Postconditions` (success + failure); `Main flow`; `Exceptions & errors` (≥ 1 row). `Extensions` and `Open questions` are optional |
| Workflow (Template 11) | header with `Trigger`, `Total timeout`, `Refs`; `Steps` table (timeout, retry, on failure, compensation); `Error scenarios`; `Events emitted` (may be `None.`); `Metrics` |
| Invariants (Template 10) | one row per invariant: ID, rule, enforced at, UCs, violation error, validation |
| Contract (Template 12/12b) | header with `Module`, `Style`, `Refs`; `Operations` table; one `Errors` table |
| BDD (Template 13) | `Refs` line; one scenario per main flow, extension, exception row and edge case, titled `AC-NNN-NN — … [REQ-X ACn]` |

A mandatory section containing `None.` is complete (writing rule W4), not a CAT-06 finding.

## CAT-07: Weak invariants

```bash
# Constraint language in UCs without an INV reference
grep -rniE '\b(must|shall not|always|never|at most|at least|maximum|minimum|between [0-9]+ and|debe|no debe|siempre|nunca|como máximo|como mínimo|entre [0-9]+ y)\b' spec/use-cases/ | grep -v 'INV-'
# Invariant rows with an empty validation cell
grep -nE '^\| *INV-[A-Z]+-[0-9]{3}' spec/domain/05-INVARIANTS.md | grep -E '\| *\|? *$'
# One-sided ranges
grep -rniE '(> *[0-9]+|greater than [0-9]+|mayor que [0-9]+)' spec/ | grep -viE '(< *[0-9]+|less than|menor que)'
```

Invariants that are often missing: uniqueness of natural identifiers; numeric ranges; referential integrity; temporal
order (start < end); allowed state transitions; tenant isolation; deletion with dependants.

## CAT-08: Evolution risks

```bash
grep -rniE '\benum\b|type .*= *'"'"'[a-z_]+'"'"' *\|' spec/domain/
grep -rniE '/v[0-9]+/' spec/contracts/
```

Signals: closed enum without an evolution rule; sequential ids exposed externally; non-null fields without default on
existing data; public API without versioning; states without a deprecated/archived path.

## CAT-09: Decisions without ADR

```bash
# Technology names outside adr/ — build the list from the spec itself, then check each has an ADR
grep -rhoE '\b(PostgreSQL|MySQL|SQLite|MongoDB|Redis|DynamoDB|S3|Kafka|RabbitMQ|JWT|OAuth2?|SAML|GraphQL|gRPC|WebSocket|AES|RSA|bcrypt|argon2)\b' spec/ --exclude-dir=adr | sort | uniq -c
grep -rniE '\b(saga|cqrs|event.sourcing|microservice|multi.?tenan)' spec/ --exclude-dir=adr
grep -rniE '(trade.?off|compromise|alternative|alternativa|compromiso)' spec/ --exclude-dir=adr
```

Decisions that need an ADR: database / storage, authentication, PII encryption, multi-tenancy model, rate-limiting
strategy, fallback strategy for external services, retry/backoff, id format, API versioning.

## CAT-10: Transport over-specification

> Corpus: `spec/`, plus `ux/` and `test/` when present (the Contracts & BDD auditor covers it corpus-wide).
> `design/` is the legitimate home of transport (`design/OPERATION-MAPPING.md`) and is not scanned.

```bash
CORPUS="spec"; [ -d ux ] && CORPUS="$CORPUS ux"; [ -d test ] && CORPUS="$CORPUS test"

# 0. Style per module. No Style row + Method/Path columns = pre-4.3 contract → treated as http
grep -nE '^\| *Style *\|' spec/contracts/API-*.md
grep -lE '^\| *(ID *\| *)?Method *\| *Path' spec/contracts/API-*.md

# 1. HTTP verbs + routes and transport columns
grep -rnE '\b(GET|POST|PUT|PATCH|DELETE)\b +`?/' $CORPUS
grep -rnE '^\| *(ID *\| *)?(Method|HTTP|Path|Route|Endpoint) *\|' $CORPUS

# 2. Status codes and redirects
grep -rnE '\b(status|HTTP|código) *:? *[1-5][0-9]{2}\b|redirect|redirig' $CORPUS

# 3. Form attributes that hide server messages (review each hit: a "Required" column of a field inventory or
#    "required" in prose is not a signal; the HTML attribute is)
grep -rnE '\b(maxlength|minlength)\b|\bpattern=|<(input|textarea|select)[^>]*\brequired|`required`' $CORPUS | grep -v 'aria-required'

# 4. Client mechanics / reload
grep -rniE 'without (javascript|js)|no (client|js) script|full.?page reload|sin (javascript|js|script)|recarga (completa|de (la )?página)|preventDefault|fetch\(' $CORPUS

# 5. URL structure and query params
grep -rnE '\?[a-z_]+=' $CORPUS
```

Not a finding:
- The module is `Style: http` (or a pre-4.3 contract with `Method | Path`) and the hit is in that contract or its API scenarios.
- A REQ demands that transport (`grep -n '?status=' requirements/REQUIREMENTS.md` returns the line): it is mandatory transport and must cite the REQ; not citing it → P3 "cite REQ".
- Required security controls (CSRF token, `SameSite`, `Secure`): `sdd-security-auditor`'s domain.
- `aria-required`, `aria-invalid`, `aria-describedby`: accessibility, not transport.

| Situation | Sev |
|---|---|
| Transport blocks a required message or behaviour (`required`/`maxlength` hiding `E_TITLE_EMPTY`; a link where the REQ names a button) | P1 |
| Routes, verbs, statuses, redirects, JS mechanics or URLs no REQ demands, in `operations` contracts, UCs, BDD, ux or test | P2 |
| Transport a REQ demands, without citing it | P3 |

Rewrites (Mode Fix):

| Before | After |
|---|---|
| `POST /tasks/{id}/title` → 400 `E_TITLE_EMPTY` | `renameTask(id, title)` → `E_TITLE_EMPTY`; transport: see design/OPERATION-MAPPING.md |
| "Reloads the whole page and redirects to `?edit=`" | "After saving, the list shows the new title" (+ REQ if the URL is mandatory) |
| `<input required maxlength=120>` | "Title required, ≤ `TITLE_MAX_LENGTH` (INV-TSK-003); `E_TITLE_EMPTY` is shown next to the field" |
| `Then status 400` | `Then error E_TITLE_EMPTY is shown and the list is unchanged` |

A URL or mechanic a REQ demands is never removed: it stays and cites the REQ.

## Regression detection (Phase 6)

```bash
# Files modified since the last resolved audit (tag suggested by Mode Fix), or since the last report date
git diff --name-only AUDIT-vX.Y-resolved..HEAD -- spec/
git log --since="YYYY-MM-DD" --name-only --pretty=format: -- spec/ | sort -u | grep -v '^$'

# Documents referencing the entities of a modified file
for e in $(grep -oE '^#{2,3} [A-Z][A-Za-z]+' spec/domain/02-ENTITIES.md | sed 's/^#* //'); do
  echo "== $e"; grep -rlw "$e" spec/ | grep -v 02-ENTITIES; done

# Enum values: same set everywhere they are declared
grep -rnE "(type|enum|status).*=.*\|" spec/domain/
grep -rn "<enum value>" spec/

# Referenced invariants that are not defined
comm -23 <(grep -rhoE 'INV-[A-Z]+-[0-9]{3}' spec/ | sort -u) \
         <(grep -hoE '^\| *INV-[A-Z]+-[0-9]{3}' spec/domain/05-INVARIANTS.md | tr -d '| ' | sort -u)
```

High-coupling groups that should change together: domain core (`02-ENTITIES`, `03-VALUE-OBJECTS`, `04-STATES`,
`05-INVARIANTS`); permissions (`PERMISSIONS-MATRIX.md` + `API-*.md`); business rules (`CLARIFICATIONS.md` + the UCs
citing the RNs).
