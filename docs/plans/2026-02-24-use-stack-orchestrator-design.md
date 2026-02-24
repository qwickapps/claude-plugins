# Use-Stack Orchestrator Design

## Problem

The `qwickapps-dev-guide` plugin has 3 separate skills (`build-with-cms`, `build-with-server`, `build-frontend-app`) that are almost always needed together when building a QwickApps product. This creates 5 issues:

1. Agents must invoke 1 skill at a time, losing context between invocations
2. Overlapping concerns create conflicts (package.json scripts, payload.config.ts, .env vars split across skills)
3. No single entry point for "set up a new project using QwickApps"
4. Users must know which skills to invoke and in what order
5. Individual skills give incomplete examples (server skill shows scripts without qwickapps-migrate, CMS skill shows scripts without gateway)

## Design

### Architecture

Add a `use-stack` orchestrator skill and rename the 3 existing skills to match their package names:

```
plugins/qwickapps-dev-guide/
  skills/
    use-stack/                         # NEW: Orchestrator
      SKILL.md                         # Stack decision tree + routing
      references/
        qwickapps-full-stack.md        # Unified setup for CMS + Server + Framework
    qwickapps-cms/                     # RENAMED from build-with-cms
      SKILL.md                         # Payload CMS patterns (deduplicated)
    qwickapps-server/                  # RENAMED from build-with-server
      SKILL.md                         # Gateway patterns (deduplicated)
    qwickapps-react-framework/         # RENAMED from build-frontend-app
      SKILL.md                         # App shell + theme patterns (deduplicated)
```

### Naming Rationale

- `use-stack`: Generic verb that works for new and existing projects. "Use" avoids confusion with "build" (compile). Extensible to future third-party stacks.
- Individual skills named after actual npm packages: `@qwickapps/cms` -> `qwickapps-cms`, `@qwickapps/server` -> `qwickapps-server`, `@qwickapps/react-framework` -> `qwickapps-react-framework`.
- Future stacks drop in naturally: `upstash-redis/`, `supabase/`, `auth0/`.

### use-stack SKILL.md

Triggers on: "set up a new project", "add CMS to my app", "configure the gateway", "what tech stack should I use", "use qwickapps", "start a new client", or when deciding which stack components to integrate.

Body contains:
1. **Available Stacks** -- Table of registered stacks with package names and skill references
2. **Stack Combinations** -- Common presets (Full Product, CMS-only, API-only, Add CMS, Add Gateway)
3. **Decision Tree** -- Routing logic based on what user is building
4. **Unified Setup** -- Points to `references/qwickapps-full-stack.md`
5. **Per-Stack Reference** -- Points to individual stack skills for deep patterns

### references/qwickapps-full-stack.md

Single authoritative source for all setup that spans multiple packages:
- Complete `.env.local` template (all vars from all 3 packages)
- Complete `package.json` scripts (dev, build, start, migrate)
- Complete `payload.config.ts` (DB adapter + port scheme + migration dir)
- `.gitignore` entries
- Directory structure for a new client
- Port scheme documentation (PORT, PORT+1, PORT+2)

### Changes to Existing Skills

**Content moved OUT (to qwickapps-full-stack.md):**
- `build-with-cms` section 6 "Database Adapter and Migrations" (payload.config.ts setup, package.json scripts, .gitignore) -- 72 lines
- `build-with-server` section 1 "Port Scheme" (.env.local template) -- 15 lines
- `build-with-server` section 7 "package.json Scripts Pattern" -- 14 lines

**Content kept IN each skill:**
- `qwickapps-cms`: ServerQwickApp, BlockRenderer, FooterFromSettings, collections table, globals table, seed patterns, migration workflow (what qwickapps-migrate does, how to promote), common mistakes
- `qwickapps-server`: createGateway full interface, apps[] config, controlPanel config, built-in plugins table, gateway.ts example, WebSocket proxy, route guards, common mistakes
- `qwickapps-react-framework`: QwickApp props, MenuItem format, app shell patterns (marketing + dashboard), app bar customization, theme CSS variables, component imports, useQwickApp hook, Next.js integration, common mistakes

**Added to each skill:**
- Back-reference at top: "For initial project setup (env, config, scripts), start with `use-stack`."
- Updated frontmatter name and description

### Extensibility

Future stacks add a new skill directory:

```
skills/
  upstash-redis/
    SKILL.md       # Redis patterns, caching strategies
  supabase/
    SKILL.md       # Auth, storage, realtime patterns
```

The `use-stack` orchestrator's "Available Stacks" table gets a new row. The `references/` directory can add new combo files (e.g., `qwickapps-with-supabase.md`).

### What This Solves

1. Single entry point: `use-stack` triggers on broad "set up" queries
2. No overlaps: One authoritative package.json, payload.config.ts, .env
3. Modular maintenance: Each package's patterns live in its own skill
4. Existing projects: Individual skills still work for "I just need to add a gateway"
5. Future-proof: New stacks drop in without restructuring
