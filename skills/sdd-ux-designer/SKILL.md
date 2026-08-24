---
name: sdd-ux-designer
description: "UX design system across 12 dimensions (brand, tokens, components, responsive, accessibility, interaction, forms, navigation, security, mobile, theming): wireframes, WCAG 2.1 AA specs. Outputs to ux/. Triggers: 'UX design', 'design system', 'wireframes', 'accessibility', 'design tokens', 'diseno UX', 'sistema de diseno', 'componentes UI'."
---

# SDD UX Designer Skill

> **Principio:** Las decisiones de interfaz y experiencia de usuario deben ser explícitas, documentadas y trazables.
> Este skill explora el espacio de diseño UI/UX en profundidad antes de la planificación,
> asegurando que ninguna dimensión visual, de accesibilidad o de interacción quede sin especificar.

## Purpose

Explorar y documentar decisiones de diseño UI/UX a través de 12 dimensiones, produciendo:

1. **Design Vision** — Tipo de interfaz, canales, público objetivo, brand constraints
2. **Design System** — Tokens, component library (Atomic Design), responsive strategy
3. **Wireframes** — ASCII + descripción textual para pantallas clave
4. **Accessibility** — WCAG 2.1 AA checklist aplicada al proyecto
5. **Interaction Model** — Transiciones, estados, animaciones, error handling visual

## When to Use This Skill

Use this skill when:
- The project has a user-facing interface (web, mobile, desktop)
- No design system or UI specifications exist in the project
- Before `sdd-plan-architect` to ensure frontend implementation has clear visual specs
- When creating or updating a design system for an existing project
- When accessibility compliance (WCAG) needs formal specification
- When multiple delivery channels (web + mobile) require responsive strategy
- Stakeholders need wireframes to validate UX before implementation

## When NOT to Use This Skill

- For API-only services with no user interface → skip entirely
- For CLI tools without visual UI → skip entirely
- To generate implementation code → use `sdd-task-implementer`
- To audit existing specs → use `sdd-spec-auditor`
- To plan implementation phases → use `sdd-plan-architect`
- For backend architecture decisions → use `sdd-tech-designer`

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `sdd-specifications-engineer` | **Prerequisite**: specs should exist (at minimum domain + use-cases) |
| `sdd-spec-auditor` | **Recommended**: audit-clean specs produce better design |
| `sdd-tech-designer` | **Complementary**: tech decisions (stack, infra) inform UX constraints |
| `sdd-security-auditor` | **Complementary**: security findings inform Frontend Security dimension |
| `sdd-plan-architect` | **Downstream consumer**: reads `ux/UI-DESIGN-SYSTEM.md` in Phase 0 |
| `sdd-req-change` | **Lateral**: spec changes can invalidate UX design |

### Pipeline Position

```
Requisitos -> sdd-specifications-engineer -> sdd-spec-auditor (fix) ->
                                                    |
                                      [sdd-tech-designer] (optional)
                                                    |
                                      [sdd-ux-designer] <- YOU ARE HERE (optional)
                                                    |
                                          sdd-plan-architect
                                          (consumes ux/ if exists)
                                                    |
                                               sdd-task-generator
                                                    |
                                               sdd-task-implementer

Lateral skills:
  sdd-tech-designer     <- tech decisions inform UX constraints
  sdd-security-auditor  <- security findings feed Frontend Security dimension
  sdd-req-change        <- spec changes can invalidate ux/
```

> **Important:** This skill is NOT a required pipeline stage. It is a lateral skill invoked on-demand.
> `sdd-plan-architect` works without it — its Phase 2 clarify covers basic UI decisions (CL-UI category).
> This skill provides deeper UX analysis for projects with significant user-facing interfaces.

---

## Invocation Modes

### Default Mode

```
/sdd-ux-designer
```

Full 12-dimension analysis. Runs all 5 phases.

### Focused Mode

```
/sdd-ux-designer --dimensions=brand,accessibility,mobile
```

Analyzes only specified dimensions (by name or number). Useful for targeted exploration.

### Update Mode

```
/sdd-ux-designer --update
```

Reads existing `ux/UI-DESIGN-SYSTEM.md` and updates only dimensions affected by spec changes. Preserves existing decisions.

### Wireframes-Only Mode

```
/sdd-ux-designer --wireframes-only
```

Runs only Phase 3 (Wireframe & Component Specification). Produces `ux/WIREFRAMES.md` only. Requires existing `ux/UI-DESIGN-SYSTEM.md`.

---

## Process

### Phase 0 — Load Context

**Purpose:** Understand the specification landscape and existing design decisions.

**Steps:**

1. **Read specifications:**
   ```
   Glob: spec/**/*.md
   Glob: requirements/REQUIREMENTS.md
   ```

2. **Read existing decisions:**
   - `spec/adr/ADR-*.md` — Extract UI-related technology and architecture decisions
   - `CLAUDE.md` — Active Technologies, frontend frameworks, CSS strategy
   - `spec/CLARIFICATIONS.md` — Business rules affecting UX (branding, locales, etc.)
   - `spec/nfr/*.md` — Performance targets, accessibility requirements
   - `spec/use-cases/*.md` — User flows, actors, interaction patterns

3. **Read tech design** (if exists):
   - `design/TECHNICAL-DESIGN.md` — Extract Delivery Channels, Tech Stack, i18n decisions
   - These inputs from `sdd-tech-designer` pre-resolve many UX dimensions

4. **Read security findings** (if exists):
   - `audits/SECURITY-AUDIT-BASELINE.md` — Extract frontend security findings (XSS, CSRF, etc.)

5. **Read existing UX design** (if update mode):
   ```
   Glob: ux/*.md
   Glob: ux/*.json
   ```

6. **Build context manifest:**
   - Interface type (web SPA, SSR, mobile, desktop, hybrid)
   - Known frontend technology decisions
   - Known UI constraints (brand guidelines, existing design system)
   - Accessibility requirements (legal, contractual)
   - Target delivery channels (web, mobile, desktop)
   - User personas / actors from use-cases

**Output:** Internal manifest (not written to disk)

---

### Phase 1 — Design Vision

**Purpose:** Establish a shared understanding of how the system looks and feels.

**Steps:**

1. **Identify interface type** from specs:
   - Web Application — SPA (React, Vue, Svelte), SSR (Next, Nuxt, SvelteKit), MPA
   - Mobile Application — Native (iOS/Android), React Native, Flutter, PWA
   - Desktop Application — Electron, Tauri, native
   - Multi-platform — Web + Mobile, responsive vs adaptive
   - Admin/Dashboard — Internal tools, data-heavy interfaces
   - Public-facing — Marketing, e-commerce, content sites

2. **Identify target users:**
   - Extract actors from use-cases
   - Classify: technical vs non-technical, age range, accessibility needs
   - Identify primary vs secondary user flows

3. **Identify brand constraints:**
   - Existing brand guidelines (colors, typography, logo usage)
   - Industry conventions (fintech = trust/blue, health = clean/green)
   - Competitor benchmarking cues from specs or user input
   - Legal/regulatory UI requirements (cookie banners, disclaimers)

4. **Identify delivery channels:**
   - Primary channel (e.g., web desktop)
   - Secondary channels (e.g., mobile responsive, native app)
   - Offline requirements
   - Performance constraints per channel (Core Web Vitals targets)

5. **Generate Design Vision Statement:**

   ```markdown
   ## Design Vision

   **Interface Type:** {type}
   **Primary Users:** {actors with brief profile}
   **Delivery Channels:** {channels with priority}
   **Brand Direction:** {tone, style direction}
   **Key UX Constraint:** {most limiting constraint}

   > {3-5 line narrative describing the target user experience}
   ```

6. **Present to user for validation before proceeding.**

**Output:** Design Vision embedded in UI-DESIGN-SYSTEM.md section 1

---

### Phase 2 — 12-Dimension Interactive Analysis

**Purpose:** Walk through each applicable UX dimension with context-aware questions and recommendations.

> Full dimension catalog: `references/ux-dimension-catalog.md`

**12 Dimensions:**

| # | Dimension | Scope |
|---|-----------|-------|
| 1 | Brand Identity | Logo, colors, typography, voice & tone |
| 2 | Design System & Tokens | JSON tokens (colors, spacing, radii, shadows, breakpoints) |
| 3 | Component Library (Atomic Design) | Atoms, molecules, organisms, templates, pages |
| 4 | Responsive & Adaptive | Breakpoints, mobile-first vs desktop-first, fluid vs fixed |
| 5 | Accessibility (WCAG 2.1 AA) | Color contrast, keyboard nav, screen readers, ARIA, focus |
| 6 | Interaction Design | Micro-interactions, transitions, animations, loading states |
| 7 | Forms & Data Entry | Validation, error messages, field types, multi-step flows |
| 8 | Navigation & Information Architecture | Nav patterns, breadcrumbs, search, sitemap |
| 9 | Frontend Security | CSP, XSS prevention, CSRF, secure cookies, clickjacking, SRI |
| 10 | Frontend Performance | Core Web Vitals (LCP < 2.5s, FID < 100ms, CLS < 0.1), lazy loading |
| 11 | Mobile-Specific | Touch targets (48px min), gestures, offline-first, PWA |
| 12 | Dark Mode & Theming | Theme switching, color semantics, user preference, prefers-color-scheme |

**Per-dimension process:**

1. **Check if resolved:** Scan ADRs, CLAUDE.md, existing design, tech-designer output for decisions
2. **If resolved:** Mark as completed, show evidence, skip questions
3. **If partial:** Generate targeted questions for unresolved aspects
4. **If missing:** Generate full question set with recommendations
5. **Present questions ONE at a time** with recommended answer + alternatives table
6. **Log each decision** with rationale

**Dimension applicability:**
- Not all dimensions apply to all systems
- Detection rules in `references/ux-dimension-catalog.md` determine applicability
- User can skip any dimension with "skip" or "n/a"
- Mobile-Specific (dim 11) only applies if mobile is a delivery channel
- Dark Mode (dim 12) only applies if theming is a requirement or user requests it

**Early termination:** User can say "done" or "proceed" to end Phase 2 at any point.

**Output:** Decisions logged per dimension (written in Phase 4)

---

### Phase 3 — Wireframe & Component Specification

**Purpose:** Generate visual representations and component definitions for key screens.

> Full output format: `references/output-templates.md` section WIREFRAMES

**Steps:**

1. **Identify key screens** from use-cases:
   - Extract primary user flows (UC actors + actions)
   - Identify entry points, main screens, critical flows, error states
   - Prioritize by user frequency and business value

2. **For each key screen, generate:**

   a. **ASCII wireframe:**
   ```
   +--------------------------------------------------+
   |  [Logo]    Home  |  Dashboard  |  Settings    [?] |
   +--------------------------------------------------+
   |                                                    |
   |  +-------------------+  +-------------------+     |
   |  | Card Title        |  | Card Title        |     |
   |  | Description text  |  | Description text  |     |
   |  | [Action Button]   |  | [Action Button]   |     |
   |  +-------------------+  +-------------------+     |
   |                                                    |
   +--------------------------------------------------+
   |  Footer  |  Links  |  Copyright                   |
   +--------------------------------------------------+
   ```

   b. **Textual description:**
   - Screen purpose and entry conditions
   - Layout structure (grid, flex, sections)
   - Component inventory per screen
   - Interactive elements and their behavior
   - Responsive adaptations (how it changes at breakpoints)
   - Accessibility notes (tab order, ARIA landmarks)

3. **Define component library** using Atomic Design:

   | Level | Examples | Naming Convention |
   |-------|---------|-------------------|
   | Atoms | Button, Input, Label, Icon, Badge | `atom-{name}` |
   | Molecules | SearchBar, FormField, NavItem, Card | `mol-{name}` |
   | Organisms | Header, Sidebar, DataTable, Form | `org-{name}` |
   | Templates | DashboardLayout, AuthLayout, ListPage | `tmpl-{name}` |
   | Pages | LoginPage, DashboardPage, SettingsPage | `page-{name}` |

4. **For each component, specify:**
   - Props/variants (sizes, states, themes)
   - States: default, hover, active, focus, disabled, error, loading
   - Accessibility requirements (role, aria-label, keyboard interaction)
   - Responsive behavior
   - Related design tokens

**Output:** Component specs and wireframes (written in Phase 4)

---

### Phase 4 — Generate Outputs

**Purpose:** Produce design documents from all collected decisions.

**Steps:**

1. **Generate `ux/UI-DESIGN-SYSTEM.md`:**
   - Design Vision (from Phase 1)
   - Per-dimension sections with:
     - Decision taken
     - Rationale
     - Alternatives considered
     - Design tokens used
     - References (specs, ADRs)
   - Template: `references/output-templates.md` section UI-DESIGN-SYSTEM

2. **Generate `ux/WIREFRAMES.md`:**
   - ASCII wireframes for each key screen
   - Textual descriptions with component references
   - Responsive variations
   - Template: `references/output-templates.md` section WIREFRAMES

3. **Generate `ux/ACCESSIBILITY-SPEC.md`:**
   - WCAG 2.1 AA compliance checklist applied to project
   - Per-component ARIA patterns
   - Keyboard navigation matrix
   - Color contrast verification table
   - Template: `references/output-templates.md` section ACCESSIBILITY-SPEC
   - Reference: `references/accessibility-checklist.md`

4. **Generate `ux/INTERACTION-MODEL.md`:**
   - State diagrams for interactive elements
   - Transition specifications (duration, easing, trigger)
   - Animation catalog (loading, success, error, empty states)
   - Error handling visual patterns
   - Template: `references/output-templates.md` section INTERACTION-MODEL

5. **Generate `ux/DESIGN-TOKENS.json`:**
   - Framework-agnostic JSON token file
   - Semantic naming convention (color.primary, spacing.md, etc.)
   - Supports light/dark theme variants
   - Template: `references/output-templates.md` section DESIGN-TOKENS

6. **Update pipeline-state.json** (see Persist Summary section)

**Output:**
- `ux/UI-DESIGN-SYSTEM.md` — Main design document
- `ux/WIREFRAMES.md` — ASCII wireframes + textual descriptions
- `ux/ACCESSIBILITY-SPEC.md` — WCAG 2.1 AA specification
- `ux/INTERACTION-MODEL.md` — Interaction and animation specs
- `ux/DESIGN-TOKENS.json` — Design tokens in JSON format

---

## Output Artifacts

```
ux/
+-- UI-DESIGN-SYSTEM.md          <- Main document: brand, tokens, components, responsive
+-- WIREFRAMES.md                <- ASCII wireframes + textual descriptions per screen
+-- ACCESSIBILITY-SPEC.md        <- WCAG 2.1 AA checklist applied to project
+-- INTERACTION-MODEL.md         <- Transitions, states, animations, error handling
+-- DESIGN-TOKENS.json           <- Tokens in JSON format (framework-agnostic)
```

---

## Important Constraints

### 1. Read-Only on Specs

```
Read: spec/**/*.md, requirements/**/*.md, audits/**/*.md, design/**/*.md
Write: ux/**/* (only ux directory)

Do NOT write: spec/**/*.md (NEVER modify specs)
Do NOT write: design/**/*.md (NEVER modify tech design)
Do NOT write: plan/**/*.md (NEVER modify plan)
Do NOT write: Any file outside ux/
```

### 2. No Code Generation

```
No: Full implementation code
No: CSS/SCSS files
No: React/Vue/Svelte components
No: Config files (tailwind.config, postcss, etc.)

Yes: Design token JSON (framework-agnostic)
Yes: ASCII wireframes
Yes: Component specification tables
Yes: ARIA pattern descriptions
Yes: Color palette and typography definitions
```

### 3. Decision Authority

| Decision Type | Authority | Where Documented |
|--------------|-----------|-----------------|
| Business rules | Specs (CLARIFICATIONS.md) | spec/ |
| Architecture | ADRs | spec/adr/ |
| Technology selection | Tech Designer | design/TECHNICAL-DESIGN.md |
| UX decisions | UX Designer + User | ux/UI-DESIGN-SYSTEM.md |
| Accessibility spec | UX Designer | ux/ACCESSIBILITY-SPEC.md |

UX Designer makes **visual and interaction recommendations** but the user has final authority. All decisions require user confirmation before being recorded.

### 4. Incremental Updates

When `ux/` already has artifacts (update mode):
1. Read existing artifacts as baseline
2. Identify what changed in specs
3. Update only affected dimensions
4. Preserve existing decisions unless contradicted by spec changes
5. Add version entry to Document History

### 5. Language Convention

- Section headers: English (for international readability)
- Descriptive text: Spanish (following spec/ convention)
- Technical terms: English (ubiquitous language)
- Design token names: English (CSS/JSON convention)

---

## Standards Referenced

| Standard | Topic | How Addressed |
|----------|-------|---------------|
| WCAG 2.1 (AA target) | Web Accessibility | Dimension 5: full checklist, per-component ARIA |
| Core Web Vitals | Frontend Performance | Dimension 10: LCP, FID, CLS targets |
| Atomic Design (Brad Frost) | Component Organization | Phase 3: atoms, molecules, organisms, templates, pages |
| OWASP Frontend Security | Frontend Security | Dimension 9: CSP, XSS, CSRF, clickjacking |
| SWEBOK v4 Ch02 | Software Design | Design processes, quality attributes |
| Material Design / Apple HIG | Design Patterns | Referenced as common pattern alternatives |

---

## References

| Reference | Location | Content |
|-----------|----------|---------|
| UX Dimension Catalog | `references/ux-dimension-catalog.md` | 12 dimensions with detection rules, questions, patterns |
| Accessibility Checklist | `references/accessibility-checklist.md` | WCAG 2.1 AA checklist, ARIA patterns, testing tools |
| Output Templates | `references/output-templates.md` | Templates for all 5 output artifacts |

---

## Persist Summary

After generating all output artifacts, update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (create if absent with default stage structure)
2. Set `stages["ux-designer"].status` = `"done"`
3. Set `stages["ux-designer"].lastRun` = current ISO-8601
4. Set `stages["ux-designer"].summary`:
   - `artifacts`: list of files created in `ux/` with labels
   - `metrics`: `{ "dimensions_analyzed": N, "wireframes": N, "components_specified": N, "wcag_level": "AA", "design_tokens": N, "frontend_security_items": N }`
   - `highlights`: top 3-5 notable observations (e.g., "12 wireframes for key flows", "WCAG 2.1 AA compliant")
   - `nextStep`: `"Run /sdd-plan-architect (ux/ will be consumed automatically)"`
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Display summary table to user (console output)
7. Handoff: follow the plugin-root `references/handoff-protocol.md` (only in station mode; never from a subagent).
