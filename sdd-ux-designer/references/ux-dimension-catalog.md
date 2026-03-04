# UX Dimension Catalog

> Reference for the 12 UX dimensions analyzed by `sdd-ux-designer`.
> Each dimension includes scope, detection rules, question templates, common patterns, and red flags.

---

## Dimension Priority Matrix

The priority of each dimension depends on the project type. Use this matrix to determine which dimensions are HIGH, MEDIUM, or LOW priority.

| # | Dimension | Web App | Mobile App | Dashboard | E-commerce | Public Site |
|---|-----------|---------|------------|-----------|------------|-------------|
| 1 | Brand Identity | HIGH | HIGH | MEDIUM | HIGH | HIGH |
| 2 | Design Tokens | HIGH | HIGH | MEDIUM | HIGH | HIGH |
| 3 | Component Library | HIGH | HIGH | HIGH | HIGH | MEDIUM |
| 4 | Responsive | HIGH | HIGH | MEDIUM | HIGH | HIGH |
| 5 | Accessibility | HIGH | HIGH | MEDIUM | HIGH | HIGH |
| 6 | Interaction Design | MEDIUM | HIGH | LOW | HIGH | MEDIUM |
| 7 | Forms & Data Entry | HIGH | HIGH | HIGH | HIGH | LOW |
| 8 | Navigation & IA | HIGH | HIGH | HIGH | HIGH | HIGH |
| 9 | Frontend Security | HIGH | MEDIUM | MEDIUM | HIGH | LOW |
| 10 | Frontend Performance | HIGH | HIGH | MEDIUM | HIGH | HIGH |
| 11 | Mobile-Specific | LOW | HIGH | LOW | HIGH | MEDIUM |
| 12 | Dark Mode & Theming | LOW | MEDIUM | LOW | LOW | LOW |

---

## 1. Brand Identity

### What It Covers
- Logo usage rules (sizes, clear space, variations)
- Color palette (primary, secondary, accent, semantic, neutral)
- Typography scale (font families, sizes, weights, line heights)
- Voice & tone guidelines (formal vs casual, technical vs friendly)
- Iconography style (outlined, filled, rounded, custom)

### Detection Rules
- **HIGH priority** if: specs mention public-facing users, e-commerce, or brand guidelines
- **MEDIUM priority** if: internal tool with corporate brand
- **LOW priority** if: CLI tool, API-only, or prototype

### Question Templates

1. **Color Palette:** "Do you have existing brand colors, or should we define them? If yes, provide hex codes for primary and secondary colors."
   - Option A: Provide existing brand colors
   - Option B: Define new palette based on industry (fintech=blue/trust, health=green/clean, tech=purple/innovation)
   - Option C: Use a framework default (Material, Tailwind) and customize later

2. **Typography:** "What font families should the system use?"
   - Option A: System fonts only (fastest, no loading)
   - Option B: Google Fonts (Inter, Roboto, Open Sans — free, widely supported)
   - Option C: Custom/licensed fonts (provide font files)

3. **Voice & Tone:** "How should the system communicate with users?"
   - Option A: Professional and formal (enterprise, legal, finance)
   - Option B: Friendly and conversational (consumer apps, social)
   - Option C: Technical and precise (developer tools, documentation)

### Common Patterns
- Material Design color system (primary, secondary, surface, error)
- Tailwind CSS default palette (slate, gray, zinc, neutral, stone)
- IBM Carbon Design System
- Apple Human Interface Guidelines
- Custom brand-first approach

### Red Flags
- No color palette defined for a public-facing app
- Using only black and white without semantic colors
- No typography hierarchy (everything same size)
- Inconsistent icon styles across specs

---

## 2. Design System & Tokens

### What It Covers
- Design token JSON structure (colors, spacing, radii, shadows, breakpoints)
- Token naming convention (semantic vs literal)
- Token categories: color, spacing, typography, elevation, border, animation
- Token format compatibility (CSS custom properties, Tailwind, Style Dictionary)
- Token versioning strategy

### Detection Rules
- **HIGH priority** if: multiple delivery channels or component reuse expected
- **MEDIUM priority** if: single app with moderate complexity
- **LOW priority** if: simple prototype or MVP

### Question Templates

1. **Token Format:** "What format should design tokens use?"
   - Option A: CSS Custom Properties (`--color-primary: #3B82F6`) — native, no build step
   - Option B: JSON (Style Dictionary compatible) — multi-platform, transformable
   - Option C: Tailwind config extension — if Tailwind is the CSS framework

2. **Naming Convention:** "How should tokens be named?"
   - Option A: Semantic naming (`color.primary`, `spacing.md`) — intent-based
   - Option B: Scale naming (`color.blue.500`, `spacing.4`) — value-based
   - Option C: Hybrid (semantic aliases + scale values)

3. **Spacing Scale:** "What spacing scale should the system use?"
   - Option A: 4px base (4, 8, 12, 16, 24, 32, 48, 64) — most common
   - Option B: 8px base (8, 16, 24, 32, 48, 64, 96) — looser layouts
   - Option C: Custom scale from existing brand guidelines

### Common Patterns
- 4px spacing grid (most common in modern design systems)
- 8-point grid system (Material Design)
- T-shirt sizing (xs, sm, md, lg, xl, 2xl)
- Fibonacci-based scale
- Tailwind default spacing scale

### Red Flags
- Hardcoded pixel values throughout specs instead of tokens
- No spacing system defined
- Inconsistent border-radius values across components
- No elevation/shadow system for depth

---

## 3. Component Library (Atomic Design)

### What It Covers
- Component hierarchy: atoms, molecules, organisms, templates, pages
- Component variants (sizes, states, themes)
- Component composition rules
- Prop/slot definitions per component
- Component documentation standards

### Detection Rules
- **HIGH priority** if: specs reference multiple UI screens or complex forms
- **MEDIUM priority** if: few screens with moderate complexity
- **LOW priority** if: single-page app or minimal UI

### Question Templates

1. **Base Component Library:** "Should we use an existing component library or build custom?"
   - Option A: Existing library (shadcn/ui, Radix, MUI, Ant Design, Chakra)
   - Option B: Headless components (Radix, Headless UI, React Aria) + custom styling
   - Option C: Fully custom component library
   - Option D: Framework-provided components (Vuetify, PrimeVue, etc.)

2. **Component Documentation:** "How should components be documented?"
   - Option A: Storybook (visual component catalog, interactive)
   - Option B: Inline documentation (JSDoc/TSDoc + README per component)
   - Option C: Design file reference (Figma link per component)

3. **Component Granularity:** "What level of granularity should the component library have?"
   - Option A: Full Atomic Design (atoms through pages) — comprehensive but more work
   - Option B: Molecules and organisms only — pragmatic middle ground
   - Option C: Page-level components only — fastest, least reusable

### Common Patterns
- shadcn/ui (copy-paste, full control, Tailwind-based)
- Radix Primitives + Tailwind (headless + utility CSS)
- Material UI (comprehensive, opinionated)
- Ant Design (enterprise-focused)
- Custom design system with Storybook

### Red Flags
- Specs reference UI elements with no component definition
- No consistent button/input/card patterns across screens
- Each screen uses different styling conventions
- No shared component strategy across delivery channels

---

## 4. Responsive & Adaptive

### What It Covers
- Breakpoint definitions (mobile, tablet, desktop, large desktop)
- Mobile-first vs desktop-first approach
- Fluid vs fixed layouts
- Container query support
- Responsive image strategy
- Layout patterns per breakpoint

### Detection Rules
- **HIGH priority** if: specs mention mobile users, multiple screen sizes, or responsive requirements
- **MEDIUM priority** if: primarily desktop but should work on tablet
- **LOW priority** if: fixed-size application (desktop only, kiosk)

### Question Templates

1. **Approach:** "Should the design be mobile-first or desktop-first?"
   - Option A: Mobile-first (recommended for public-facing apps) — progressive enhancement
   - Option B: Desktop-first (recommended for complex dashboards) — graceful degradation
   - Option C: Adaptive (separate layouts per breakpoint) — most work, best UX per device

2. **Breakpoints:** "What breakpoints should the system use?"
   - Option A: Tailwind defaults (sm:640, md:768, lg:1024, xl:1280, 2xl:1536)
   - Option B: Bootstrap defaults (sm:576, md:768, lg:992, xl:1200, xxl:1400)
   - Option C: Custom breakpoints based on content needs

3. **Layout Strategy:** "How should layouts adapt?"
   - Option A: CSS Grid + Flexbox (modern, powerful)
   - Option B: Container queries (component-level responsiveness)
   - Option C: Framework grid system (Bootstrap grid, Tailwind container)

### Common Patterns
- 12-column grid system
- CSS Grid with auto-fit/auto-fill
- Container queries for component-level responsiveness
- Responsive typography with clamp()
- srcset/sizes for responsive images

### Red Flags
- No mention of mobile in a web application spec
- Fixed pixel widths in layouts
- No responsive image strategy for image-heavy apps
- Desktop-only wireframes for a public-facing app

---

## 5. Accessibility (WCAG 2.1 AA)

### What It Covers
- Color contrast ratios (4.5:1 normal text, 3:1 large text)
- Keyboard navigation (all interactive elements focusable)
- Screen reader support (ARIA roles, labels, live regions)
- Focus management (visible focus indicators, logical tab order)
- Alternative text for images and non-text content
- Reduced motion support (prefers-reduced-motion)

### Detection Rules
- **HIGH priority** if: public-facing app, government/regulated sector, or accessibility mentioned in specs
- **MEDIUM priority** if: enterprise internal tool (still legally required in many jurisdictions)
- **LOW priority**: Never LOW — accessibility should always be at least MEDIUM

### Question Templates

1. **Compliance Target:** "What WCAG compliance level is required?"
   - Option A: WCAG 2.1 Level AA (recommended — covers most legal requirements)
   - Option B: WCAG 2.1 Level AAA (highest standard — very restrictive)
   - Option C: Section 508 / EN 301 549 (US/EU specific requirements)
   - Option D: Best effort (no formal compliance target, but follow best practices)

2. **Assistive Technology:** "Which assistive technologies should be tested?"
   - Option A: VoiceOver (macOS/iOS) + NVDA (Windows) — covers most users
   - Option B: Full matrix (VoiceOver + NVDA + JAWS + TalkBack)
   - Option C: Automated testing only (axe, Lighthouse) — minimum viable

3. **Focus Management:** "How should focus be managed in modal/dynamic content?"
   - Option A: Focus trap in modals, return focus on close (ARIA dialog pattern)
   - Option B: Focus management library (focus-trap, react-focus-lock)
   - Option C: Browser default behavior (minimal intervention)

### Common Patterns
- ARIA landmark roles (banner, main, navigation, contentinfo)
- Skip navigation links
- Focus trap for modals and dialogs
- Live regions for dynamic content (aria-live)
- Visually hidden text for screen readers (sr-only class)

### Red Flags
- No mention of accessibility in any spec
- Color-only information encoding (red=error, green=success)
- Custom interactive elements without ARIA roles
- No keyboard navigation path defined
- Infinite scroll without keyboard alternative

> Full checklist: `references/accessibility-checklist.md`

---

## 6. Interaction Design

### What It Covers
- Micro-interactions (button press, toggle, hover effects)
- Page transitions (route changes, view switches)
- Loading states (skeleton screens, spinners, progress bars)
- Success/error feedback (toasts, inline messages, alerts)
- Animation timing and easing functions
- Drag and drop interactions
- Gesture support (swipe, pinch, long press)

### Detection Rules
- **HIGH priority** if: specs mention rich interactions, drag-and-drop, real-time updates
- **MEDIUM priority** if: standard form-based application
- **LOW priority** if: static content site, admin panel

### Question Templates

1. **Animation Strategy:** "How should the system use animations?"
   - Option A: Minimal (transitions only for feedback — 150-200ms) — snappy, professional
   - Option B: Moderate (meaningful transitions + micro-interactions) — engaging, polished
   - Option C: Rich (full page transitions + parallax + spring animations) — delightful, heavier

2. **Loading Strategy:** "How should loading states be displayed?"
   - Option A: Skeleton screens (content placeholders) — perceived performance
   - Option B: Spinner/progress bar — explicit loading indicator
   - Option C: Optimistic UI (show result, rollback on error) — fastest perceived
   - Option D: Combination based on wait time (<200ms: none, <1s: spinner, >1s: skeleton)

3. **Error Feedback:** "How should errors be communicated to users?"
   - Option A: Inline validation (real-time, per-field) — immediate feedback
   - Option B: Toast notifications (non-blocking, auto-dismiss) — unobtrusive
   - Option C: Modal/dialog for critical errors — attention-demanding
   - Option D: Combination based on severity

### Common Patterns
- CSS transition: 150ms ease-out (standard button/hover)
- CSS transition: 200-300ms ease-in-out (expanding/collapsing)
- Spring animations (framer-motion, react-spring)
- Skeleton screens with pulse animation
- Toast notifications with auto-dismiss (5s default)

### Red Flags
- No loading states defined in specs with async operations
- No error handling UI patterns
- Animations without prefers-reduced-motion support
- No feedback for user actions (silent failures)

---

## 7. Forms & Data Entry

### What It Covers
- Form layout patterns (single column, multi-column, multi-step)
- Validation strategy (client-side, server-side, hybrid)
- Error message conventions (inline, summary, toast)
- Field types and input masks
- Auto-save and draft persistence
- File upload patterns
- Multi-step flow with progress indication

### Detection Rules
- **HIGH priority** if: specs contain forms, data entry, user registration, or CRUD operations
- **MEDIUM priority** if: few input fields, simple settings pages
- **LOW priority** if: read-only application, content display

### Question Templates

1. **Validation Timing:** "When should form validation occur?"
   - Option A: On blur (validate when leaving field) — balanced
   - Option B: On submit only (validate all at once) — simplest
   - Option C: Real-time (validate on each keystroke) — most responsive, more complex
   - Option D: Hybrid (real-time for format, on blur for business rules, on submit for cross-field)

2. **Error Display:** "How should form errors be displayed?"
   - Option A: Inline below each field (red text + icon) — most accessible
   - Option B: Error summary at top + inline markers — best for long forms
   - Option C: Toast notification — least intrusive, easy to miss

3. **Multi-Step Forms:** "How should multi-step forms work?"
   - Option A: Wizard with progress bar (step 1 of N) — clear progress
   - Option B: Accordion sections (expand/collapse) — all visible
   - Option C: Single long form with sections — simplest

### Common Patterns
- Single column forms (mobile-friendly, highest completion rate)
- Floating labels (Material Design style)
- Input masks for phone, credit card, date
- Auto-save drafts every 30s
- Confirm before destructive actions

### Red Flags
- Forms with no validation strategy
- No error message convention across forms
- File upload without size/type restrictions
- Multi-step forms without save progress
- No confirmation for irreversible actions

---

## 8. Navigation & Information Architecture

### What It Covers
- Primary navigation pattern (top bar, sidebar, bottom tabs)
- Secondary navigation (breadcrumbs, tabs, pagination)
- Search functionality (full-text, filters, facets)
- URL structure and deep linking
- Sitemap / page hierarchy
- Mobile navigation adaptation

### Detection Rules
- **HIGH priority** if: specs describe multiple pages/sections, complex information hierarchy
- **MEDIUM priority** if: few pages but clear navigation needed
- **LOW priority** if: single-page application with minimal navigation

### Question Templates

1. **Primary Navigation:** "What navigation pattern should the main menu use?"
   - Option A: Top navigation bar (horizontal) — standard for marketing/content sites
   - Option B: Sidebar navigation (vertical) — standard for dashboards/admin
   - Option C: Bottom tab bar — standard for mobile apps
   - Option D: Hamburger menu — space-efficient, lower discoverability

2. **Search:** "Does the system need search functionality?"
   - Option A: Global search with suggestions (typeahead) — best for content-rich apps
   - Option B: Section-specific search with filters — best for data-heavy apps
   - Option C: Command palette (Ctrl+K) — best for power users
   - Option D: No search needed

3. **Breadcrumbs:** "Should the system show breadcrumb navigation?"
   - Option A: Yes, hierarchical breadcrumbs on all pages — best for deep hierarchies
   - Option B: Yes, only on detail pages — pragmatic
   - Option C: No breadcrumbs — flat navigation structure

### Common Patterns
- Responsive sidebar (full on desktop, hamburger on mobile)
- Breadcrumb + page title combination
- Tab navigation for related views
- Pagination vs infinite scroll vs load more
- Deep linking with URL parameters for filters

### Red Flags
- No navigation pattern defined for multi-page app
- Inconsistent nav placement across pages
- No mobile nav adaptation
- Deep hierarchy (>4 levels) without breadcrumbs
- No search in a content-heavy application

---

## 9. Frontend Security

### What It Covers
- Content Security Policy (CSP) headers
- XSS prevention (input sanitization, output encoding, DOM manipulation)
- CSRF protection (tokens, SameSite cookies)
- Clickjacking prevention (X-Frame-Options, frame-ancestors)
- Subresource Integrity (SRI) for CDN assets
- Secure cookie configuration (HttpOnly, Secure, SameSite)
- Client-side data exposure (localStorage, sessionStorage sensitivity)
- HTTPS enforcement and HSTS

### Detection Rules
- **HIGH priority** if: specs handle user data, authentication, payments, or PII
- **MEDIUM priority** if: internal tool with authentication
- **LOW priority** if: static site with no user data

### Question Templates

1. **CSP Strategy:** "How strict should the Content Security Policy be?"
   - Option A: Strict CSP (nonce-based, no inline scripts) — most secure, requires build setup
   - Option B: Moderate CSP (self + known CDNs, no eval) — balanced
   - Option C: Report-only CSP initially — learn before enforcing

2. **Client-Side Storage:** "What data can be stored client-side?"
   - Option A: Nothing sensitive in client storage (all in HTTP-only cookies) — most secure
   - Option B: Session tokens in memory, preferences in localStorage — pragmatic
   - Option C: Encrypted client-side storage for offline support

3. **Third-Party Scripts:** "How should third-party scripts be managed?"
   - Option A: No third-party scripts (all self-hosted) — most secure
   - Option B: SRI hashes for all CDN resources — verified integrity
   - Option C: Trusted CDN domains in CSP — convenient but less controlled

### Common Patterns
- CSP with nonce for inline scripts
- CSRF tokens via double-submit cookie pattern
- HttpOnly + Secure + SameSite=Strict cookies
- X-Frame-Options: DENY or CSP frame-ancestors 'none'
- HSTS with includeSubDomains and preload

### Red Flags
- Storing JWT in localStorage (XSS risk)
- No CSP headers defined
- Inline event handlers (onclick="...") in specs
- No CSRF protection for state-changing requests
- Mixed HTTP/HTTPS content

---

## 10. Frontend Performance

### What It Covers
- Core Web Vitals targets (LCP < 2.5s, FID < 100ms, CLS < 0.1)
- Image optimization (formats, compression, lazy loading, srcset)
- Code splitting and lazy loading (routes, components)
- Bundle size budget
- Caching strategy (service worker, CDN, HTTP cache headers)
- Font loading strategy (display: swap, preload, subsetting)
- Critical CSS / above-the-fold optimization

### Detection Rules
- **HIGH priority** if: public-facing app, SEO requirements, mobile users on slow connections
- **MEDIUM priority** if: internal tool where performance matters but not critical
- **LOW priority** if: admin tool used on fast connections only

### Question Templates

1. **Performance Budget:** "What are the performance targets?"
   - Option A: Core Web Vitals (LCP < 2.5s, FID < 100ms, CLS < 0.1) — Google recommended
   - Option B: Strict (LCP < 1.5s, FID < 50ms, CLS < 0.05) — premium experience
   - Option C: Relaxed (LCP < 4s, FID < 200ms, CLS < 0.25) — internal tools

2. **Image Strategy:** "How should images be optimized?"
   - Option A: Next-gen formats (WebP/AVIF) with fallback — best compression
   - Option B: Responsive images (srcset + sizes) — best for varied screen sizes
   - Option C: CDN with automatic optimization (Cloudflare Images, imgix) — offload optimization
   - Option D: All of the above (recommended for image-heavy sites)

3. **Code Splitting:** "How should JavaScript be split?"
   - Option A: Route-based splitting (each page loads its own bundle) — standard
   - Option B: Component-based splitting (heavy components lazy-loaded) — granular
   - Option C: No splitting (small app, single bundle under 100KB)

### Common Patterns
- Route-based code splitting with React.lazy/dynamic imports
- Image lazy loading with loading="lazy"
- Service worker for offline caching (Workbox)
- Critical CSS inlining for above-the-fold
- Font display: swap with preload for custom fonts
- Bundle size budget: <200KB initial JS (compressed)

### Red Flags
- No performance targets in specs with mobile users
- Large unoptimized images in specs
- No lazy loading strategy for below-the-fold content
- Blocking third-party scripts in the critical path
- No caching strategy defined

---

## 11. Mobile-Specific

### What It Covers
- Touch target sizing (minimum 48x48px per WCAG, 44x44pt Apple HIG)
- Gesture support (swipe, pinch-to-zoom, pull-to-refresh)
- Offline-first capability
- PWA configuration (manifest, service worker, install prompt)
- Native vs hybrid vs responsive decision
- Mobile-specific UI patterns (bottom sheets, action sheets, floating action button)
- Safe area insets (notch, home indicator)

### Detection Rules
- **HIGH priority** if: mobile is a primary delivery channel or specs mention mobile app
- **MEDIUM priority** if: responsive web app used on mobile
- **LOW priority** if: desktop-only application
- **N/A** if: API-only or CLI tool

### Question Templates

1. **Mobile Approach:** "How should the mobile experience be delivered?"
   - Option A: Responsive web (same codebase, CSS adaptations) — simplest, broadest reach
   - Option B: PWA (installable, offline, push notifications) — web + native-like features
   - Option C: Native apps (Swift/Kotlin) — best performance, platform-specific
   - Option D: Cross-platform (React Native, Flutter) — shared codebase, near-native

2. **Offline Strategy:** "Does the mobile experience need offline support?"
   - Option A: No offline support needed
   - Option B: Offline read (cache previously viewed content)
   - Option C: Offline read + write (queue actions, sync when online) — most complex
   - Option D: Full offline-first (all features available offline)

3. **Touch Interactions:** "What mobile-specific interactions are needed?"
   - Option A: Standard tap/scroll only — simplest
   - Option B: Swipe actions (swipe to delete, swipe between views) — common mobile pattern
   - Option C: Rich gestures (pinch-to-zoom, long press, drag-to-reorder) — advanced

### Common Patterns
- Bottom sheet for contextual actions
- Pull-to-refresh for list views
- Swipe-to-dismiss for cards/items
- Floating action button (FAB) for primary action
- Tab bar with 3-5 items max
- Safe area padding for notch devices

### Red Flags
- Touch targets smaller than 48px in mobile specs
- No offline strategy for mobile-focused app
- Desktop-only navigation patterns on mobile
- No consideration of slow mobile connections
- Text too small on mobile (< 16px)

---

## 12. Dark Mode & Theming

### What It Covers
- Theme switching mechanism (system preference, manual toggle, scheduled)
- Semantic color tokens (use "surface" not "white", "on-surface" not "black")
- Color adjustments for dark mode (not just inversion)
- Image and illustration adaptation for dark backgrounds
- User preference persistence (localStorage, user profile)
- `prefers-color-scheme` media query support
- High contrast mode support

### Detection Rules
- **HIGH priority** if: specs explicitly require dark mode or theming
- **MEDIUM priority** if: modern consumer app where dark mode is expected
- **LOW priority** if: internal tool, admin panel, or no theme requirement
- **N/A** if: user explicitly says no theming needed

### Question Templates

1. **Theme Support:** "Should the system support dark mode?"
   - Option A: Light mode only — simplest, fewer design tokens
   - Option B: Light + dark mode with system preference detection — modern standard
   - Option C: Light + dark + custom themes — most flexible, most work
   - Option D: Dark mode only — specialized (media apps, developer tools)

2. **Theme Detection:** "How should the theme be determined?"
   - Option A: System preference only (prefers-color-scheme) — automatic, no UI needed
   - Option B: Manual toggle with system preference as default — user control
   - Option C: Manual toggle + scheduled (day/night) — premium experience

3. **Theme Persistence:** "Where should the theme preference be stored?"
   - Option A: localStorage (client-only, instant) — simplest
   - Option B: User profile in database (synced across devices) — best for multi-device
   - Option C: Both (localStorage for instant apply, profile for sync)

### Common Patterns
- CSS custom properties for theme tokens
- Semantic color naming (background, surface, on-surface, primary, on-primary)
- Dark mode: reduce brightness, not just invert colors
- Elevation changes in dark mode (lighter surfaces = higher elevation)
- prefers-color-scheme media query with fallback class
- Theme transition: 200ms ease-in-out on background-color

### Red Flags
- Using "white" and "black" as color names instead of semantic tokens
- Simple color inversion for dark mode (loses contrast hierarchy)
- No prefers-color-scheme support when dark mode is implemented
- Theme flash on page load (FOUC — flash of unstyled content)
- Images/illustrations not adapted for dark backgrounds
