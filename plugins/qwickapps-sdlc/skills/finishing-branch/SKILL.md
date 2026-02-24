---
name: finishing-branch
description: This skill should be used when implementation work on a branch is complete and a decision is needed on how to integrate the work. Trigger phrases include "finish this branch", "wrap up this work", "merge this branch", "create a PR", "open a pull request", or "what do I do with this branch now".
---

# Finishing a Branch

## Overview

Guide the completion of development work by verifying quality, presenting integration options, and executing the chosen path cleanly.

**Core principle:** Verify quality first. Present structured options. Execute the chosen path. Clean up.

**Announce at start:** "I'm using the finishing-branch skill to complete this work."

---

## Step 1: Run Quality Verification

Before presenting any options, verify the work is actually complete. Do not offer integration paths for broken work.

### Run verifying-completion

**REQUIRED SUB-SKILL:** Invoke `qwickapps-sdlc:verifying-completion` to run the full quality gate.

This skill runs:
- Build verification (TypeScript compilation, production build)
- Full test suite
- Lint checks
- Any project-specific validation

**If verifying-completion reports failures:**

```
Build/tests failing. Cannot proceed with integration until these pass:

[Show specific failures from verifying-completion output]

Fix the failures and re-run this skill.
```

Stop. Do not present integration options until all gates pass.

**If verifying-completion passes:** Continue to Step 2.

---

## Step 2: Gather Branch Context

Collect the information needed to present options accurately.

```bash
# Current branch name
git branch --show-current

# Base branch (where this branch diverged from)
git merge-base HEAD main 2>/dev/null && echo "base: main" || \
git merge-base HEAD dev 2>/dev/null && echo "base: dev"

# Commits on this branch (not yet in base)
git log --oneline $(git merge-base HEAD main 2>/dev/null || git merge-base HEAD dev)..HEAD

# Check if branch is already pushed
git status -sb | head -1

# Confirm worktree path if applicable
git worktree list | grep $(git branch --show-current)
```

Identify:
- Branch name (e.g., `feature-auth`)
- Base branch (e.g., `main` or `dev`)
- Number of commits
- Whether branch is already pushed to remote
- Worktree path (if in a worktree)

---

## Step 3: Present Integration Options

Present exactly these four options. Keep the presentation concise. Do not add explanatory paragraphs.

```
Implementation complete. All checks pass.

Branch: <branch-name>
Base: <base-branch>
Commits: <N> commits

What would you like to do?

1. Merge to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is for more work
4. Discard this branch

Which option?
```

Wait for the user's response before proceeding.

---

## Step 4: Execute the Chosen Option

### Option 1: Merge Locally

```bash
# Switch to base branch
git checkout <base-branch>

# Pull latest remote changes
git pull

# Merge the feature branch (no fast-forward for clear history)
git merge --no-ff <feature-branch> -m "Merge <feature-branch> into <base-branch>"
```

After merging, run the test suite once more on the merged result:

```bash
# Run project test command
pnpm test
# or: npm test
```

**If tests pass on merged result:**

```bash
# Delete the feature branch
git branch -d <feature-branch>
```

Report: "Merged <feature-branch> into <base-branch>. Tests passing. Branch deleted."

Then proceed to Step 5 (worktree cleanup).

**If tests fail on merged result:**

```
Merge conflicts or regressions detected after merge. Tests failing:

[Show failures]

Options:
1. Abort the merge and keep the branch for fixes
2. Fix the failures now on <base-branch>
```

Wait for user decision before proceeding.

### Option 2: Push and Create a Pull Request

```bash
# Push branch to remote, setting upstream
git push -u origin <feature-branch>
```

Create the PR using the gh CLI:

```bash
gh pr create \
  --title "<Concise title describing the change>" \
  --body "$(cat <<'EOF'
## Summary
- <What was changed and why - bullet 1>
- <What was changed and why - bullet 2>
- <What was changed and why - bullet 3>

## Test Plan
- [ ] Build passes (verified locally)
- [ ] All tests pass (verified locally)
- [ ] <Specific thing to verify in review>
- [ ] <Another specific verification step>
EOF
)"
```

**PR title guidelines:**
- Under 70 characters
- Start with a verb: "Add", "Fix", "Update", "Remove", "Refactor"
- Describe the change, not the implementation detail

**PR body guidelines:**
- Summary bullets describe what changed and why, not how
- Test plan items are concrete and checkable
- Do not include implementation details that belong in commit messages

Report the PR URL once created.

Do not clean up the worktree. The PR may require follow-up changes and the worktree should remain available.

### Option 3: Keep Branch for More Work

Report the current state and stop:

```
Keeping branch <feature-branch>. Worktree preserved at <path>.
Run /finishing-branch again when ready to integrate.
```

Do not clean up the worktree. Do not delete the branch. This option ends the skill execution.

### Option 4: Discard the Branch

This option permanently deletes commits. Require explicit confirmation before proceeding.

Present what will be deleted:

```
This will permanently delete:
- Branch: <feature-branch>
- Commits:
  <list each commit: hash + message>
- Worktree at: <path> (if applicable)

This cannot be undone.

Type "discard" to confirm.
```

Wait for the exact word "discard" typed by the user. Do not accept "yes", "ok", "confirm", or anything else.

**If confirmed with "discard":**

```bash
# If in a worktree, switch out first
git checkout <base-branch>

# Force delete the branch
git branch -D <feature-branch>
```

Then proceed to Step 5 (worktree cleanup).

**If not confirmed:** Report "Discarded cancelled. Branch preserved." and stop.

---

## Step 5: Clean Up the Worktree

Applies to Options 1, 2, and 4 only. Do not clean up for Option 3.

### Check if work was done in a worktree

```bash
git worktree list
```

If the feature branch appears in the worktree list, the worktree must be removed.

### Remove the worktree

```bash
# Navigate out of the worktree first if currently inside it
cd <main-repo-path>

# Remove the worktree
git worktree remove <worktree-path>
```

**If git worktree remove fails** because the branch still has local changes:

```bash
# Force remove (only after confirming branch is merged or discarded)
git worktree remove --force <worktree-path>
```

After removal, confirm:

```bash
git worktree list
```

The removed worktree should no longer appear.

Report: "Worktree at <path> removed."

---

## Integration Path Summary

| Option | Tests on merged result | Push | PR created | Worktree cleaned |
|--------|----------------------|------|------------|-----------------|
| 1. Merge locally | Yes | No | No | Yes |
| 2. Create PR | No (on base) | Yes | Yes | No |
| 3. Keep as-is | No | No | No | No |
| 4. Discard | No | No | No | Yes |

---

## Common Mistakes

### Presenting options before verification passes

**Problem:** Creating a PR or merging broken work forces the reviewer or CI pipeline to catch failures that should have been caught locally.

**Correct approach:** Always run verifying-completion first. Only present options after all gates pass.

### Auto-removing worktree for Option 2

**Problem:** The PR is open and may need further changes. The worktree is still needed.

**Correct approach:** Remove the worktree only for Options 1 and 4 (where the branch is merged or deleted). For Option 2, preserve the worktree in case follow-up work is needed.

### Accepting loose confirmation for discard

**Problem:** "Yes" or "Sure" can be typed accidentally. Branch deletion is irreversible.

**Correct approach:** Require the exact word "discard". Nothing else is accepted.

### Merging without pulling latest base

**Problem:** The base branch may have advanced since the feature branch was created. Merging without pulling creates unnecessary conflicts or misses integration issues.

**Correct approach:** Always `git pull` on the base branch before merging.

### Skipping post-merge test run

**Problem:** Merge conflicts can be resolved incorrectly in ways that introduce bugs not present on either branch alone.

**Correct approach:** Run the test suite after merging, on the merged result, before deleting the feature branch.

---

## Red Flags

Never:
- Present integration options when tests or build are failing
- Remove worktree for Options 2 or 3 (the branch may need more work)
- Accept anything other than "discard" as confirmation for Option 4
- Merge without running tests on the merged result
- Force-push to main or dev without explicit user request

Always:
- Run verifying-completion before presenting options
- Show exactly what commits will be deleted before discard
- Clean up worktrees for Options 1 and 4 only
- Report the PR URL after creation

---

## Integration

**Called by:**
- **executing-plans** - After all implementation tasks complete
- **brainstorming** - After implementation concludes following an approved design

**Pairs with:**
- **creating-worktree** - Creates the worktree that this skill cleans up
- **verifying-completion** - REQUIRED sub-skill called in Step 1
