---
name: estimating-effort
description: "This skill should be used when the user needs an effort estimate for a feature, bug fix, refactor, or technical task before committing to it. Trigger phrases: 'how long will this take', 'estimate this', 'how much effort', 'give me a rough estimate', 'size this work', 'how many days', 'can we fit this in the sprint', 'estimate the effort for'. Use this before sprint planning, before committing to a deadline, or when scope is ambiguous."
---

# Estimating Effort

## Overview

Produce a structured effort estimate using three-point estimation: optimistic, most likely, and pessimistic scenarios for each component of the work. The estimate identifies risks, maps dependencies, documents assumptions, and states a confidence level so the user can make an informed decision about scheduling, staffing, or scope.

Estimates are saved to: `docs/estimates/YYYY-MM-DD-<feature-name>-estimate.md` using the ESTIMATION.md template.

## Core Principles

**Three-point estimation is required.** A single number is a commitment disguised as an estimate. Three points — optimistic, most likely, pessimistic — communicate uncertainty honestly. Use the PERT formula to compute the expected value: `(Optimistic + 4 × Most Likely + Pessimistic) / 6`.

**Confidence must be stated explicitly.** Every estimate has a confidence level: High, Medium, or Low. The confidence level reflects how well the work is understood, not how optimistic the estimator is. A low-confidence estimate is still useful — it tells the user that more investigation is needed before the number can be trusted.

**Unknowns require investigation, not assumption.** If a component of the work is not understood well enough to estimate, investigate it before estimating. Use Grep, file inspection, QwickBrain document search, or targeted clarifying questions. Do not estimate what has not been studied.

**Scope ambiguity must be resolved before estimating.** Ask clarifying questions about scope. An estimate built on an ambiguous scope is not an estimate — it is a guess that will produce a surprise later.

## Process

### Step 1: Clarify Scope

Before producing any numbers, confirm what is and is not in scope.

Ask clarifying questions one at a time. Focus on:
- What problem is being solved?
- What systems or components are involved?
- Are there adjacent areas that might be affected?
- What is explicitly out of scope?
- Is there a design document or spike report to reference?

If a design or spike report exists, read it before proceeding. If not, note that the estimate is based on an incomplete specification and adjust confidence accordingly.

**Example clarifying questions:**

"Does this include updating the existing API, or is it adding a new endpoint alongside the current one?"

"Are there mobile clients that consume this service, or is it web-only?"

"Is test coverage for the new code expected, or is this a time-pressured hotfix?"

Continue asking until the scope boundary is clear enough to decompose the work.

### Step 2: Research the Work

Investigate before estimating. Read the relevant code, check the existing test coverage, identify the integration points, and look for any prior art in the codebase or documentation.

**Research methods:**
- Read relevant source files to understand current state
- Check the test suite to understand coverage and test infrastructure
- Search QwickBrain for related design documents, spikes, or ADRs
- Look at git history for related changes
- Identify third-party dependencies and check their documentation

Do not estimate a component that has not been examined. If examination would take more time than is available, document the component as "not investigated" and assign it a low-confidence estimate with a large pessimistic range.

### Step 3: Decompose the Work

Break the work into components. A component is a distinct piece of work that can be estimated independently.

Examples of well-defined components:
- "API endpoint: add POST /users/preferences with validation and persistence"
- "Frontend form: add preferences UI with field validation and submit handling"
- "Database: add preferences table with migration and rollback"
- "Tests: unit tests for validation logic, integration tests for the API endpoint"
- "Documentation: update API reference and admin guide"

Examples of poorly defined components:
- "Backend work"
- "Fix the bug"
- "Add the feature"

Each component needs its own three-point estimate. Estimating the whole at once produces numbers that obscure where the uncertainty lives.

### Step 4: Estimate Each Component

For each component, produce:

**Optimistic estimate:** Everything goes smoothly. No unexpected complexity, no blocked dependencies, no rework.

**Most likely estimate:** Normal working conditions. Some small surprises but nothing that requires significant rework or outside help.

**Pessimistic estimate:** Things go wrong in the ways that commonly go wrong for this type of work: the integration behaves differently than expected, the test environment needs setup, a dependency has a breaking change, a review requires a non-trivial revision.

**Confidence level for this component:**
- High: The work is well understood, the patterns are familiar, similar work has been done recently
- Medium: Most of the work is understood, but one or two pieces have unknowns
- Low: Significant unknowns remain, new technology is involved, or the existing code in this area is unfamiliar

**Expected value (PERT):** `(Optimistic + 4 × Most Likely + Pessimistic) / 6`

Also identify for each component:
- Dependencies: What must be done before this component can start? What does this component block?
- Risks: What specific things could cause the pessimistic case to materialize?

### Step 5: Identify Risk Factors

Across all components, identify risks that affect the overall estimate:

**Scope risks:** The requirements might expand. A feature that "should be simple" has a history of growing.

**Technical risks:** Unfamiliar libraries, untested integration points, legacy code with poor test coverage, services that are known to be unreliable.

**Dependency risks:** External teams, third-party services, infrastructure changes that are outside the estimator's control.

**Process risks:** Review cycles, approval gates, deployment windows, team capacity.

For each risk, rate its probability (High / Medium / Low) and its impact on the estimate if it materializes (state the added effort in hours or days).

### Step 6: Produce the Summary

Aggregate the component estimates into a total:

- Total optimistic
- Total most likely
- Total pessimistic
- Total expected value (sum of component expected values)

State the overall confidence level. The overall confidence is bounded by the lowest-confidence component. A plan where 90% of the work is High confidence but 10% is Low confidence has a Medium overall confidence at best.

Apply a contingency buffer based on overall confidence:
- High confidence: 10-15% buffer
- Medium confidence: 20-30% buffer
- Low confidence: 40-50% buffer

State the recommended planning range: expected value to expected value plus buffer.

### Step 7: Save the Estimate Document

Write the estimate to `docs/estimates/YYYY-MM-DD-<feature-name>-estimate.md` using the ESTIMATION.md template.

The document must include:
- What is being estimated
- Estimation method used
- Overall confidence level with justification
- Each component with its three-point estimate
- Risk register with probability and impact
- Total estimate summary table
- Assumptions that, if wrong, would invalidate the estimate
- Explicit list of what is not included

## Confidence Level Reference

**High (80-100% confidence)**
- Work is well understood
- Similar work completed in the last three months
- Codebase in this area is familiar and well-tested
- No significant external dependencies
- All assumptions are verifiable

**Medium (50-80% confidence)**
- Most work is understood, some unknowns remain
- Some prior experience with this type of work
- One or two unverified assumptions
- At least one external dependency
- Investigation was time-limited

**Low (below 50% confidence)**
- Significant unknowns remain
- New technology or unfamiliar codebase area
- Multiple external dependencies
- Assumptions have not been verified
- A spike or design phase should precede this estimate

## Presenting the Estimate

When presenting the estimate to the user, lead with the planning range, not the most likely number.

**Correct framing:**

"Based on the current specification, this work is estimated at 4-6 days (most likely: 4.5 days, with a 20% buffer for Medium confidence). The main uncertainty is in the third-party payment integration — that component alone has a 1-3 day range depending on how their webhook documentation matches reality."

**Incorrect framing:**

"This will take about 4 days." (No range, no confidence, no explanation of what could cause variance.)

After presenting the estimate, offer the user options:

1. Accept the estimate and proceed to planning
2. Invest in a spike to reduce uncertainty on the low-confidence components before re-estimating
3. Reduce scope to fit within a tighter constraint and re-estimate the reduced scope

## When to Re-estimate

State the conditions that would invalidate this estimate:

- Scope changes beyond what was described during clarification
- A technical blocker discovered during implementation that changes the architecture
- A key assumption proves false
- New dependencies are identified

An estimate that becomes invalid should be re-estimated before proceeding. Do not carry forward a number that no longer reflects the work.

## Integration with Other Skills

**qwickapps-sdlc:brainstorming** — Use brainstorming to define the design before estimating. Estimates without a design are speculative.

**qwickapps-sdlc:writing-plans** — The plan produced by writing-plans can be used as input to refine an estimate. Each task in the plan corresponds to a component in the estimate.

**QwickBrain documents** — Search for related SPIKE, FRD, and DESIGN documents before estimating. Prior investigation often contains effort notes or complexity observations relevant to the current estimate.
