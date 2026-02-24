---
name: closing-sprint
description: >
  This skill should be used when ending a sprint cycle and generating a handoff document for
  the next sprint. Trigger phrases include: "close sprint", "end sprint", "sprint review",
  "sprint wrap-up", "sprint retrospective", "finish the sprint", "wrap up this sprint",
  "let's close out the sprint", "sprint is over". Auto-loads when any of these phrases are
  detected. Always produce a handoff document stored in QwickBrain before declaring the
  sprint closed.
---

# Closing a Sprint

End every sprint by capturing what was accomplished, what rolled over, what blocked progress,
and what the team learned. Store this knowledge in QwickBrain so the next sprint can start
from an informed position.

**Core principle:** A sprint that ends without a handoff document loses its lessons and forces
the next sprint to rediscover them.

---

## Sprint Closure Sequence

Execute these steps in order. Do not skip steps to reach the handoff document faster. Each step
produces the evidence that makes the handoff accurate.

```
Review completed tasks
        |
        v
Review merged PRs
        |
        v
Review remaining open issues
        |
        v
Ask for lessons learned and retro notes
        |
        v
Update GitHub project board (if applicable)
        |
        v
Create and store handoff document
        |
        v
Confirm with user
```

---

## Step 1: Review Completed Tasks

Begin by reviewing all tasks that were completed this sprint. This provides the raw material for
the "completed work" section of the handoff.

List completed tasks:

```
TaskList (filter: completed)
```

For each completed task, note:

- The task description
- The issue it was tied to
- Any significant decisions or implementation notes worth preserving

If QwickBrain context entries were stored during the sprint, retrieve them now. They contain
investigation findings, decisions, and notes that belong in the handoff.

```
mcp__qwickbrain__search_memories:
  query: "issue context"
```

Retrieve each relevant memory:

```
mcp__qwickbrain__get_memory:
  name: "issue-42-context"
```

---

## Step 2: Review Merged PRs

Check which PRs were merged during this sprint. Merged PRs represent completed and integrated
work.

```bash
# List PRs merged recently (adjust date as needed)
gh pr list --state merged --limit 20

# View a specific PR for detail
gh pr view <number>
```

For each merged PR, note:

- PR number and title
- The issue it closed
- The commit SHA of the merge

Also check whether any PRs from the sprint are still open. Open PRs at sprint end roll over
to the next sprint as the first priority.

```bash
# List open PRs
gh pr list --state open
```

Flag open PRs explicitly. They are not completed work — they are in-progress work that requires
attention at the start of the next sprint.

---

## Step 3: Review Remaining Open Issues

After confirming what was merged, examine what was not. Review the full list of open issues to
determine which ones rolled over from this sprint's backlog versus which ones are newly opened.

```bash
# All open issues
gh issue list --state open

# Filter by label
gh issue list --state open --label feature
gh issue list --state open --label bug
gh issue list --state open --label research
gh issue list --state open --label refactor
gh issue list --state open --label chore
```

For each open issue that was in the sprint backlog, note:

- Was it started but not finished, or never started?
- Is there a specific reason it was not completed (blocker, scope change, deprioritized)?
- Should it roll over to the next sprint, or should it be closed or deferred?

Ask the user about any open issues that are ambiguous:

"Issue #47 (dashboard analytics) was in the sprint but not completed. Should it roll over to
the next sprint, or should we close/defer it?"

Do not make rollover decisions unilaterally. The user decides what carries forward.

---

## Step 4: Ask for Lessons Learned and Retrospective Notes

The most valuable part of sprint closure is capturing what the team learned. Ask the user for
their retrospective input.

Ask one question at a time and wait for each answer before continuing.

**Question 1: What went well?**

"What went well this sprint? What helped the team move faster or produce better work?"

Wait for the answer. Examples of things that go well:

- A particular workflow or tool that saved time
- A decision that was made correctly early and prevented rework
- A team coordination pattern that improved quality

**Question 2: What did not go well?**

"What slowed the team down or caused rework this sprint?"

Wait for the answer. Examples of things that do not go well:

- Scope that expanded mid-sprint without issue creation
- Blockers that were not surfaced early enough
- PRs that sat open for too long due to missing review assignments
- Tests that were skipped and caused a regression

**Question 3: What should change?**

"Given what did not go well, what should we do differently next sprint?"

Wait for the answer. Specific, actionable process changes are more valuable than vague
commitments. Examples:

- "Assign a reviewer at the time the PR is opened, not after the first review cycle"
- "Create QwickBrain context entries at the start of every issue, not only on complex ones"
- "Surface blockers in the issue tracker the same day they are discovered"

**Question 4: What is the top recommendation for next sprint?**

"If you had to give one piece of advice to the version of us starting next sprint, what would
it be?"

This produces the highlight that appears first in the handoff document's lessons section.

---

## Step 5: Update GitHub Project Board

If the repository uses a GitHub project board to track sprint status, update it to reflect
the sprint's close.

```bash
# List open project items (if applicable)
gh project list --owner <org-or-user>

# View project items
gh project item-list <project-number> --owner <org-or-user>
```

Move completed issues to the appropriate column (Done, Closed, Shipped — whatever the project
uses). Move rolled-over issues back to the Backlog or To Do column so they appear correctly
at the start of the next sprint.

If no GitHub project board is in use, skip this step and note that in the handoff document.

---

## Step 6: Create and Store the Handoff Document

With all the evidence gathered, create the sprint handoff document and store it in QwickBrain.
This document is the primary input to the next sprint's kickoff (starting-sprint skill, Step 1).

```
mcp__qwickbrain__create_document:
  name: "sprint-N-handoff"
  doc_type: "memory"
  content: |
    # Sprint N Handoff

    **Sprint:** N
    **Close date:** YYYY-MM-DD
    **Sprint goal:** [Original goal from the sprint plan]
    **Goal achieved:** [Yes / Partially / No — with brief explanation]

    ## Completed Work

    ### Closed Issues
    - #42 feature: Add user authentication flow — Merged in PR #45 (abc1234)
    - #38 bug: Fix cart total not updating on quantity change — Merged in PR #46 (def5678)
    - #51 chore: Update dependencies to latest minor versions — Merged in PR #47 (ghi9012)

    ### Merged PRs
    - PR #45: feat(auth): implement JWT-based authentication flow — Closes #42
    - PR #46: fix(cart): correct quantity change total calculation — Closes #38
    - PR #47: chore: update all workspace dependencies — Closes #51

    ## Rolled Over Work

    ### Open Issues (in sprint backlog but not completed)
    - #47 feature: Dashboard analytics — Not started. Awaiting design approval from
      design team. Expected delivery of designs: next Monday. Recommend picking up early
      next sprint once designs are ready.

    ### Open PRs (still awaiting merge)
    - PR #48: refactor(products): extract product search into service — Awaiting review.
      Author: Raaj. Reviewer: needs assignment. Priority: merge early next sprint.

    ## Blockers This Sprint

    ### Resolved Blockers
    - #51 chore: Was blocked on confirming pnpm 9 compatibility. Resolved Tuesday.
      pnpm 9 is compatible. No breaking changes observed.

    ### Active Blockers (carrying into next sprint)
    - #47 feature: Blocked on design approval. Owner: design team. ETA: next Monday.

    ## Key Decisions Made This Sprint

    - Chose JWT over session-based auth based on stateless API requirements.
      Evidence stored in: issue-42-context (QwickBrain). ADR created: ADR-007.
    - Cart total fix was a UI state bug, not a backend issue. No API changes needed.
      Root cause: React state not triggering re-render on quantity change.
      Fixed at: src/components/Cart/CartItem.tsx:47.

    ## Lessons Learned

    ### What went well
    - Setting up QwickBrain context entries at issue start made resuming sessions fast.
    - Writing the regression test for #38 before the fix caught two edge cases that
      were not in the original bug report.

    ### What did not go well
    - PR #48 has been open since Tuesday without a reviewer assigned. Open PRs that sit
      unreviewed block context switching to other issues.
    - Scope on #42 expanded mid-sprint when the admin role requirement was discovered.
      Should have created a separate issue for the role-based access control layer.

    ### What to change next sprint
    - Assign a reviewer at the time the PR is opened, not after the first review cycle.
    - When scope expands during implementation, stop and create a new issue before
      continuing. Do not absorb expanded scope silently.

    ## Top Recommendation for Next Sprint

    Assign reviewers when PRs are opened. The PR #48 delay cost one full day of
    unblocking time. A 30-second reviewer assignment prevents the bottleneck.

    ## Metrics

    - Issues completed: 3
    - Issues rolled over: 1
    - PRs merged: 3
    - PRs open at close: 1
    - Blockers surfaced: 1 (resolved), 1 (active)
```

Also store a short memory entry pointing to the handoff document for easy search retrieval:

```
mcp__qwickbrain__set_memory:
  name: "sprint-N-summary"
  content: |
    Sprint N closed YYYY-MM-DD.
    Goal: [one sentence]
    Completed: #42, #38, #51
    Rolled over: #47 (blocked on design), PR #48 (awaiting review)
    Handoff: sprint-N-handoff (QwickBrain memory)
    Top lesson: Assign reviewers when PRs are opened.
```

---

## Step 7: Confirm with User

After storing the handoff document, present a compact summary to the user and ask for
confirmation.

Cover:
- Sprint goal achievement (yes, partially, or no)
- Total issues completed (count and list)
- Total PRs merged (count)
- Rolled-over items (issues and PRs)
- Active blockers carrying forward
- Top recommendation for next sprint
- Location of the full handoff (QwickBrain: sprint-N-handoff)

Ask: "Does this sprint summary look accurate? Is there anything missing before I mark the
sprint closed?"

Wait for confirmation. Apply any corrections, update the handoff document, and confirm the
sprint is closed.

---

## Closing Issue Cleanup

After the sprint is confirmed closed, verify that all completed issues have been closed in
GitHub. Merged PRs with `Fixes #N` in the body close issues automatically. Verify this is
the case.

```bash
# Verify issue is closed
gh issue view 42

# If not closed automatically, close manually
gh issue close 42 --comment "Fixed in PR #45 (abc1234). JWT auth flow live on staging."
```

Do not leave issues open that represent completed work. Open issues that represent resolved
problems pollute the backlog and make the next sprint's planning harder.

---

## Verification Checklist

Before declaring sprint closure complete:

- [ ] Completed tasks reviewed (TaskList)
- [ ] QwickBrain context entries retrieved for all active issues
- [ ] Merged PRs listed with issue references
- [ ] Open PRs identified and flagged for rollover
- [ ] Open issues reviewed for rollover or deferral decisions
- [ ] User consulted on ambiguous rollover decisions
- [ ] Lessons learned captured (what went well, what did not, what changes)
- [ ] GitHub project board updated (or skipped with reason noted)
- [ ] Handoff document created in QwickBrain as `sprint-N-handoff`
- [ ] Summary memory stored as `sprint-N-summary`
- [ ] Summary presented to user and confirmed
- [ ] All completed issues verified as closed in GitHub

If any item is unchecked, complete it before declaring the sprint closed.

---

## Common Mistakes

**Creating the handoff document without asking for retrospective input**

A handoff document written without the user's retrospective input reflects only the work that
was done, not the lessons. Lessons learned are the most valuable part of the handoff for the
next sprint. Always ask before writing the document.

**Leaving open issues from completed work**

Issues that represent work that has been merged and verified should be closed. Open issues
create backlog noise and make sprint planning harder. Close them explicitly if GitHub did not
do it automatically.

**Vague lessons learned sections**

"Communication could be better" is not actionable. "Assign a reviewer at the time the PR is
opened" is actionable. Push for specific, concrete lessons. Vague retrospective notes produce
no behavior change.

**Not storing the handoff in QwickBrain**

A handoff document that exists only in a conversation context disappears between sessions. The
QwickBrain entry is the persistent record that the starting-sprint skill reads at the next
kickoff. If it is not stored, the next sprint starts blind.

**Making rollover decisions without user input**

Do not silently carry issues forward or silently close them. Present each ambiguous issue to
the user and wait for an explicit decision. The user knows the business context for whether
work should continue, defer, or be dropped.
