---
name: writing-tests
description: >
  This skill should be used when implementing any new feature, fixing any bug, or changing existing
  behavior. Invoke before writing a single line of implementation code. Trigger phrases include:
  "add a feature", "fix this bug", "implement X", "write code for", "update the logic", "make this
  work", "change how X behaves". The RED-GREEN-REFACTOR cycle is non-negotiable. No production code
  may exist without a failing test that was written and observed to fail first.
---

# Writing Tests (Test-Driven Development)

Write the test first. Watch it fail. Write minimal code to pass. Watch it pass. Refactor. Repeat.

**Core principle:** If the test was not watched to fail, it does not prove the implementation is correct.

---

## The Iron Law

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

If code was written before the test, delete it. Start over from a failing test.

Rules for deletion:

- Do not keep the premature code as a "reference"
- Do not "adapt" it while writing the tests alongside it
- Do not look at it while implementing
- Delete means delete

Implement fresh from the tests. No exceptions.

---

## When to Apply

Apply this skill for:

- New features
- Bug fixes
- Behavior changes
- Refactoring with behavioral impact

**Exceptions — consult the team before skipping:**

- Throwaway prototypes that will be discarded
- Generated or scaffolded code (migrations, boilerplate)
- Pure configuration files with no logic

The thought "I'll skip TDD just this once" is rationalization. Stop. Write the test first.

---

## The RED-GREEN-REFACTOR Cycle

Every unit of work follows this sequence. Do not skip steps or reorder them.

### RED: Write a Failing Test

Write one minimal test that describes the desired behavior. The test must reference code that does not exist yet or behavior that is not yet implemented.

Requirements for a good failing test:

- Tests one behavior only. If "and" appears in the test name, split it into two tests.
- Has a clear, descriptive name that states what the code should do
- Tests real behavior, not implementation details or mock internals
- Is as simple as possible

**Good example:**

```typescript
test('retries a failed operation exactly 3 times before succeeding', async () => {
  let attempts = 0;
  const operation = () => {
    attempts++;
    if (attempts < 3) throw new Error('temporary failure');
    return 'success';
  };

  const result = await retryOperation(operation);

  expect(result).toBe('success');
  expect(attempts).toBe(3);
});
```

This test has a clear name, tests real behavior, and exercises exactly one thing.

**Bad example:**

```typescript
test('retry works', async () => {
  const mock = jest.fn()
    .mockRejectedValueOnce(new Error())
    .mockRejectedValueOnce(new Error())
    .mockResolvedValueOnce('success');
  await retryOperation(mock);
  expect(mock).toHaveBeenCalledTimes(3);
});
```

This test has a vague name and tests mock call count instead of real behavior.

### Verify RED: Watch It Fail

**This step is mandatory. Never skip it.**

Run the test and confirm the failure:

```bash
npm test path/to/the.test.ts
```

Confirm three things:

1. The test fails (not errors out due to syntax or import problems)
2. The failure message is the expected one (feature missing, assertion failed)
3. The test fails because the feature does not exist yet — not because of a typo or wrong import

**If the test passes immediately:** The test is covering existing behavior or is written incorrectly. Fix the test before proceeding.

**If the test errors:** Fix the error (syntax, missing import, wrong test setup) and re-run until it fails correctly.

A test that has never been seen to fail has not proven it detects bugs.

### GREEN: Write Minimal Code to Pass

Write the simplest possible implementation that makes the failing test pass. Nothing more.

**Good example:**

```typescript
async function retryOperation<T>(fn: () => Promise<T>): Promise<T> {
  for (let i = 0; i < 3; i++) {
    try {
      return await fn();
    } catch (e) {
      if (i === 2) throw e;
    }
  }
  throw new Error('unreachable');
}
```

This is the minimum code required. It passes the test.

**Bad example:**

```typescript
async function retryOperation<T>(
  fn: () => Promise<T>,
  options?: {
    maxRetries?: number;
    backoff?: 'linear' | 'exponential';
    onRetry?: (attempt: number) => void;
    timeout?: number;
  }
): Promise<T> {
  // ... full implementation with unneeded flexibility
}
```

This is over-engineered. No test requires `backoff` or `onRetry`. Do not add features the tests do not demand.

Do not refactor other code during the GREEN phase. Do not improve unrelated areas. Make the test pass. Stop.

### Verify GREEN: Watch It Pass

**This step is mandatory.**

Run the full test suite:

```bash
npm test path/to/the.test.ts
```

Confirm:

- The new test passes
- All previously passing tests still pass
- Output contains no unexpected errors or warnings

**If the new test still fails:** Fix the implementation. Do not modify the test to match wrong behavior.

**If other tests now fail:** Fix them before proceeding. Do not leave regressions.

### REFACTOR: Improve Without Changing Behavior

After all tests are green, improve the code:

- Remove duplication
- Improve naming
- Extract helpers or modules
- Consolidate related logic

Rules for refactoring:

- Do not add new behavior during refactoring
- Run the test suite after every non-trivial change
- If tests go red, fix the regression immediately before continuing

After refactoring, return to RED for the next behavior.

---

## Characteristics of a Good Test Suite

| Quality | Correct | Incorrect |
|---------|---------|-----------|
| Minimal scope | One assertion per test name | `test('validates email and trims whitespace and checks domain')` |
| Clear names | Name states expected behavior | `test('test1')`, `test('works correctly')` |
| Real behavior | Exercises actual logic | Tests mock call counts without real logic |
| Edge cases covered | Null, empty, boundary inputs tested | Only the happy path |

---

## Applying TDD to Bug Fixes

Every bug fix must follow the same cycle.

**Bug:** Empty email address is accepted by the form submission handler.

**RED — write the failing test:**

```typescript
test('rejects an empty email address', async () => {
  const result = await submitForm({ email: '' });
  expect(result.error).toBe('Email is required');
});
```

**Verify RED — run the test, confirm it fails:**

```bash
$ npm test
FAIL: expected "Email is required", received undefined
```

**GREEN — minimal fix:**

```typescript
function submitForm(data: FormData) {
  if (!data.email?.trim()) {
    return { error: 'Email is required' };
  }
  // ...existing logic
}
```

**Verify GREEN — run the test, confirm it passes:**

```bash
$ npm test
PASS (24/24)
```

**REFACTOR — extract if other fields need the same pattern:**

```typescript
function requireField(value: string | undefined, label: string) {
  if (!value?.trim()) return { error: `${label} is required` };
  return null;
}
```

The test now serves as a regression guard. The bug cannot return without the test catching it.

---

## Why Order Matters

**"I will write tests after to confirm it works"**

Tests written after implementation pass immediately. Passing immediately proves nothing:

- The test may test what was built, not what is required
- Edge cases discovered during implementation may not appear in after-the-fact tests
- The test was never seen to catch the bug it was supposed to prevent

Tests written first are forced to fail, which proves they detect missing behavior.

**"I already manually tested the edge cases"**

Manual testing is ad-hoc. It has no record, cannot be re-run automatically, and degrades as code changes. Automated tests run the same way every time. Manual verification of the same change is required on every future modification.

**"Deleting hours of work is wasteful"**

The time already spent is gone regardless. The choice now is:

- Delete and implement with TDD (more hours, high confidence, few bugs)
- Keep untested code and add tests after (less time, low confidence, hidden bugs)

Keeping code that has no failing test behind it is not an asset. It is technical debt with unknown defects.

**"TDD slows me down"**

TDD is faster than the alternative when the full cycle is counted: implementation plus debugging plus regressions. Tests written first find bugs before commit. Tests written after find bugs in production.

---

## Common Rationalizations

| Rationalization | Reality |
|----------------|---------|
| "Too simple to need a test" | Simple code breaks. The test takes 30 seconds to write. |
| "I'll add tests after" | Tests that pass immediately do not prove the code is correct. |
| "Manual testing covered it" | Manual tests are not reproducible. They degrade over time. |
| "Deleting X hours of work is wasteful" | Sunk cost. Untested code is technical debt with hidden defects. |
| "Keep the code as a reference, then write tests first" | You will adapt the existing code. That is testing after. Delete it. |
| "Need to explore the problem space first" | Fine. Throw away the exploration. Start the implementation with TDD. |
| "The test is hard to write" | Listen to the test. Hard to test means hard to use. Simplify the interface. |
| "TDD is dogmatic" | TDD finds bugs before commit, prevents regressions, and documents behavior. It is pragmatic. |

---

## Red Flags — Stop and Start Over

These situations indicate TDD was skipped. Stop. Delete the code. Start from a failing test.

- Implementation code was written before a test existed
- The test was written after the implementation
- The test passed on the first run without being expected to
- The reason the test failed cannot be explained
- "I'll add tests later" was said at any point
- The phrase "just this once" appeared
- "I already manually tested it" was used to justify skipping
- The code was kept as a "reference" while writing tests
- "Tests after achieve the same goals" was believed

---

## When Stuck

| Problem | Solution |
|---------|----------|
| Do not know how to write a test | Write the API call you wish existed. Write the assertion first. Consult the pair programming partner. |
| The test is too complicated to write | The design is too complicated. Simplify the interface before implementing. |
| Everything must be mocked | The code is too tightly coupled. Introduce dependency injection. |
| Test setup requires enormous scaffolding | Extract the scaffolding into helpers. If still complex, simplify the design. |

---

## Verification Checklist

Before marking any implementation complete:

- [ ] Every new function or method has at least one test
- [ ] Each test was watched to fail before implementation began
- [ ] Each failure was for the expected reason (missing feature, not syntax error)
- [ ] Minimal code was written to pass each test
- [ ] All tests pass after implementation
- [ ] No unexpected warnings or errors appear in test output
- [ ] Tests use real logic, not just mock call counts
- [ ] Edge cases and error paths are covered

If any item cannot be checked, TDD was skipped. Start over.
