---
name: writing-plans
description: "This skill should be used when there is an approved design or a set of requirements for a multi-step task that needs a concrete implementation plan before code is written. Trigger phrases: 'write a plan for', 'create an implementation plan', 'plan this out', 'let's write the plan', 'turn this design into a plan'. This skill is also invoked automatically by the brainstorming skill after design approval."
---

# Writing Plans

## Overview

Write a comprehensive, bite-sized implementation plan that any skilled developer can follow without needing to understand the full codebase. The plan specifies exact file paths, complete code, exact test commands, and expected output for every step.

Announce at the start: "I'm using the writing-plans skill to create the implementation plan."

Plans are saved to: `docs/plans/YYYY-MM-DD-<feature-name>.md`

## Core Constraints

**DRY.** Do not repeat implementation patterns that already exist in the codebase. Reference existing utilities, hooks, and patterns. Introduce new abstractions only when existing ones are genuinely insufficient.

**YAGNI.** Include only what the approved design specifies. Strip out anything that might be useful someday but was not requested. A plan that implements the minimal correct thing is almost always better than one that anticipates future needs.

**TDD.** Every piece of logic gets a test written before the implementation. The plan must include the failing test step, the verification that it fails, the implementation step, and the verification that it passes — in that order.

**Frequent commits.** Every task ends with a commit. Do not bundle multiple tasks into one commit. Small, focused commits make review easier and rollback safer.

## What "Bite-Sized" Means

Each step in a task is one action that takes two to five minutes. No step does more than one thing. Examples of correctly sized steps:

- "Write the failing test for X"
- "Run the test to confirm it fails"
- "Write the minimal implementation that makes the test pass"
- "Run the test suite to confirm all tests pass"
- "Commit"

Examples of incorrectly sized steps:

- "Write tests and implement the authentication module" (too large — this is a task, not a step)
- "Add validation" (not specific enough — which validation? what file? what code?)

If a step cannot be completed in five minutes, it needs to be broken down further.

## Preparation

Before writing the plan:

1. Read the approved design document from `docs/plans/YYYY-MM-DD-<topic>-design.md`
2. Explore the codebase to understand the existing patterns, file structure, and conventions
3. Identify which files will be created, which will be modified, and where tests will live
4. Verify that the technology choices in the design are compatible with the existing stack
5. Flag any gaps or ambiguities in the design before writing the plan

If there are gaps in the design that prevent writing a specific, complete plan, raise them now. Do not write a plan with placeholder steps.

## Plan Document Header

Every plan must start with this header:

```markdown
# [Feature Name] Implementation Plan

> **For Claude:** Use sdlc:executing-plans to implement this plan task-by-task.

**Goal:** [One sentence describing what this builds]

**Architecture:** [2-3 sentences about the overall approach]

**Tech Stack:** [Key technologies and libraries involved]

---
```

## Task Structure

Each task in the plan follows this structure:

````markdown
### Task N: [Component or Feature Name]

**Files:**
- Create: `exact/path/to/new-file.ts`
- Modify: `exact/path/to/existing-file.ts` (lines 45-67)
- Test: `tests/exact/path/to/new-file.test.ts`

**Context:**
[One to three sentences explaining what this task accomplishes and why it comes at this point in the sequence]

**Step 1: Write the failing test**

```typescript
// tests/exact/path/to/new-file.test.ts

import { functionName } from '../../src/path/to/new-file';

describe('functionName', () => {
  it('returns expected output for valid input', () => {
    const result = functionName({ key: 'value' });
    expect(result).toEqual({ status: 'ok', data: 'expected' });
  });
});
```

**Step 2: Run test to confirm it fails**

```bash
pnpm run test tests/exact/path/to/new-file.test.ts
```

Expected output:
```
FAIL tests/exact/path/to/new-file.test.ts
  functionName
    x returns expected output for valid input
      Cannot find module '../../src/path/to/new-file'
```

**Step 3: Write the minimal implementation**

```typescript
// src/exact/path/to/new-file.ts

export function functionName(input: { key: string }): { status: string; data: string } {
  return { status: 'ok', data: input.key };
}
```

**Step 4: Run test to confirm it passes**

```bash
pnpm run test tests/exact/path/to/new-file.test.ts
```

Expected output:
```
PASS tests/exact/path/to/new-file.test.ts
  functionName
    + returns expected output for valid input
```

**Step 5: Run full test suite to confirm no regressions**

```bash
pnpm run test
```

Expected output:
```
Test Suites: X passed, X total
Tests:       Y passed, Y total
```

**Step 6: Commit**

```bash
git add tests/exact/path/to/new-file.test.ts src/exact/path/to/new-file.ts
git commit -m "feat: add functionName with test coverage"
```
````

## Requirements for Plan Quality

**Exact file paths always.** Never write "add a file in the components directory." Write `src/components/UserCard/UserCard.tsx`.

**Complete code in every step.** Never write "add validation logic here." Write the actual code. If the code is long, include the full relevant section with context.

**Exact commands with expected output.** Every test command includes the expected pass or fail message. Every build command includes what success looks like. This lets the executor verify correctness without interpretation.

**Task ordering must reflect dependencies.** If Task 3 modifies a file created in Task 1, Task 1 must come first. Mark dependency relationships explicitly in each task's context.

**Edge cases covered by tests.** The plan must include test cases for edge conditions: empty inputs, invalid inputs, boundary values, error states. These are not optional. If the design does not specify edge behavior, define it in the plan and note the assumption.

## Handling Existing Code

When a task modifies existing code, specify:
- Which lines are being changed (e.g., "lines 45-67 in `src/auth/handler.ts`")
- What the current code looks like (include a snippet)
- What the replacement code looks like

Do not write "modify the handler to add error handling." Write the before and after.

## Documentation Steps

If the feature requires documentation updates:
- Include the documentation step as a task in the plan
- Specify the exact file to update
- Include the content to add or modify
- Documentation tasks have the same commit requirement as implementation tasks

## Execution Handoff

After saving the plan, present the execution options:

---

Plan complete and saved to `docs/plans/<filename>.md`. Two options for execution:

**Option 1: Subagent-driven (this session)**

Dispatch a fresh subagent per task, review after each task completes, fast iteration. Stay in this session.

**Option 2: Parallel session (separate)**

Open a new Claude session in the worktree. Use sdlc:executing-plans to run the plan with batch checkpoints.

Which approach?

---

**If Option 1 is chosen:** Dispatch subagents per task. Review output between tasks. Raise issues before proceeding to the next task.

**If Option 2 is chosen:** Guide the user to open a new session in the correct worktree. Confirm the plan file path. The new session uses the executing-plans skill.

## Common Plan Mistakes

**Vague steps.** "Add error handling" is not a step. "Add a try/catch around the database call at `src/db/users.ts:34` and return `{ error: 'Database unavailable' }` on failure" is a step.

**Missing expected output.** A test command without expected output forces the executor to interpret whether the result is correct. Include the output.

**Bundled commits.** One commit per task. Not one commit per feature, not one commit at the end.

**Missing test verification.** Every test written must be run and verified to fail before implementation, then verified to pass after implementation. Skipping either verification defeats TDD.

**Orphaned tasks.** Every task must connect logically to the feature being built. If a task exists in the plan, it must be traceable to the design document.
