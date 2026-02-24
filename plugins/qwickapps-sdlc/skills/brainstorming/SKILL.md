---
name: brainstorming
description: "This skill should be used when the user wants to create a new feature, build a component, add functionality, or modify system behavior. Trigger phrases: 'I want to build', 'let's design', 'I have an idea', 'help me figure out', 'what's the best way to', 'brainstorm this with me', 'let's plan', 'I need to add'. This skill MUST run before any implementation work begins."
---

# Brainstorming Ideas Into Designs

## Overview

Turn ideas into fully formed designs through structured collaborative dialogue. Understand what the user is trying to achieve, explore the trade-offs of different approaches, and converge on a design that both parties approve before any code is written.

<HARD-GATE>
Do NOT write any code, scaffold any project, invoke any implementation skill, or take any implementation action until a design has been presented and the user has explicitly approved it. This applies to every project, regardless of perceived simplicity. "Simple" projects are where unexamined assumptions cause the most wasted effort.
</HARD-GATE>

## Why Design Before Implementation

Every project — a single utility function, a configuration change, a todo list — goes through this process. The design document for a trivial project may be three sentences. The design document for a complex feature may be several pages. The length scales with complexity. The requirement to get approval before proceeding does not.

Skipping design approval wastes effort in a predictable way: work gets built, reviewed, found to miss the mark, and rebuilt. The design stage exists to surface that misalignment early, when it costs minutes instead of hours.

## Checklist

Create a task for each item and complete them in order:

1. **Explore project context** — read relevant files, docs, and recent commits to understand the current state
2. **Ask clarifying questions** — one question at a time, focusing on purpose, constraints, and success criteria
3. **Propose 2-3 approaches** — with trade-offs clearly stated and a lead recommendation with reasoning
4. **Present design in sections** — scaled to complexity, get approval after each section
5. **Write design document** — save to `docs/plans/YYYY-MM-DD-<topic>-design.md` and commit
6. **Invoke writing-plans** — hand off to the writing-plans skill for implementation planning

## Process Flow

```
Explore project context
        |
        v
Ask clarifying questions (one at a time)
        |
        v
Propose 2-3 approaches with trade-offs
        |
        v
Present design sections
        |
        v
User approves?
   |          |
  no          yes
   |          |
   v          v
Revise    Write design doc
              |
              v
        Invoke writing-plans
```

The terminal state is invoking writing-plans. Do not invoke any other skill after brainstorming completes.

## Step 1: Explore Project Context

Before asking a single question, understand what already exists:

- Read relevant source files, configuration files, and documentation
- Check recent commits for context on current direction
- Identify existing patterns, conventions, and constraints
- Note any related features or components that might be affected

Gather enough context to ask informed questions. Vague questions waste the user's time and signal poor preparation.

## Step 2: Ask Clarifying Questions

Ask questions one at a time. Do not bundle multiple questions into one message.

**What to ask about:**
- Purpose: What problem does this solve? Who uses it?
- Scope: What is explicitly in scope? What is explicitly out of scope?
- Constraints: Technical constraints, time constraints, existing system limitations
- Success criteria: How will anyone know this is done and done well?
- Edge cases: What should happen when things go wrong?

**How to ask:**
- Prefer multiple-choice questions when the answer space is bounded
- Use open-ended questions when the answer space is genuinely open
- Ask the most important question first
- Only move to the next question after receiving an answer

**Example of correct question sequencing:**

Message 1: "Is this feature intended for end users of the product, or for internal admin use only?"

(Wait for answer)

Message 2: "Should this work offline, or can it require an active network connection?"

(Wait for answer)

Continue until enough is understood to propose approaches.

## Step 3: Propose 2-3 Approaches

Once the intent is understood, propose distinct approaches before committing to any one design. Present them conversationally.

**Structure for each approach:**
- Name (short label)
- Description (what it is and how it works)
- Pros (specific benefits in this context)
- Cons (specific costs or limitations)

**Lead with a recommendation.** State which approach is recommended and why. The recommendation must be grounded in the constraints and success criteria gathered in Step 2. "I recommend Option A because..." is always more useful than "here are three options, you decide."

Apply YAGNI ruthlessly when evaluating approaches. Remove any proposed feature that was not explicitly requested and does not directly serve the stated success criteria.

## Step 4: Present the Design in Sections

Once an approach is selected, present the design. Break it into logical sections and check in after each one.

**Sections to cover (as applicable):**
- Architecture: Overall structure and how components relate
- Components: What gets built, what it does, where it lives
- Data: Data model, storage, retrieval, mutation
- Integrations: How this connects to existing systems
- Error handling: What happens when things go wrong
- Testing: How correctness will be verified

**Scale each section to its complexity.** A simple utility function may need two sentences per section. A new subsystem may need 200-300 words. Calibrate the depth to the decision at hand.

**After each section, ask:** "Does this look right before I continue?"

Incorporate feedback and revise before proceeding to the next section. Do not present the entire design at once and ask for approval at the end — surface disagreements section by section.

## Step 5: Write the Design Document

After all sections are approved, write the design to disk.

**File path:** `docs/plans/YYYY-MM-DD-<topic>-design.md`

**Document structure:**
```markdown
# [Feature Name] Design

**Date:** YYYY-MM-DD
**Status:** Approved

## Goal

[One sentence: what problem this solves]

## Approach

[Which approach was selected and why]

## Architecture

[How the system is structured]

## Components

[What gets built, where it lives]

## Data

[Data model and flow]

## Integrations

[How this connects to existing systems]

## Error Handling

[What happens when things go wrong]

## Testing

[How correctness will be verified]

## Out of Scope

[What was explicitly excluded]
```

Commit the design document before invoking writing-plans.

## Step 6: Invoke writing-plans

After the design is committed, invoke the writing-plans skill. This is the only valid next step. Do not begin implementation directly from brainstorming.

Announce: "Design approved and saved. Invoking writing-plans to create the implementation plan."

## Key Principles

**One question at a time.** Asking multiple questions at once overwhelms and leads to partial answers. Ask one. Wait. Ask the next.

**Multiple choice when possible.** An open-ended question like "what kind of UI do you want?" is harder to answer than "should this be a modal dialog, an inline form, or a separate page?"

**YAGNI ruthlessly.** Remove anything not explicitly requested. A clean, minimal design is almost always better than a comprehensive one that builds what might be needed someday.

**Always explore alternatives.** Proposing only one approach is a failure of process. Two or three options with trade-offs gives the user real choice and surfaces assumptions.

**Incremental approval.** Validate the design section by section. Do not present the whole thing and ask if it's OK.

**Be ready to revise.** Feedback during design presentation is not failure. It is the system working. Incorporate changes and continue.

## What Not to Do

- Do not begin writing code before design approval
- Do not propose a single approach without alternatives
- Do not ask multiple questions in one message
- Do not present the entire design at once without section-by-section check-ins
- Do not skip sections because they seem obvious
- Do not invoke any skill other than writing-plans when brainstorming is complete
