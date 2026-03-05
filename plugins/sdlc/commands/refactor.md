---
name: refactor
description: Code restructuring with behavior preservation. Creates a GitHub issue, analyzes impact, writes behavior preservation tests, restructures code, and verifies no behavior change.
---

The /refactor command ensures restructuring preserves existing behavior. Do not restructure any code before behavior preservation tests are written and passing.

## Argument

Accept an optional argument: what to refactor. If not provided, use AskUserQuestion to ask the user what they want to restructure and why before proceeding.

## Phases

### Phase 1: Analysis

Load `sdlc:tracking-issues` to create a new GitHub issue with the label `refactor`. If the user provided an existing issue number, link to it rather than creating a new one.

Load `sdlc:brainstorming` for impact analysis. Adopt the architect agent persona throughout this phase.

Use all available tools to identify the full blast radius:
- Use the Task tool with Explore agent to trace all code paths that touch the target code
- Use Grep to find all consumers, callers, and importers of the target module or function
- Use Read to inspect integration points at the identified file:line locations
- Check test files to understand what behavior is currently covered

Document the impact analysis explicitly before proceeding:
- All affected components with file:line references
- All consumers of the restructured code
- All dependencies that will change
- Any integration points that must remain stable

Apply FACT-VERIFICATION.md. Every identified dependency must have a source (file:line). Do not assert impact without evidence.

Use AskUserQuestion to present the impact analysis to the user and get explicit agreement on scope before planning. If the scope is larger than anticipated, surface this clearly and let the user decide whether to narrow it.

Do not proceed to planning until scope is agreed.

### Phase 2: Plan

Load `sdlc:writing-plans` to produce a detailed restructuring plan.

Document the before and after structure explicitly:
- Current structure: what exists, where it lives, how it is organized
- Target structure: what the result will look like after restructuring
- What moves: files, functions, modules being relocated or renamed
- What stays: interfaces and behavior that must remain identical

Create tasks using TaskCreate. Each task must include:
- The specific structural change being made
- The behavior preservation check that confirms the change did not alter behavior
- The definition of done: behavior tests pass before and after

Tasks must be sequenced so each one leaves the codebase in a working state. Never plan a task that temporarily breaks the build or tests.

Reference VALIDATION-GATES.md when defining done criteria. Build and tests must pass after every task, not just at the end.

### Phase 3: Implementation

Load `sdlc:creating-worktree` to set up an isolated workspace. Follow WORKTREE-ENFORCEMENT.md: use the create-worktree.sh script, never `git checkout -b` directly.

Load `sdlc:writing-tests` to write behavior preservation tests BEFORE any restructuring begins.

The behavior preservation tests must:
- Exercise every externally observable behavior of the code being restructured
- Cover all consumers identified in Phase 1
- Cover edge cases identified during analysis
- Pass against the current (pre-restructure) code

Run the tests to confirm they pass in the current state. If any test fails before restructuring begins, STOP. Use AskUserQuestion to report the pre-existing failure and ask how to proceed. Do not mask pre-existing failures by restructuring around them.

Once all behavior preservation tests pass on the current code, proceed with restructuring.

For each task during restructuring:
1. Make the structural change
2. Run the full behavior preservation test suite
3. Run the full existing test suite
4. Apply VALIDATION-GATES.md: build must pass, all tests must pass
5. Verify the task's behavior preservation check before marking it complete

Load `sdlc:securing-code` if the restructuring touches authentication, authorization, input handling, or data access paths.

If any behavior preservation test fails after a structural change:
- STOP immediately
- Do not continue to the next task
- Identify which behavior changed (file:line)
- Fix the structural change to restore the behavior
- Re-run all tests before continuing

### Phase 4: Verification

Load `sdlc:verifying-completion`.

Produce evidence-based proof of behavior preservation:
- List every behavior preservation test written, with file:line reference for each
- Confirm the test suite passed before restructuring (with evidence)
- Confirm the test suite passes after restructuring (with evidence)
- Confirm no existing tests were deleted or modified to make restructuring pass

Apply VALIDATION-GATES.md:
- Compilation/Build Gate: production build must succeed
- Unit Test Gate: all existing unit tests pass, all behavior preservation tests pass
- Integration Test Gate: if the restructuring touched database or API code, run integration tests
- End-to-End Gate: if the restructuring touched user-facing code, validate in a production-like environment

Apply SATISFACTORY-CRITERIA.md before marking verification complete. Work is not satisfactory if evidence of behavior preservation is vague or incomplete.

Use AskUserQuestion to present the verification results to the user before proceeding to commit.

### Phase 5: Commit

Load `sdlc:finishing-branch` to finalize the branch.

Reference the GitHub issue number in every commit message using `#N` notation.

The PR description must:
- Link to the issue with `Closes #N`
- State what was restructured and the motivation
- List the behavior preservation tests written and where they live
- Confirm that no behavior changed (with reference to the passing test suite)
- List any known follow-up work

Close the issue on merge. Do not close it before the PR is merged.
