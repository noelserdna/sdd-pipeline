# Accessibility Checklist (WCAG 2.2 Level AA)

> Used by Dimension 5 and when writing `ux/ACCESSIBILITY-SPEC.md`. You know WCAG 2.2 and the WAI-ARIA Authoring
> Practices; this file only fixes how to apply them in SDD.

## 1. Applicability table

Walk every WCAG 2.2 A/AA success criterion and emit one row per criterion (4.1.1 Parsing is obsolete in 2.2 — omit it):

| SC | Level | Applies? | Where (screens / components) | How the project meets it | Verified by |
|----|-------|----------|------------------------------|--------------------------|-------------|
| 1.4.3 Contrast (Minimum) | AA | Yes | all text | tokens `color.text.*` ≥ 4.5:1 on `color.surface.*` | contrast table §3 |
| 1.2.2 Captions | A | No | — | no video in scope | — |

"Applies? = No" needs a one-clause reason. Give extra attention to the criteria new in 2.2 because older habits miss them:

- **2.4.11 Focus Not Obscured (Minimum)** — sticky headers/footers, cookie banners and toasts must not hide the focused element.
- **2.5.7 Dragging Movements** — every drag (sortable lists, sliders, maps) has a single-pointer alternative.
- **2.5.8 Target Size (Minimum)** — pointer targets ≥ 24×24 CSS px or sufficiently spaced; record the chosen token (mobile channel keeps its 44–48 px rule from Dimension 11).
- **3.2.6 Consistent Help** — help mechanisms appear in the same relative order across pages.
- **3.3.7 Redundant Entry** — data already entered in a flow is pre-filled or selectable.
- **3.3.8 Accessible Authentication (Minimum)** — no cognitive-function test (memorising, transcribing, puzzles) without an alternative; allow paste and password managers.

## 2. Per-component matrix

For each component in the library: role, accessible name source, keyboard keys (APG pattern), focus behaviour on open/close/delete/error, live-region politeness, states exposed (`aria-expanded`, `aria-selected`, `aria-invalid`…).

## 3. Contrast table

Every foreground/background token pair actually used, with its ratio, per theme (light/dark): text 4.5:1 (large 3:1), UI components and focus indicators 3:1 (1.4.11).

## 4. Project rules (SDD-specific)

- **Server-authoritative validation.** When the spec requires server messages (UC exception rows, BDD scenarios asserting an error code or message), do not specify blocking constraint attributes (`required`, `maxlength`, `minlength`, `pattern`, blocking `type="email"`) on those fields — the browser would stop the submit and the required message would never render. Use `aria-required="true"` plus a visible required hint, the server message in an element referenced by `aria-describedby`, `aria-invalid="true"` on error, and focus to the first invalid field or an error summary (3.3.1, 3.3.3, 4.1.3). Length limits are hints; the server enforces them. State the behaviour, not the attribute.
- **Role and name stability (4.1.2).** A control whose role and accessible name a requirement fixes (e.g. button "Save") keeps them: turning it into a link or renaming it breaks `getByRole` acceptance tests. Check any such change — even a Tier-1 decision — against the requirement's accessibility/UI contract before Phase 4; on conflict ask the user or record a deviation with its REQ id in `feedback/`.
- **No transport in ux/.** HTTP methods, routes, status codes, redirects or URL shapes appear only when a REQ demands them, citing it; otherwise describe the outcome ("after saving, the list shows the new title"). Transport lives in `design/OPERATION-MAPPING.md`.

## 5. Verification

Name the automated tool (axe-core or equivalent) for CI and the manual passes (keyboard-only, one screen reader per target platform, 200% zoom / 320 px reflow, forced colors, `prefers-reduced-motion`). Automated tools catch only part of WCAG issues, so the spec lists which SCs need manual checks.
