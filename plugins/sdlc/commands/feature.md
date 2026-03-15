---
name: feature
description: Full SDLC feature development. Creates a GitHub issue, runs through requirements, design, planning, implementation, review, documentation, and commit phases.
---

The /feature command runs a full SDLC cycle for a new feature.

## Argument

Accept an optional argument: the feature description. If not provided, use AskUserQuestion to ask the user what feature they want to build before proceeding.

## Phases

### Phase 1: Requirements

Load `sdlc:tracking-issues` to create a new GitHub issue with the label `feature`. If the user provided an issue number instead of a description, link to the existing issue rather than creating a new one.

Load `sdlc:brainstorming` to explore the user's intent. Use AskUserQuestion to clarify:
- Scope: what is in and out of scope
- Acceptance criteria: what does done look like
- Constraints: performance, security, compatibility requirements
- Affected surfaces: frontend, backend, database, API

Do not proceed to design until scope is agreed.

### Phase 2: Design

Continue with brainstorming's design phase to produce a technical approach.

For frontend work, also load `sdlc:designing-ux` to address UI/UX considerations, component structure, and user flow.

For complex features with significant architectural impact, use EnterPlanMode to present the design to the user and get explicit sign-off before proceeding to planning.

Document design decisions with rationale. Record any Architecture Decision Records (ADRs) using `KB_CREATE_DOCUMENT` with type `DOC_TYPE_ADR` if the decision is significant and long-lived. If no SOP plugin is configured, save ADRs to `docs/adrs/` in the repository.

### Phase 3: Planning

Load `sdlc:writing-plans` to produce a detailed implementation plan.

Create bite-sized tasks using TaskCreate. Each task must:
- Be independently completable
- Have a clear definition of done
- Follow TDD: test first, then implementation
- Be small enough to complete in one focused session

Reference VALIDATION-GATES.md when defining done criteria for each task.

### Phase 4: Implementation

Load `sdlc:creating-worktree` to set up an isolated workspace for the feature branch. Follow WORKTREE-ENFORCEMENT.md: use the create-worktree.sh script, never `git checkout -b` directly.

For the execution strategy, choose based on task complexity:
- Use `sdlc:delegating-tasks` to dispatch a subagent per task when tasks are independent and well-defined
- Use `sdlc:executing-plans` for batch execution when tasks are tightly coupled

For each task during implementation:
1. Load `sdlc:writing-tests` to write tests before the implementation
2. Implement the minimum code to make tests pass
3. Load `sdlc:securing-code` to identify and address security concerns
4. Verify the task's definition of done before marking it complete

Apply VALIDATION-GATES.md after each task: build must pass, tests must pass, no regressions.

### Phase 5: Review

Load `sdlc:requesting-review` to dispatch a code-reviewer agent. The review covers correctness, security, performance, and adherence to codebase conventions.

Address all blocking review comments before proceeding.

Load `sdlc:verifying-completion` for an evidence-based completion check. Verify:
- All acceptance criteria from Phase 1 are met
- All tasks are marked complete
- Build and test suite pass in a production-like environment
- No regressions in related functionality

Apply SATISFACTORY-CRITERIA.md: work is not complete until all five criteria pass (specificity, evidence-based, actionable, complete, sufficient depth).

### Phase 6: Documentation

Adopt the tech-writer agent persona to update documentation:
- Update or create user-facing documentation for the feature
- Update API documentation if interfaces changed
- Update the README if the feature changes setup or configuration
- Add inline code comments for non-obvious logic

Documentation must reflect the final implemented state, not the design.

### Phase 7: Commit and PR

Load `sdlc:finishing-branch` to finalize the branch.

Reference the GitHub issue number in every commit message using `#N` notation. The PR description must:
- Link to the issue with `Closes #N`
- Summarize what changed and why
- Include the test plan used to verify the feature
- List any known limitations or follow-up work

Run full validation before creating the PR:
- `npm run build` or equivalent
- `npm run test` or equivalent
- `npm run lint` or equivalent

Do not create the PR until all validation passes.
