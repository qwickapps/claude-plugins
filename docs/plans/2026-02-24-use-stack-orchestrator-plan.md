# Use-Stack Orchestrator Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `use-stack` orchestrator skill and rename/deduplicate the 3 existing dev-guide skills.

**Architecture:** Orchestrator owns unified setup content. Individual skills keep per-package deep patterns. Skills renamed to match npm package names.

**Tech Stack:** Claude Code plugin skills (Markdown), no code changes.

---

### Task 1: Rename skill directories

**Files:**
- Rename: `plugins/qwickapps-dev-guide/skills/build-with-cms/` -> `plugins/qwickapps-dev-guide/skills/qwickapps-cms/`
- Rename: `plugins/qwickapps-dev-guide/skills/build-with-server/` -> `plugins/qwickapps-dev-guide/skills/qwickapps-server/`
- Rename: `plugins/qwickapps-dev-guide/skills/build-frontend-app/` -> `plugins/qwickapps-dev-guide/skills/qwickapps-react-framework/`

**Step 1: Rename directories using git mv**

```bash
cd plugins/qwickapps-dev-guide/skills
git mv build-with-cms qwickapps-cms
git mv build-with-server qwickapps-server
git mv build-frontend-app qwickapps-react-framework
```

**Step 2: Verify renames**

```bash
ls plugins/qwickapps-dev-guide/skills/
```

Expected: `qwickapps-cms/`, `qwickapps-server/`, `qwickapps-react-framework/`

**Step 3: Commit**

```bash
git add -A plugins/qwickapps-dev-guide/skills/
git commit -m "refactor(dev-guide): rename skills to match package names"
```

---

### Task 2: Create use-stack orchestrator SKILL.md

**Files:**
- Create: `plugins/qwickapps-dev-guide/skills/use-stack/SKILL.md`

**Step 1: Create directory**

```bash
mkdir -p plugins/qwickapps-dev-guide/skills/use-stack/references
```

**Step 2: Write SKILL.md**

The SKILL.md should contain:

```yaml
---
name: use-stack
description: >
  This skill should be used when the user asks to "set up a new project",
  "add CMS to my app", "configure the gateway", "what tech stack should I use",
  "use qwickapps", "start a new client", "integrate a package", or when deciding
  which stack components to use for a project. Routes to the correct stack-specific
  skills and provides unified setup for multi-component combinations.
---
```

Body sections:
1. Overview (what this skill does)
2. Available Stacks table (name, package, skill reference, description)
3. Common Combinations (Full Product, CMS App, API Service, Add to Existing)
4. Decision Tree (what to load based on user need)
5. New Project Setup Checklist (points to references/qwickapps-full-stack.md)
6. Existing Project Integration (which individual skill to reference)

Target: ~1500 words.

**Step 3: Commit**

```bash
git add plugins/qwickapps-dev-guide/skills/use-stack/SKILL.md
git commit -m "feat(dev-guide): add use-stack orchestrator skill"
```

---

### Task 3: Create unified setup reference

**Files:**
- Create: `plugins/qwickapps-dev-guide/skills/use-stack/references/qwickapps-full-stack.md`

**Step 1: Write the unified setup reference**

Content should include (single authoritative versions):
- Complete `.env.local` template with all vars from all 3 packages
- Complete `package.json` scripts (dev, dev:fast, dev:fresh, dev:local, start, build, migrate:promote)
- Complete `payload.config.ts` setup (postgresAdapter + port scheme + DEV_MIGRATION_DIR)
- Port scheme documentation (PORT -> Gateway, PORT+1 -> Control Panel, PORT+2 -> Next.js/Payload)
- `.gitignore` entries (.dev-migrations/)
- New client directory structure
- `gateway.ts` boilerplate that references correct ports
- `tsconfig.gateway.json` note

Source material:
- Port scheme: from build-with-server SKILL.md lines 19-44
- package.json scripts: from build-with-server SKILL.md lines 279-289 (more complete) + build-with-cms SKILL.md lines 358-367
- payload.config.ts: from build-with-cms SKILL.md lines 314-331
- .env vars: from build-with-server SKILL.md lines 34-41 + build-with-cms references to DATABASE_URI and DEV_MIGRATION_DIR
- .gitignore: from build-with-cms SKILL.md lines 370-374

**Step 2: Commit**

```bash
git add plugins/qwickapps-dev-guide/skills/use-stack/references/
git commit -m "feat(dev-guide): add unified setup reference for full QwickApps stack"
```

---

### Task 4: Deduplicate qwickapps-cms SKILL.md

**Files:**
- Modify: `plugins/qwickapps-dev-guide/skills/qwickapps-cms/SKILL.md`

**Step 1: Update frontmatter**

Change name from `build-with-cms` to `qwickapps-cms`. Update description to mention the package name `@qwickapps/cms` and add back-reference to `use-stack`.

**Step 2: Remove overlapping content**

Remove section 6 "Database Adapter and Migrations" (lines 306-391) which covers:
- payload.config.ts database setup (moved to qwickapps-full-stack.md)
- package.json scripts (moved to qwickapps-full-stack.md)
- .gitignore entry (moved to qwickapps-full-stack.md)
- "Setting Up a New Client Project" checklist (moved to qwickapps-full-stack.md)

**Step 3: Add migration workflow section (keep non-overlapping parts)**

Keep the qwickapps-migrate workflow explanation (what it does on `pnpm dev`, how to promote), common migration mistakes. These are CMS-specific knowledge, not setup.

**Step 4: Add back-reference at top**

Add after the frontmatter:
```
> **Setup:** For initial project setup (env, config, package.json scripts), start with the `use-stack` skill.
```

**Step 5: Renumber sections**

Adjust section numbers after removing section 6.

**Step 6: Commit**

```bash
git add plugins/qwickapps-dev-guide/skills/qwickapps-cms/SKILL.md
git commit -m "refactor(dev-guide): deduplicate qwickapps-cms, add back-reference to use-stack"
```

---

### Task 5: Deduplicate qwickapps-server SKILL.md

**Files:**
- Modify: `plugins/qwickapps-dev-guide/skills/qwickapps-server/SKILL.md`

**Step 1: Update frontmatter**

Change name from `build-with-server` to `qwickapps-server`. Update description.

**Step 2: Remove overlapping content**

- Remove section 1 "Port Scheme" .env.local template (lines 34-41) -- moved to unified setup
- Remove section 7 "package.json Scripts Pattern" (lines 277-293) -- moved to unified setup
- Keep port scheme explanation (conceptual, not the .env template)

**Step 3: Add back-reference at top**

Same pattern as Task 4.

**Step 4: Renumber sections**

**Step 5: Commit**

```bash
git add plugins/qwickapps-dev-guide/skills/qwickapps-server/SKILL.md
git commit -m "refactor(dev-guide): deduplicate qwickapps-server, add back-reference to use-stack"
```

---

### Task 6: Update qwickapps-react-framework SKILL.md

**Files:**
- Modify: `plugins/qwickapps-dev-guide/skills/qwickapps-react-framework/SKILL.md`

**Step 1: Update frontmatter**

Change name from `build-frontend-app` to `qwickapps-react-framework`. Update description to reference `@qwickapps/react-framework`.

**Step 2: Add back-reference at top**

Same pattern as Tasks 4-5.

**Step 3: No content removal needed**

This skill has no overlapping setup content. It is self-contained for frontend patterns.

**Step 4: Commit**

```bash
git add plugins/qwickapps-dev-guide/skills/qwickapps-react-framework/SKILL.md
git commit -m "refactor(dev-guide): rename build-frontend-app to qwickapps-react-framework"
```

---

### Task 7: Update plugin.json description

**Files:**
- Modify: `plugins/qwickapps-dev-guide/.claude-plugin/plugin.json`

**Step 1: Update description**

Update to mention the new skill names and the use-stack orchestrator.

**Step 2: Commit**

```bash
git add plugins/qwickapps-dev-guide/.claude-plugin/plugin.json
git commit -m "docs(dev-guide): update plugin.json description for renamed skills"
```

---

### Task 8: Update marketplace.json

**Files:**
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Update qwickapps-dev-guide entry**

Update the description to reflect the new skill names.

**Step 2: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "docs: update marketplace description for qwickapps-dev-guide"
```
