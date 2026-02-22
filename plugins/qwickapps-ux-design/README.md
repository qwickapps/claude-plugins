# qwickapps-ux-design

Claude plugin for QwickApps frontend development. Enforces design system consistency while preserving full creative freedom.

## What it does

- **frontend-design** skill: QwickApps-aware replacement for the official frontend-design skill. Same creative freedom — all implementation goes through `@qwickapps/react-framework`.
- **find-component** skill: Look up the right framework component for any UI need before writing JSX.
- **extend-framework** skill: Guided workflow for adding missing components or palettes to the framework before using them.
- **enforce-framework-usage hook**: Blocks MUI imports, hardcoded colors, and inline styles before they land in any file.

## Rules

1. Use ONLY `@qwickapps/react-framework` components — no raw MUI, no bare HTML elements with styles
2. Use ONLY `--theme-*` CSS variables for colors — no hex, no rgba
3. If a component is missing: invoke `extend-framework` skill to add it first, then use it
4. Creative direction is unrestricted — bold, minimal, editorial, brutalist, all valid

## Install

```
/plugins install qwickapps-ux-design
```
