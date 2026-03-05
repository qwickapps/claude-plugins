---
name: debugging
description: >
  This skill should be used when encountering any bug, test failure, unexpected behavior, build
  failure, or integration issue, before proposing or attempting any fix. Trigger phrases include:
  "this is broken", "the test is failing", "it is not working", "something went wrong", "the build
  failed", "unexpected behavior", "debug this", "why is X happening". Root cause investigation is
  mandatory before any fix attempt. Random fixes waste time and introduce new bugs. Symptom fixes
  are failure.
---

# Debugging

Find the root cause before attempting any fix. Random fixes waste time and create new bugs.

**Core principle:** Never propose a fix without first understanding why the problem occurs.

---

## The Iron Law

```
NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST
```

Phase 1 must be completed before any fix is attempted or proposed. If Phase 1 has not been completed, there is no basis for a fix.

---

## When to Apply

Apply this skill for any technical issue:

- Test failures
- Runtime bugs
- Unexpected behavior
- Performance problems
- Build failures
- Integration failures
- Intermittent issues

Apply this skill **especially** when:

- Time pressure makes guessing feel justified (systematic debugging is faster than thrashing)
- A fix "seems obvious" (obvious fixes frequently address symptoms, not root causes)
- Multiple fixes have already been attempted without success
- The issue is not fully understood

Do not skip this process for issues that seem simple. Simple bugs have root causes too.

---

## The Four Phases

Complete each phase fully before moving to the next. Do not skip ahead.

---

### Phase 1: Root Cause Investigation

This phase must be completed before any fix is proposed.

#### 1. Read Error Messages Carefully

Read the full error output. Do not skip past it or summarize it from memory.

- Read the complete stack trace from top to bottom
- Note exact line numbers, file paths, and error codes
- Note any warnings preceding the error
- Error messages frequently contain the exact location and cause of the problem

#### 2. Reproduce Consistently

Determine whether the issue can be triggered reliably.

- What are the exact steps to reproduce?
- Does it happen every time, or intermittently?
- What inputs or conditions trigger it?

If the issue cannot be reproduced consistently, gather more data. Do not guess at a fix for an unreproducible issue.

#### 3. Check Recent Changes

Identify what changed that could have introduced the issue.

- Review `git diff` and recent commits
- Check for new dependencies, version bumps, or config changes
- Consider environmental differences (local vs. CI, dev vs. staging)

If the issue appeared recently, the cause is almost always in what changed.

#### 4. Gather Evidence in Multi-Component Systems

When the system involves multiple components (e.g., CI pipeline, API to service to database, gateway to backend), add diagnostic instrumentation before proposing any fix.

For each component boundary:

- Log what data enters the component
- Log what data exits the component
- Verify that environment variables and configuration are propagated correctly
- Check the state at each layer

Run once to gather evidence showing where the problem is. Then analyze the evidence to identify the failing component. Then investigate that specific component.

**Example — CI signing pipeline with multiple layers:**

```bash
# Layer 1: Check workflow environment
echo "=== Secrets in workflow: ==="
echo "SIGNING_IDENTITY: ${SIGNING_IDENTITY:+SET}${SIGNING_IDENTITY:-UNSET}"

# Layer 2: Check build script environment
echo "=== Env vars in build script: ==="
env | grep SIGNING_IDENTITY || echo "SIGNING_IDENTITY not in environment"

# Layer 3: Check keychain state
echo "=== Keychain contents: ==="
security list-keychains
security find-identity -v

# Layer 4: Check signing command output
codesign --sign "$SIGNING_IDENTITY" --verbose=4 "$APP_PATH"
```

This reveals which layer breaks: workflow has the secret, build script does not — the propagation is the problem.

Do not guess at which layer is failing. Add logging and observe.

#### 5. Trace the Data Flow

When the error is deep in a call stack, trace backward from the point of failure to the origin.

- Where does the bad value appear?
- What function called the failing code?
- What passed the bad value to that function?
- Keep tracing up the call stack until the origin of the bad value is found

Fix the problem at its origin. Fixing it at a symptom location leaves the actual bug in place.

---

### Phase 2: Pattern Analysis

After understanding the error and where it occurs, analyze the surrounding context.

#### 1. Find Working Examples

Locate similar code in the same codebase that works correctly.

- What is it doing differently?
- What dependencies or configuration does it rely on?

#### 2. Compare Against References

If implementing a known pattern (retry logic, authentication flow, database migration), read the reference implementation completely. Do not skim. Read every line. Understand the full pattern before applying it.

Partial understanding of a pattern guarantees bugs.

#### 3. Identify Differences

List every difference between the working example and the broken code. Do not dismiss small differences as irrelevant without verification.

#### 4. Understand Dependencies

What does the broken component depend on? What configuration, environment variables, or state does it assume? Verify those assumptions are met.

---

### Phase 3: Hypothesis and Testing

Apply the scientific method. Form one hypothesis and test it minimally.

#### 1. Form a Single Hypothesis

State clearly: "I think X is the root cause because Y."

Write it down. Be specific. Vague hypotheses produce vague tests and inconclusive results.

Correct: "The environment variable SIGNING_IDENTITY is available in the workflow but not passed to the build script."

Incorrect: "Something is wrong with the environment."

#### 2. Test Minimally

Make the smallest possible change to test the hypothesis. Change one variable. Do not bundle multiple changes into a single test.

If multiple things are changed at once, it is impossible to know which one fixed the problem — or which introduced a new one.

#### 3. Evaluate the Result

- Fix confirmed: Proceed to Phase 4
- Fix not confirmed: Form a new hypothesis. Do not layer additional changes on top of the failed attempt.

#### 4. Acknowledge Uncertainty

If the root cause is not understood, say so. Do not propose a fix on a hypothesis that has not been verified. Research further, ask for help, or defer.

---

### Phase 4: Implementation

Fix the root cause that was identified. Not the symptom.

#### 1. Write a Failing Test First

Before applying the fix, write a test that reproduces the bug. Follow the `sdlc:writing-tests` skill.

The test must:

- Reproduce the exact failure described in the bug
- Fail before the fix is applied
- Pass after the fix is applied

This proves the fix addresses the problem and prevents regression.

#### 2. Apply a Single Fix

Implement the fix for the identified root cause. One change. No opportunistic improvements. No "while I'm here" refactoring.

Each additional change introduces a new variable that makes it harder to verify what solved the problem.

#### 3. Verify the Fix

Run the test written in step 1:

- The test passes
- All previously passing tests still pass
- The original issue is resolved

#### 4. If the Fix Does Not Work

Stop. Do not attempt another fix immediately.

Reassess:

- What new information does this failed fix provide?
- Is the hypothesis wrong, or was the implementation of the fix wrong?
- Return to Phase 1 with the new information

Count how many fixes have been attempted.

**If three or more fixes have been attempted without success:** Stop and question the architecture.

#### 5. When Three Fixes Fail: Question the Architecture

If three separate fixes have been attempted and the issue persists, the problem is likely architectural, not a simple bug.

Signs of an architectural problem:

- Each fix reveals a new problem in a different location
- Each fix attempt requires significant refactoring
- Each fix produces new symptoms elsewhere

Stop attempting more fixes. Discuss the architecture with your partner before proceeding. The question is not "what is the next fix?" but "is the current approach fundamentally sound?"

---

## Red Flags — Stop and Return to Phase 1

Stop immediately when any of these appear:

- "Quick fix for now, investigate later"
- "Just try changing X and see if it works"
- "Add multiple changes and run the tests"
- "I'll manually verify instead of writing a test"
- "It's probably X, let me fix that"
- "I don't fully understand it but this might work"
- "Here are the main problems" followed by a list of fixes without prior investigation
- Proposing solutions before tracing the data flow
- Attempting a fourth fix without stopping to question the architecture

All of these indicate Phase 1 was skipped or abandoned prematurely. Return to Phase 1.

---

## Common Rationalizations

| Rationalization | Reality |
|----------------|---------|
| "The issue seems simple, no need for the process" | Simple bugs have root causes too. The process is fast for simple bugs. |
| "Emergency — no time to investigate" | Systematic debugging is faster than guess-and-check. Guessing causes more downtime. |
| "Let me try this first, then investigate if it doesn't work" | The first attempt sets the pattern for the session. Start correctly. |
| "I'll write the test after confirming the fix works" | Untested fixes do not stick. Write the test first to prove the fix. |
| "Making multiple changes at once saves time" | It makes it impossible to isolate what worked or what broke something else. |
| "The reference is long, I'll adapt the pattern" | Partial pattern understanding guarantees bugs. Read it completely. |
| "I see the problem clearly, I can just fix it" | Seeing symptoms is not the same as understanding root cause. |
| "One more fix attempt" after two failures | After three failures, the problem is architectural. Stop and discuss. |

---

## Quick Reference

| Phase | Key Activities | Exit Criteria |
|-------|---------------|---------------|
| 1. Root Cause | Read errors fully, reproduce consistently, check recent changes, gather evidence, trace data flow | Root cause understood: the specific location and reason for the failure |
| 2. Pattern Analysis | Find working examples, read references completely, identify differences | Differences between working and broken are enumerated |
| 3. Hypothesis | Form a single specific hypothesis, test with one minimal change | Hypothesis confirmed or refuted with evidence |
| 4. Implementation | Write failing test, apply single fix, verify all tests pass | Root cause fixed, regression test passes, no new failures |

---

## When Investigation Yields No Root Cause

If systematic investigation reveals the issue is environmental, timing-dependent, or external and genuinely cannot be pinpointed:

1. Document what was investigated and what was ruled out
2. Implement appropriate handling (retry logic, timeout, user-facing error message)
3. Add logging and monitoring to capture future occurrences

Note: 95% of "no root cause found" conclusions are the result of incomplete investigation. Exhaust all available investigation methods before concluding a root cause cannot be found.

---

## Supporting Techniques

Apply these techniques within Phase 1 when relevant:

**Backward tracing:** When the error is deep in a call stack, trace backward to find the original trigger. Start at the failure. Ask what called the failing code. Ask what passed the bad value. Keep tracing until the origin is found. Fix at the origin.

**Defense-in-depth:** After the root cause is fixed, add validation at multiple layers to prevent the same class of error from silently propagating in the future.

**Condition-based waiting:** When dealing with race conditions or timing issues, replace arbitrary sleep or timeout values with condition polling. Test that the condition is actually met before proceeding.
