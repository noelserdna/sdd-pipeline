# Accessibility Checklist (WCAG 2.1 Level AA)

> Reference checklist for `sdd-ux-designer` Dimension 5 and `ux/ACCESSIBILITY-SPEC.md` generation.
> Organized by the four WCAG principles: Perceivable, Operable, Understandable, Robust.

---

## 1. Perceivable

Information and user interface components must be presentable to users in ways they can perceive.

### 1.1 Text Alternatives

| Criterion | Level | Check | Component Types |
|-----------|-------|-------|-----------------|
| 1.1.1 Non-text Content | A | All images have meaningful alt text or are marked decorative (`alt=""`) | Images, icons, charts, graphs |

### 1.2 Time-based Media

| Criterion | Level | Check | Component Types |
|-----------|-------|-------|-----------------|
| 1.2.1 Audio-only, Video-only | A | Transcript or audio description provided | Audio players, video players |
| 1.2.2 Captions (Prerecorded) | A | Synchronized captions for video | Video players |
| 1.2.3 Audio Description | A | Audio description or media alternative | Video players |
| 1.2.5 Audio Description (Prerecorded) | AA | Audio description for prerecorded video | Video players |

### 1.3 Adaptable

| Criterion | Level | Check | Component Types |
|-----------|-------|-------|-----------------|
| 1.3.1 Info and Relationships | A | Semantic HTML conveys structure (headings, lists, tables, form labels) | All structural elements |
| 1.3.2 Meaningful Sequence | A | Reading order matches visual order in DOM | All page layouts |
| 1.3.3 Sensory Characteristics | A | Instructions don't rely solely on shape, size, position, or sound | Help text, instructions |
| 1.3.4 Orientation | AA | Content not restricted to single display orientation | All pages |
| 1.3.5 Identify Input Purpose | AA | Input fields have autocomplete attributes | Forms, inputs |

### 1.4 Distinguishable

| Criterion | Level | Check | Requirement |
|-----------|-------|-------|-------------|
| 1.4.1 Use of Color | A | Color is not the sole means of conveying information | Status indicators, errors, links |
| 1.4.2 Audio Control | A | Auto-playing audio can be paused/stopped | Media players |
| 1.4.3 Contrast (Minimum) | AA | **4.5:1** ratio for normal text, **3:1** for large text (18pt+ or 14pt bold) | All text content |
| 1.4.4 Resize Text | AA | Text can be resized up to 200% without loss of content | All text |
| 1.4.5 Images of Text | AA | Text is used instead of images of text (except logos) | All UI text |
| 1.4.10 Reflow | AA | Content reflows at 320px width (no horizontal scroll) | All pages |
| 1.4.11 Non-text Contrast | AA | **3:1** ratio for UI components and graphical objects | Buttons, inputs, icons, charts |
| 1.4.12 Text Spacing | AA | Content adapts to custom text spacing without loss | All text containers |
| 1.4.13 Content on Hover/Focus | AA | Additional content on hover/focus is dismissible, hoverable, persistent | Tooltips, popovers, dropdowns |

### Color Contrast Quick Reference

| Element | Minimum Ratio | Tools |
|---------|--------------|-------|
| Normal text (< 18pt) | 4.5:1 | WebAIM Contrast Checker |
| Large text (>= 18pt or >= 14pt bold) | 3:1 | Colour Contrast Analyser |
| UI components (borders, icons) | 3:1 | axe DevTools |
| Focus indicators | 3:1 against adjacent | Lighthouse |
| Placeholder text | 4.5:1 (if relied upon) | Manual check |

---

## 2. Operable

User interface components and navigation must be operable.

### 2.1 Keyboard Accessible

| Criterion | Level | Check | Component Types |
|-----------|-------|-------|-----------------|
| 2.1.1 Keyboard | A | All functionality available via keyboard | All interactive elements |
| 2.1.2 No Keyboard Trap | A | Focus can be moved away from any component | Modals, menus, custom widgets |
| 2.1.4 Character Key Shortcuts | A | Single-character shortcuts can be remapped/disabled | Custom keyboard shortcuts |

### Keyboard Interaction Patterns

| Component | Key | Action |
|-----------|-----|--------|
| Button | Enter, Space | Activate |
| Link | Enter | Navigate |
| Checkbox | Space | Toggle |
| Radio | Arrow keys | Move selection |
| Tab (tablist) | Arrow keys | Switch tabs |
| Menu | Arrow keys | Navigate items |
| Menu | Enter | Select item |
| Menu | Escape | Close menu |
| Dialog | Escape | Close dialog |
| Dialog | Tab | Cycle within dialog (focus trap) |
| Combobox | Arrow Down | Open/navigate options |
| Combobox | Enter | Select option |
| Combobox | Escape | Close dropdown |
| Accordion | Enter, Space | Expand/collapse |
| Slider | Arrow keys | Adjust value |
| Tree | Arrow keys | Navigate nodes |
| Tree | Enter | Activate node |
| Tree | Arrow Right | Expand node |
| Tree | Arrow Left | Collapse node |

### 2.2 Enough Time

| Criterion | Level | Check | Component Types |
|-----------|-------|-------|-----------------|
| 2.2.1 Timing Adjustable | A | Time limits can be extended or disabled | Session timeouts, auto-refresh |
| 2.2.2 Pause, Stop, Hide | A | Moving/auto-updating content can be paused | Carousels, animations, tickers |

### 2.3 Seizures and Physical Reactions

| Criterion | Level | Check | Component Types |
|-----------|-------|-------|-----------------|
| 2.3.1 Three Flashes | A | No content flashes more than 3 times per second | Animations, video |

### 2.4 Navigable

| Criterion | Level | Check | Component Types |
|-----------|-------|-------|-----------------|
| 2.4.1 Bypass Blocks | A | Skip navigation link to main content | Page layout |
| 2.4.2 Page Titled | A | Pages have descriptive, unique titles | All pages |
| 2.4.3 Focus Order | A | Focus order follows logical reading sequence | All interactive elements |
| 2.4.4 Link Purpose (in Context) | A | Link text describes destination (no "click here") | All links |
| 2.4.5 Multiple Ways | AA | Multiple ways to locate pages (nav, search, sitemap) | Site navigation |
| 2.4.6 Headings and Labels | AA | Headings and labels are descriptive | All headings, form labels |
| 2.4.7 Focus Visible | AA | Keyboard focus indicator is visible | All focusable elements |

### Focus Management Patterns

| Scenario | Focus Behavior |
|----------|---------------|
| Modal opens | Move focus to modal (first focusable or title) |
| Modal closes | Return focus to trigger element |
| Page navigation | Move focus to main content or page title |
| Error on submit | Move focus to first error field or error summary |
| Dynamic content added | Announce via aria-live, optionally move focus |
| Item deleted from list | Move focus to next/previous item or list |
| Dropdown opens | Move focus to first option |
| Dropdown closes | Return focus to trigger |
| Toast appears | Announce via aria-live="polite", don't move focus |
| Alert appears | Announce via role="alert" (implicit aria-live="assertive") |

### 2.5 Input Modalities

| Criterion | Level | Check | Component Types |
|-----------|-------|-------|-----------------|
| 2.5.1 Pointer Gestures | A | Multi-point/path gestures have single-pointer alternative | Maps, pinch-to-zoom, swipe |
| 2.5.2 Pointer Cancellation | A | Down-event doesn't trigger action (use up-event or click) | All clickable elements |
| 2.5.3 Label in Name | A | Accessible name contains visible text | Buttons, links with text |
| 2.5.4 Motion Actuation | A | Motion-triggered functions have alternatives | Shake, tilt features |

---

## 3. Understandable

Information and the operation of user interface must be understandable.

### 3.1 Readable

| Criterion | Level | Check | Component Types |
|-----------|-------|-------|-----------------|
| 3.1.1 Language of Page | A | `lang` attribute on `<html>` element | All pages |
| 3.1.2 Language of Parts | AA | `lang` attribute on elements in different language | Multilingual content |

### 3.2 Predictable

| Criterion | Level | Check | Component Types |
|-----------|-------|-------|-----------------|
| 3.2.1 On Focus | A | Focus change doesn't trigger context change | All focusable elements |
| 3.2.2 On Input | A | Input change doesn't trigger unexpected context change | Form inputs, selects |
| 3.2.3 Consistent Navigation | AA | Navigation is consistent across pages | Site-wide navigation |
| 3.2.4 Consistent Identification | AA | Same functionality has consistent labels | Repeated UI elements |

### 3.3 Input Assistance

| Criterion | Level | Check | Component Types |
|-----------|-------|-------|-----------------|
| 3.3.1 Error Identification | A | Errors are clearly identified and described in text | Form validation |
| 3.3.2 Labels or Instructions | A | Input fields have visible labels or instructions | All form inputs |
| 3.3.3 Error Suggestion | AA | Error messages suggest corrections when known | Form validation |
| 3.3.4 Error Prevention (Legal, Financial, Data) | AA | Reversible, verified, or confirmable submissions | Critical forms (payment, deletion) |

---

## 4. Robust

Content must be robust enough to be interpreted by assistive technologies.

### 4.1 Compatible

| Criterion | Level | Check | Component Types |
|-----------|-------|-------|-----------------|
| 4.1.1 Parsing | A | Valid HTML (deprecated in WCAG 2.2 but still good practice) | All pages |
| 4.1.2 Name, Role, Value | A | Custom components have proper ARIA name, role, value | All custom widgets |
| 4.1.3 Status Messages | AA | Status messages announced without focus change | Toasts, inline messages, counters |

---

## ARIA Patterns Reference

Common ARIA patterns for custom components. Use these when native HTML elements cannot fulfill the requirement.

### Dialog (Modal)

```html
<div role="dialog" aria-modal="true" aria-labelledby="dialog-title">
  <h2 id="dialog-title">Dialog Title</h2>
  <div>Content...</div>
  <button>Close</button>
</div>
```

- Focus moves to dialog on open
- Focus trapped within dialog
- Escape key closes dialog
- Focus returns to trigger on close

### Tabs

```html
<div role="tablist" aria-label="Section tabs">
  <button role="tab" aria-selected="true" aria-controls="panel-1" id="tab-1">Tab 1</button>
  <button role="tab" aria-selected="false" aria-controls="panel-2" id="tab-2">Tab 2</button>
</div>
<div role="tabpanel" id="panel-1" aria-labelledby="tab-1">Panel 1 content</div>
<div role="tabpanel" id="panel-2" aria-labelledby="tab-2" hidden>Panel 2 content</div>
```

- Arrow keys navigate between tabs
- Tab key moves focus into panel
- Selected tab has `aria-selected="true"`

### Accordion

```html
<h3>
  <button aria-expanded="true" aria-controls="section-1">Section Title</button>
</h3>
<div id="section-1" role="region" aria-labelledby="accordion-btn-1">Content...</div>
```

- Enter/Space toggles expansion
- `aria-expanded` reflects state
- `role="region"` for expanded content

### Combobox (Autocomplete)

```html
<label for="search">Search</label>
<input id="search" role="combobox" aria-expanded="false" aria-autocomplete="list"
       aria-controls="listbox-1" aria-activedescendant="">
<ul role="listbox" id="listbox-1">
  <li role="option" id="opt-1">Option 1</li>
</ul>
```

- Arrow keys navigate options
- `aria-activedescendant` tracks highlighted option
- Enter selects option
- Escape closes listbox

### Menu

```html
<button aria-haspopup="true" aria-expanded="false" aria-controls="menu-1">Menu</button>
<ul role="menu" id="menu-1">
  <li role="menuitem">Item 1</li>
  <li role="menuitem">Item 2</li>
  <li role="separator"></li>
  <li role="menuitem">Item 3</li>
</ul>
```

- Arrow keys navigate items
- Enter activates item
- Escape closes menu
- Focus returns to trigger

### Alert / Live Region

```html
<!-- Polite announcement (waits for pause in speech) -->
<div aria-live="polite" aria-atomic="true">3 results found</div>

<!-- Assertive announcement (interrupts current speech) -->
<div role="alert">Error: Session expired. Please log in again.</div>

<!-- Status message -->
<div role="status">File uploaded successfully</div>
```

- `role="alert"` = implicit `aria-live="assertive"`
- `role="status"` = implicit `aria-live="polite"`
- `aria-atomic="true"` announces entire region content

### Tooltip

```html
<button aria-describedby="tooltip-1">
  Help
  <span role="tooltip" id="tooltip-1">Additional information about this feature</span>
</button>
```

- Appears on hover and focus
- Dismissible with Escape
- Persistent while hovered
- `aria-describedby` links trigger to tooltip

---

## Testing Tools

### Automated Testing

| Tool | Type | Coverage |
|------|------|----------|
| axe-core / axe DevTools | Browser extension + CI | ~57% of WCAG issues |
| Lighthouse (Accessibility) | Chrome DevTools | Subset of axe rules |
| WAVE | Browser extension | Visual overlay of issues |
| pa11y | CLI / CI integration | Automated page scanning |
| jest-axe / vitest-axe | Unit test integration | Component-level a11y testing |

### Manual Testing

| Tool | Type | Use For |
|------|------|---------|
| VoiceOver | macOS/iOS screen reader | Screen reader testing (Safari) |
| NVDA | Windows screen reader (free) | Screen reader testing (Firefox/Chrome) |
| JAWS | Windows screen reader (paid) | Screen reader testing (enterprise standard) |
| TalkBack | Android screen reader | Mobile screen reader testing |
| Keyboard only | Manual | Tab order, focus management, keyboard traps |
| Colour Contrast Analyser | Desktop app | Manual contrast checking (any color) |
| Zoom to 200% | Browser zoom | Reflow and text resize testing |
| High contrast mode | OS setting | Forced colors testing |

### Testing Checklist (per component)

1. [ ] Navigate to component using only keyboard (Tab, Shift+Tab)
2. [ ] Activate component using keyboard (Enter, Space)
3. [ ] Check focus indicator is visible and meets 3:1 contrast
4. [ ] Test with screen reader (announce name, role, state)
5. [ ] Verify color contrast meets 4.5:1 (normal) or 3:1 (large)
6. [ ] Zoom to 200% — verify no content loss
7. [ ] Check with forced colors / high contrast mode
8. [ ] Verify content reflows at 320px viewport width
9. [ ] Test with prefers-reduced-motion enabled

---

## Screen Reader Announcement Patterns

| Scenario | Expected Announcement |
|----------|----------------------|
| Button | "{label}, button" |
| Link | "{text}, link" |
| Checkbox (checked) | "{label}, checkbox, checked" |
| Checkbox (unchecked) | "{label}, checkbox, not checked" |
| Radio (selected) | "{label}, radio button, selected, 2 of 5" |
| Tab (selected) | "{label}, tab, selected, 1 of 3" |
| Combobox | "{label}, combo box, {value}, expanded/collapsed" |
| Dialog opens | "{title}, dialog" |
| Alert | (assertive) "{message}" |
| Status update | (polite) "{message}" |
| Loading | "Loading" then "Content loaded" (or aria-busy) |
| Error on field | "{label}, invalid, {error message}" |
