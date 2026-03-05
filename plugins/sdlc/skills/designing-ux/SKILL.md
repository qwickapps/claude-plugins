---
name: designing-ux
description: >
  This skill should be used when building or modifying any user-facing interface, frontend
  component, page, layout, form, or navigation element. Auto-loads when working on UI code,
  CSS, HTML templates, React components, Vue components, or any rendering logic visible to
  end users. Trigger phrases include: "build a page", "add a component", "create a form",
  "design the layout", "update the UI", "style this", "make it look like", "add a nav",
  "responsive layout", "mobile view", "dark mode". This skill provides a checklist to apply
  while building frontend — not a guide, a gate.
---

# Designing UX

Apply this checklist while building or modifying any user-facing interface. Work through each
section relevant to the code at hand. Stop on failures. Fix before proceeding.

---

## 1. Accessibility — WCAG 2.1 AA (Non-Negotiable)

Accessibility is not optional. WCAG 2.1 AA is the minimum bar. Apply this checklist to
every component.

### Semantic HTML

- [ ] Use semantic elements for their intended purpose: `<nav>`, `<main>`, `<header>`,
      `<footer>`, `<article>`, `<section>`, `<aside>`, `<button>`, `<a>`
- [ ] Never use `<div>` or `<span>` as interactive elements — use `<button>` for
      click actions, `<a>` for navigation
- [ ] Use heading levels (`<h1>` through `<h6>`) to express document structure, not for
      visual sizing
- [ ] Use `<ul>`, `<ol>`, and `<li>` for lists of items, not for layout
- [ ] Use `<table>` with `<caption>`, `<th scope="col/row">` for tabular data — never
      for layout

### ARIA Labels and Roles

- [ ] Add `aria-label` or `aria-labelledby` to interactive elements that have no visible
      text label (icon buttons, close buttons, search inputs)
- [ ] Add `aria-describedby` to link descriptions or helper text to form fields
- [ ] Use `role` attribute only when HTML semantics are insufficient — prefer native
      elements
- [ ] Add `aria-expanded`, `aria-haspopup`, `aria-controls` to toggle controls
      (dropdowns, accordions, modals)
- [ ] Add `aria-live="polite"` to regions that update dynamically (status messages,
      search results, notifications)
- [ ] Add `aria-invalid="true"` and `aria-describedby` pointing to the error message
      on invalid form fields
- [ ] Add `aria-busy="true"` to regions that are loading

### Keyboard Navigation

- [ ] Every interactive element is reachable by Tab key in logical document order
- [ ] No keyboard traps — Tab always has a way out of every region
- [ ] Modal dialogs trap focus within the dialog while open; return focus to the trigger
      element on close
- [ ] Dropdowns and menus support Arrow keys for navigation, Escape to close
- [ ] Custom components implement the ARIA Authoring Practices pattern for their widget
      type (combobox, listbox, tree, grid)
- [ ] Skip navigation link present at the top of the page to bypass repeated navigation

### Focus Management

- [ ] Visible focus indicator on every interactive element — never use `outline: none`
      without a custom replacement that meets 3:1 contrast ratio
- [ ] Focus moves to the first interactive element when a modal or drawer opens
- [ ] Focus returns to the triggering element when a modal or drawer closes
- [ ] Focus moves to new content when a page section updates without a full navigation
      (single-page app route changes)

### Color Contrast

- [ ] Normal text (< 18px or < 14px bold): minimum 4.5:1 contrast ratio against background
- [ ] Large text (>= 18px or >= 14px bold): minimum 3:1 contrast ratio
- [ ] UI components and graphical objects (icons, focus rings, chart elements): minimum
      3:1 contrast against adjacent colors
- [ ] Never use color as the only means of conveying information — pair with text, icons,
      or patterns

---

## 2. Responsive Design

Build mobile-first. Progressively enhance for larger viewports.

### Mobile-First Approach

- [ ] Write base styles for the smallest viewport (320px minimum)
- [ ] Add breakpoint overrides using `min-width` media queries, not `max-width`
- [ ] Test at 320px, 375px, 768px, 1024px, 1280px, and 1440px viewport widths

### Breakpoints

Use a consistent scale across the project. Prefer four breakpoints:

| Name | Min-Width |
|------|-----------|
| sm | 640px |
| md | 768px |
| lg | 1024px |
| xl | 1280px |

Do not invent intermediate breakpoints for individual components. When a component does
not fit the standard breakpoints, reconsider the component design, not the breakpoint scale.

### Fluid Typography

- [ ] Use `rem` or `em` for font sizes, not `px`
- [ ] Use `clamp()` for fluid type that scales between viewport sizes:
      `font-size: clamp(1rem, 2.5vw, 1.5rem)` — minimum, preferred, maximum
- [ ] Line length: 45-75 characters per line (use `max-width: 65ch` on text containers)
- [ ] Line height: 1.4 to 1.6 for body text, 1.1 to 1.2 for headings

### Flexible Grids

- [ ] Use CSS Grid for two-dimensional layouts
- [ ] Use Flexbox for one-dimensional layouts (rows or columns, not both)
- [ ] Avoid fixed pixel widths on layout containers — use `%`, `fr`, or `min-content`/
      `max-content` where appropriate
- [ ] Test layout at extreme content lengths (empty, one character, very long strings)
      and at narrow viewports

### Touch Targets

- [ ] Minimum touch target size: 44x44px (Apple HIG) or 48x48px (Material Design)
- [ ] Sufficient spacing between adjacent touch targets to prevent mis-taps

---

## 3. Component Architecture

Components should be focused, composable, and predictable.

### Single Responsibility

- [ ] Each component does one thing and does it well
- [ ] If a component has "and" in its name or does two unrelated things, split it
- [ ] Keep components under 200 lines; extract sub-components when a component grows larger

### Controlled vs. Uncontrolled

- [ ] Decide explicitly: is state owned by the component (uncontrolled) or by the parent
      via props (controlled)?
- [ ] Controlled components accept a `value` prop and an `onChange` callback — the
      parent drives the state
- [ ] Uncontrolled components manage their own state internally via `defaultValue` or
      `useRef`
- [ ] Do not mix controlled and uncontrolled behavior in the same component

### Props Design

- [ ] Prop names are explicit and self-describing (`onSubmit`, not `handler`)
- [ ] Required props are documented; optional props have sensible defaults
- [ ] Boolean props default to `false` (opt-in, not opt-out)
- [ ] Avoid prop drilling more than two levels — use context or composition instead
- [ ] Never accept an entire object when only specific fields are needed

### Composability

- [ ] Prefer composition over configuration — accept `children` instead of rendering
      everything internally when the internal structure may vary
- [ ] Keep presentational components separate from data-fetching components
- [ ] Presentational components receive all data via props; no direct API calls or store
      subscriptions inside them

---

## 4. Layout and Spacing

Consistent spacing and hierarchy make interfaces readable and predictable.

### Spacing Scale

Use a base-8 spacing scale (or base-4 for tight UIs). Every margin, padding, and gap value
must be a multiple of the base unit:

| Token | Value |
|-------|-------|
| xs | 4px |
| sm | 8px |
| md | 16px |
| lg | 24px |
| xl | 32px |
| 2xl | 48px |
| 3xl | 64px |

- [ ] No arbitrary pixel values (e.g., `margin: 13px`) — use only scale values
- [ ] Spacing is consistent across similar components (all cards use the same padding)

### Visual Hierarchy

- [ ] Primary action is visually dominant; secondary and tertiary actions recede
- [ ] Related elements are grouped with proximity; unrelated elements are separated
- [ ] The user's eye should flow naturally to the most important element first

### Whitespace

- [ ] Do not compress whitespace to add more content — whitespace is a design element
- [ ] Sections have clear breathing room; elements do not feel cramped
- [ ] Increase whitespace between unrelated sections; decrease it between related items

---

## 5. Color and Theming

### CSS Custom Properties for Theming

- [ ] All color values are defined as CSS custom properties, not hardcoded hex values
- [ ] Custom properties use semantic names, not descriptive names:
      `--color-action` not `--color-blue`, `--color-danger` not `--color-red`
- [ ] Color tokens are defined at the `:root` level and overridden inside a
      `[data-theme="dark"]` selector (or equivalent) for dark mode

### Dark and Light Mode

- [ ] All components respect `prefers-color-scheme` media query by default
- [ ] A user-selectable theme toggle stores preference in `localStorage` and applies it
      via a `data-theme` attribute on `<html>` or `<body>`
- [ ] No hard-coded color values in component styles — all colors reference tokens
- [ ] Images and icons that do not adapt automatically are handled with CSS filters or
      separate dark-mode variants

### Semantic Color Naming

- [ ] `--color-text-primary`, `--color-text-secondary`, `--color-text-disabled`
- [ ] `--color-surface-base`, `--color-surface-raised`, `--color-surface-overlay`
- [ ] `--color-action`, `--color-action-hover`, `--color-action-pressed`
- [ ] `--color-danger`, `--color-warning`, `--color-success`, `--color-info`
- [ ] `--color-border`, `--color-border-strong`, `--color-border-focus`

---

## 6. Typography

### Font Stack

- [ ] Limit to two typefaces maximum: one for body, one for headings (optional)
- [ ] Define a system font stack as the fallback:
      `system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`
- [ ] Load web fonts asynchronously with `font-display: swap` to prevent invisible text

### Type Scale

Define and document the type scale before writing any font-size values:

| Role | Size | Line Height |
|------|------|-------------|
| display | 3rem | 1.1 |
| h1 | 2rem | 1.2 |
| h2 | 1.5rem | 1.2 |
| h3 | 1.25rem | 1.3 |
| body | 1rem | 1.6 |
| small | 0.875rem | 1.5 |
| caption | 0.75rem | 1.4 |

- [ ] No font sizes outside the defined scale
- [ ] Body text uses `1rem` base — never set body font size below `0.875rem` for
      readability

---

## 7. Forms

Forms are the primary mechanism for user input. Apply this checklist to every form.

### Labels and Structure

- [ ] Every input has a visible `<label>` element with a matching `for` attribute
- [ ] Never use `placeholder` as a substitute for a label — placeholder disappears on
      focus
- [ ] Group related fields with `<fieldset>` and `<legend>`
- [ ] Mark required fields visually and with `required` attribute on the input

### Validation and Error States

- [ ] Validate on blur (when the user leaves the field), not on every keystroke
- [ ] Show inline error messages directly below the field, not at the top of the page
- [ ] Error message text is specific: "Enter a valid email address" not "Invalid input"
- [ ] Error messages are linked to inputs via `aria-describedby`
- [ ] Successful validation shows a clear confirmation (checkmark, green border, message)
- [ ] On form submission failure, move focus to the first error field or to an error
      summary at the top of the form

### Loading and Success States

- [ ] The submit button shows a loading indicator during submission — disable it to
      prevent double submission
- [ ] Show a success message or navigate to the next step on completion
- [ ] Never clear the form without confirmation when clearing would lose significant data

---

## 8. Navigation

### Consistency

- [ ] Primary navigation is in the same position on every page
- [ ] Active state (current page/section) is visually distinct and communicated via
      `aria-current="page"` or `aria-current="true"`
- [ ] Navigation items are in a predictable and logical order

### Breadcrumbs

- [ ] Pages more than two levels deep have breadcrumb navigation
- [ ] Breadcrumb is a `<nav aria-label="Breadcrumb">` containing an `<ol>` of links
- [ ] The current page is the last breadcrumb item and is not a link

---

## 9. Performance

### Images

- [ ] Use modern formats: WebP with JPEG/PNG fallback, or `<picture>` with source sets
- [ ] Add `width` and `height` attributes on `<img>` elements to prevent layout shift
- [ ] Use `loading="lazy"` for images below the fold
- [ ] Use `loading="eager"` for the largest contentful paint (LCP) image above the fold
- [ ] Use `fetchpriority="high"` on the LCP image
- [ ] Provide descriptive `alt` text for informative images; use `alt=""` for decorative
      images

### Layout Stability (CLS)

- [ ] Reserve space for content that loads asynchronously (images, ads, embeds) using
      aspect-ratio boxes or skeleton placeholders
- [ ] Avoid inserting content above existing content after page load
- [ ] Set explicit sizes on web font containers to avoid font-swap layout shift

### Asset Optimization

- [ ] Inline critical CSS; defer non-critical stylesheets
- [ ] Tree-shake unused JavaScript — verify bundle size with a build tool report
- [ ] Use code splitting to load route-specific bundles on demand

---

## 10. Loading States

- [ ] Show skeleton screens (content-shaped placeholder elements) while data loads — not
      spinners alone
- [ ] Load the page shell immediately; hydrate content progressively as data arrives
- [ ] For actions (button clicks, form submissions): show an inline spinner or progress
      indicator within or adjacent to the trigger element
- [ ] Never block the entire page with a full-screen spinner for actions that do not
      require it

---

## 11. Error States

- [ ] Error messages use plain language: "Something went wrong. Try again." not
      "Error 500: Internal Server Error"
- [ ] Every error message includes a recovery action: a retry button, a link to support,
      or a suggested next step
- [ ] Never surface raw error objects, stack traces, or server error codes to users
- [ ] Empty states (no results, no data) are friendly and include a call to action

---

## UX Gate Before Shipping

Run through this gate before marking any frontend task complete:

- [ ] WCAG 2.1 AA accessibility checklist complete (semantic HTML, ARIA, keyboard, contrast)
- [ ] Component tested at 320px, 768px, and 1280px viewports
- [ ] All colors reference CSS custom properties — no hardcoded hex values in components
- [ ] All spacing values are from the defined scale — no arbitrary pixel values
- [ ] Every form field has a visible label
- [ ] Loading state present for any async action
- [ ] Error state present for any operation that can fail
- [ ] No `outline: none` without a visible custom focus indicator

If any item fails, fix it before proceeding. Accessibility and responsive issues caught
in code review cost significantly less than those caught by users.
