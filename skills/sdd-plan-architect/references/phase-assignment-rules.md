# Phase Assignment Rules (vertical FASEs)

A FASE is an **increment**: at its end a person runs a short demo from a clean checkout and sees a user journey work
end to end, through every layer. The customer accepts or rejects increments, so the plan is cut by what a user can
do, never by technical layer (no "infrastructure FASE", "backend FASE", "frontend FASE"). Plans written this way carry
`> **Plan-Style:** vertical` in `PLAN.md`; `sdd lint --plan` checks them mechanically.

## Inputs

`requirements/REQUIREMENTS.md` (priority, `Needs:`, dependencies), `spec/use-cases/` (actor, primary entity,
`Depends`), `spec/tests/BDD-UC-*.md` (scenario ids `AC-NNN-NN` and their `[REQ-X-NNN ACn]` tags), `test/TEST-PLAN.md`
§5 (test targets grouped by use case) and `requirements/CUSTOMER-NEEDS.md` (`N-NNN`).

When the route skipped the specifications there are no use cases and no BDD files: the inputs are
`REQUIREMENTS.md` (each requirement's criteria, numbered AC1, AC2… in order) and `CUSTOMER-NEEDS.md`. Read "use case"
below as "the group of requirements that serves one customer need" and "scenario" as `REQ-X-NNN ACn`.

## Rules

| # | Rule | Why |
|---|------|-----|
| R1 Order | Dependencies are hard constraints (a UC whose precondition is another UC's postcondition goes after it). Among what the dependencies allow, MoSCoW decides: Must before Should before Could. | Value first, but never a journey that cannot run |
| R2 Skeleton | FASE-0 (`FASE-0-SKELETON`) is the walking skeleton: the minimum **write → observe → persist** path of the central use case, even when it crosses 2-3 requirements, plus only the infrastructure that path needs. | The riskiest integration (all layers, storage, build) is proven first, with something the customer can see |
| R3 Increments | One user journey per FASE. The CRUD of one entity is one increment (the skeleton may take its create + list slice first). A UC with more than 12 scenarios splits by scenario groups (happy path + validation, then the rest). Without use cases, a journey is the requirements that serve one customer need (their `Needs:` lines), or a cluster of requirements a user sees working together. | A demo tells one story; a FASE the customer can judge in minutes |
| R4 Budget | At most 3 use cases and about 15 tasks per FASE. Split along R3 when exceeded. | Increments small enough to accept or reject quickly |
| R5 Whole requirements | Assign each requirement whole to the FASE that completes it: `sdd gate --fase N` judges every criterion of the REQs on the `Requisitos:` line. An earlier FASE may still cite some of that REQ's scenarios in `Escenarios:` and its demo. | A REQ listed early would show its later criteria as MISSING |
| R6 Security | Authentication, authorization and input validation ship in the first FASE that exposes the resource, never in a later "security FASE". A role enters with its first capability (the admin role arrives with the admin report). | An increment that works but is insecure is not acceptable |
| R7 NFR | `FASE-N-HARDENING` only for measured NFRs (performance, availability with a threshold), and only when they exist. Other NFRs and REQ-C constraints are criteria of every FASE they touch. | Measurement needs the whole path; constraints apply from day one |
| R8 Demo | At most 10 steps from a clean checkout, each citing the scenario it shows (`AC-NNN-NN`, or `REQ-X-NNN ACn` for a requirement without a BDD scenario, and always `REQ-X-NNN ACn` when the route skipped the specifications) and the needs it serves (`N-NNN`). Include seed data when a step needs state the FASE cannot create yet. For an API, steps are consumer calls (`curl`, a client script), not unit tests. | The demo is the evidence the customer accepts |
| R9 Streams | Parallel Streams are the exception: only when the FASE splits into disjoint write-sets (`## Módulos y Conjuntos de Escritura`). A vertical FASE is usually serial. | Parallelism without shared files; never a reason to cut by layer |
| R10 Mixed plans | A plan already implemented horizontally keeps its FASEs. New FASEs are added vertically after the last verified one (`git tag -l 'fase-*-verified'`) and `PLAN.md` says so: `> **Plan-Style:** vertical (from FASE-4)`. Lint then checks FASE-4 onward and counts REQ ids cited anywhere in the earlier FASEs as assigned. | Never re-plan delivered work |

## Procedure

1. **Central use case.** The UC that is the reason the product exists (the one most `Must` REQs and needs point at).
   Its minimum write → observe → persist path, with the REQs it crosses, is FASE-0.
2. **Journeys.** Group the remaining UCs into journeys (R3) using the UC groups of `test/TEST-PLAN.md` §5; without
   use cases, group the remaining requirements by customer need (R3).
3. **Order** the journeys by R1; apply R4 and R5; place auth and roles by R6; add HARDENING by R7.
4. **Write each FASE** with `fase-template.md`: `Incremento`, `Requisitos`, `Escenarios`, `Necesidades`, criteria
   grouped by use case, `## Demo` (R8).
5. **Spec files.** A spec file belongs to the FASE of the UC it serves; a file serving several UCs is listed in each,
   with a section qualifier (`domain/02-ENTITIES.md` · `ENT-002 Vehicle`). Transversal documents (glossary, error
   catalog, overview, system context, CLARIFICATIONS) are listed in FASE-0 and referenced by the rest.
6. **Check** with `node "${SDD_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT}/scripts/sdd.mjs" lint --plan` (V8: backed criteria and
   a demo per FASE; V9: every Must REQ-F/REQ-NF assigned).

## Conflict resolution

1. A dependency beats priority (R1): a Should that a Must depends on moves forward with it.
2. The skeleton beats the one-journey rule: FASE-0 may cross 2-3 REQs to close write → observe → persist.
3. Security beats budget: if auth pushes a FASE over R4, move a scenario group out, never the auth.
4. R5 beats R3: when a journey needs half of a REQ, cite those scenarios early and list the REQ in the FASE that
   completes it.
5. Still ambiguous → the earliest FASE whose demo needs it; if two orders are equally valid, ask the user.

## Worked example: todo-app (`examples/todo-app/requirements/REQUIREMENTS.md`)

CLI; central UC = create a task. UCs: UC-001 create, UC-002 list, UC-003 complete, UC-004 delete, UC-005 filter.

| FASE | Incremento | Requisitos | Why |
|------|-----------|------------|-----|
| FASE-0-SKELETON | Apuntar tareas y verlas en otra ejecución | REQ-F-001, REQ-F-002, REQ-F-006, REQ-NF-002 | R2: add (write) + list (observe) + `data/todos.json` (persist); coverage (Must, measured on every run) starts here |
| FASE-1-LIFECYCLE | Completar y borrar tareas | REQ-F-003, REQ-F-004 | Must; both depend on REQ-F-001; one journey (close the tasks you have) |
| FASE-2-FILTER | Filtrar por estado | REQ-F-005 | Should (R1), depends on REQ-F-002 |
| FASE-3-HARDENING | Latencia con 1 000 tareas | REQ-NF-001 | R7: measured NFR, needs every command |

REQ-C-001/002 are criteria of every FASE (R7). FASE-0 demo (seed: `data/todos.json` with task 2 completed, because
`done` arrives in FASE-1):

| # | Acción | Resultado esperado | Escenario |
|---|--------|--------------------|-----------|
| 1 | `rm -rf data && todo list` | `No tasks`, exit 0 | AC-002-02 · N-002 |
| 2 | `todo add "Buy milk"` | task 1 pending; `data/todos.json` has one task | AC-001-01, AC-001-04 · N-001, N-004 |
| 3 | `todo add ""` | exit 2, `title must not be empty` | AC-001-03 · N-001 |
| 4 | `cp demo/seed-fase-0.json data/todos.json && todo list` | `1 [ ] …` and `2 [x] …` | AC-002-01, AC-002-03 · N-002, N-004 |
| 5 | `npm test -- --coverage` | statements of `src/api/**` ≥ 90 % | REQ-NF-002 AC1 · N-005 |

## Worked example: web app (login + 3 CRUD entities + admin report)

Workshop bookings. Entities Customer → Vehicle → Appointment; roles staff and admin. REQ-F-001 log in, REQ-F-002
register and list customers, REQ-F-003 edit and delete customers, REQ-F-004 manage vehicles, REQ-F-005 manage
appointments (all Must), REQ-F-006 monthly report for admins (Should), REQ-NF-001 appointment list p95 < 300 ms.

| FASE | Incremento | Requisitos | Rule |
|------|-----------|------------|------|
| FASE-0-SKELETON | El personal entra y registra un cliente que sigue ahí al recargar | REQ-F-001, REQ-F-002 | R2 + R6: login ships with the first exposed resource |
| FASE-1-CUSTOMERS | Corregir y dar de baja clientes | REQ-F-003 | R3: rest of the Customer CRUD |
| FASE-2-VEHICLES | Registrar los vehículos de un cliente | REQ-F-004 | R1: needs customers; one entity's CRUD |
| FASE-3-APPOINTMENTS | Dar, mover y anular citas | REQ-F-005 | R1: needs vehicles |
| FASE-4-REPORT | El administrador ve el informe mensual | REQ-F-006 | R6: the admin role enters with its first capability; Should last |
| FASE-5-HARDENING | Listado de citas rápido con 10 000 citas | REQ-NF-001 | R7 |

Not like this: FASE-0 "database + auth + CI", FASE-1 "all models", FASE-2 "all endpoints", FASE-3 "all screens" —
nothing for the customer to accept until the end.
