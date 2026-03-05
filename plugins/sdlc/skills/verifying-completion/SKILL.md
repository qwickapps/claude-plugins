---
name: verifying-completion
description: >
  This skill should be used before claiming any work is complete, fixed, passing, or ready to
  commit. It must be invoked before creating commits, pull requests, or moving to the next task.
  Trigger phrases include: "mark this complete", "this is done", "the tests pass", "the bug is
  fixed", "ready to commit", "ready for review", "this should work now", "all tests are passing".
  Fresh verification evidence is required before any success claim. "It should work" is never
  acceptable. Run the command. Read the output. Then make the claim.
---

# Verifying Completion

Run verification commands. Read the output. Then claim the result.

**Core principle:** Evidence before assertions, always. Claims without verification are not claims — they are guesses.

---

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If the verification command was not run in the current context, the claim cannot be made. A previous run does not count. A partial run does not count. "Should pass" is not evidence.

---

## The Gate

Before claiming any status or expressing completion, follow this sequence:

1. **Identify:** What command proves this claim?
2. **Run:** Execute the full command now, fresh, complete
3. **Read:** Read the full output — check exit code, count failures, read error messages
4. **Evaluate:** Does the output confirm the claim?
   - If no: State the actual status with the evidence from the output
   - If yes: State the claim and include the specific output that supports it
5. **Then claim:** Only after step 4

Skipping any step means the claim is unverified.

---

## What Each Claim Requires

| Claim | Required Evidence | Not Sufficient |
|-------|-----------------|----------------|
| Tests pass | Test command output showing 0 failures | A previous run, "should pass", linter passing |
| Linter clean | Linter output showing 0 errors, 0 warnings | Partial check, assuming no new issues |
| Build succeeds | Build command exit code 0, no errors | Linter passing, "looks correct" |
| Bug is fixed | Test for the original symptom passes | Code was changed, assumed fixed |
| Regression test works | Observed RED then GREEN in current session | Test passes once without red-green cycle |
| Agent completed task | VCS diff confirms changes were made | Agent reported success |
| Requirements are met | Line-by-line checklist against original requirements | Tests passing |

---

## Running Verification Commands

### Tests

Run the full test suite before claiming tests pass:

```bash
npm test
```

Read the output completely. The number of tests that passed and failed is in the output. Do not claim tests pass without reading that number.

For targeted verification of a specific test file:

```bash
npm test path/to/specific.test.ts
```

Then run the full suite to confirm no regressions:

```bash
npm test
```

### Build

Run the build command to confirm compilation succeeds:

```bash
npm run build
```

Linter passing does not imply the build passes. TypeScript type checks do not imply the build passes. Run the build.

### Linter

```bash
npm run lint
```

Read the output for errors and warnings. Zero errors and zero warnings is the standard.

### Combined Pre-Commit Verification

Before creating a commit, run all three:

```bash
npm run build && npm test && npm run lint
```

All three must pass. A partial success is a failure.

---

## Verifying Regression Tests (RED-GREEN Cycle)

A regression test that was written after the fact needs to be verified through the full red-green cycle to confirm it actually detects the bug.

The sequence:

1. Write the test
2. Run the test — it must fail (RED)
3. Revert the fix temporarily
4. Run the test again — it must fail without the fix (confirms the test detects the bug)
5. Restore the fix
6. Run the test — it must pass (GREEN)

Skipping step 4 means the test was never proven to catch the bug it was written for.

---

## Verifying Requirements Are Met

Passing tests do not automatically mean all requirements are satisfied.

Before claiming a feature is complete:

1. Re-read the original requirements or acceptance criteria
2. Create a checklist with each requirement as a line item
3. Verify each item against the actual output or behavior
4. Report any gaps explicitly

Do not claim a phase is complete because tests pass. Requirements and test coverage are separate concerns.

---

## Verifying Agent-Delegated Work

When a task was delegated to a subagent or automated process:

1. Check the VCS diff to confirm changes were actually made
2. Read the changes to verify they are correct
3. Run the verification commands independently
4. Report the actual state based on direct observation

Agent-reported success is not verification. Verify independently.

---

## Red Flags — Stop Before Claiming

Stop and run verification when any of these are present:

- Using "should", "probably", "seems to", or "appears to" when describing success
- Expressing satisfaction or completion before the verification command has been run ("done", "fixed", "passing", "ready")
- Preparing to commit or open a pull request without having run verification commands in the current session
- Relying on a previous successful run from an earlier context
- Trusting an agent's self-reported success without independent confirmation
- Checking only part of the verification suite (tests but not build, build but not tests)
- Feeling that the work is obviously correct and verification is unnecessary

Any of these require stopping and running the full verification sequence before proceeding.

---

## Common Rationalizations

| Rationalization | Reality |
|----------------|---------|
| "It should work now" | Run the verification command. |
| "I am confident it is correct" | Confidence is not evidence. Run the verification command. |
| "Just this once the check is not needed" | No exceptions. Run the verification command. |
| "The linter passed, so the build is fine" | Linter and compiler are different. Run the build. |
| "The agent said it succeeded" | Verify independently. Check the VCS diff and run the commands. |
| "A partial check is good enough" | Partial verification proves nothing about the unchecked parts. |
| "Tests pass, the phase is complete" | Test coverage does not equal requirement coverage. Check both. |
| "I just ran this — running it again is redundant" | If the context changed, the previous run is stale. Run it again. |

---

## Correct Verification Patterns

**Tests:**

```
Action: Run npm test
Output: 34 passed, 0 failed
Claim: All 34 tests pass.
```

```
Not acceptable: "The tests should pass now."
Not acceptable: "I'm confident the tests pass based on the changes made."
```

**Build:**

```
Action: Run npm run build
Output: Exit code 0, no errors
Claim: The build succeeds.
```

```
Not acceptable: "The linter is clean so the build should be fine."
```

**Bug fix:**

```
Action: Write test reproducing the bug. Run it — FAIL. Apply fix. Run it — PASS.
Output: Test passes with fix, fails without fix.
Claim: The bug is fixed and the regression test confirms it.
```

```
Not acceptable: "I changed the logic so the bug is fixed."
```

**Requirements:**

```
Action: Re-read requirements. Create checklist. Verify each item.
Output: 5/5 requirements verified.
Claim: All requirements are met.
```

```
Not acceptable: "The tests pass so the feature is complete."
```

---

## Verification Checklist

Before marking any work complete, before committing, and before moving to the next task:

- [ ] Identified the specific command that verifies the completion claim
- [ ] Ran that command in the current context (not relying on a previous run)
- [ ] Read the full output of the command
- [ ] Confirmed the output supports the claim being made
- [ ] Ran the full test suite (not just the targeted test file)
- [ ] Ran the build if any code was changed
- [ ] Verified requirements line-by-line if claiming a feature is complete
- [ ] Verified agent-delegated work independently via VCS diff if a subagent was used

If any item cannot be checked, run the missing verification before proceeding.
