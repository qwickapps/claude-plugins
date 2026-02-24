---
name: requesting-review
description: >
  This skill should be used after completing delegated or subagent-driven work, after implementing
  a major feature, before merging any branch to main, or whenever a fresh perspective is needed on
  completed code. Trigger phrases include: "request a code review", "review this before merging",
  "get feedback on my changes", "have someone review this", "run a code review", "check my work",
  "review before I merge", "is this ready to merge", "I want a review on this". Also activate when
  completing any task in a multi-task plan, after fixing a complex bug, or before beginning a refactor.
---

# Requesting Code Review

Dispatch the qwickapps-sdlc code-reviewer agent to catch issues before they cascade. Reviews surface
problems when they are small and contained. Skipping review to save time creates debt that surfaces
later at higher cost.

**Core principle:** Review early, review often.

---

## When to Request Review

### Mandatory

Request a review in all of these situations without exception:

- After completing each task in subagent-driven or delegated development
- After implementing a major feature
- Before merging any branch to main

### Optional but Valuable

Request a review when any of these apply:

- Stuck on a problem and need a fresh perspective
- Starting a refactor and want a baseline assessment of current code quality
- Completing a complex bug fix that involved multiple file changes
- Uncertain whether the implementation matches the original requirements

The cost of an unnecessary review is low. The cost of a missed defect is high.

---

## How to Request

### Step 1: Get the Git SHAs

Identify the commit range that represents the work being reviewed.

```bash
# Base: the commit before this work started (or origin/main if working from a shared branch)
BASE_SHA=$(git rev-parse HEAD~1)

# Or, if comparing to the main branch:
BASE_SHA=$(git rev-parse origin/main)

# Head: the current state
HEAD_SHA=$(git rev-parse HEAD)
```

For multi-commit work, find the SHA just before the work began:

```bash
# List recent commits to identify the base
git log --oneline -10
```

### Step 2: Collect Supporting Context

Before dispatching the reviewer, gather:

- The task description or ticket number that drove this work
- The plan document path (if a written plan exists under `docs/plans/`)
- The list of changed files: `git diff --name-only $BASE_SHA $HEAD_SHA`

### Step 3: Dispatch the Code-Reviewer Agent

Use the Task tool to dispatch the code-reviewer agent. Provide the following information:

- `WHAT_WAS_IMPLEMENTED`: A clear description of what was built or changed
- `PLAN_OR_REQUIREMENTS`: What the implementation was supposed to accomplish (link to plan or issue)
- `BASE_SHA`: The starting commit SHA
- `HEAD_SHA`: The ending commit SHA
- `CHANGED_FILES`: The list of files changed in this range
- `DESCRIPTION`: A one or two sentence summary of the change

### Step 4: Act on Feedback

After the reviewer responds, classify each item and act accordingly:

- **Critical**: Fix immediately. Do not proceed without resolving.
- **Important**: Fix before the branch is considered complete or merged.
- **Minor**: Record for a follow-up task. Do not block progress.
- **Incorrect feedback**: Push back with technical reasoning. Provide file:line references or test output as evidence.

---

## Example Workflow

A plan with three tasks has just reached the end of Task 2.

```
[Task 2 complete: Added authentication middleware]

1. Get SHAs:
   BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
   HEAD_SHA=$(git rev-parse HEAD)

2. Changed files:
   git diff --name-only $BASE_SHA $HEAD_SHA
   > src/middleware/auth.ts
   > src/middleware/auth.test.ts
   > src/routes/api.ts

3. Dispatch code-reviewer agent:
   WHAT_WAS_IMPLEMENTED: JWT authentication middleware with token validation and role checking
   PLAN_OR_REQUIREMENTS: Task 2 from docs/plans/auth-plan.md — implement middleware
   BASE_SHA: a7981ec
   HEAD_SHA: 3df7661
   CHANGED_FILES: src/middleware/auth.ts, src/middleware/auth.test.ts, src/routes/api.ts
   DESCRIPTION: Added validateJWT() and requireRole() middleware functions with unit tests

4. Reviewer response:
   Strengths: Good test coverage, clear error messages
   Issues:
     Important: Token expiry check missing in validateJWT — expired tokens will be accepted
     Minor: Magic number (3600) for token TTL should be a named constant
   Assessment: Fix the expiry check before proceeding to Task 3

5. Actions taken:
   - Added expiry check to validateJWT() [Important — fixed immediately]
   - Added TOKEN_TTL_SECONDS constant [Minor — fixed while here]
   - Continue to Task 3
```

---

## Integration with Development Workflows

### Subagent-Driven Development

When tasks are delegated to subagents, review after each task completes. Issues discovered at the
task level are contained to a small diff. Issues discovered at merge time require re-reading the
entire feature branch.

Default cadence:

- Delegate Task N to subagent
- Subagent completes Task N
- Request review of Task N
- Address feedback
- Delegate Task N+1

### Executing Plans

When working through a written plan with many tasks, review in batches if individual task diffs are
very small. A reasonable batch is three tasks. Do not defer all review to the end of the plan.

### Ad-Hoc Development

For ad-hoc work without a formal plan, request review at two points:

1. When stuck and needing a second opinion on the current approach
2. Before merging to main

### Before Merge

Always run a review before merging to main, regardless of how small the change appears. The review
serves as a final gate for correctness, security, and code quality before the change becomes part
of the shared codebase.

---

## Why Reviews Must Happen Early

Defects compound. A wrong assumption in Task 1 that goes unreviewed propagates into Task 2, Task 3,
and every file that depends on the bad assumption. By the time a review happens at merge time, the
diff spans hundreds of lines and the fix requires unwinding multiple tasks.

When review happens after each task, the diff is small. The context is fresh. The fix is contained.
Rework at that scale takes minutes. Rework at merge time takes hours.

This is not a theoretical argument. It is the observed cost difference between catching a wrong data
model in Task 1 versus after ten tasks have been built on top of it.

**Review early to keep the cost of correction small.**

---

## Providing Good Context to the Reviewer

The quality of a review depends on the context provided. A reviewer given no context will flag style
issues and obvious bugs. A reviewer given full context — what was built, why, what constraints
exist, what the plan requires — will catch semantic errors, requirement mismatches, and architectural
misalignments.

Invest time in the context provided to the reviewer. Each field matters:

**WHAT_WAS_IMPLEMENTED**: Be specific. Not "added auth" but "added JWT validation middleware that
verifies the token signature, checks expiry, and enforces role-based access on protected routes."

**PLAN_OR_REQUIREMENTS**: Reference the exact section of the plan or issue. The reviewer uses this
to determine whether the implementation matches the requirement, not just whether the code is correct
in isolation.

**CHANGED_FILES**: The complete list. Do not omit test files. Do not omit migration files. The
reviewer needs to see what was and was not touched to identify gaps.

**DESCRIPTION**: One or two sentences that summarize the change for a reader encountering it cold.

A well-contextualized review catches issues that a diff-only review will miss.

---

## What the Reviewer Examines

The code-reviewer agent assesses:

- Correctness relative to the stated requirements
- Potential security vulnerabilities (input validation, authentication gaps, data exposure)
- Error handling coverage including edge cases
- Code clarity and adherence to project conventions
- Test coverage completeness and quality
- Performance implications of the approach

The reviewer operates on the diff and the provided context. It does not have access to prior
conversations, design decisions made verbally, or constraints that were decided outside the written
plan. Provide the context that fills those gaps.

---

## Common Mistakes

| Mistake | Correct approach |
|---------|-----------------|
| Skipping review because the change is small | Review every task, regardless of diff size |
| Deferring all review to before merge | Review in the cadence defined for the workflow mode |
| Providing minimal context to the reviewer | Provide full task description, plan reference, and changed files |
| Ignoring Critical issues and continuing | Fix Critical issues before any further work |
| Proceeding with Important issues unresolved | Resolve Important issues before the branch grows |
| Dismissing reviewer feedback without checking | Verify the concern against the codebase before pushing back |
| Pushing back without evidence | Reference file:line, tests, or ADRs when disagreeing |

---

## Handling Reviewer Feedback

### If the reviewer identifies a real issue

Fix it. For Critical and Important items, fix before proceeding to the next task or merge. For Minor
items, open a follow-up task and continue.

### If the reviewer is wrong

Push back. State the technical reason the suggestion is incorrect. Provide evidence:

- Paste the relevant code with file:line reference
- Reference the test that already covers the case
- Explain why the reviewer's concern does not apply to this codebase's context

Reviewers operate without full context. They can be wrong. Correct technical analysis is the
standard, not deference.

### If the reviewer's feedback is unclear

Ask a specific clarifying question before implementing anything. Partial understanding leads to
wrong implementations. Request clarification on all unclear items before acting on any of them.

---

## What Not to Do

**Never skip review because the change seems simple.**

The thought "it's just a small change" is the most reliable predictor of unreviewed regressions.
Simple diffs contain typos in critical paths, missing null checks, and off-by-one errors.

**Never ignore Critical issues.**

A Critical issue means the implementation is wrong in a way that will cause failures. Proceeding
with a known Critical issue compounds the problem into the next task.

**Never proceed with unresolved Important issues.**

Important issues degrade code quality when accumulated. Resolve them before the branch grows larger.

**Never argue with valid feedback out of attachment to the implementation.**

The code is not a reflection of identity. If the reviewer is right, fix it. Attachment to
incorrect implementations wastes time.

---

## Verification Checklist

Before marking any task complete in a multi-task plan:

- [ ] Git SHAs identified for the task range
- [ ] Code-reviewer agent dispatched with complete context
- [ ] All Critical issues resolved
- [ ] All Important issues resolved or explicitly deferred with justification
- [ ] Minor issues recorded for follow-up or addressed in place
- [ ] Incorrect feedback challenged with technical reasoning and evidence

---

## The Review Cadence

| Development mode | Review frequency |
|-----------------|-----------------|
| Subagent-driven (task-by-task) | After every task |
| Plan execution (batched) | Every three tasks, and before merge |
| Ad-hoc | When stuck, and before merge |
| Any branch | Always before merge to main |

The earlier an issue is found, the smaller the fix. Request reviews before the codebase assumes
the implementation is correct.
