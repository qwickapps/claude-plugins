---
name: creating-worktree
description: This skill should be used when starting any feature, bug fix, refactor, or spike work that requires an isolated git workspace. Trigger phrases include "create a worktree", "set up a worktree", "start a new branch", "isolate this work", or before executing any implementation plan.
---

# Creating a Worktree

## Overview

Git worktrees create isolated workspaces that share the same repository. Each worktree has its own working directory, checked-out branch, and environment. Using worktrees prevents accidental commits to protected branches and supports parallel work streams.

**Announce at start:** "I'm using the creating-worktree skill to set up an isolated workspace."

**Reference:** See WORKTREE-ENFORCEMENT.md for the enforcement rule this skill implements.

---

## Step 1: Check for SOP-Configured Worktree Script

Before doing anything else, check whether an SOP plugin has configured a worktree script.

Look for these SOP variables:
- `WORKTREE_ENFORCED` - Whether worktree creation is mandatory
- `WORKTREE_SCRIPT` - Path to a project-specific creation script
- `WORKTREE_PREFIX` - Directory prefix for worktree folders

Also search for a script in the project:

```bash
find . -name "create-worktree.sh" -type f | head -5
```

**Decision point:**

| Result | Next step |
|--------|-----------|
| `WORKTREE_SCRIPT` is set or script found | Proceed to Step 2a (use the script) |
| No script available | Proceed to Step 2b (EnterWorktree fallback) |

---

## Step 2a: Use the Project Script (Primary Path)

When a worktree script is available, use it exclusively. Never substitute raw git commands.

### Run the script

```bash
# Using SOP-configured script path
$WORKTREE_SCRIPT <name> [base-branch]

# Or using discovered script path
./path/to/create-worktree.sh <name> [base-branch]
```

### Change into the worktree

```bash
# If WORKTREE_PREFIX is set
cd ../$WORKTREE_PREFIX<name>

# Otherwise check git worktree list for the path
git worktree list
```

Confirm the working directory changed before proceeding.

---

## Step 2b: EnterWorktree Fallback (No Script Found)

Use this path only when no worktree script exists in the project.

Use the EnterWorktree tool built into Claude Code:

```
EnterWorktree(name: "<name>")
```

This creates an isolated git worktree and switches the session into it.

### Install dependencies

Auto-detect the package manager and install dependencies:

```bash
# Node.js (check in priority order)
if [ -f pnpm-lock.yaml ]; then
    pnpm install
elif [ -f yarn.lock ]; then
    yarn install
elif [ -f package-lock.json ]; then
    npm install
elif [ -f package.json ]; then
    npm install
fi

# Python
if [ -f requirements.txt ]; then
    pip install -r requirements.txt
elif [ -f pyproject.toml ]; then
    poetry install 2>/dev/null || pip install -e .
fi

# Go
if [ -f go.mod ]; then
    go mod download
fi
```

Note any environment files that may need manual copying. Document this gap so the user knows their environment may be incomplete.

---

## Step 3: Verify the Worktree

After creation by either path, verify the environment is complete before doing any work.

### Verification checklist

```bash
# 1. Confirm on the correct branch
git branch --show-current

# 2. Confirm dependencies are installed
ls node_modules 2>/dev/null || ls vendor 2>/dev/null || echo "Check deps directory"

# 3. Confirm environment files (project-specific)
# SOP plugins define what to check; without SOP, check for common patterns:
ls .env* 2>/dev/null
```

**If any check fails with the script path:** Stop. Report which check failed. Do not attempt to fix manually. Delete the worktree and re-run the script.

```bash
# Get worktree path from git
git worktree list

# Remove and recreate
cd <original-repo-path>
git worktree remove <worktree-path>
git branch -D <name>
$WORKTREE_SCRIPT <name>
```

**If any check fails with the EnterWorktree path:** Report the gap explicitly so the user can decide how to proceed.

---

## Step 4: Report Ready State

After successful verification, report the worktree location and state:

```
Worktree ready at <full-path>
Branch: <branch-name>
Dependencies: installed
Ready to implement <task-name>
```

If using the EnterWorktree fallback, note any gaps:

```
Worktree ready at <full-path>
Branch: <branch-name>
Note: No project worktree script found. Environment files were not automatically copied.
Manual action required: Check for .env files or other config that needs copying from the main worktree.
```

---

## Common Mistakes

### Using git commands directly when a script exists

**Problem:** `git worktree add` creates the worktree but does not run project-specific setup (env files, settings, dependency installation). The environment is broken before any work begins.

**Correct approach:** Always check for a worktree script first. Fall back to EnterWorktree only when no script exists.

### Skipping verification

**Problem:** Proceeding without verification means discovering a broken environment mid-implementation, requiring costly context switching to debug.

**Correct approach:** Run all verification checks before starting any implementation work.

### Attempting to manually fix a broken worktree

**Problem:** Manually copying files or running installs after the fact is error-prone and produces inconsistent results.

**Correct approach:** Delete the worktree and re-create it. The script or tool is authoritative.

---

## Quick Reference

| Situation | Action |
|-----------|--------|
| SOP script available | Run script, cd into worktree, verify |
| No script available | Use EnterWorktree tool, install deps, note gaps |
| Script verification fails | Delete worktree, re-run script |
| Tool verification fails | Report gap to user |
| Already created manually | Delete it, re-create properly |

---

## Naming Conventions

Use descriptive, kebab-case names that match the work being done:

```
feature-auth           # New feature
bug-917                # Bug fix (use issue number)
spike-payments         # Investigation spike
refactor-api-client    # Refactoring task
```

---

## When to Create a Worktree

Worktree creation is required before starting:

- New feature development
- Bug fixes
- Refactoring tasks
- Investigation spikes
- Any implementation plan execution

Never implement directly on protected branches. The overhead of creating a worktree is minimal compared to the risk of accidental commits.

---

## Integration

**Called by:**
- **executing-plans** - REQUIRED before executing any implementation plan
- **writing-plans** - REQUIRED after plan approval when implementation follows immediately
- **brainstorming** - REQUIRED when design is approved and implementation is next

**Pairs with:**
- **finishing-branch** - Use to complete and integrate work done in this worktree
- **WORKTREE-ENFORCEMENT.md** - The enforcement rule this skill implements
