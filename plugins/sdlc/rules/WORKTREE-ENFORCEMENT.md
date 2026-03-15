# Worktree Enforcement

**When to apply:** Before creating ANY branch for feature/bug work. ALWAYS.

---

## Core Principle

**Use worktrees for branch isolation.** Never work directly on protected branches.

Git worktrees create isolated workspaces that share the same repository. Each worktree has its own working directory and checked-out branch. This prevents accidental commits to protected branches and allows parallel work streams.

---

## SOP Configuration Variables

An SOP plugin (e.g., qwickapps-sop) may set these variables to customize worktree behavior:

| Variable | Purpose | Example |
|----------|---------|---------|
| `WORKTREE_ENFORCED` | Whether worktree creation is mandatory | `true` |
| `WORKTREE_SCRIPT` | Path to a project-specific worktree creation script | `.claude/scripts/create-worktree.sh` |
| `WORKTREE_PREFIX` | Directory prefix for worktree folders | `qwickapps-wt-` |
| `PROTECTED_BRANCHES` | Branches that must not be committed to directly | `main,dev` |
| `PACKAGE_MANAGER` | Package manager for dependency installation | `pnpm` |

If no SOP plugin sets these variables, generic defaults apply.

---

## Worktree Creation

### Path A: SOP Script Available

If `WORKTREE_ENFORCED` is true and `WORKTREE_SCRIPT` is set by an SOP plugin, use the script:

```bash
$WORKTREE_SCRIPT <name> [base-branch]
cd ../$WORKTREE_PREFIX<name>
```

The script handles project-specific setup: copying environment files, installing dependencies, configuring settings. Never bypass it with raw git commands.

### Path B: No SOP Plugin (Fallback)

If no SOP plugin is installed or `WORKTREE_SCRIPT` is not set, use the EnterWorktree Claude Code tool:

```
EnterWorktree(name: "<name>")
```

After entering the worktree, install dependencies manually based on detected lock files:

```bash
# Auto-detect and install
[ -f pnpm-lock.yaml ] && pnpm install
[ -f package-lock.json ] && npm install
[ -f yarn.lock ] && yarn install
[ -f requirements.txt ] && pip install -r requirements.txt
[ -f go.mod ] && go mod download
```

Note any environment files that may need manual copying.

---

## Mandatory Checklist

Before creating ANY branch or worktree:

- [ ] **STOP** - Do not create branch/worktree yet
- [ ] **CHECK** - Is a worktree script available via SOP config?
- [ ] **CREATE** - Use the script or EnterWorktree tool (never raw git commands)
- [ ] **VERIFY** - Confirm the worktree is complete (branch, deps, env)
- [ ] **SWITCH** - Change to the new worktree directory

---

## When to Create Worktrees

**Required for:**
1. New feature development
2. Bug fixes
3. Refactoring tasks
4. Experimental spikes
5. Any implementation plan execution

**Never work directly on protected branches.** Even small fixes get their own worktree.

---

## Verification

After creating the worktree, verify before starting work:

```bash
# 1. Confirm correct branch
git branch --show-current

# 2. Confirm dependencies installed
ls node_modules 2>/dev/null || ls vendor 2>/dev/null || echo "Check deps"

# 3. Confirm environment files present (project-specific)
# SOP plugins define what to check here
```

**If verification fails with SOP script:** Delete the worktree and re-run the script. Do not manually patch.

**If verification fails with EnterWorktree:** Report the gap to the user so they can decide how to proceed.

---

## Common Mistakes

### Using raw git commands when a script exists

**Problem:** `git worktree add` or `git checkout -b` skips project-specific setup (env files, deps, settings).

**Fix:** Always check for a worktree script first. Use it when available.

### Skipping verification

**Problem:** A broken environment discovered mid-implementation wastes time on debugging instead of feature work.

**Fix:** Run verification checks before starting any implementation.

### Manually fixing a broken worktree

**Problem:** Manually copying files after the fact is error-prone and inconsistent.

**Fix:** Delete the worktree and re-create it properly. The script (or tool) is authoritative.

### Working directly on protected branches

**Problem:** Direct commits to main/dev risk breaking CI and blocking other developers.

**Fix:** Always create a worktree first. The overhead is minimal compared to the risk.

---

## Quick Reference

| Situation | Action |
|-----------|--------|
| SOP script available | Run script, cd into worktree, verify |
| No SOP script | Use EnterWorktree tool, install deps, note gaps |
| Verification fails (script) | Delete worktree, re-run script |
| Verification fails (tool) | Report gap to user |
| Already created manually | Delete it, re-create properly |
