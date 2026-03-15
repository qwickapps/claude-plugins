---
name: starting-sprint
description: >
  This skill should be used when beginning a new sprint cycle. Trigger phrases include:
  "start sprint", "begin sprint", "new sprint", "sprint kickoff", "let's plan this sprint",
  "what are we working on this sprint", "set up the sprint", "open the sprint". Auto-loads
  when any of these phrases are detected. Do not skip the handoff review step even when
  starting fresh with no prior sprint context.
---

# Starting a Sprint

Begin every sprint by reviewing the past before planning the future. Load what was learned,
assess what remains, set goals, and build a concrete backlog before writing a line of code.

**Core principle:** A sprint that begins without reviewing the previous sprint handoff repeats
the same mistakes and loses the same context.

---

## Sprint Kickoff Sequence

Execute these steps in order. Do not skip steps to save time. Each step informs the next.

```
Load previous handoff
        |
        v
Review open issues and PRs
        |
        v
Ask for sprint priorities
        |
        v
Build the sprint backlog
        |
        v
Identify blockers and dependencies
        |
        v
Document the sprint plan
```

---

## Step 1: Load Previous Sprint Handoff

The first action at sprint kickoff is always to retrieve the previous sprint's handoff document.
This document contains completed work, remaining issues, blockers, and lessons learned from the
last cycle.

Search for the handoff using `KB_SEARCH_DOCUMENTS`:
- query: "sprint handoff"

If a specific sprint number is known, retrieve it directly using `KB_GET_DOCUMENT`:
- key: "sprint-N-handoff"

Also search for any open issue context stored during the previous sprint using `KB_SEARCH_DOCUMENTS`:
- query: "issue context"

If no SOP plugin is configured, look for handoff documents in `docs/sprints/` in the repository.

**If no handoff document is found:**

This is acceptable for the first sprint or after a gap. Note explicitly that no prior handoff
was found. Do not invent context. Proceed to Step 2 with a clean slate and document this
situation in the sprint plan.

**If a handoff document is found:**

Read the entire document. Extract:

- Work completed in the last sprint (closed issues, merged PRs)
- Work that rolled over (open issues, unfinished tasks)
- Blockers that were present (resolved or still active)
- Lessons learned (what slowed the team down, what helped)
- Recommendations from the previous sprint (next priorities)

Present a summary to the user before proceeding.

---

## Step 2: Review Open Issues

After loading the handoff, inspect the current state of the repository's issue tracker. The
handoff document reflects the previous sprint's end state. Issues may have been added, closed,
or reprioritized since then.

```bash
# List all open issues, most recently created first
gh issue list --state open

# Filter by label to see breakdown
gh issue list --state open --label feature
gh issue list --state open --label bug
gh issue list --state open --label research
gh issue list --state open --label refactor
gh issue list --state open --label chore

# View a specific issue for detail
gh issue view <number>
```

Build a mental model of the full open issue list:

- How many open issues exist?
- Which were carried over from the previous sprint?
- Which are new since the last sprint ended?
- Which are marked with high-priority labels or mentioned in the handoff?

Present this overview to the user as part of the sprint planning conversation.

---

## Step 3: Review Open Pull Requests

Before adding new work to the sprint, check whether PRs from the previous sprint are still open
and need attention. Open PRs that sit unmerged block the team and accumulate merge conflicts.

```bash
# List all open PRs
gh pr list --state open

# View a specific PR for detail
gh pr view <number>
```

Flag any open PRs to the user:

- PRs awaiting review (need a reviewer assigned or review completed)
- PRs with review comments (need author response)
- PRs that are approved and ready to merge

Resolving open PRs before starting new work reduces context switching and keeps the codebase clean.

---

## Step 4: Ask for Sprint Priorities

Now that the past sprint context and current issue state are understood, ask the user for their
priorities for this sprint.

Ask one question at a time and wait for each answer before continuing.

**Question 1: Sprint goal**

"What is the primary goal for this sprint? What does success look like at the end?"

Wait for the answer. The sprint goal should be stated in user or business terms, not technical
terms. Examples:

- "Users can complete the checkout flow without errors"
- "The admin dashboard loads in under 2 seconds for all data ranges"
- "Background email notifications are live in production"

**Question 2: Capacity**

"How many working days does the team have this sprint? Are there any planned absences or
blockers that will reduce capacity?"

Use this to calibrate how much work can realistically be committed to.

**Question 3: Priorities**

"Given the open issues, which ones are highest priority for this sprint? Are there any that
are hard requirements versus nice-to-have?"

The user may name specific issues by number, by title, or by label. Clarify until each
priority is unambiguous.

**Question 4: Deferrals**

"Are there any open issues that should explicitly NOT be worked on this sprint, even if they
look high priority?"

Sometimes issues are blocked on external dependencies or decisions. Surfacing these explicitly
avoids picking them up accidentally.

---

## Step 5: Build the Sprint Backlog

Using the priorities from Step 4, build the sprint backlog as a concrete list of tasks. Each
issue to be worked on this sprint becomes one or more tasks.

For each issue in the sprint:

1. Read the full issue:
   ```bash
   gh issue view <number>
   ```

2. Break it into discrete implementation tasks using TaskCreate. Tasks should be 2-5 minutes of
   focused work each. Larger units of work become difficult to track and review.

3. Set the task description to reference the issue number and the specific subtask.

Example task breakdown for issue #42 (user authentication):

```
TaskCreate: "Issue #42 - Create JWT session service (src/services/session.ts)"
TaskCreate: "Issue #42 - Add login route handler (src/routes/auth.ts)"
TaskCreate: "Issue #42 - Add logout route handler (src/routes/auth.ts)"
TaskCreate: "Issue #42 - Add JWT verification middleware (src/middleware/authenticate.ts)"
TaskCreate: "Issue #42 - Write tests for session service"
TaskCreate: "Issue #42 - Write tests for auth routes"
TaskCreate: "Issue #42 - Write tests for auth middleware"
TaskCreate: "Issue #42 - Verify E2E: login/logout flow works in browser"
```

Do not add tasks for work not tied to a specific issue. If new work surfaces during task
breakdown, create the issue first (tracking-issues skill) and then add tasks.

---

## Step 6: Identify Blockers and Dependencies

Before finalizing the sprint plan, surface blockers and dependencies explicitly.

**Blockers:** Issues that cannot be started because something external must happen first.

Examples:
- Waiting on design approval for a new screen
- Waiting on an API contract from another team
- A dependency that has not been updated to a compatible version

**Dependencies:** Issues that must be completed in a specific order because one depends on the
other.

Example:
- The auth middleware (task B) cannot be implemented until the session service (task A) is
  complete, because the middleware imports the session service.

List all blockers and dependencies explicitly in the sprint plan document. For each blocker,
note:

- What is blocking
- Who or what can unblock it
- What action is required
- When the blocker is expected to be resolved

---

## Step 7: Document the Sprint Plan

After the backlog is built and blockers are identified, store the sprint plan.
This document is referenced throughout the sprint and used to generate the closing-sprint
handoff at the end.

Store the sprint plan using `KB_CREATE_DOCUMENT`:
- type: `DOC_TYPE_SPIKE`
- title: "Sprint N Plan"
- labels: ["sprint-plan", "sprint-N"]
- content: [the plan document below]

If no SOP plugin is configured, save to `docs/sprints/sprint-N-plan.md` in the repository.

```
# Sprint N Plan

**Date:** YYYY-MM-DD
**Sprint goal:** [Statement from the user]
**Capacity:** [Working days / team members / known absences]

## Previous Sprint Summary
[Key points from the handoff document, or "No prior handoff found"]

## Open Issues at Sprint Start
[List with issue numbers, titles, and labels]
- #42 feature: Add user authentication flow
- #38 bug: Cart total does not update on quantity change
- #51 chore: Update all dependencies to latest minor versions

## Open PRs at Sprint Start
[List with PR numbers, titles, and current state]
- PR #45: feat(api): add product search endpoint — Awaiting review

## Sprint Backlog
[Issues committed to this sprint with their tasks]

### #42 - Add user authentication flow (feature)
- [ ] Create JWT session service
- [ ] Add login route handler
- [ ] Add logout route handler
- [ ] Add JWT verification middleware
- [ ] Write tests for session service
- [ ] Write tests for auth routes
- [ ] Write tests for auth middleware
- [ ] Verify E2E: login/logout flow in browser

### #38 - Fix cart total bug (bug)
- [ ] Reproduce bug and identify root cause
- [ ] Write failing regression test
- [ ] Fix root cause
- [ ] Verify test passes and E2E behavior is correct

## Blockers
[Issues that cannot start due to external dependencies]
- #51 chore: Blocked on confirming no breaking changes in the pnpm 9 upgrade.
  Owner: Raaj. Expected resolution: by Wednesday.

## Dependencies
[Task ordering constraints within the sprint]
- Auth middleware depends on session service being complete.

## Not in Sprint (Explicit Deferrals)
[Issues that were explicitly deferred]
- #47 feature: Dashboard analytics — Deferred to next sprint. Awaiting design approval.

## Sprint Priorities (in order)
1. #38 bug (blocking user checkout, high urgency)
2. #42 feature (sprint goal requirement)
3. #51 chore (low effort, high value)
```

After storing the plan, confirm with the user that the plan is accurate and complete before
beginning any implementation.

---

## Step 8: Present Sprint Summary to User

Before leaving sprint kickoff mode, present a compact summary of the sprint plan to the user
for final confirmation.

Cover:
- Sprint goal (one sentence)
- Total issues committed this sprint (count and list)
- Total tasks created
- Known blockers (and who owns resolving them)
- Open PRs needing attention before new work begins
- What is explicitly out of scope this sprint

Ask: "Does this sprint plan look accurate? Should I adjust anything before we start?"

Wait for confirmation before marking the kickoff complete.

---

## Verification Checklist

Before declaring sprint kickoff complete:

- [ ] Previous sprint handoff loaded from knowledge base (or no-handoff documented)
- [ ] Open issues reviewed in full (all labels)
- [ ] Open PRs reviewed and flagged to user
- [ ] Sprint goal captured from user (one sentence, outcome-focused)
- [ ] Capacity noted (working days, absences)
- [ ] Priorities confirmed (explicit ordering)
- [ ] Explicit deferrals noted (what is NOT in scope)
- [ ] Sprint backlog built (one TaskCreate per subtask per issue)
- [ ] Blockers identified and noted with owners
- [ ] Dependencies between tasks identified
- [ ] Sprint plan document stored in knowledge base as `sprint-N-plan`
- [ ] Summary presented to user and confirmed

If any item is unchecked, complete it before beginning implementation work.

---

## Common Mistakes

**Skipping the handoff review**

The previous sprint's lessons and rollover items are the most relevant input to the current
sprint. Skipping the handoff leads to repeating mistakes and losing track of work in progress.

**Starting work before priorities are confirmed**

Building the backlog before asking for priorities produces a backlog that does not reflect
what the user actually wants this sprint. Ask first.

**Not documenting blockers**

Undocumented blockers cause surprise mid-sprint when work cannot proceed. Surface them at
kickoff so they can be resolved early.

**Adding tasks without issue references**

Every task in the backlog must trace to an issue. Untracked work cannot be closed, reported,
or retrospected on. Create the issue first.

**Setting tasks that are too large**

Tasks that represent hours of work are not tasks — they are mini-features. Break them down.
Tasks should represent 2-5 minutes of focused, verifiable work.
