---
name: creating-worktree
description: This skill should be used when starting any feature, bug fix, refactor, or spike work that requires an isolated git workspace. Trigger phrases include "create a worktree", "set up a worktree", "start a new branch", "isolate this work", or before executing any implementation plan in qwickapps.
---

# Creating a Worktree

## Overview

Git worktrees create isolated workspaces that share the same repository. Each worktree has its own working directory, checked-out branch, and environment. In qwickapps projects, worktrees also require environment files and installed dependencies that raw git commands do not copy.

**Core principle:** Always use the project's create-worktree.sh script when one exists. Never use `git worktree add` or `git checkout -b` directly.

**Announce at start:** "I'm using the creating-worktree skill to set up an isolated workspace."

**Reference:** See WORKTREE-ENFORCEMENT.md for the full enforcement rule that this skill implements.

---

## Step 1: Search for the Project Script

Before doing anything else, search for the create-worktree.sh script.

```bash
# Search from the current directory upward
find . -name "create-worktree.sh" -type f | head -5

# Also check known locations
ls .claude/scripts/create-worktree.sh 2>/dev/null
ls ../.claude/scripts/create-worktree.sh 2>/dev/null
```

**Decision point:**

| Result | Next step |
|--------|-----------|
| Script found | Proceed to Step 2 (use the script) |
| Script not found | Proceed to Step 3 (EnterWorktree fallback) |

---

## Step 2: Use the create-worktree.sh Script (Primary Path)

When the script is found, use it exclusively. Never substitute git commands.

### Why the script is mandatory

The script does work that git commands cannot replicate automatically:

1. Creates the worktree at `../qwickapps-wt-<name>`
2. Copies ALL `.env` files from every client and package, preserving directory structure
3. Copies `.claude/settings.local.json` (personal Claude Code permissions)
4. Runs `pnpm install` to install dependencies

Skipping the script produces a broken environment: missing environment variables, wrong permissions, missing node_modules. Debugging these failures takes far longer than running the script.

### Run the script

```bash
# Basic usage: new branch from current HEAD
.claude/scripts/create-worktree.sh <worktree-name>

# Examples
.claude/scripts/create-worktree.sh feature-auth
.claude/scripts/create-worktree.sh bug-917
.claude/scripts/create-worktree.sh spike-payments

# With existing branch name as second argument
.claude/scripts/create-worktree.sh my-feature dev
```

The script creates the worktree at `../qwickapps-wt-<worktree-name>` relative to the repo root.

### Change into the worktree

```bash
cd ../qwickapps-wt-<worktree-name>
```

Confirm the working directory changed before proceeding.

---

## Step 3: EnterWorktree Fallback (No Script Found)

Use this path only when no create-worktree.sh script exists in the project.

Use the EnterWorktree tool built into Claude Code:

```
EnterWorktree(name: "<worktree-name>")
```

This creates an isolated git worktree and switches the session into it. Run dependency installation manually after:

```bash
# Node.js projects
if [ -f package.json ]; then npm install; fi
if [ -f pnpm-lock.yaml ]; then pnpm install; fi

# Python projects
if [ -f requirements.txt ]; then pip install -r requirements.txt; fi
if [ -f pyproject.toml ]; then poetry install; fi
```

Note any environment files that need manual copying. Document this gap so the user knows their environment may be incomplete.

---

## Step 4: Verify the Worktree

After creation by either path, verify the environment is complete before doing any work.

### Verification checklist

```bash
# 1. Confirm on the correct branch
git branch --show-current

# 2. Confirm .env files were copied (qwickapps projects)
ls clients/*/client/.env* 2>/dev/null
ls clients/*/control-panel/.env* 2>/dev/null

# 3. Confirm personal settings were copied (qwickapps projects)
ls .claude/settings.local.json 2>/dev/null

# 4. Confirm dependencies are installed
ls node_modules 2>/dev/null | head -3
```

**If any check fails with the script path:** Stop. Report which check failed. Do not attempt to fix manually. Delete the worktree and re-run the script.

```bash
# Delete and recreate if something is wrong
git worktree remove ../qwickapps-wt-<name>
git branch -D <name>
.claude/scripts/create-worktree.sh <name>
```

**If any check fails with the EnterWorktree path:** Report the gap explicitly so the user can decide how to proceed.

---

## Step 5: Report Ready State

After successful verification, report the worktree location and state:

```
Worktree ready at <full-path>
Branch: <branch-name>
Environment files: copied
Dependencies: installed
Ready to implement <task-name>
```

If using the EnterWorktree fallback, note any gaps:

```
Worktree ready at <full-path>
Branch: <branch-name>
Note: No create-worktree.sh script found. Environment files were not automatically copied.
Manual action required: Copy .env files before running the application.
```

---

## Common Mistakes

### Using git commands directly

**Problem:** `git worktree add` creates the worktree but does not copy .env files, settings, or run pnpm install. The environment is broken before any work begins.

**Correct approach:** Always search for and use create-worktree.sh first. Fall back to EnterWorktree only when no script exists.

### Skipping verification

**Problem:** Proceeding without verification means discovering broken environment mid-implementation, requiring costly context switching to debug.

**Correct approach:** Run all four verification checks before starting any implementation work.

### Attempting to manually fix a broken worktree

**Problem:** Manually copying files or running installs after the fact is error-prone and produces inconsistent results.

**Correct approach:** Delete the worktree and re-run the script. The script is authoritative.

### Assuming the script location

**Problem:** Hard-coding `.claude/scripts/create-worktree.sh` fails if the script is at a different path.

**Correct approach:** Always search with `find . -name "create-worktree.sh"` before assuming the path.

---

## Quick Reference

| Situation | Action |
|-----------|--------|
| Script found | Run script, cd into worktree, verify |
| Script not found | Use EnterWorktree tool, note gaps |
| Script found but verification fails | Delete worktree, re-run script |
| Already created worktree manually | Delete it, re-create with script |
| Unsure of worktree name convention | Check existing worktrees with `git worktree list` |

---

## Naming Conventions

Use descriptive, kebab-case names that match the work being done:

```
feature-auth           # New feature
bug-917                # Bug fix (use issue number)
spike-payments         # Investigation spike
refactor-api-client    # Refactoring task
```

The script creates the worktree directory at `../qwickapps-wt-<name>`, placing it as a sibling to the main repo.

---

## When to Create a Worktree

Worktree creation is required before starting:

- New feature development
- Bug fixes
- Refactoring tasks
- Investigation spikes
- Any implementation plan execution

Never implement directly on `main` or `dev`. Even small fixes get their own worktree. The overhead is under 60 seconds with the script. The cost of debugging a broken environment or an accidental direct commit to main is far higher.

---

## Integration

**Called by:**
- **executing-plans** - REQUIRED before executing any implementation plan
- **writing-plans** - REQUIRED after plan approval when implementation follows immediately
- **brainstorming** - REQUIRED when design is approved and implementation is next

**Pairs with:**
- **finishing-branch** - Use to complete and integrate work done in this worktree
- **WORKTREE-ENFORCEMENT.md** - The enforcement rule this skill implements
