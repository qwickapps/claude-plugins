---
name: parallelizing-work
description: This skill should be used when facing two or more independent failures, investigations, or tasks that can be worked on concurrently without shared state or sequential dependencies. Trigger phrases include "multiple failures", "independent problems", "investigate in parallel", "dispatch agents", "parallel investigation", and "concurrent investigation".
---

# Parallelizing Work

When multiple independent problems exist, dispatch one Task subagent per problem domain and let them work concurrently. Collecting results from parallel subagents takes the same wall-clock time as investigating one problem sequentially.

Core principle: independent problems deserve independent agents working simultaneously, not a queue.

## When to Use

Apply this skill when all three conditions are true:

1. Two or more distinct failures, bugs, or investigation areas exist
2. Each problem is independent: understanding or fixing one does not require context from another
3. Agents can work without interfering: they are not editing the same files or writing to the same shared state

Do not apply this skill when:
- Failures are related and fixing one may fix the others
- The full system state must be understood before any single problem makes sense
- Agents would edit the same files, run the same database migrations, or compete for the same resources
- The scope is exploratory and the problem domains are not yet identified

## Decision Tree

```
Multiple failures or investigation areas?
  No  -> Single agent handles the work sequentially
  Yes -> Are they independent?
           No  -> Investigate together; fixing one may fix others
           Yes -> Can they work without shared state?
                    No  -> Use sequential agents to avoid conflicts
                    Yes -> Dispatch in parallel (this skill)
```

## What "Independent" Means

Two problems are independent when:
- Fixing problem A does not change whether problem B exists
- Understanding problem A does not require knowing the root cause of problem B
- An agent working on A does not need to touch the files an agent working on B will touch

Two problems are NOT independent when:
- They share a common root cause (one fix resolves both)
- They involve the same code path or data structure
- One agent's changes would invalidate or conflict with another's

When in doubt, investigate one problem to confirm independence before dispatching parallel agents.

## The Pattern

### Step 1: Identify Independent Domains

Group the failures or tasks by what is actually broken. Each group becomes one agent's scope.

Example grouping:
- Domain A: Authentication token expiry logic (3 test failures)
- Domain B: Batch job completion event handling (2 test failures)
- Domain C: File upload size validation (1 test failure)

Each domain is self-contained. Fixing token expiry logic has no bearing on batch job events.

### Step 2: Write Focused Agent Prompts

Each agent prompt must be:

**Focused.** One domain, one clear goal. Agents that receive broad scope lose time deciding where to start.

**Self-contained.** Include all context the agent needs: the specific test names or error messages, the relevant file paths, what the expected behavior should be. Do not tell agents to go discover the problem themselves when the problem is already known.

**Specific about output.** State exactly what the agent should return: a summary of root cause, what was changed, which tests now pass, and the commit SHA if the agent is fixing rather than investigating.

**Constrained.** Specify what the agent must not touch. If the agent is fixing test file A, tell it explicitly not to modify production code outside that domain.

### Step 3: Dispatch in Parallel

Issue all Task tool calls in a single message. Do not wait for agent 1 to return before dispatching agent 2. All agents start at the same time.

```
[Single message containing:]
Task tool call -> Agent 1: Fix authentication token expiry failures
Task tool call -> Agent 2: Fix batch job completion event failures
Task tool call -> Agent 3: Fix file upload validation failures
```

All three run concurrently. Total elapsed time equals the longest single investigation, not the sum of all three.

### Step 4: Collect and Synthesize Results

When all agents return, read each summary in turn:

- What root cause did the agent find?
- What changes did the agent make?
- Which tests now pass?
- Did the agent encounter any unexpected scope (related problems it noticed but was told not to fix)?

Check for conflicts: did any two agents edit the same file? If so, review those files for merge issues before continuing.

Run the full test suite to verify all fixes work together. Parallel agents can each produce locally correct fixes that interact unexpectedly at integration.

Synthesize findings into a single summary for the current session before deciding next steps.

## Writing Good Agent Prompts

### Structure

```
[Domain description and scope boundary]

[Specific failures to fix or questions to answer, listed precisely]

[Relevant file paths and context]

[What the agent must not change]

[What to return when done]
```

### Example: Investigation Agent

```
Investigate the 3 failing tests in src/auth/token-expiry.test.ts:

1. "should reject expired tokens after 1 hour" - fails with "token still valid"
2. "should refresh tokens within grace period" - fails with TypeError on line 47
3. "should invalidate refresh tokens on logout" - fails with "token still active"

These are in the authentication subsystem. Relevant files:
- src/auth/token-expiry.ts (token validation logic)
- src/auth/token-expiry.test.ts (the failing tests)

Do NOT change any other files.

Return: root cause of each failure, whether it is a test bug or production bug, and your recommended fix.
```

### Example: Fix Agent

```
Fix the 2 failing tests in src/jobs/batch-completion.test.ts:

1. "should emit completion event when all jobs finish" - event not firing
2. "should handle partial batch completion" - expects 3 results, gets 0

Root cause is likely in the event emission logic in src/jobs/batch-runner.ts.

Relevant files:
- src/jobs/batch-runner.ts
- src/jobs/batch-completion.test.ts

Do NOT change unrelated job types or the queue implementation.

Return: what you changed, why, and the commit SHA.
```

## Common Mistakes

**Too broad a scope.** "Fix all the failing tests" gives the agent no focus. The agent wastes time triaging rather than fixing. Provide the specific test names and files.

**No context about expected behavior.** "Fix the race condition" leaves the agent guessing what the correct behavior should be. Include what the test expects and what it currently gets.

**No output constraints.** Without telling an agent what not to change, it may refactor broadly. Specify scope boundaries explicitly.

**Dispatching sequentially when parallel is possible.** Reading one agent's result before dispatching the next forfeits the time benefit. Dispatch all parallel-eligible agents in one message.

**Assuming independence without verifying.** If two failures share a common subsystem, check whether they share a root cause before splitting them across agents. A shared root cause means one fix handles both; two agents working in parallel may produce conflicting solutions to the same underlying problem.

## When Not to Use

**Exploratory debugging.** When the source of failures is unknown, a single agent should survey the landscape first. Use parallel dispatch after the problem domains are identified, not before.

**Shared file editing.** If two agents would need to edit the same file, they will produce conflicting changes. Handle these sequentially or decompose the task so each agent owns a distinct file set.

**Related failures.** If fixing the authentication middleware might resolve both the token failures and the session failures, investigate the middleware first. Parallel agents on related failures duplicate work and may produce redundant or conflicting fixes.

**Post-refactoring sweep.** After a large refactoring, failures across multiple files often share one root cause. Diagnose the refactoring impact first; only parallelize once independent domains are confirmed.

## Integration and Synthesis

After parallel agents return:

1. Review each agent's summary for unexpected scope creep or noted-but-unfixed problems.
2. Run the full test suite, not just the targeted tests. Adjacent behavior may have changed.
3. If agents flagged related problems outside their scope, decide whether to address them now or track them as follow-up.
4. Record the root causes found. Independent failures across domains often reveal systemic patterns worth noting in a follow-up design review.

## Integration with Other Skills

- **qwickapps-sdlc:delegating-tasks** -- Use when executing an ordered implementation plan rather than investigating independent failures. Tasks in a plan are sequential; use delegating-tasks. Failures after a test run are often independent; use parallelizing-work.
- **qwickapps-sdlc:debugging** -- Use for a single complex failure requiring deep investigation. When that investigation reveals multiple independent root causes, switch to parallelizing-work.
- **qwickapps-sdlc:verifying-completion** -- After parallel agents return and fixes are integrated, use verifying-completion to confirm the overall solution is solid before closing out the branch.

## Example Session

**Scenario:** Six test failures across three files after a major refactoring of the event system.

**Failures observed:**

```
FAIL src/agents/agent-tool-abort.test.ts (3 failures)
  - should abort tool with partial output capture
  - should handle mixed completed and aborted tools
  - should properly track pendingToolCount

FAIL src/jobs/batch-completion-behavior.test.ts (2 failures)
  - should execute all batch jobs
  - should report final batch status

FAIL src/approvals/tool-approval-race-conditions.test.ts (1 failure)
  - should not double-execute approved tool
```

**Independence check:** Abort logic, batch completion, and approval race conditions are in separate subsystems with separate implementations. No shared root cause is apparent.

**Dispatch in parallel:**

```
Agent 1 -> Fix agent-tool-abort.test.ts (3 failures - likely timing issues)
Agent 2 -> Fix batch-completion-behavior.test.ts (2 failures - event structure)
Agent 3 -> Fix tool-approval-race-conditions.test.ts (1 failure - async timing)
```

**Results received:**

- Agent 1: Replaced arbitrary timeouts with event-based waiting. Committed.
- Agent 2: Fixed threadId placement in event payload. Committed.
- Agent 3: Added await for async tool execution before checking call count. Committed.

**Integration:** Full suite green. No conflicts between agent changes. Each fix was isolated to its domain.

**Time saved:** Three independent investigations completed in the elapsed time of one.
