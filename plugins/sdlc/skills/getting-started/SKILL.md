---
name: getting-started
description: >
  This skill should be used at the start of every session and whenever the user asks how the SDLC
  system works, what commands are available, how to start a task, or what skills exist.
  Trigger phrases: "how do I use this", "what commands are available", "where do I start",
  "what is sdlc", "how does this system work", "what skills do you have",
  "I don't know where to start", "help me get started", "what should I do first".
  Also load this skill when the agent detects it is beginning a new session without prior context.
---

# Getting Started with sdlc

This is the meta skill for the sdlc plugin. It explains how the system is organized,
how to use commands, when skills activate, and how to get work done effectively.

---

## How the System Is Organized

The sdlc plugin has three types of components:

**Commands (9)** — User-invocable workflows. The user types `/feature`, `/bug`, `/research`, etc.
Each command runs a structured multi-phase workflow. Commands create GitHub issues, load skills per
phase, and drive the work from start to finish.

**Skills (23)** — Agent-loaded techniques. Skills are NOT invoked by the user. The agent loads
applicable skills automatically based on context. Each skill provides deep procedural knowledge
for a specific technique or discipline. Skills activate when there is any meaningful chance they
apply, not only when the task explicitly names them.

**Agent Personas (8)** — Behavioral profiles loaded during specific phases. Commands activate
personas at the right moment (product-manager for requirements, architect for design, coder for
implementation, etc.).

---

## The 9 Commands

All work starts with a command. Commands are the entry points.

### /feature
Full software development lifecycle for a new feature. Phases: requirements gathering, design,
planning, implementation, review, documentation, and commit. Creates a GitHub issue labeled
`feature`. Use when adding new functionality.

### /bug
Investigation and fix for broken behavior. Phases: root cause investigation, regression test,
fix, verification, and commit. Creates or links a GitHub issue labeled `bug`. Use when something
is not working correctly.

### /research
Deep technical investigation before a decision. Phases: define the question, investigate using
all available tools (codebase, documentation, package registries, QwickBrain), document findings
with evidence, save to QwickBrain as a spike document, and close the issue. Creates a GitHub
issue labeled `research`. Use when a decision requires understanding before acting.

### /refactor
Code restructuring that preserves behavior. Phases: impact analysis, plan with before/after
structure, behavior-preservation tests, implementation, and verification. Creates a GitHub issue
labeled `refactor`. Use when reorganizing code without changing external behavior.

### /chore
Maintenance tasks with no new behavior. Phases: scope definition, implementation, verification,
and commit. Creates a GitHub issue labeled `chore`. Use for dependency updates, CI fixes,
configuration cleanup, and similar maintenance.

### /review
Code quality assessment of a PR or diff. Loads the code-reviewer agent. Produces an issue list
with file:line references, severity levels, and concrete fix recommendations. Use when assessing
code that was written outside the current session, or when a PR needs review.

### /commit
Controlled, validated commit. Runs VALIDATION-GATES.md checks (build, tests, warnings), shows
a diff summary, confirms with the user, generates a commit message referencing the issue, and
commits. Never pushes without explicit user approval. Use when ready to commit completed work.

### /release
Version release management. Determines version bump strategy, generates a changelog from issue
labels, writes a migration guide for breaking changes, and coordinates CI/CD. Creates a
milestone. Use when shipping a new version.

### /docs
Documentation updates. Identifies what changed from git diff and issue context, updates relevant
documentation files, and verifies accuracy against code. Use when documentation needs to reflect
changes that have already landed.

---

## The 23 Skills

Skills load automatically. Do not wait for the user to mention a skill by name. Load every skill
that has any meaningful relevance to the current task.

### Engineering Discipline

**writing-tests** — Enforces RED-GREEN-REFACTOR. Write a failing test. Watch it fail. Write the
minimum code to pass. Watch it pass. Refactor. Load whenever writing or modifying code.

**debugging** — Root cause analysis before fixes. The iron law: no fix without a root cause.
Systematic observation, hypothesis formation, evidence gathering, and verification. Load whenever
investigating a bug or unexpected behavior.

**verifying-completion** — Evidence before assertions. Run verification commands. Confirm output.
Fresh evidence required. Load before declaring any task complete.

**securing-code** — OWASP top 10 awareness, auth patterns, input validation, output encoding,
CSRF protection. Load when writing auth code, API endpoints, or form handling.

**optimizing-performance** — Profiling before optimization. Measure, identify bottleneck, fix,
measure again. No premature optimization. Load when performance is mentioned or when writing
database queries, caching logic, or rendering pipelines.

### Planning Pipeline

**brainstorming** — Explore user intent before building. Ask clarifying questions one at a time.
Propose two to three approaches with trade-offs. Present design for approval before implementation.
Load when the task scope is unclear or when starting a non-trivial feature.

**writing-plans** — Break an approved design into bite-sized tasks (two to five minutes each).
Use TaskCreate for each step. Save the plan to docs/plans/. Load after brainstorming produces an
approved design.

**executing-plans** — Load the plan, review it critically, execute in batches with checkpoints.
Default batch size is three tasks with a review between batches. Load when a plan exists and
implementation is beginning.

**estimating-effort** — Three-point estimation (optimistic, likely, pessimistic). Risk factor
identification. Dependency mapping. Load when the user asks for time or effort estimates.

### Delegation

**delegating-tasks** — Fresh subagent per task via the Task tool. Two-stage review: spec
compliance, then code quality. Load when a task is well-defined and can be executed independently.

**parallelizing-work** — One subagent per independent problem domain, dispatched concurrently.
Load when facing two or more independent failures or investigations that can run simultaneously.

### Code Review

**requesting-review** — Dispatch the code-reviewer agent via the Task tool. Provide git SHAs,
plan context, and changed files. Load after completing delegated work, after major features, and
before merge.

**receiving-review** — Verify feedback before implementing it. Challenge questionable feedback
with evidence. Technical correctness over social comfort. Load when review feedback has arrived
and needs evaluation.

### Git Workflow

**creating-worktree** — Uses the project's create-worktree.sh script. Copies .env files,
settings, and runs pnpm install. Never uses git worktree add or git checkout -b directly. Load
when starting implementation that requires an isolated workspace.

**finishing-branch** — Presents options (merge, PR, keep worktree, discard) via AskUserQuestion.
Verifies all tests pass first. Load when implementation is complete and ready to merge or archive.

### Project Management

**tracking-issues** — Every piece of work starts with a GitHub issue. Create via gh CLI (ask
permission first). Store local context in QwickBrain. Reference issue numbers in commits. Close
on completion. Load at the start of every command workflow.

**starting-sprint** — Load previous sprint handoff from QwickBrain. Review open issues. Set
sprint goals. Create sprint backlog. Load when beginning a new sprint cycle.

**closing-sprint** — Create a handoff document with lessons learned. Store in QwickBrain. Update
the GitHub project. Load when a sprint is ending.

### Design

**designing-ux** — UX patterns, accessibility (WCAG), responsive design, component architecture,
color contrast, keyboard navigation. Load when building or changing any user-facing interface.

### Release

**planning-release** — Semantic versioning strategy, changelog generation, breaking change
identification, migration guide writing, and release notes drafting. Load during /release.

**deploying** — CI/CD pipeline patterns, environment promotion, rollback strategies, health
checks, Docker deployment. Load when deploying to any environment.

### Meta

**getting-started** — This skill. Explains how to use the system.

**writing-skills** — Creates new skills for Claude Code plugins. Load when the user wants to
add a new skill to a plugin or when writing skill documentation.

---

## Skill Activation Principle

Load a skill if there is even a 1% chance it applies.

The cost of loading an unnecessary skill is low. The cost of missing a relevant skill is high:
suboptimal decisions, skipped steps, quality problems, and rework.

### Skills Are Not Optional

Skills are not suggestions. They are procedural knowledge that changes how the work gets done.
If the task involves code changes, writing-tests is active. If something is broken, debugging
is active. If the task is completing, verifying-completion is active.

### Red Flags for Rationalization

Watch for thoughts like these. Each one is a signal to stop and check for skills before
proceeding.

- "This is too simple to need a plan." Stop. Check for writing-plans and brainstorming.
- "I know what the bug is, I'll just fix it." Stop. Load debugging. Find the root cause first.
- "The tests are passing, I'm done." Stop. Load verifying-completion. Run the verification.
- "I'll write the code first and add tests after." Stop. Load writing-tests. Test first.
- "This doesn't need review, it's a small change." Stop. Load requesting-review if appropriate.
- "I'll just commit directly." Stop. Use /commit to run validation gates.

### Load Process Skills Before Implementation Skills

Process skills (brainstorming, debugging, writing-tests) shape how implementation happens.
Load them before starting work, not after encountering a problem.

---

## Issue-Driven Development

All work in this system starts with a GitHub issue. Issues provide:

- A record of what was worked on and why
- Commit linkage (commits reference the issue number)
- A closure mechanism (issue closed when work is done)
- Sprint context for tracking-issues and QwickBrain

The tracking-issues skill handles issue creation. Every command workflow loads it at the start.

Do not begin implementation without an issue. If no issue exists, create one before writing code.

---

## All Work Starts with a Command

When the user brings a task:

1. Identify which command applies.
2. Run that command. The command defines the phases and loads the right skills.
3. If the task does not fit a command, identify which individual skills apply and load them.

For exploratory or conversational work where no command applies, check: does this involve code
changes (writing-tests, securing-code), investigation (debugging, researching), planning
(brainstorming, writing-plans), or completion (verifying-completion)? Load whatever applies.

---

## Quick Reference

| User says | Command to run |
|-----------|---------------|
| "Build a new feature" | /feature |
| "Something is broken" | /bug |
| "I need to understand X before deciding" | /research |
| "Reorganize this code" | /refactor |
| "Update the dependencies" | /chore |
| "Review this PR" | /review |
| "I'm ready to commit" | /commit |
| "Time to ship" | /release |
| "Update the docs" | /docs |

| Task type | Skills to load |
|-----------|---------------|
| Any code change | writing-tests, verifying-completion |
| Bug or unexpected behavior | debugging |
| Auth, API, form handling | securing-code |
| Performance concerns | optimizing-performance |
| New feature, unclear scope | brainstorming |
| Approved design, needs planning | writing-plans |
| Plan exists, implementation starting | executing-plans |
| Work ready for review | requesting-review |
| Review feedback received | receiving-review |
| Starting new workspace | creating-worktree |
| Implementation complete | finishing-branch, verifying-completion |
| Any user-facing interface | designing-ux |
