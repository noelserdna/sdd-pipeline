---
name: sdd-tech-designer
description: "Technical architecture and design exploration across 12 dimensions (delivery channels, architecture style, tech stack, data strategy, auth, API, infrastructure, CI/CD, observability, cost, DX, i18n). Analyzes specifications with ATAM-lite quality attribute evaluation. Use when: (1) Making technology stack decisions before planning, (2) Evaluating architecture trade-offs (monolith vs microservices, SQL vs NoSQL), (3) Documenting technical decisions as ADR drafts, (4) Exploring infrastructure and deployment options. Outputs to design/. Triggers: 'technical design', 'tech stack', 'architecture decision', 'design exploration', 'diseno tecnico', 'stack tecnologico', 'ADR'."
---

# SDD Tech Designer Skill

> **Principio:** Las decisiones técnicas deben ser explícitas, documentadas y trazables.
> Este skill explora el espacio de diseño técnico en profundidad antes de la planificación,
> asegurando que ninguna dimensión arquitectónica quede sin analizar.

## Purpose

Explorar y documentar decisiones de diseño técnico y arquitectura a través de 12 dimensiones, produciendo:

1. **Vision del sistema** — Tipo de sistema, stakeholders técnicos, constraints
2. **Atributos de calidad** — Priorización ATAM-lite con trade-off matrix
3. **Análisis dimensional** — Recorrido contextual de 12 dimensiones técnicas
4. **Documentos de diseño** — Technical Design, Quality Attributes, ADR drafts

## When to Use This Skill

Use this skill when:
- The system has significant technical complexity (multiple integration points, scale requirements, security constraints)
- Multiple valid architecture styles could apply and trade-offs need explicit evaluation
- Stakeholders need a formal technology selection rationale
- Before `sdd-plan-architect` for projects requiring deep technical exploration
- When exploring architecture alternatives for an existing or new system
- When the team needs a comprehensive Technology Decision Record

## When NOT to Use This Skill

- For simple CRUD apps where plan-architect's Phase 2 clarify is sufficient
- To generate implementation code → use `sdd-task-implementer`
- To audit existing specs → use `sdd-spec-auditor`
- To plan implementation phases → use `sdd-plan-architect`

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `sdd-specifications-engineer` | **Prerequisite**: specs should exist (at minimum domain + use-cases) |
| `sdd-spec-auditor` | **Recommended**: audit-clean specs produce better design |
| `sdd-security-auditor` | **Complementary**: security findings inform Auth & Security dimension |
| `sdd-plan-architect` | **Downstream consumer**: reads `design/TECHNICAL-DESIGN.md` in Phase 0 |
| `sdd-req-change` | **Lateral**: spec changes can invalidate design |

### Pipeline Position

```
Requisitos → sdd-specifications-engineer → sdd-spec-auditor (fix) →
                                                    ↓
                                      [sdd-tech-designer] ← YOU ARE HERE (optional)
                                                    ↓
                                          sdd-plan-architect
                                          (consumes design/ if exists)
                                                    ↓
                                               sdd-task-generator
                                                    ↓
                                               sdd-task-implementer

Lateral skills:
  sdd-security-auditor  ← security findings feed Auth & Security dimension
  sdd-req-change        ← spec changes can invalidate design/
```

> **Important:** This skill is NOT a required pipeline stage. It is a lateral skill invoked on-demand.
> `sdd-plan-architect` works without it — its Phase 2 clarify covers basic technical decisions.
> This skill provides deeper analysis for complex systems.

---

## Invocation Modes

### Default Mode

```
/sdd-tech-designer
```

Full 12-dimension analysis. Runs all 5 phases.

### Focused Mode

```
/sdd-tech-designer --dimensions=1,4,5,7
```

Analyzes only specified dimensions (by number). Useful for targeted exploration.

### Update Mode

```
/sdd-tech-designer --update
```

Reads existing `design/TECHNICAL-DESIGN.md` and updates only dimensions affected by spec changes. Preserves existing decisions.

### Quality-Only Mode

```
/sdd-tech-designer --quality-only
```

Runs only Phase 2 (Quality Attributes). Produces `design/QUALITY-ATTRIBUTES.md` only.

---

## Process

### Phase 0 — Load Context

**Purpose:** Understand the specification landscape and existing decisions.

**Steps:**

1. **Read specifications:**
   ```
   Glob: spec/**/*.md
   Glob: requirements/REQUIREMENTS.md
   ```

2. **Read existing decisions:**
   - `spec/adr/ADR-*.md` — Extract technology and architecture decisions
   - `CLAUDE.md` — Active Technologies, constraints
   - `spec/CLARIFICATIONS.md` — Business rules affecting design
   - `audits/SECURITY-AUDIT-BASELINE.md` — Security findings (if exists)

3. **Read existing design (if update mode):**
   ```
   Glob: design/*.md
   ```

4. **Build context manifest:**
   - System type (web app, API, data pipeline, real-time, etc.)
   - Known technology decisions
   - Known constraints (budget, team, compliance)
   - Security posture and findings

**Output:** Internal manifest (not written to disk)

---

### Phase 1 — System Vision

**Purpose:** Establish a shared understanding of what kind of system is being designed.

**Steps:**

1. **Identify system type** from specs:
   - Web Application (SPA, SSR, MPA)
   - API Service (REST, GraphQL, gRPC)
   - Data Pipeline (batch, streaming, ETL)
   - Real-time System (WebSocket, SSE, pub/sub)
   - CLI Tool
   - Mobile Application
   - Hybrid / Multi-component

2. **Identify technical stakeholders:**
   - End users (from use-cases actors)
   - Developers (team size, expertise from CLAUDE.md)
   - Operations (deployment, monitoring needs from nfr/)
   - External systems (from contracts/, integrations)

3. **Identify hard constraints:**
   - Budget (from nfr/ or user input)
   - Compliance (GDPR, HIPAA, PCI-DSS from nfr/SECURITY.md)
   - Platform lock-in (existing cloud provider, hosting)
   - Team expertise (from CLAUDE.md or user input)
   - Timeline (from project context)

4. **Generate System Vision Statement:**

   ```markdown
   ## System Vision

   **Type:** {system type}
   **Primary Users:** {actors}
   **Scale:** {expected load/size from nfr/}
   **Key Constraint:** {most limiting constraint}

   > {3-5 line narrative describing what the system IS at a technical level}
   ```

5. **Present to user for validation before proceeding.**

**Output:** System Vision embedded in TECHNICAL-DESIGN.md §1

---

### Phase 2 — Quality Attributes (ATAM-lite)

**Purpose:** Prioritize quality attributes and identify trade-offs using a simplified Architecture Tradeoff Analysis Method.

> Full reference: `references/quality-attributes.md`

**Steps:**

1. **Extract quality requirements** from specs:
   - Read `spec/nfr/*.md` for explicit NFRs
   - Read `spec/domain/05-INVARIANTS.md` for implicit quality needs
   - Read `spec/use-cases/` for performance/reliability expectations
   - Read `audits/SECURITY-AUDIT-BASELINE.md` for security priorities

2. **Score each quality attribute** (1-5 importance):
   - Performance, Security, Scalability, Reliability, Maintainability,
     Usability, Testability, Deployability, Cost Efficiency, Portability

3. **Identify trade-off pairs:**
   - Performance ↔ Maintainability
   - Security ↔ Usability
   - Scalability ↔ Cost Efficiency
   - Reliability ↔ Deployability
   - etc.

4. **Generate trade-off matrix:**

   | Attribute | Score | Favored Over | Sacrificed For |
   |-----------|-------|-------------|----------------|
   | Security | 5 | Usability | — |
   | Performance | 4 | Maintainability | Security |

5. **Present top 3 trade-offs to user for validation:**
   - "Security is prioritized over usability — are you OK with stricter auth flows?"
   - etc.

**Output:** `design/QUALITY-ATTRIBUTES.md`

---

### Phase 3 — 12-Dimension Analysis (Interactive)

**Purpose:** Walk through each applicable dimension with context-aware questions and recommendations.

> Full dimension catalog: `references/dimension-catalog.md`

**12 Dimensions:**

| # | Dimension | Scope |
|---|-----------|-------|
| 1 | Delivery Channels | Web, mobile, CLI, API-only, desktop |
| 2 | Architecture Style | Monolith, microservices, serverless, modular |
| 3 | Tech Stack | Languages, frameworks, rationale |
| 4 | Data Strategy | DB type, schema, migrations, caching |
| 5 | Auth & Security | Auth model, encryption, compliance |
| 6 | API Design | REST/GraphQL/gRPC, versioning, rate limiting |
| 7 | Infrastructure | Cloud provider, containers, IaC |
| 8 | CI/CD Pipeline | Build, test, deploy strategy |
| 9 | Observability | Logging, monitoring, alerting, tracing |
| 10 | Cost & Scaling | Budget constraints, scaling strategy |
| 11 | Developer Experience | Monorepo, tooling, local dev |
| 12 | i18n & Accessibility | Localization, WCAG, RTL support |

**Per-dimension process:**

1. **Check if resolved:** Scan ADRs, CLAUDE.md, existing design for decisions
2. **If resolved:** Mark as ✅, show evidence, skip questions
3. **If partial:** Generate targeted questions for unresolved aspects
4. **If missing:** Generate full question set with recommendations
5. **Present questions ONE at a time** with recommended answer + alternatives
6. **Log each decision** with rationale

**Dimension applicability:**
- Not all dimensions apply to all systems
- Detection rules in `references/dimension-catalog.md` determine applicability
- User can skip any dimension with "skip" or "n/a"

**Early termination:** User can say "done" or "proceed" to end Phase 3 at any point.

**Output:** Decisions logged per dimension (written in Phase 4)

---

### Phase 4 — Generate Outputs

**Purpose:** Produce design documents from all collected decisions.

**Steps:**

1. **Generate `design/TECHNICAL-DESIGN.md`:**
   - System Vision (from Phase 1)
   - Per-dimension sections with:
     - Decision taken
     - Rationale
     - Alternatives considered
     - Trade-offs accepted
     - References (ADRs, specs, research)
   - Template: `references/output-templates.md` §TECHNICAL-DESIGN

2. **Generate `design/QUALITY-ATTRIBUTES.md`:**
   - Attribute priority table
   - Trade-off matrix
   - Scenario evaluations
   - Template: `references/output-templates.md` §QUALITY-ATTRIBUTES

3. **Generate ADR drafts** for key decisions:
   - Only for decisions that warrant formal architectural record
   - Typically: architecture style, primary database, auth model, deployment platform
   - Template: `references/output-templates.md` §ADR-DRAFT
   - File naming: `design/ADR-DRAFT-NNN-{slug}.md`
   - These are DRAFTS — user should review and move to `spec/adr/` if approved

4. **Update pipeline-state.json** (see Persist Summary section)

**Output:**
- `design/TECHNICAL-DESIGN.md` — Main design document
- `design/QUALITY-ATTRIBUTES.md` — Quality attribute analysis
- `design/ADR-DRAFT-NNN-{slug}.md` — Draft ADRs (0 or more)

---

## Output Artifacts

```
design/
├── TECHNICAL-DESIGN.md          ← Main document: 12 dimensions with decisions
├── QUALITY-ATTRIBUTES.md        ← Quality attribute analysis with trade-offs
└── ADR-DRAFT-NNN-{slug}.md     ← Draft ADRs for key decisions (optional)
```

---

## Important Constraints

### 1. Read-Only on Specs

```
✅ READ: spec/**/*.md, requirements/**/*.md, audits/**/*.md
✅ WRITE: design/**/*.md (only design directory)

❌ WRITE: spec/**/*.md (NEVER modify specs)
❌ WRITE: plan/**/*.md (NEVER modify plan)
❌ WRITE: Any file outside design/
```

### 2. No Code Generation

```
❌ Full implementation code
❌ Config files (docker-compose, terraform, etc.)

✅ Architecture decision records (ADR drafts)
✅ ASCII architecture diagrams
✅ Schema sketches (illustrative, not authoritative)
✅ Technology comparison tables
```

### 3. Decision Authority

| Decision Type | Authority | Where Documented |
|--------------|-----------|-----------------|
| Business rules | Specs (CLARIFICATIONS.md) | spec/ |
| Architecture | ADRs | spec/adr/ (formal) or design/ADR-DRAFT (draft) |
| Technology selection | Tech Designer | design/TECHNICAL-DESIGN.md |
| Quality trade-offs | Tech Designer + User | design/QUALITY-ATTRIBUTES.md |

Tech Designer makes **technology and design recommendations** but the user has final authority. All decisions require user confirmation before being recorded.

### 4. Incremental Updates

When `design/` already has artifacts (update mode):
1. Read existing artifacts as baseline
2. Identify what changed in specs
3. Update only affected dimensions
4. Preserve existing decisions unless contradicted by spec changes
5. Add version entry to Document History

### 5. Language Convention

- Section headers: English (for international readability)
- Descriptive text: Spanish (following spec/ convention)
- Technical terms: English (ubiquitous language)

---

## SWEBOK v4 Alignment

| SWEBOK Chapter | Topic | How Addressed |
|---------------|-------|---------------|
| Ch02 (Software Design) | Architecture Styles | Dimension 2: Architecture Style analysis |
| Ch02 (Software Design) | Quality Attributes | Phase 2: ATAM-lite evaluation |
| Ch02 (Software Design) | Design Rationale | ADR drafts with trade-off documentation |
| Ch02 (Software Design) | Design Processes | Systematic 12-dimension exploration |
| Ch03 (Software Construction) | Construction Planning | Technology stack decisions inform construction |
| Ch10 (Software Quality) | Quality Planning | Quality attribute prioritization |

---

## References

| Reference | Location | Content |
|-----------|----------|---------|
| Dimension Catalog | `references/dimension-catalog.md` | 12 dimensions with detection rules, questions, patterns |
| Quality Attributes | `references/quality-attributes.md` | ISO 25010 simplified, ATAM-lite method, scoring |
| Output Templates | `references/output-templates.md` | Templates for all output artifacts |

---

## Persist Summary

After generating all output artifacts, update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["tech-designer"].status` = `"done"`
3. Set `stages["tech-designer"].lastRun` = current ISO-8601
4. Set `stages["tech-designer"].summary`:
   - `artifacts`: list of files created in `design/` with labels
   - `metrics`: `{ "dimensions_analyzed": N, "quality_attributes": N, "adr_drafts": N, "trade_offs_evaluated": N }`
   - `highlights`: top 3-5 notable observations (e.g., "Microservices architecture selected", "3 ADR drafts for review")
   - `nextStep`: `"Run /sdd-plan-architect (design/ will be consumed automatically)"`
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Display summary table to user (console output)
7. Handoff: follow the plugin-root `references/handoff-protocol.md` (only in station mode; never from a subagent).
