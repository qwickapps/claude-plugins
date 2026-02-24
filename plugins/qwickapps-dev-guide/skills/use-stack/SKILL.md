---
name: use-stack
description: >
  This skill should be used when the user asks to "set up a new project",
  "add CMS to my app", "configure the gateway", "what tech stack should I use",
  "use qwickapps", "start a new client", "integrate a package", or when deciding
  which stack components to use for a project. Routes to the correct stack-specific
  skills and provides unified setup for multi-component combinations.
---

# Tech Stack Selection and Setup

This skill is the entry point for selecting and configuring tech stack components in a QwickApps
project. It routes to per-package skills for deep patterns and provides unified setup for
multi-component combinations.

---

## Available Stacks

| Stack | Package | Skill | Description |
|-------|---------|-------|-------------|
| CMS | `@qwickapps/cms` | `qwickapps-cms` | Payload CMS integration: ServerQwickApp, BlockRenderer, collections, globals, seeds, migrations |
| Gateway | `@qwickapps/server` | `qwickapps-server` | Gateway layer: createGateway, proxy routing, control panel, built-in plugins, route guards |
| Framework | `@qwickapps/react-framework` | `qwickapps-react-framework` | App shell: QwickApp wrapper, navigation, theme CSS variables, component imports |

Additional stacks may be added in the future (e.g., `upstash-redis`, `supabase`, `auth0`).

---

## Common Stack Combinations

### Full Product (most common)

**Components:** CMS + Gateway + Framework

Use when building a complete QwickApps product with:
- Payload CMS for content management and admin
- Gateway proxy for unified routing and control panel
- React framework for the frontend app shell

**Setup:** Load `references/qwickapps-full-stack.md` for the unified configuration, then
reference all three per-package skills.

### CMS Application

**Components:** CMS + Framework (no gateway)

Use when building a standalone Payload CMS app with Next.js. No gateway proxy; Next.js
serves directly. Suitable for content sites and admin panels that do not need a gateway layer.

**Setup:** Follow the standard Next.js + Payload setup. Skip gateway.ts and port scheme.
Reference `qwickapps-cms` and `qwickapps-react-framework` skills.

### API Service

**Components:** Gateway only

Use when building a pure API gateway or proxy service with no CMS or frontend.
The gateway proxies to backend services and provides the control panel.

**Setup:** Reference `qwickapps-server` skill only. No Payload, no Next.js.

### Add CMS to Existing App

**Components:** CMS (added to existing project)

Use when integrating `@qwickapps/cms` into a project that already has a frontend and
possibly a gateway. Install the package, configure payload.config.ts, add collections.

**Setup:** Reference `qwickapps-cms` skill. Check `references/qwickapps-full-stack.md` for
the database adapter and migration configuration if not already present.

### Add Gateway to Existing App

**Components:** Gateway (added to existing project)

Use when adding a gateway layer to a project that already has a Next.js frontend.
Create gateway.ts, update package.json scripts to run both concurrently.

**Setup:** Reference `qwickapps-server` skill. Check `references/qwickapps-full-stack.md`
for the port scheme and script configuration.

---

## Decision Tree

To determine which stack components are needed:

1. **Is this a new project or adding to an existing one?**
   - New project: Likely "Full Product" unless the user specifies otherwise
   - Existing project: Identify which component is being added

2. **Does the project need content management (CMS, admin panel, collections)?**
   - Yes: Include CMS (`qwickapps-cms`)
   - No: Skip CMS

3. **Does the project need a gateway proxy (unified routing, control panel, monitoring)?**
   - Yes: Include Gateway (`qwickapps-server`)
   - No: Skip Gateway (Next.js serves directly)

4. **Does the project need a frontend app shell (navigation, theming, scaffolding)?**
   - Yes: Include Framework (`qwickapps-react-framework`)
   - No: Skip Framework (API-only service)

If uncertain, ask the user which components they need using the combinations table above.

---

## New Project Setup

For new projects, follow these steps:

1. **Determine the stack combination** using the decision tree above
2. **Read the unified setup reference** at `references/qwickapps-full-stack.md` for:
   - Complete `.env.local` template
   - Port scheme (PORT, PORT+1, PORT+2)
   - Complete `package.json` scripts
   - Complete `payload.config.ts` configuration
   - `.gitignore` entries
   - Directory structure
3. **Configure each component** by referencing the per-package skill:
   - CMS: `qwickapps-cms` for collections, globals, seeds, ServerQwickApp
   - Gateway: `qwickapps-server` for createGateway, apps config, control panel
   - Framework: `qwickapps-react-framework` for QwickApp wrapper, navigation, theming

The unified setup reference is the single authoritative source for configuration that spans
multiple packages. Individual skills provide per-package deep patterns but do not duplicate
the shared setup.

---

## Existing Project Integration

For existing projects, determine which component to add and reference its skill directly:

- **Adding CMS:** Read `qwickapps-cms` skill. If payload.config.ts does not exist yet,
  also check `references/qwickapps-full-stack.md` for database adapter setup.
- **Adding Gateway:** Read `qwickapps-server` skill. Also check
  `references/qwickapps-full-stack.md` for port scheme and script updates.
- **Adding Framework:** Read `qwickapps-react-framework` skill. No shared setup needed.

---

## UX Design

For UI components, layout patterns, and visual design, use the `qwickapps-ux-design` plugin's
`frontend-design` skill. That skill handles component selection, design system enforcement,
and `--theme-*` CSS variable usage. It complements the framework skill but focuses on
design rather than architecture.

---

## Additional Resources

### Reference Files

- **`references/qwickapps-full-stack.md`** -- Complete unified setup for the full QwickApps
  stack (env, config, scripts, port scheme, directory structure)

### Per-Package Skills

- **`qwickapps-cms`** -- Payload CMS deep patterns (ServerQwickApp, BlockRenderer, seeds)
- **`qwickapps-server`** -- Gateway deep patterns (createGateway, control panel, plugins)
- **`qwickapps-react-framework`** -- Frontend deep patterns (QwickApp, navigation, theme)
