---
name: delegating-tasks
description: This skill should be used when executing an implementation plan with tasks that are mostly independent and can be completed within the current session. Trigger phrases include "execute this plan", "implement these tasks", "work through the plan", "delegate implementation", and "subagent-driven development".
---

# Delegating Tasks

Execute an implementation plan by dispatching a fresh subagent per task, with a two-stage review after each task completes: spec compliance first, then code quality.

Core principle: one fresh subagent per task, two ordered reviews per task, zero skipped gates.

## When to Use

Apply this skill when all three conditions are true:

1. An implementation plan exists with discrete, extractable tasks
2. Tasks are mostly independent (completing task N does not require task N+1 to have run first)
3. Work stays in the current session (no parallel session handoff needed)

Do not apply this skill when:
- Tasks are tightly coupled and must share state mid-execution
- The plan has not been written yet (use the writing-plans skill first)
- A parallel session approach is preferred over same-session execution

## Decision Tree

```
Have an implementation plan?
  No  -> Write the plan first (sdlc:writing-plans)
  Yes -> Are tasks mostly independent?
           No  -> Manual execution or rewrite the plan
           Yes -> Stay in this session?
                    No  -> Use executing-plans skill instead
                    Yes -> Use delegating-tasks (this skill)
```

## The Process

### Setup (once per plan)

Read the plan file once. Extract every task with its full text and surrounding context. Do not make subagents read the plan file themselves; the controller provides all text directly.

Create a TodoWrite entry for each task before dispatching any subagent. This gives a clear progress map from the start.

### Per-Task Loop

Repeat the following for each task in order. Never dispatch two implementation subagents in parallel -- they will conflict on shared files and git state.

**Step 1: Dispatch implementer subagent**

Use the Task tool with a general-purpose or coder subagent_type. Provide:
- The full task text and acceptance criteria (copied directly from the plan)
- Scene-setting context: what the codebase does, what branch is active, where this task fits in the overall plan
- Any constraints or conventions the implementer must follow
- Instruction to implement, write tests, commit, and self-review before returning

Do not tell the subagent to go read the plan file. Provide everything it needs inline.

**Step 2: Answer questions before implementation begins**

If the implementer subagent surfaces questions, answer them clearly and completely before allowing it to proceed. Do not rush the subagent into implementation with unanswered questions. Incomplete answers produce incomplete implementations.

After answering, re-dispatch the implementer with the answers included.

**Step 3: Receive implementer result**

The implementer subagent should return:
- A summary of what was implemented
- Confirmation that tests pass
- A self-review noting anything it caught and fixed
- The commit SHA(s)

**Step 4: Dispatch spec compliance reviewer**

Dispatch a fresh reviewer subagent using the Task tool. Provide:
- The original task text and acceptance criteria (same text as given to implementer)
- The commit SHA(s) to review
- Instruction to check whether the code matches the spec: nothing missing, nothing extra

The spec reviewer confirms one thing only: does the implementation match what was asked for?

**Step 5: Handle spec compliance result**

If spec reviewer returns issues:
- Send the same implementer subagent back to fix the spec gaps
- Once fixed, dispatch the spec reviewer again for a re-review
- Repeat until spec compliance passes

Do not proceed to code quality review while spec compliance has open issues. The order is mandatory: spec first, quality second.

**Step 6: Dispatch code quality reviewer**

Only after spec compliance passes, dispatch a fresh code quality reviewer subagent. Provide:
- The task context
- The commit SHA(s)
- Instruction to assess: naming, structure, error handling, testability, maintainability, and any important or blocking issues

**Step 7: Handle code quality result**

If code quality reviewer returns issues:
- Send the implementer subagent back to fix the quality issues
- Once fixed, dispatch the code quality reviewer again for a re-review
- Repeat until the reviewer approves

**Step 8: Mark task complete**

Update the TodoWrite entry for this task to complete.

If the task has an associated PM item, call `AUDIT_LOG` immediately after marking complete:
- `event`: `item_completed`
- `item_id`: the PM item UUID
- `payload`: `{ "autonomous_completion": true }`

Move to the next task.

### After All Tasks

After every task is marked complete, dispatch a final code reviewer subagent to assess the entire implementation as a whole. This final review catches cross-task issues that per-task reviews miss.

Then use the sdlc:finishing-branch skill to close out the development branch.

## Prompt Content Requirements

### Implementer Prompt Must Include

- Full task text and acceptance criteria (do not reference the plan file path)
- Repository context: what the app does, the active branch, relevant file paths
- Where this task fits in the plan: what came before, what comes after
- Conventions to follow (naming, test style, commit message format)
- Explicit instruction to self-review before returning

### Spec Reviewer Prompt Must Include

- The original task spec (same text given to implementer)
- The commit SHA(s) to review
- Instruction to check for missing requirements and unasked-for additions
- Instruction to return a clear pass or a specific list of failures

### Code Quality Reviewer Prompt Must Include

- The task context
- The commit SHA(s) to review
- Areas to assess: naming clarity, function size, error handling, test coverage, code structure
- Instruction to categorize issues by severity: blocking, important, minor

## Example Walkthrough

```
Plan has 3 tasks. Extract all tasks upfront. Create TodoWrite with 3 entries.

--- Task 1: Add user authentication endpoint ---

Dispatch implementer with full task 1 text + context.

Implementer asks: "Should the JWT expire in 1 hour or 24 hours?"
Answer: "1 hour. Include refresh token logic per the spec."
Re-dispatch implementer with answer included.

Implementer returns:
  - POST /auth/login implemented
  - 6 tests passing
  - Self-review: missed refresh token initially, added it
  - Committed: abc1234

Dispatch spec reviewer with task 1 spec + commit abc1234.

Spec reviewer: FAIL
  - Missing: rate limiting (spec says "limit to 5 attempts per minute")
  - Extra: added /auth/status endpoint (not requested)

Dispatch implementer to fix spec gaps.
Implementer: added rate limiting, removed /auth/status, committed def5678.

Re-dispatch spec reviewer with commit def5678.
Spec reviewer: PASS - all requirements met, nothing extra.

Dispatch code quality reviewer with commit def5678.
Code quality reviewer: Issues (important): magic number 5 in rate limit check.

Dispatch implementer to fix.
Implementer: extracted RATE_LIMIT_MAX_ATTEMPTS constant, committed ghi9012.

Re-dispatch code quality reviewer.
Code quality reviewer: PASS - approved.

Mark Task 1 complete in TodoWrite.

--- Task 2: Add password reset flow ---
[repeat same loop]

--- Task 3: Add session management ---
[repeat same loop]

--- Final review ---
Dispatch final code reviewer across all commits.
Final reviewer: PASS - implementation cohesive, ready to merge.

Use sdlc:finishing-branch to close out.
```

## Key Rules

### Never Do

- Implement on main or master without explicit user consent
- Skip spec compliance review or code quality review
- Run code quality review before spec compliance passes
- Dispatch multiple implementation subagents in parallel
- Tell a subagent to read the plan file itself
- Proceed past a review with open issues
- Treat the implementer's self-review as a substitute for the two-stage review
- Move to the next task while any review loop has unresolved issues
- Accept "close enough" on spec compliance

### Always Do

- Provide the full task text directly to the subagent
- Include scene-setting context so the subagent understands where the task fits
- Answer all questions before letting the implementer proceed
- Re-review after every round of fixes
- Track progress in TodoWrite after each task completes

## Advantages Over Manual Execution

**Fresh context per task.** Each subagent starts with a clean slate. No confusion from prior task context bleeding into the current one.

**Questions surface early.** Implementer questions appear before code is written, not after. Answering them upfront prevents rework.

**Structured quality gates.** Two reviews per task, in a fixed order, with mandatory fix loops. Issues cannot be silently accepted.

**No file reading overhead.** The controller extracts task text once and provides it directly. Subagents spend zero time navigating the plan file.

**Spec compliance is separate from quality.** Over-building and under-building are caught before style issues enter the conversation. The two stages do not interfere.

## Integration with Other Skills

- **sdlc:writing-plans** -- Creates the plan this skill executes. Run this first.
- **sdlc:creating-worktree** -- Set up an isolated workspace before starting implementation.
- **sdlc:requesting-review** -- Code review template for reviewer subagents.
- **sdlc:finishing-branch** -- Complete development after all tasks pass review.
- **sdlc:writing-tests** -- Subagents follow test-driven development for each task.
- **sdlc:parallelizing-work** -- Use instead when independent failures need concurrent investigation rather than sequential implementation.
