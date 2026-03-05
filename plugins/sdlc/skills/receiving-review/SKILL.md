---
name: receiving-review
description: >
  This skill should be used when code review feedback has arrived and needs to be evaluated and
  acted upon. Load before implementing any suggestion from a reviewer. Trigger phrases include:
  "here is the review feedback", "the reviewer said", "address these review comments", "fix the
  review issues", "respond to this PR review", "the code review came back", "reviewer wants",
  "reviewer flagged", "implement the review suggestions", "fix items 1 through N". Also activate
  whenever feedback seems technically questionable or unclear, or when reviewer suggestions conflict
  with existing architectural decisions.
---

# Receiving Code Review

Verify feedback before implementing it. Understand before acting. Challenge what is technically
incorrect. The standard is correctness, not compliance.

**Core principle:** Feedback is a signal to evaluate, not an order to execute.

---

## The Response Pattern

When review feedback arrives, follow this sequence in order. Do not skip steps.

```
1. READ:      Complete all feedback before reacting to any of it
2. UNDERSTAND: Restate each item in technical terms, or ask for clarification
3. VERIFY:    Check each suggestion against the actual codebase
4. EVALUATE:  Determine whether each suggestion is correct for this codebase
5. RESPOND:   State the technical action being taken or the reason for pushback
6. IMPLEMENT: Address items one at a time, testing each before moving to the next
```

---

## Read All Feedback First

Read the complete review before acting on any individual item. Items in a review may be related.
Acting on item 3 before understanding item 7 can result in implementing something that item 7
would have changed.

This is especially important when the reviewer has grouped concerns or when later items provide
context that reframes earlier ones.

---

## Understand Before Acting

After reading the full review, restate each item in technical terms. This confirms the item is
understood before any code is touched.

If an item is unclear, stop. Ask a specific question about that item before implementing anything.

**Do not implement items that are understood while leaving unclear items for later.** A partial
implementation based on incomplete understanding of the full review produces inconsistent code.

**Correct:**

```
Reviewer: "Fix items 1 through 6"

Understanding:
- Item 1: Remove the unused import of lodash from src/utils/format.ts — clear
- Item 2: Add null check before accessing user.profile.avatar — clear
- Item 3: The retry logic duplicates what the request library already provides — clear
- Item 4: "Normalize the response" — unclear. Does this mean shape transformation,
  status code normalization, or header normalization?
- Item 5: Extract the date formatting into a shared util — clear
- Item 6: Fix the TypeScript error on line 84 — clear

Response: "Understood items 1, 2, 3, 5, and 6. Need clarification on item 4 before proceeding.
What does 'normalize the response' mean in this context — shape, status codes, or headers?"
```

---

## Verify Against the Codebase

Before implementing a suggestion, check whether the suggestion is correct for this codebase.

Questions to ask:

- Does this suggestion break existing functionality?
- Why was the current implementation chosen? Is there a prior decision (ADR, issue, comment) that explains it?
- Does this suggestion work on all the platforms or versions this code targets?
- Does the reviewer have full context about this codebase's conventions and constraints?

Tools to use:

- Read the relevant file and surrounding code
- Search for existing patterns that conflict or align with the suggestion
- Check QwickBrain for ADRs or spike documents that may have addressed this decision
- Run the existing tests to understand what behavior is currently guaranteed

If verification is not straightforward, say so:

```
"Cannot verify this without running the E2E suite against the macmini environment.
Should I investigate further, or proceed with caution and note this as a risk?"
```

---

## Evaluate Whether Each Suggestion Is Correct

A suggestion from a reviewer is an external input. It must be evaluated on technical merit.

Reviewers do not always have full context. They may:

- Be unaware of a platform constraint that required the current approach
- Suggest a pattern that is appropriate for their codebase but not this one
- Recommend a feature that is not used anywhere (YAGNI applies)
- Misread the code and flag a problem that does not exist

Evaluate each suggestion independently. Agreement or disagreement should follow from the technical
assessment, not from social pressure or deference.

### YAGNI Check for "Proper" Features

When a reviewer suggests implementing something more fully or professionally, check whether
the thing is actually used.

```bash
# Search for usages before building
grep -r "endpointName\|functionName\|featureName" src/
```

If nothing calls it, the addition is unnecessary complexity. State this clearly and ask whether
to remove the dead code entirely or build the feature.

---

## Respond Without Performance

Do not use performative language. The following responses are forbidden:

- "You're absolutely right!" — performative, not technical
- "Great point!" — evaluative praise, not an action
- "Excellent catch!" — same problem
- "Thanks for pointing that out!" — any gratitude expression
- "Let me implement that now" — agreement without verification

The code is what speaks. State what is being done and do it.

**Correct acknowledgment when feedback is right:**

```
"Confirmed — the null check is missing on line 47. Adding it now."
"Correct. Extracted the duplicated logic into formatDate() in src/utils/date.ts."
"Fixed. The retry logic is now delegated to the request library's built-in retry config."
```

**If you catch yourself about to write "Thanks" or "You're right" — delete it.** State the action
instead. The action is the acknowledgment.

---

## When to Push Back

Push back on a suggestion when any of these are true:

- The suggestion breaks existing functionality
- The reviewer lacks context about a deliberate architectural decision
- The suggestion violates YAGNI (adds code with no caller)
- The suggestion is technically incorrect for this stack, platform, or version
- A prior decision (ADR, spike, partner conversation) already settled this
- The suggestion conflicts with a pattern the partner established

### How to Push Back

Push back technically, not defensively. State the reason with evidence.

- Reference the file and line number that shows why the current implementation is correct
- Quote the test that already covers the concern the reviewer raised
- Reference the ADR or issue that documents why this approach was chosen
- Explain the platform constraint the reviewer may not be aware of

**Example — suggestion breaks backward compatibility:**

```
Reviewer: "Remove the legacy API fallback in src/api/client.ts:88-102"

Response: "The fallback at client.ts:88-102 handles the v1 API format still returned by
the staging environment. The migration doc (docs/adr/0012-api-versioning.md) records that
v1 format support must remain until Q3. Removing it now would break the staging E2E suite.
Should we schedule removal for after the v1 deprecation date?"
```

**Example — suggestion adds unused code:**

```
Reviewer: "The metrics endpoint should have database-backed storage, date filtering, and CSV export"

Response: "Searched the codebase — nothing calls this endpoint (grep: zero results for
'/api/metrics' outside of the endpoint definition itself). Adding database storage, filters,
and export for an unused endpoint is YAGNI. Should this endpoint be removed, or is there
usage I am missing?"
```

---

## When the Reviewer Is Right

When a suggestion is correct, implement it and describe what changed.

Do not over-explain. Do not apologize. State the fix concisely.

```
✅ "Fixed. Added null guard at user.ts:34 before accessing profile.avatar."
✅ "Corrected. Removed the lodash import — it was unused after the refactor in Task 3."
✅ "Done. Extracted the date formatting logic into src/utils/date.ts:formatRelativeDate()."
```

Do not pad the response. The code change is the proof.

---

## Correcting a Pushback That Was Wrong

If a pushback was made and it turns out the reviewer was correct, state the correction and proceed.

```
✅ "Checked — you are right. The retry library does handle this case. My initial reading was
   wrong because I was looking at the v1 config format. Removing the duplicated logic now."
```

Do not write a long apology. Do not explain why the pushback was made. State what was wrong and
fix it. Move on.

---

## Implementation Order

When feedback contains multiple items, implement in this order:

1. Clarify any unclear items first. Do not implement anything until all items are understood.
2. Fix blocking issues: bugs, security holes, broken functionality.
3. Fix simple corrections: typos, unused imports, wrong variable names.
4. Fix structural changes: logic refactoring, extraction, reorganization.
5. Address stylistic or minor items last.

Test after each fix. Do not batch multiple fixes and test at the end. Regressions become hard to
locate when multiple changes are committed before any testing.

---

## Feedback from Different Sources

### From the Partner (Human Collaborator)

Feedback from the partner is trusted. Implement after understanding. Still clarify scope if
anything is unclear. Still push back if the suggestion is technically incorrect — the partner
benefits from correct analysis, not agreement.

Skip performative acknowledgment entirely. Go straight to action.

### From the Code-Reviewer Agent

The code-reviewer agent operates from the diff and the provided context. It does not have access
to conversation history, prior decisions, or the partner's preferences. Apply extra verification:

- Does the reviewer have the full picture?
- Is the suggestion based on a pattern that applies to this codebase?
- Does it conflict with a decision the partner already made?

If a reviewer suggestion conflicts with a decision the partner established, stop and discuss with
the partner before implementing.

### From GitHub PR Reviews

When a reviewer leaves inline comments on a GitHub PR, reply in the comment thread. Use:

```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies \
  --method POST \
  --field body="..."
```

Do not post a top-level PR comment in response to an inline comment. Keep the conversation
threaded to the relevant code.

---

## Common Mistakes

| Mistake | Correct approach |
|---------|-----------------|
| Agreeing immediately without checking | Read, understand, verify, then respond |
| Implementing all items before testing any | One item at a time, test each |
| Acting on unclear items to avoid asking | Stop, ask, clarify all unclear items first |
| Assuming the reviewer is always correct | Verify against codebase reality |
| Avoiding pushback because it feels uncomfortable | Technical correctness is the standard, not comfort |
| Writing "you're absolutely right" | State the fix, not the agreement |
| Implementing without understanding why | Understand the requirement, then implement |
| Implementing a feature with no callers | YAGNI — ask before adding dead code |
| Long apologies when a pushback was wrong | State the correction factually and move on |

---

## Verification Checklist

Before marking review feedback as addressed:

- [ ] All feedback items read before any were implemented
- [ ] All unclear items clarified before implementation began
- [ ] Each suggestion verified against the codebase before implementation
- [ ] YAGNI check performed for any "add feature" suggestions
- [ ] All incorrect suggestions challenged with technical evidence
- [ ] Each fix implemented individually and tested before moving to the next
- [ ] No performative agreement language in any response
- [ ] Blocking issues fixed before non-blocking items

---

## The Bottom Line

Code review feedback is a technical signal. Evaluate it as such.

Verify it against the codebase. Accept what is correct. Challenge what is not. Ask about what is
unclear. Implement only after understanding.

Technical rigor is the obligation. Social comfort is not.
