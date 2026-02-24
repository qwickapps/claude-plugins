---
name: bug
description: Bug investigation and fix. Creates/links a GitHub issue, performs root cause analysis, writes regression test, implements fix, and verifies.
---

The /bug command follows a strict investigation-first approach. Do not attempt any fix before root cause is identified and documented.

## Argument

Accept an optional argument: a bug description or an existing issue number.

- If a description is provided, create a new GitHub issue.
- If an issue number is provided (e.g. `#123`), link to that existing issue.
- If neither is provided, use AskUserQuestion to ask for the bug description and reproduction steps before proceeding.

## Phases

### Phase 1: Investigation

Load `qwickapps-sdlc:tracking-issues` to create or link the GitHub issue with the label `bug`.

Before investigation begins, gather from the user (via AskUserQuestion if not already provided):
- Reproduction steps
- Expected behavior
- Actual behavior
- Environment (local, staging, production)
- When the bug first appeared (if known)

Load `qwickapps-sdlc:debugging` for systematic root cause analysis.

Apply RESEARCH-DEPTH.md. Use all available tools to gather evidence:
- Task tool with Explore agent: trace code paths related to the bug
- Grep: find the specific function, method, or pattern involved
- Read: inspect the actual implementation at identified file:line locations
- Browser automation (`mcp__claude-in-chrome__*`): reproduce and capture the bug if it is frontend-facing

Apply FACT-VERIFICATION.md to all claims. Every claim about the bug must have a source (file:line or log output). Never assert root cause without evidence.

Apply INVESTIGATION-METHODS.md. Exhaust all investigation methods before concluding "cannot verify". Document each method attempted and its result.

Do not propose or write any fix until the root cause is documented with:
- The exact file:line where the bug originates
- The mechanism explaining why it happens
- The conditions that trigger it (reproduction steps)
- Evidence from code inspection or logs

If investigation reaches a dead end, follow COMMUNICATION-PROTOCOL.md: stop, present what was found, present options for continuing, and wait for user input.

### Phase 2: Fix

Write the regression test first. The test must:
- Reproduce the bug in its current state (test fails before the fix)
- Verify the correct behavior after the fix (test passes after the fix)
- Cover edge cases identified during investigation

Load `qwickapps-sdlc:writing-tests` to implement the regression test.

Adopt the coder agent persona to implement the fix. The fix must be minimal: change only what is necessary to address the root cause. Do not refactor unrelated code in the same commit.

Load `qwickapps-sdlc:securing-code` if the bug has security implications (e.g. input handling, authentication, data exposure).

Load `qwickapps-sdlc:creating-worktree` to set up an isolated workspace if one is not already active. Follow WORKTREE-ENFORCEMENT.md: use the create-worktree.sh script.

### Phase 3: Verification

Load `qwickapps-sdlc:verifying-completion`.

Run the full test suite. Verify:
- The regression test now passes
- No existing tests are broken
- Build passes without errors or critical warnings

Apply VALIDATION-GATES.md:
- Compilation/Build Gate: build must succeed
- Unit Test Gate: all unit tests pass including the new regression test
- Integration Test Gate: if the bug affected database or API behavior, run integration tests
- End-to-End Gate: if the bug was user-facing, validate in a production-like environment or browser

Apply SATISFACTORY-CRITERIA.md before marking verification complete. The user's actual problem must be solved, not just the literal symptom.

### Phase 4: Commit and Close

Commit with a message that:
- Describes what was fixed (not just "fix bug")
- Uses `Fixes #N` to reference and auto-close the issue on merge

Include in the commit or PR description:
- Root cause summary (file:line)
- What the fix changes and why it works
- How the regression test covers the fix

Close the GitHub issue on merge. Do not close the issue before the PR is merged.
