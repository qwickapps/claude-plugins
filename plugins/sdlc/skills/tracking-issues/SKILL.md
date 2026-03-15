---
name: tracking-issues
description: >
  This skill should be used at the start of every piece of work and whenever managing GitHub
  issues in any command workflow. Trigger phrases include: "start a feature", "fix a bug",
  "work on a task", "I need to track this", "create an issue", "close the issue", "what issue
  is this", "link this to an issue", "reference the issue in my commit". Auto-loads at the
  beginning of every command workflow. Every piece of work starts with an issue and ends by
  closing it. Do not begin implementation without an issue number.
---

# Tracking Issues

Every piece of work begins with a GitHub issue. Every piece of work ends by closing it. The issue
is the unit of work: it links the intent to the commit, the commit to the PR, and the PR to the
resolution.

**Core principle:** Work without an issue is work without context, history, or closure.

---

## The Issue-First Law

Before writing a single line of code or starting any investigation:

1. Check whether an issue already exists for this work.
2. If yes, use that issue.
3. If no, ask permission to create one, then create it.

Never begin implementation without an issue number. The issue number belongs in every commit
message, every context entry, and every PR description.

---

## Step 1: Check for an Existing Issue

Before creating a new issue, search for one that already tracks this work.

```bash
# List open issues with relevant label
gh issue list --label feature --state open
gh issue list --label bug --state open
gh issue list --state open --search "keyword"

# View a specific issue
gh issue view 42
```

If an issue is found that matches the work, use it. Do not create a duplicate. Verify the issue
scope matches the planned work before proceeding.

If no matching issue is found, proceed to Step 2.

---

## Step 2: Ask Permission to Create an Issue

Creating an issue is a write operation on the repository. Ask the user before creating one.

Present the proposed issue to the user:

- Title: one sentence describing what this issue tracks
- Body: context, acceptance criteria, and any relevant links
- Label: the label appropriate for this type of work (see Label Reference below)

Wait for explicit confirmation before proceeding with `gh issue create`.

**Do not create issues silently.** Even when the work is unambiguous, confirm the issue title
and label before creating.

---

## Step 3: Create the Issue via gh CLI

Once permission is granted, create the issue using the gh CLI.

```bash
# Feature work
gh issue create \
  --title "Add user authentication flow" \
  --body "Implement login, logout, and session management for the web app.

## Acceptance criteria
- User can log in with email and password
- Session persists across page refreshes
- User can log out from any page
- Invalid credentials show a clear error message" \
  --label feature

# Bug fix
gh issue create \
  --title "Fix: cart total does not update when item quantity changes" \
  --body "## Bug description
When the user changes item quantity in the cart, the total displayed on screen
does not update until the page is refreshed.

## Steps to reproduce
1. Add an item to cart
2. Change the quantity using the +/- buttons
3. Observe the total does not change

## Expected behavior
Total updates immediately after quantity change." \
  --label bug

# Research / spike
gh issue create \
  --title "Research: evaluate options for background job processing" \
  --body "We need to choose a background job library before implementing email notifications.
Evaluate BullMQ, pg-boss, and inngest. Document findings and recommendation." \
  --label research

# Refactor
gh issue create \
  --title "Refactor: extract payment logic into dedicated service" \
  --body "The checkout route handler is handling payment processing, order creation,
and inventory update directly. Extract each concern into a dedicated service." \
  --label refactor

# Maintenance
gh issue create \
  --title "Chore: update all dependencies to latest minor versions" \
  --body "Run pnpm update across all workspaces and verify no breaking changes." \
  --label chore
```

After creation, note the issue number from the output. Every subsequent action references this
number.

---

## Label Reference

| Command type | Label |
|-------------|-------|
| /feature | `feature` |
| /bug | `bug` |
| /research | `research` |
| /refactor | `refactor` |
| /chore | `chore` |

Use the label that matches the command type. Do not mix labels within a single issue.

---

## Step 4: Store Issue Context

After the issue is created, store the working context. This context persists across
sessions and is available when resuming work.

Store the working context using `CTX_STORE_ISSUE`:
- key: "issue-42-context" (following CTX_ISSUE_KEY_FORMAT)
- content: [the context entry below]

If no SOP plugin is configured, save context to `.claude/issue-context/issue-42.md` in the repository.

```
Issue: #42 - Add user authentication flow
Label: feature
Branch: feature/auth-flow (if created)
Approach: JWT-based auth with refresh tokens
Key files:
  - src/routes/auth.ts (new)
  - src/middleware/authenticate.ts (new)
  - src/services/session.ts (new)
Dependencies: jsonwebtoken, bcrypt
Notes: Admin pages require role-based guard. See ADR-007 for auth decisions.
Status: In progress
```

Include in the context entry:

- Issue number and title
- Label and associated command type
- Branch name once created
- Planned approach (high level)
- Key files to create or modify
- Relevant dependencies
- Any design decisions or constraints discovered

Update the context entry as the investigation evolves. Do not let it go stale.

---

## Step 5: Update Context During Investigation

As work progresses, update the context entry with findings and decisions.

Update the working context using `CTX_STORE_ISSUE`:
- key: "issue-42-context" (following CTX_ISSUE_KEY_FORMAT)
- content: [the updated context entry below]

If no SOP plugin is configured, update `.claude/issue-context/issue-42.md` in the repository.

```
Issue: #42 - Add user authentication flow
Label: feature
Branch: feature/auth-flow
Approach: JWT-based auth with refresh tokens. Decided against sessions after
          researching existing auth patterns in src/middleware/. See issue
          comments for full rationale.
Key findings:
  - Existing middleware at src/middleware/cors.ts:12 shows pattern for request
    interceptors. Auth middleware should follow the same export shape.
  - bcrypt is already in package.json:45. No new dependency needed for hashing.
  - Token expiry: 15 min access, 7 day refresh (matches industry standard).
Key files modified:
  - src/routes/auth.ts (created, login/logout handlers)
  - src/middleware/authenticate.ts (created, JWT verification)
  - src/services/session.ts (created, token issuance and refresh)
Status: Implementation complete, tests passing. Ready for review.
```

To retrieve context when resuming work, use `CTX_GET_ISSUE`:
- key: "issue-42-context"

If no SOP plugin is configured, read `.claude/issue-context/issue-42.md` from the repository.

---

## Step 6: Reference the Issue in Commits

Every commit message must reference the issue number. This links the commit to the intent and
enables automatic tracking in GitHub.

**Closing commit (fixes the issue):**

```
feat(auth): implement JWT-based authentication flow

Fixes #42

- Add login and logout handlers in src/routes/auth.ts
- Add JWT verification middleware in src/middleware/authenticate.ts
- Add token issuance and refresh in src/services/session.ts
- Add refresh token rotation on use
```

**Intermediate commit (part of the issue, not closing it):**

```
feat(auth): add session service with token issuance

Part of #42

Implements token generation and refresh rotation logic.
Access tokens expire in 15 minutes. Refresh tokens expire in 7 days.
```

Use `Fixes #N` on the final commit that resolves the issue. Use `Part of #N` on intermediate
commits. Never omit the issue reference.

---

## Step 7: Link Issues to PRs

When creating a pull request, reference the issue in the PR body. GitHub will link the PR to
the issue automatically and close the issue when the PR is merged (if `Fixes #N` appears in
the body).

```bash
gh pr create \
  --title "feat(auth): implement JWT-based authentication flow" \
  --body "## Summary
- Implement login and logout endpoints
- Add JWT verification middleware
- Add refresh token rotation

## Issue
Fixes #42

## Test plan
- [ ] Login with valid credentials returns access and refresh tokens
- [ ] Login with invalid credentials returns 401
- [ ] Authenticated requests pass through the middleware
- [ ] Expired tokens are rejected
- [ ] Refresh token rotation invalidates the old token"
```

---

## Step 8: Close the Issue on Completion

When work is complete and verified, close the issue. Ask permission before closing if the
closure was not already implied by the user's instruction (for example, they said "finish this
feature" but did not explicitly say "close the issue").

```bash
# Close with a comment explaining what was done
gh issue close 42 --comment "Fixed in commit abc1234. Authentication flow is live on staging.
JWT tokens with 15-minute access and 7-day refresh. Refresh rotation is active."
```

If a PR was merged with `Fixes #42` in the body, GitHub closes the issue automatically. In
that case, verify the issue is already closed before running `gh issue close` manually.

```bash
# Verify issue state
gh issue view 42
```

---

## Issue States and Transitions

An issue moves through these states:

```
Open (created) -> In Progress (work started, context stored) ->
Under Review (PR open, review requested) -> Closed (merged or resolved)
```

Keep the issue state accurate. If work is paused for more than a day, add a comment to the
issue explaining the current state and what is blocking or waiting.

```bash
# Add a progress comment
gh issue comment 42 --body "Implementation complete. Waiting on review from design team
before merging. Auth flow screens recorded and shared in Figma. ETA: end of sprint."
```

---

## When Work Spans Multiple Issues

Some implementations touch multiple areas that warrant separate issues. Create one issue per
concern and link them.

```bash
# Create a parent issue for the feature
gh issue create --title "Feature: user authentication" --label feature

# Create child issues for sub-tasks
gh issue create --title "Auth: add JWT session service" --label feature
gh issue create --title "Auth: add login/logout routes" --label feature
gh issue create --title "Auth: add auth middleware" --label feature
```

Reference the parent issue in child issue bodies:

```
Part of #42 (user authentication feature)
```

Close child issues as each sub-task completes. Close the parent issue when all sub-tasks are done.

---

## Verification Checklist

Before marking this skill's responsibilities complete for a given piece of work:

- [ ] Existing issues searched before creating a new one
- [ ] Issue created or identified with correct label
- [ ] User confirmed issue creation before it was made
- [ ] Issue number noted and stored
- [ ] Context entry created with issue number, approach, and key files
- [ ] All commits reference the issue number (`Fixes #N` or `Part of #N`)
- [ ] PR linked to issue when opened
- [ ] Context entry updated as work progressed
- [ ] Issue closed on completion with a closing comment
- [ ] Issue verified as closed (not left open)

If any item is unchecked, complete it before declaring the work done.

---

## Common Mistakes

**Creating issues without asking permission**

Ask first. Issue creation is visible to the whole team. Confirm the title and label before
creating.

**Beginning work without an issue**

Stop immediately. Create the issue first. Commit messages without issue references cannot be
linked to context in GitHub or the context store.

**Forgetting to update the context entry**

Set the context entry at the start. Update it at every significant decision point. Resume
sessions by reading it first.

**Using the wrong label**

Labels drive project board visibility and sprint tracking. Mismatched labels (e.g., `chore`
for a feature) make sprint reporting inaccurate.

**Not closing the issue**

Open issues that represent completed work pollute the backlog and make sprint planning harder.
Close every issue when the work is done and verified.
