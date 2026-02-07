# Phase Assignment Rules (Generic Algorithm)

> Algorithm for assigning spec files to implementation phases (FASEs). This is project-agnostic: it uses structural analysis of the spec/ directory to derive phase assignments automatically.
>
> See `phase-assignment-rules.example.md` for a concrete project-specific example.

---

## Overview

Phase assignment determines which FASE owns which spec files. The algorithm uses **dependency analysis** and **bounded context detection** to group related specs into coherent implementation units. Rules are applied in priority order; the first match wins.

---

## Priority Order

1. **By Invariant Prefix** — strongest signal, groups invariants by their domain prefix
2. **By Use Case Grouping** — clusters UCs that share actors, entities, or workflows
3. **By ADR Topic** — assigns ADRs to the phase whose concern they address
4. **By Contract Module** — maps API contract files to phases by the bounded context they expose
5. **By Workflow** — assigns workflow documents to the phase that implements the primary flow
6. **By Domain Section** — assigns entity, value object, and state machine sections to owning phases
7. **By Keyword Fallback** — scans content for domain-specific terms to infer phase ownership

---

## Rule 1: By Invariant Prefix

**How to detect:** Parse `domain/05-INVARIANTS.md` (or equivalent). Each invariant has a code like `INV-{PREFIX}-{NNN}`. Extract the `{PREFIX}` portion (e.g., `SEC`, `AUTH`, `ORD`).

**How to assign:**

1. Group all invariants by their prefix.
2. For each prefix group, identify the **primary bounded context** it belongs to by reading the invariant descriptions:
   - Prefixes mentioning security, encryption, audit, system-level concerns --> infrastructure/foundation phase (typically FASE-0).
   - Prefixes mentioning a specific domain aggregate (e.g., `ORD` for Order, `PAY` for Payment) --> the phase that implements that aggregate.
3. If a prefix group's invariants reference entities from multiple bounded contexts, assign to the **earliest** phase that introduces the primary entity.

**Decision table template:**

| INV Prefix | Detected Bounded Context | Assigned FASE | Rationale |
|------------|--------------------------|---------------|-----------|
| `{PREFIX}` | {context name from entity analysis} | FASE-{N} | {why this prefix maps here} |

---

## Rule 2: By Use Case Grouping

**How to detect:** Read all `UC-*.md` files in `use-cases/`. For each UC, extract:
- **Primary actor** (who initiates the UC)
- **Primary entity** (which aggregate root is created/modified)
- **Referenced invariants** (which INV-* codes appear)
- **Referenced workflows** (which WF-* are triggered)

**How to assign:**

1. **Cluster by primary entity:** UCs that create, read, update, or delete the same aggregate root belong to the same FASE.
2. **Cluster by actor:** If multiple UCs share the same primary actor AND operate on closely related entities, consider grouping them in one FASE.
3. **Dependency ordering:** If UC-A produces output consumed by UC-B, then UC-A's FASE must come before UC-B's FASE.
4. **Infrastructure UCs:** UCs involving monitoring, health checks, admin panels, security incident handling --> FASE-0.
5. **CRUD split:** If a UC has both read-only and write operations, the read-only portion may be assigned to an earlier FASE (e.g., "view prompts" in one phase, "manage prompts" in a later phase) using an **operation qualifier**.

**Decision table template:**

| UC ID | Primary Actor | Primary Entity | Assigned FASE | Rationale |
|-------|---------------|----------------|---------------|-----------|
| UC-{NNN} | {actor} | {entity} | FASE-{N} | {clustering reason} |

---

## Rule 3: By ADR Topic

**How to detect:** Read each `ADR-*.md` file. Identify the **primary concern** from its title and "Decision" section:
- Infrastructure concerns (event architecture, error handling, caching, API versioning, observability) --> foundation phase.
- Domain-specific concerns (scoring algorithms, matching strategies, notification channels) --> the phase that implements the relevant domain logic.
- Cross-cutting concerns (encryption, multi-tenancy, rate limiting) --> primary assignment to foundation phase, with secondary references in consuming phases.

**How to assign:**

1. Map each ADR to the bounded context its decision affects most directly.
2. If an ADR affects multiple contexts, list all phases with the **primary** phase first.
3. Cross-cutting ADRs (security, observability, error handling) default to FASE-0 as primary.

**Decision table template:**

| ADR ID | Primary Concern | Primary FASE | Secondary FASEs | Rationale |
|--------|-----------------|--------------|-----------------|-----------|
| ADR-{NNN} | {concern} | FASE-{N} | FASE-{M}, ... | {why primary here} |

---

## Rule 4: By Contract Module

**How to detect:** List all files in `contracts/`. Each API contract file (e.g., `API-*.md`) exposes endpoints for a specific bounded context. Examine the base path and endpoint groupings.

**How to assign:**

1. **Single-context contracts:** If all endpoints in the contract serve one bounded context, assign the entire contract to that context's FASE.
2. **Multi-context contracts:** If a contract mixes endpoints for different contexts (e.g., an "organization" API with both admin endpoints and reporting endpoints), split by section and assign each section to the appropriate FASE using **section qualifiers**.
3. **Transversal contracts:** Event catalogs (`EVENTS-domain.md`), error code registries (`ERROR-CODES.md`), and permission matrices are assigned to FASE-0 as primary but referenced by all phases.

**Decision table template:**

| Contract File | Detected Context(s) | Assigned FASE(s) | Qualifier (if split) |
|---------------|----------------------|-------------------|----------------------|
| `API-{name}.md` | {context} | FASE-{N} | {section if multi-phase} |

---

## Rule 5: By Workflow

**How to detect:** Read each `WF-*.md` file. Identify which entities and services participate in the workflow's sequence.

**How to assign:**

1. A workflow belongs to the FASE that implements the **primary action** of the workflow (the main processing step, not setup or notification steps).
2. If a workflow spans entities from multiple FASEs, assign it to the FASE that owns the **triggering entity** (the aggregate root that starts the flow).
3. Workflows that are purely infrastructure (retry, circuit-breaker, health-check) --> FASE-0.

**Decision table template:**

| Workflow | Triggering Entity | Primary Action | Assigned FASE |
|----------|--------------------|----------------|---------------|
| WF-{NNN} | {entity} | {action} | FASE-{N} |

---

## Rule 6: By Domain Section

**How to detect:** Parse domain model files (`02-ENTITIES.md`, `03-VALUE-OBJECTS.md`, `04-STATES.md`, etc.). Each section describes an entity, value object, or state machine.

**How to assign:**

1. **Entities:** Assign each entity to the FASE that first needs it as an aggregate root. If a later FASE extends the entity (e.g., adds new state transitions), the later FASE gets a secondary reference with a section qualifier.
2. **Value Objects:** Assign to the same FASE as the entity that primarily uses the VO.
3. **State Machines:** Assign to the FASE that implements the primary state transitions. If later FASEs add transitions to the same state machine, use section qualifiers.
4. **Glossary:** Transversal -- referenced by all FASEs, primary assignment to FASE-0.
5. **Event schemas:** Assign to the FASE that produces the event. If consumed by multiple FASEs, primary assignment to the producer.

**Decision table template:**

| Domain Element | Type | Primary FASE | Secondary FASEs | Qualifier |
|----------------|------|-------------|-----------------|-----------|
| {ElementName} | Entity/VO/State | FASE-{N} | FASE-{M}, ... | {section if split} |

---

## Rule 7: By Keyword Fallback

**How to detect:** When no structural rule matches, scan the spec file's content for domain-specific keywords that are strongly associated with a bounded context.

**How to assign:**

1. Build a **keyword-to-context map** from the project's glossary and entity names. For example, if the glossary defines "Extraction" as a core concept and FASE-1 owns the Extraction entity, then keywords like "extract", "parse", "upload" map to FASE-1.
2. Count keyword occurrences per context. The context with the highest keyword density wins.
3. If no context dominates, ask the user.

**Keyword map construction:**

```
FOR EACH fase IN plan/fases/:
  context_name = fase.bounded_context
  keywords = []
  keywords += fase.entity_names (lowercase, singular)
  keywords += fase.actor_names (lowercase)
  keywords += glossary terms associated with this context
  keyword_map[context_name] = keywords
```

---

## Bounded Context Detection Algorithm

Before applying rules, detect the project's bounded contexts:

```
1. PARSE domain/02-ENTITIES.md → extract all entity names
2. PARSE use-cases/ → extract all actor names
3. PARSE contracts/ → extract all API base paths
4. BUILD dependency graph:
   - Entity A depends on Entity B if A references B as a foreign key or aggregate member
   - UC-X depends on UC-Y if X's precondition includes Y's postcondition
5. CLUSTER entities into bounded contexts using:
   a. Entities with no cross-references → each is its own context
   b. Entities with mutual references → same context
   c. Entities referenced only via domain events → separate contexts (loosely coupled)
6. ORDER contexts by dependency depth:
   - Contexts with no dependencies → earliest FASEs
   - Contexts depending on others → later FASEs
   - Infrastructure/cross-cutting → FASE-0
```

---

## Dependency Analysis for FASE Ordering

Once specs are grouped into bounded contexts, determine FASE execution order:

```
1. BUILD a context dependency graph:
   - Context A depends on Context B if A's UCs reference B's entities or events
2. TOPOLOGICAL SORT the graph → produces FASE ordering
3. ASSIGN FASE numbers:
   - FASE-0: infrastructure, security, cross-cutting (no domain dependencies)
   - FASE-1..N: domain contexts in topological order
   - Tie-breaking: prefer the context with fewer dependencies first
4. VALIDATE: no circular dependencies (if found, merge contexts or introduce an interface boundary)
```

---

## Transversal Documents

Some documents are referenced by ALL phases. Identify them by checking if:
- The document defines vocabulary used project-wide (glossary)
- The document defines event schemas consumed by 3+ bounded contexts
- The document defines error codes used across multiple APIs
- The document provides system-level overview or architectural context

Assign transversal documents to FASE-0 as primary, with references in every subsequent FASE.

**Common transversal documents:**

| Document Pattern | Why Transversal |
|------------------|-----------------|
| `00-OVERVIEW.md` | System vision and scope |
| `01-SYSTEM-CONTEXT.md` | Boundaries, actors, external systems |
| `domain/01-GLOSSARY.md` | Ubiquitous language |
| `contracts/EVENTS-*.md` | Domain event catalog |
| `contracts/ERROR-CODES.md` | Error code registry |
| `CLARIFICATIONS.md` | Business rules (RN-*) |
| `CHANGELOG.md` | Change history |

---

## Multi-Phase Specs

Some specs span multiple phases. Handle with **section qualifiers**:

**Detection:** A spec is multi-phase if:
- It defines multiple entities assigned to different FASEs
- It defines an API with endpoint groups serving different bounded contexts
- It defines BDD scenarios covering features from different FASEs

**Handling:**

```markdown
| Spec File | FASE | Section Qualifier | What to Extract |
|-----------|------|-------------------|-----------------|
| `domain/02-ENTITIES.md` | FASE-{N} | Section: {EntityName} | {specific fields/methods} |
| `contracts/API-{name}.md` | FASE-{N} | Endpoints: /v1/{path}/* | {specific endpoint group} |
| `tests/BDD-{name}.md` | FASE-{N} | Feature: {feature name} | {specific scenarios} |
```

---

## Conflict Resolution

When a spec matches multiple rules pointing to different phases:

1. **INV prefix wins** over UC number (invariants are the strongest signal of domain ownership)
2. **UC number wins** over ADR/keyword (UCs are explicit assignments from requirements)
3. **If still ambiguous:** assign to the **earliest** phase that needs the spec
4. **If truly multi-phase:** list all phases with section qualifiers

---

## New Spec Handling

When a new spec is encountered that does not match any rule:

1. Check if its filename contains a mapped UC/ADR/WF number --> use that rule
2. Check if its content references INV-* with a mapped prefix --> use Rule 1
3. Check if it is referenced by an existing FASE file --> use that phase
4. Trace the spec's primary entity to a UC --> use that UC's phase
5. If still unclear: **ask the user** which phase it belongs to

---

## Hypothetical Example

Consider a hypothetical **e-commerce platform** with these bounded contexts:

- **Infrastructure** (FASE-0): Auth, event bus, error handling, observability
- **Catalog** (FASE-1): Product management, categories, search indexing
- **Cart** (FASE-2): Shopping cart, pricing rules, promotions
- **Orders** (FASE-3): Order placement, payment processing, order lifecycle
- **Fulfillment** (FASE-4): Shipping, warehouse, tracking
- **Analytics** (FASE-5): Reports, dashboards, recommendations

Applying the rules:

**Rule 1 (INV prefix):**
- `INV-SEC-*`, `INV-SYS-*` --> FASE-0 (infrastructure invariants)
- `INV-CAT-*` --> FASE-1 (e.g., "catalog must have at least one category")
- `INV-PRC-*` --> FASE-2 (e.g., "price must be non-negative")
- `INV-ORD-*` --> FASE-3 (e.g., "order total must equal sum of line items")
- `INV-SHP-*` --> FASE-4 (e.g., "shipment must reference a valid order")

**Rule 2 (UC grouping):**
- UC-001 "Browse Products", UC-002 "Search Catalog" --> FASE-1 (same actor: Customer, same entity: Product)
- UC-003 "Add to Cart", UC-004 "Apply Coupon" --> FASE-2 (same entity: Cart)
- UC-005 "Place Order", UC-006 "Process Payment" --> FASE-3 (dependency chain: order then payment)
- UC-007 "Ship Order" --> FASE-4 (depends on FASE-3 output)

**Rule 3 (ADR topic):**
- ADR-001 "Use event sourcing for order lifecycle" --> FASE-0 (infrastructure), FASE-3 (primary consumer)
- ADR-002 "Elasticsearch for catalog search" --> FASE-1

**Rule 5 (Workflow):**
- WF-001 "Order-to-Shipment" --> FASE-3 (triggering entity: Order), secondary reference in FASE-4

**Dependency ordering:** Catalog (no deps) < Cart (depends on Catalog) < Orders (depends on Cart) < Fulfillment (depends on Orders) < Analytics (depends on all).
