# Design: qwickapps-sdlc Plugin

**Date:** 2026-02-24
**Status:** Approved
**Scope:** Replace superpowers plugin + Claude portion of ai-sdlc-workflows with a unified SDLC plugin

---

## Problem

The current SDLC tooling is fragmented across multiple sources:

1. **superpowers** (third-party plugin, 13 skills): TDD, debugging, brainstorming, planning, code review, worktrees, parallel agents, verification
2. **ai-sdlc-workflows** (repo, Claude portion): 9 commands, 11 quality rules, 9 agent personas, 10 document templates
3. **code-review** (separate plugin): Automated PR review

Overlaps exist between these systems (planning, code review, commit workflows). Users must know which plugin provides what. Skills from different plugins have no awareness of each other, producing incomplete guidance.

## Solution

A single `qwickapps-sdlc` plugin that:

- Replaces superpowers entirely (all 13 skills rewritten)
- Replaces the Claude portion of ai-sdlc-workflows (commands, agents absorbed)
- Adds issue-driven development (GitHub Issues + QwickBrain)
- Adds a dedicated /research command for deep investigation
- Syncs quality rules and templates from ai-sdlc-workflows/shared/ (other tools continue using them)
- Leverages Claude Code native capabilities (AskUserQuestion, TaskCreate, Task subagents, EnterPlanMode, gh CLI, QwickBrain MCP)

## Plugin Structure

```
qwickapps-sdlc/
  .claude-plugin/
    plugin.json
  skills/                        # 23 skills (agent-loaded, not user-invocable)
    # Engineering Discipline
    writing-tests/SKILL.md           # TDD RED-GREEN-REFACTOR
    debugging/SKILL.md               # Root cause analysis
    verifying-completion/SKILL.md    # Evidence before assertions
    securing-code/SKILL.md           # OWASP, auth, input validation
    optimizing-performance/SKILL.md  # Profiling, caching, lazy loading
    # Planning Pipeline
    brainstorming/SKILL.md           # Explore intent, propose approaches
    writing-plans/SKILL.md           # Break work into bite-sized tasks
    executing-plans/SKILL.md         # Run plan with checkpoints
    estimating-effort/SKILL.md       # Three-point estimation
    # Delegation
    delegating-tasks/SKILL.md        # Fresh subagent per task
    parallelizing-work/SKILL.md      # Concurrent investigation
    # Code Review
    requesting-review/SKILL.md       # Dispatch reviewer subagent
    receiving-review/SKILL.md        # Rigorous response to feedback
    # Git Workflow
    creating-worktree/SKILL.md       # Isolated workspace setup
    finishing-branch/SKILL.md        # Merge/PR/cleanup
    # Project Management
    tracking-issues/SKILL.md         # GitHub Issues + QwickBrain
    starting-sprint/SKILL.md         # Sprint kickoff, context loading
    closing-sprint/SKILL.md          # Handoff doc, lessons learned
    # Design
    designing-ux/SKILL.md            # UX patterns, accessibility
    # Release
    planning-release/SKILL.md        # Version strategy, changelog
    deploying/SKILL.md               # CI/CD, environment promotion
    # Meta
    getting-started/SKILL.md         # How to use the SDLC system
    writing-skills/SKILL.md          # Creating new skills
  commands/                      # 9 commands (user-invocable)
    feature.md
    bug.md
    research.md
    refactor.md
    chore.md
    review.md
    commit.md
    release.md
    docs.md
  agents/                        # 8 agent personas
    code-reviewer.md
    product-manager.md
    architect.md
    quality-engineer.md
    coder.md
    tech-writer.md
    engineering-manager.md
    devops.md
  hooks/                         # Activation and enforcement
    skill-activation.md          # Auto-detect applicable skills
    pre-commit-validation.md     # Validation gates before commit
  rules/                         # Synced from ai-sdlc-workflows/shared/rules/
    SATISFACTORY-CRITERIA.md
    VALIDATION-GATES.md
    COMMUNICATION-PROTOCOL.md
    ITERATION-GATES.md
    RESEARCH-DEPTH.md
    INVESTIGATION-METHODS.md
    FACT-VERIFICATION.md
    WORKTREE-ENFORCEMENT.md
    WRITING-STYLE.md
    COMMON-PATTERNS.md
  templates/                     # Synced from ai-sdlc-workflows/shared/templates/
    FRD.md
    DESIGN.md
    TEST-PLAN.md
    REVIEW.md
    BUG.md
    SPIKE.md
    RELEASE.md
    ESTIMATION.md
  scripts/
    sync-rules.sh                # Pull latest from ai-sdlc-workflows
    sync-templates.sh            # Pull latest from ai-sdlc-workflows
```

## Commands (9)

Each command represents a distinct user intent. The agent loads relevant skills automatically per phase.

### /feature -- Full SDLC Feature Development
**User says:** "I need to build something new"
**Issue:** Creates GitHub issue, labels: `feature`
**Phases:**
1. Requirements: loads tracking-issues, brainstorming. Uses AskUserQuestion for scope/approach.
2. Design: loads brainstorming (design phase), designing-ux (if frontend). Uses EnterPlanMode for complex features.
3. Planning: loads writing-plans. Uses TaskCreate for each plan step.
4. Implementation: loads creating-worktree, executing-plans OR delegating-tasks. Per task: writing-tests, securing-code.
5. Review: loads requesting-review, verifying-completion.
6. Documentation: tech-writer agent persona.
7. Commit: loads finishing-branch.

### /bug -- Bug Investigation and Fix
**User says:** "Something is broken"
**Issue:** Creates/links issue, labels: `bug`
**Phases:**
1. Investigation: loads debugging, tracking-issues. Root cause analysis before any fix.
2. Fix: loads writing-tests (regression test first), coder persona.
3. Verification: loads verifying-completion. E2E validation.
4. Commit: references issue.

### /research -- Deep Technical Investigation
**User says:** "I need to understand X before deciding"
**Issue:** Creates issue, labels: `research`
**Workflow:**
1. Define question clearly (AskUserQuestion if ambiguous)
2. Investigation using RESEARCH-DEPTH and INVESTIGATION-METHODS rules
   - Local codebase (Explore agent, Grep, Read)
   - Package registries, code repositories
   - Documentation (WebFetch), community (WebSearch)
   - QwickBrain (past decisions, ADRs)
   - Testing/experimentation if needed
3. Document findings: question, methods, evidence (file:line, URLs), options with trade-offs, unknowns with WHY, confidence level, recommendation
4. Save to QwickBrain: create_document type: spike
5. Close issue with summary

### /refactor -- Code Restructuring
**User says:** "This code needs reorganizing"
**Issue:** Creates issue, labels: `refactor`
**Phases:**
1. Analysis: loads brainstorming (impact analysis), architect persona.
2. Plan: loads writing-plans. Document before/after structure.
3. Implementation: loads creating-worktree, writing-tests (behavior preservation tests first).
4. Verification: loads verifying-completion. Prove no behavior change.
5. Commit: references issue.

### /chore -- Maintenance and Cleanup
**User says:** "Update deps / fix CI / clean up config"
**Issue:** Creates issue, labels: `chore`
**Workflow:** Lighter than /feature. No design phase needed.
1. Define scope (AskUserQuestion for clarification)
2. Implementation: loads relevant skills per task (writing-tests if code changes)
3. Verification: loads verifying-completion
4. Commit: references issue

### /review -- Code Quality Assessment
**User says:** "Review this code/PR"
**Links to:** Existing PR or diff
**Workflow:**
1. Load code-reviewer agent persona
2. Assess: security, quality, patterns, correctness
3. Output: Issue list with file:line, severity (critical/high/medium/low), fix recommendations
4. Comment on PR if applicable (gh CLI)

### /commit -- Controlled Commit
**User says:** "I'm ready to commit"
**Pre-commit validation gates (from VALIDATION-GATES.md):**
- Build passes
- Tests pass (unit + integration)
- No critical warnings
**Workflow:**
1. Run validation gates
2. Show diff summary (AskUserQuestion for confirmation)
3. Generate commit message referencing issue
4. Commit (never push without explicit approval)

### /release -- Version Release Management
**User says:** "Time to ship a release"
**Issue:** Creates milestone
**Workflow:**
1. loads planning-release, engineering-manager persona
2. Version bump strategy (AskUserQuestion: major/minor/patch)
3. Changelog generation from issue labels
4. Migration guide if breaking changes
5. loads deploying for CI/CD
6. Release documentation (tech-writer persona)

### /docs -- Documentation Updates
**User says:** "Update the docs"
**Workflow:**
1. tech-writer agent persona
2. Identify what changed (git diff, issue context)
3. Update relevant docs (README, CHANGELOG, API docs)
4. Verify accuracy against code

## Skills (23)

All skills use present participle (gerund) naming. Organized by concern.

### Engineering Discipline

**writing-tests**: Enforces RED-GREEN-REFACTOR. Write failing test. Watch it fail. Write minimal code. Watch it pass. Refactor. Commit. Hard gate: no code without a failing test first.

**debugging**: Root cause analysis before fixes. Iron law: NO FIXES WITHOUT ROOT CAUSE. Includes: observation, hypothesis, evidence gathering, verification. Uses systematic investigation, not random attempts.

**verifying-completion**: Evidence before assertions. Run verification commands. Confirm output. Fresh evidence required -- no "it should work." Hard gate: no completion claims without proof.

**securing-code**: OWASP top 10 awareness. Auth patterns, input validation, output encoding, CSRF protection. Auto-loads when writing auth code, API endpoints, form handling.

**optimizing-performance**: Profiling before optimizing. Measure, identify bottleneck, fix bottleneck, measure again. No premature optimization. Caching patterns, lazy loading, database query optimization.

### Planning Pipeline

**brainstorming**: Explore user intent before building. Ask questions one at a time (AskUserQuestion). Propose 2-3 approaches with trade-offs. Present design for approval. Hard gate: no implementation before design approval.

**writing-plans**: Break approved design into bite-sized tasks (2-5 minutes each). Uses TaskCreate for each step. Each task: write test, run test, implement, verify. Output: plan document saved to docs/plans/.

**executing-plans**: Load plan, review critically, execute in batches. Uses TaskUpdate to track progress. Default 3 tasks per batch with review between batches.

**estimating-effort**: Three-point estimation (optimistic/likely/pessimistic). Risk factor identification. Dependency mapping. Output: effort estimate with confidence level.

### Delegation

**delegating-tasks**: Fresh subagent per task via Task tool. Two-stage review: (1) spec compliance, (2) code quality. Each subagent gets plan context and executes independently.

**parallelizing-work**: When facing 2+ independent failures. One Task subagent per problem domain. Dispatch in parallel. Collect results. Investigating sequentially wastes time.

### Code Review

**requesting-review**: Dispatch code-reviewer agent via Task tool after completing work. Provides git SHAs, plan context, changed files. Mandatory after each task in delegated work, after major features, before merge.

**receiving-review**: When review feedback arrives. Verify before implementing. Ask before assuming. Technical correctness over social comfort. Never blindly agree. Challenge questionable feedback with evidence.

### Git Workflow

**creating-worktree**: Uses project's create-worktree.sh script (from WORKTREE-ENFORCEMENT.md). Copies .env files, settings, runs pnpm install. Never uses git worktree add or git checkout -b directly.

**finishing-branch**: When implementation complete and tests pass. Uses AskUserQuestion to present options: merge to main, create PR, keep worktree, discard branch. Verifies all tests pass before presenting options.

### Project Management

**tracking-issues**: Every piece of work starts with an issue. Creates GitHub issue via gh CLI (asks permission via AskUserQuestion first). Stores local context in QwickBrain. Commits reference issue numbers. Closes issues on completion.

**starting-sprint**: Sprint kickoff. Load previous sprint handoff from QwickBrain. Review open issues. Set sprint goals. Create sprint backlog using TaskCreate.

**closing-sprint**: Create handoff document. Lessons learned. Update GitHub project. Store handoff in QwickBrain for next sprint.

### Design

**designing-ux**: UX patterns, component selection, accessibility. Responsive design guidance. Works alongside qwickapps-ux-design plugin (which adds framework-specific enforcement). Generic enough for any frontend.

### Release

**planning-release**: Semantic versioning strategy. Changelog generation from issue labels. Breaking change identification and migration guide writing. Release notes drafting.

**deploying**: CI/CD pipeline patterns. Environment promotion (dev, staging, production). Rollback strategies. Health checks. Infrastructure as code patterns.

### Meta

**getting-started**: How to use the SDLC system. Explains commands, skills, agents. Skill detection logic: if even 1% chance a skill applies, load it. Red flags for rationalization ("this is too simple").

**writing-skills**: Creating new skills for plugins. TDD applied to documentation. Baseline without skill, write skill, verify compliance. Uses Anthropic best practices.

## Agent Personas (8)

Each persona defines behavior and focus for specific workflow phases. Loaded by commands at the relevant phase.

| Agent | Loaded by | Phase | Focus |
|-------|-----------|-------|-------|
| product-manager | /feature | Requirements | User needs, acceptance criteria, success metrics |
| architect | /feature, /refactor | Design | Technical feasibility, pattern reuse, minimal design |
| quality-engineer | /feature, /bug | Test planning | Edge cases, failure modes, coverage |
| coder | /feature, /bug, /chore | Implementation | Clean code, no over-engineering, YAGNI |
| code-reviewer | /review, /feature | Quality | Security, patterns, correctness |
| tech-writer | /docs, /feature | Documentation | Accurate, minimal, user-facing |
| engineering-manager | /release | Coordination | Multi-team, prioritization, roadmap |
| devops | /release | Deployment | CI/CD, infrastructure, monitoring |

## Hooks (2)

### skill-activation (SessionStart / UserPromptSubmit)
Detects applicable skills and loads them. Equivalent to superpowers' using-superpowers but for the full SDLC skill set. Checks user intent against skill descriptions.

### pre-commit-validation (PreToolUse on Bash for git commit)
Enforces VALIDATION-GATES.md before any commit. Checks: build passes, tests pass, no critical warnings. Blocks commit if gates fail.

## Rules and Templates (Synced)

Rules and templates are synced from `ai-sdlc-workflows/shared/` using scripts in `scripts/`.

**Rules (10):** SATISFACTORY-CRITERIA, VALIDATION-GATES, COMMUNICATION-PROTOCOL, ITERATION-GATES, RESEARCH-DEPTH, INVESTIGATION-METHODS, FACT-VERIFICATION, WORKTREE-ENFORCEMENT, WRITING-STYLE, COMMON-PATTERNS

**Templates (8):** FRD, DESIGN, TEST-PLAN, REVIEW, BUG, SPIKE, RELEASE, ESTIMATION

These are read by hooks and referenced by commands/skills. The authoritative source remains ai-sdlc-workflows/shared/ so other tools (Cursor, Aider, Windsurf) continue using them.

## Claude Code Native Capabilities Used

| Capability | Used by | Purpose |
|------------|---------|---------|
| AskUserQuestion | Commands (feature, bug, chore, commit, release) | Gather choices, confirm actions, present options |
| TaskCreate/TaskUpdate/TaskList | writing-plans, executing-plans | Track plan tasks within session |
| Task tool (subagents) | delegating-tasks, parallelizing-work, requesting-review | Dispatch specialized agents |
| EnterPlanMode | /feature (complex features) | Get user sign-off on approach |
| Skill tool | Commands invoke skills | Load skill content at right phase |
| gh CLI (Bash) | tracking-issues, /review, /release | GitHub issue/PR/milestone management |
| QwickBrain MCP | tracking-issues, /research, starting-sprint, closing-sprint | Document storage, memory, search |

## Relationship to Other Plugins

| Plugin | Relationship |
|--------|-------------|
| superpowers | **Replaced.** Uninstall after qwickapps-sdlc is ready. |
| ai-sdlc-workflows (Claude portion) | **Replaced.** Remove .claude/commands/ and .claude/rules/ symlinks. Rules synced into plugin. |
| ai-sdlc-workflows (shared/) | **Kept.** Authoritative source for rules/templates. Used by Cursor, Aider, etc. |
| qwickapps-dev-guide | **Separate.** Domain knowledge plugin. Phase 2: consolidate into /build-with command. |
| qwickapps-ux-design | **Separate.** UX framework enforcement. Complements designing-ux skill. |
| code-review plugin | **Replaced.** code-reviewer agent covers this. |
| plugin-dev | **Kept.** Different purpose (plugin development). |
| context7 | **Kept.** Documentation lookup MCP. |

## Implementation Notes

1. Skills are rewritten from scratch, not copied from superpowers. Follow the same quality standards (SATISFACTORY-CRITERIA) but written in our voice.
2. Commands absorb the best of ai-sdlc-workflows commands but restructured to leverage Claude Code capabilities (AskUserQuestion, TaskCreate, etc.).
3. Agent personas are refined versions of ai-sdlc-workflows agents, focused on their specific phase contributions.
4. Issue-driven development is woven into every command, not a separate workflow.
5. The sync scripts are simple shell scripts that copy files from ai-sdlc-workflows/shared/ into the plugin's rules/ and templates/ directories.

## Phase 2 (Separate Design)

Consolidate qwickapps-dev-guide's 3 skills (build-with-cms, build-with-server, build-frontend-app) into a unified /build-with command. This is a separate design effort after the SDLC plugin is operational.
