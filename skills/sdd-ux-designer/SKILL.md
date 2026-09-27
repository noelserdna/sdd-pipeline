---
name: sdd-ux-designer
description: "UX design system across 12 dimensions (brand, tokens, components, responsive, accessibility, interaction, forms, navigation, security, mobile, theming): wireframes, WCAG 2.2 AA specs, DTCG design tokens. Outputs to ux/. Triggers: 'UX design', 'design system', 'wireframes', 'accessibility', 'design tokens', 'diseno UX', 'sistema de diseno', 'componentes UI'."
---

# SDD UX Designer Skill

> **Principio:** Las decisiones de interfaz y experiencia de usuario deben ser explícitas, documentadas y trazables.
> Este skill explora el espacio de diseño UI/UX en profundidad antes de la planificación,
> asegurando que ninguna dimensión visual, de accesibilidad o de interacción quede sin especificar.

## Purpose

Explore and document UI/UX decisions across 12 dimensions, producing a design vision, a design system (tokens, Atomic Design component library, responsive strategy), ASCII wireframes for key screens, a WCAG 2.2 AA accessibility spec and an interaction model. Skip it for API-only services and CLI tools without a visual UI.

## Relationship to Other Skills

| Skill | Relationship |
|-------|-------------|
| `sdd-specifications-engineer` | **Prerequisite**: specs should exist (at minimum domain + use-cases) |
| `sdd-spec-auditor` | **Recommended**: audit-clean specs produce better design |
| `sdd-tech-designer` | **Complementary**: tech decisions (stack, infra) inform UX constraints |
| `sdd-security-auditor` | **Complementary**: security findings inform Frontend Security dimension |
| `sdd-plan-architect` | **Downstream consumer**: reads `ux/UI-DESIGN-SYSTEM.md` in Phase 0 |
| `sdd-req-change` | **Lateral**: spec changes can invalidate UX design |

This is a lateral, optional skill: `sdd-plan-architect` works without it (its Phase 2 clarify covers basic UI decisions, category CL-UI). It adds depth for projects with significant user-facing interfaces.

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

Runs Phase 0 (context), Phase 3 (wireframes and components) and only step 2 of Phase 4 (write `ux/WIREFRAMES.md`), then Persist Summary. Requires an existing `ux/UI-DESIGN-SYSTEM.md`, whose tokens and component names the wireframes reuse; other `ux/` files are left untouched.

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
   - `audits/SECURITY-AUDIT-BASELINE.md` (from `sdd-security-auditor`) — open findings touching the client (XSS, CSRF, clickjacking, token storage, CSP). Dimension 9 cites them by ID.

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
| 5 | Accessibility (WCAG 2.2 AA) | Contrast, keyboard, screen readers, ARIA, focus not obscured, target size, accessible authentication |
| 6 | Interaction Design | Micro-interactions, transitions, animations, loading states |
| 7 | Forms & Data Entry | Validation, error messages, field types, multi-step flows |
| 8 | Navigation & Information Architecture | Nav patterns, breadcrumbs, search, sitemap |
| 9 | Frontend Security | CSP, XSS, CSRF, secure cookies, clickjacking, SRI — cites open `sdd-security-auditor` findings when the audit exists |
| 10 | Frontend Performance | Core Web Vitals (LCP < 2.5s, INP < 200ms, CLS < 0.1 at p75), lazy loading |
| 11 | Mobile-Specific | Touch targets (44pt iOS / 48dp Android; WCAG floor 24px), gestures, offline-first, PWA |
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

   a. **ASCII wireframe** (desktop and, when mobile is a channel, mobile), using the symbol conventions in `references/output-templates.md`.

   b. **Textual description:**
   - Screen purpose and entry conditions
   - Layout structure (grid, flex, sections)
   - Component inventory per screen
   - Interactive elements and their behavior
   - Responsive adaptations (how it changes at breakpoints)
   - Accessibility notes (tab order, ARIA landmarks)

3. **Define the component library** with Atomic Design levels (atoms, molecules, organisms, templates, pages), named `atom-`, `mol-`, `org-`, `tmpl-`, `page-{name}`.

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
   - WCAG 2.2 AA applicability table (one row per success criterion)
   - Per-component ARIA patterns
   - Keyboard navigation matrix
   - Color contrast verification table
   - Template: `references/output-templates.md` section ACCESSIBILITY-SPEC
   - Read `references/accessibility-checklist.md` first (table format, criteria new in 2.2, project rules)

4. **Generate `ux/INTERACTION-MODEL.md`:**
   - State diagrams for interactive elements
   - Transition specifications (duration, easing, trigger)
   - Animation catalog (loading, success, error, empty states)
   - Error handling visual patterns
   - Template: `references/output-templates.md` section INTERACTION-MODEL

5. **Generate `ux/DESIGN-TOKENS.json`:**
   - W3C Design Tokens (DTCG) format: `$value` / `$type`, aliases `{group.token}`
   - Primitives plus one semantic `theme-*` group per theme (light/dark)
   - Template: `references/output-templates.md` section DESIGN-TOKENS

6. **Update pipeline-state.json** (see Persist Summary section)

**Output:**
- `ux/UI-DESIGN-SYSTEM.md` — Main design document
- `ux/WIREFRAMES.md` — ASCII wireframes + textual descriptions
- `ux/ACCESSIBILITY-SPEC.md` — WCAG 2.2 AA specification
- `ux/INTERACTION-MODEL.md` — Interaction and animation specs
- `ux/DESIGN-TOKENS.json` — Design tokens (DTCG format)

---

## Important Constraints

### 1. Write scope

Reads `spec/`, `requirements/`, `audits/`, `design/`. Writes only `ux/` plus the `ux-designer` entry of `pipeline-state.json`. Specs, `design/` and `plan/` belong to other skills; a needed spec change goes through `sdd-req-change`.

### 2. No code

Produce design tokens, ASCII wireframes, component tables, ARIA patterns and palette/typography definitions — not CSS, components or framework config files.

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

### 5. Language

Output follows the user's language; section headers, technical terms and token names stay in English.

### 6. Transport-Neutral, Server-Authoritative UI

- No HTTP methods, routes, status codes or URL mechanics unless a REQ demands them (cite it); transport lives in `design/OPERATION-MAPPING.md`.
- Client validation never prevents server messages the spec requires: no blocking `required`/`maxlength`/`pattern`; use `aria-required`, `aria-invalid`, `aria-describedby`.
- A decision (incl. Tier-1) changing an element's role, type or accessible name (button↔link) is checked against the REQ accessibility/UI contract before Phase 4; on conflict ask or record a deviation in `feedback/`.

---

## References

| Reference | Location | Content |
|-----------|----------|---------|
| UX Dimension Catalog | `references/ux-dimension-catalog.md` | 12 dimensions with detection rules, questions, patterns |
| Accessibility Checklist | `references/accessibility-checklist.md` | WCAG 2.2 AA applicability table, criteria new in 2.2, project rules |
| Output Templates | `references/output-templates.md` | Templates for all 5 output artifacts |

---

## Persist Summary

After generating all output artifacts, update `pipeline-state.json`:

1. Read `pipeline-state.json` from project root (if absent, instantiate `$SDD_PLUGIN_ROOT/templates/pipeline-state.template.json` as `sdd-setup` Step 1 does)
2. Set `stages["ux-designer"].status` = `"done"`
3. Set `stages["ux-designer"].lastRun` = current ISO-8601
4. Set `stages["ux-designer"].summary`:
   - `artifacts`: list of files created in `ux/` with labels
   - `metrics`: `{ "dimensions_analyzed": N, "wireframes": N, "components_specified": N, "wcag_level": "2.2 AA", "design_tokens": N, "frontend_security_items": N }`
   - `highlights`: top 3-5 notable observations (e.g., "12 wireframes for key flows", "3 open security findings addressed in dim 9")
   - `nextStep`: `"Run /sdd-plan-architect (ux/ will be consumed automatically)"`
   - `generatedAt`: current ISO-8601
5. Write updated `pipeline-state.json`
6. Display summary table to user (console output)
7. Handoff: follow the plugin-root `references/handoff-protocol.md` (only in station mode; never from a subagent).
