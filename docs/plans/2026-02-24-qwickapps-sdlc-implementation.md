# qwickapps-sdlc Plugin Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the qwickapps-sdlc plugin that replaces superpowers + Claude portion of ai-sdlc-workflows with a unified SDLC plugin.

**Architecture:** A self-contained Claude Code plugin with 23 skills, 9 commands, 8 agents, 2 hooks, synced rules/templates, and sync scripts. Skills auto-load based on context. Commands are user-invocable workflows. Agents are personas loaded per phase. Hooks enforce skill activation and pre-commit validation.

**Tech Stack:** Claude Code plugin system (markdown + JSON + bash). GitHub CLI for issue management. QwickBrain MCP for document storage.

**Design doc:** `docs/plans/2026-02-24-qwickapps-sdlc-plugin-design.md`

---

## Task 1: Plugin Scaffold and Manifest

**Files:**
- Create: `plugins/qwickapps-sdlc/.claude-plugin/plugin.json`
- Create: All empty directories for the plugin structure

**Step 1: Create directory structure**

```bash
cd ~/Projects/claude-plugins-wt-dev-migration-docs
mkdir -p plugins/qwickapps-sdlc/.claude-plugin
mkdir -p plugins/qwickapps-sdlc/skills/{writing-tests,debugging,verifying-completion,securing-code,optimizing-performance,brainstorming,writing-plans,executing-plans,estimating-effort,delegating-tasks,parallelizing-work,requesting-review,receiving-review,creating-worktree,finishing-branch,tracking-issues,starting-sprint,closing-sprint,designing-ux,planning-release,deploying,getting-started,writing-skills}
mkdir -p plugins/qwickapps-sdlc/commands
mkdir -p plugins/qwickapps-sdlc/agents
mkdir -p plugins/qwickapps-sdlc/hooks
mkdir -p plugins/qwickapps-sdlc/rules
mkdir -p plugins/qwickapps-sdlc/templates
mkdir -p plugins/qwickapps-sdlc/scripts
```

**Step 2: Create plugin.json manifest**

```json
{
  "name": "qwickapps-sdlc",
  "version": "1.0.0",
  "description": "Complete software development lifecycle management. Replaces superpowers + ai-sdlc-workflows with unified issue-driven workflows, quality gates, agent personas, and engineering discipline skills.",
  "author": {
    "name": "QwickApps",
    "email": "support@qwickapps.com"
  },
  "keywords": ["sdlc", "tdd", "debugging", "planning", "code-review", "issue-tracking", "quality-gates", "workflows"]
}
```

**Step 3: Verify structure**

```bash
find plugins/qwickapps-sdlc -type d | sort
```

Expected: All directories created correctly.

**Step 4: Commit**

```bash
git add plugins/qwickapps-sdlc
git commit -m "feat(sdlc): scaffold qwickapps-sdlc plugin structure"
```

---

## Task 2: Sync Scripts + Rules + Templates

**Files:**
- Create: `plugins/qwickapps-sdlc/scripts/sync-rules.sh`
- Create: `plugins/qwickapps-sdlc/scripts/sync-templates.sh`
- Populate: `plugins/qwickapps-sdlc/rules/` (10 files)
- Populate: `plugins/qwickapps-sdlc/templates/` (8 files)

**Step 1: Create sync-rules.sh**

Script that copies rules from ai-sdlc-workflows/shared/rules/ into the plugin's rules/ directory. Source path: `~/Projects/ai-sdlc-workflows/shared/rules/`. Target: `${SCRIPT_DIR}/../rules/`.

**Step 2: Create sync-templates.sh**

Script that copies templates from ai-sdlc-workflows/shared/templates/ into the plugin's templates/ directory. Source path: `~/Projects/ai-sdlc-workflows/shared/templates/`. Target: `${SCRIPT_DIR}/../templates/`.

**Step 3: Run sync scripts**

```bash
bash plugins/qwickapps-sdlc/scripts/sync-rules.sh
bash plugins/qwickapps-sdlc/scripts/sync-templates.sh
```

**Step 4: Verify files copied**

```bash
ls plugins/qwickapps-sdlc/rules/
ls plugins/qwickapps-sdlc/templates/
```

Expected: 10 rule files, 8 template files.

**Step 5: Commit**

```bash
git add plugins/qwickapps-sdlc/scripts plugins/qwickapps-sdlc/rules plugins/qwickapps-sdlc/templates
git commit -m "feat(sdlc): add sync scripts and populate rules/templates"
```

---

## Task 3: Meta Skills (getting-started, writing-skills)

**Files:**
- Create: `plugins/qwickapps-sdlc/skills/getting-started/SKILL.md`
- Create: `plugins/qwickapps-sdlc/skills/writing-skills/SKILL.md`

**Source material:**
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/skills/using-superpowers/SKILL.md` (rewrite for qwickapps-sdlc)
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/skills/writing-skills/SKILL.md` (rewrite)

**Requirements:**
- `getting-started`: Meta skill explaining the 9 commands and 23 skills. Skill detection logic. Red flags for rationalization. Replace all superpowers references with qwickapps-sdlc.
- `writing-skills`: Creating new skills for plugins. TDD applied to documentation. Rewrite to reference qwickapps-sdlc patterns.

**Writing style:**
- YAML frontmatter with name and description (third person, specific trigger phrases)
- Body in imperative/infinitive form
- Target 1,500-2,000 words per SKILL.md
- Detailed content in references/ if needed

**Verify:** Check frontmatter has name + description, body < 3000 words, imperative form.

**Commit:**
```bash
git add plugins/qwickapps-sdlc/skills/getting-started plugins/qwickapps-sdlc/skills/writing-skills
git commit -m "feat(sdlc): add meta skills (getting-started, writing-skills)"
```

---

## Task 4: Engineering Discipline Skills (writing-tests, debugging, verifying-completion)

**Files:**
- Create: `plugins/qwickapps-sdlc/skills/writing-tests/SKILL.md`
- Create: `plugins/qwickapps-sdlc/skills/debugging/SKILL.md`
- Create: `plugins/qwickapps-sdlc/skills/verifying-completion/SKILL.md`

**Source material:**
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/skills/test-driven-development/SKILL.md`
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/skills/systematic-debugging/SKILL.md`
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/skills/verification-before-completion/SKILL.md`

**Requirements:**
- Rewrite each skill from scratch in qwickapps-sdlc voice
- Carry forward all core principles and hard gates
- Reference qwickapps-sdlc rules (VALIDATION-GATES.md, etc.) where relevant
- Use imperative form, third-person descriptions
- Target 1,500-2,000 words each

**Key principles to preserve:**
- `writing-tests`: RED-GREEN-REFACTOR. Write failing test first. Watch it fail. Minimal code to pass. Hard gate: no code without failing test.
- `debugging`: Root cause before fixes. Iron law: NO FIXES WITHOUT ROOT CAUSE. Systematic investigation.
- `verifying-completion`: Evidence before assertions. Fresh verification required. Hard gate: no completion claims without proof.

**Verify:** Frontmatter valid, body < 3000 words, imperative form, no superpowers references.

**Commit:**
```bash
git add plugins/qwickapps-sdlc/skills/writing-tests plugins/qwickapps-sdlc/skills/debugging plugins/qwickapps-sdlc/skills/verifying-completion
git commit -m "feat(sdlc): add engineering discipline skills (writing-tests, debugging, verifying-completion)"
```

---

## Task 5: Security and Performance Skills (securing-code, optimizing-performance)

**Files:**
- Create: `plugins/qwickapps-sdlc/skills/securing-code/SKILL.md`
- Create: `plugins/qwickapps-sdlc/skills/optimizing-performance/SKILL.md`

**Source material:** These are new skills (no superpowers equivalent). Write from scratch.

**Requirements:**
- `securing-code`: OWASP top 10 awareness. Auth patterns (JWT, session, OAuth). Input validation. Output encoding. CSRF protection. SQL injection prevention. XSS prevention. Auto-loads when writing auth code, API endpoints, form handling.
- `optimizing-performance`: Measure before optimizing. Profile, identify bottleneck, fix, measure again. No premature optimization. Database query optimization. Caching patterns. Lazy loading. Bundle size awareness.

**Verify:** Frontmatter valid, body < 3000 words, imperative form.

**Commit:**
```bash
git add plugins/qwickapps-sdlc/skills/securing-code plugins/qwickapps-sdlc/skills/optimizing-performance
git commit -m "feat(sdlc): add security and performance skills"
```

---

## Task 6: Planning Pipeline Skills (brainstorming, writing-plans, executing-plans, estimating-effort)

**Files:**
- Create: `plugins/qwickapps-sdlc/skills/brainstorming/SKILL.md`
- Create: `plugins/qwickapps-sdlc/skills/writing-plans/SKILL.md`
- Create: `plugins/qwickapps-sdlc/skills/executing-plans/SKILL.md`
- Create: `plugins/qwickapps-sdlc/skills/estimating-effort/SKILL.md`

**Source material:**
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/skills/brainstorming/SKILL.md`
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/skills/writing-plans/SKILL.md`
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/skills/executing-plans/SKILL.md`
- `estimating-effort` is new (no superpowers equivalent)

**Requirements:**
- Rewrite each from scratch. Carry forward core principles.
- `brainstorming`: Explore intent, AskUserQuestion for choices, propose 2-3 approaches, present design for approval. Hard gate: no implementation before design approval. Reference TaskCreate for tracking.
- `writing-plans`: Break design into bite-sized tasks (2-5 min each). Use TaskCreate per step. DRY, YAGNI, TDD. Save to docs/plans/.
- `executing-plans`: Load plan, review critically, execute in batches. Use TaskUpdate for progress. Default 3 tasks per batch with review.
- `estimating-effort`: Three-point estimation (optimistic/likely/pessimistic). Risk factors. Dependency mapping. Use AskUserQuestion for scope clarification.

**Verify:** Frontmatter valid, body < 3000 words, imperative form, references Claude Code capabilities (AskUserQuestion, TaskCreate, EnterPlanMode).

**Commit:**
```bash
git add plugins/qwickapps-sdlc/skills/brainstorming plugins/qwickapps-sdlc/skills/writing-plans plugins/qwickapps-sdlc/skills/executing-plans plugins/qwickapps-sdlc/skills/estimating-effort
git commit -m "feat(sdlc): add planning pipeline skills"
```

---

## Task 7: Delegation Skills (delegating-tasks, parallelizing-work)

**Files:**
- Create: `plugins/qwickapps-sdlc/skills/delegating-tasks/SKILL.md`
- Create: `plugins/qwickapps-sdlc/skills/parallelizing-work/SKILL.md`

**Source material:**
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/skills/subagent-driven-development/SKILL.md`
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/skills/dispatching-parallel-agents/SKILL.md`

**Requirements:**
- `delegating-tasks`: Fresh subagent per task via Task tool. Two-stage review: spec compliance then code quality. Reference requesting-review skill for review step.
- `parallelizing-work`: One Task subagent per independent problem domain. Decision tree for when to parallelize. Dispatch in parallel, collect results.

**Verify:** Frontmatter valid, body < 3000 words, imperative form.

**Commit:**
```bash
git add plugins/qwickapps-sdlc/skills/delegating-tasks plugins/qwickapps-sdlc/skills/parallelizing-work
git commit -m "feat(sdlc): add delegation skills"
```

---

## Task 8: Code Review Skills (requesting-review, receiving-review)

**Files:**
- Create: `plugins/qwickapps-sdlc/skills/requesting-review/SKILL.md`
- Create: `plugins/qwickapps-sdlc/skills/receiving-review/SKILL.md`

**Source material:**
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/skills/requesting-code-review/SKILL.md`
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/skills/receiving-code-review/SKILL.md`

**Requirements:**
- `requesting-review`: Dispatch code-reviewer agent via Task tool. Provide git SHAs, plan context, changed files. Mandatory after each delegated task, after major features, before merge.
- `receiving-review`: Verify before implementing. Ask before assuming. Technical correctness over social comfort. Never blindly agree. Challenge questionable feedback with evidence.

**Verify:** Frontmatter valid, body < 3000 words, imperative form.

**Commit:**
```bash
git add plugins/qwickapps-sdlc/skills/requesting-review plugins/qwickapps-sdlc/skills/receiving-review
git commit -m "feat(sdlc): add code review skills"
```

---

## Task 9: Git Workflow Skills (creating-worktree, finishing-branch)

**Files:**
- Create: `plugins/qwickapps-sdlc/skills/creating-worktree/SKILL.md`
- Create: `plugins/qwickapps-sdlc/skills/finishing-branch/SKILL.md`

**Source material:**
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/skills/using-git-worktrees/SKILL.md`
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/skills/finishing-a-development-branch/SKILL.md`
- `~/Projects/ai-sdlc-workflows/shared/rules/WORKTREE-ENFORCEMENT.md` (for worktree script patterns)

**Requirements:**
- `creating-worktree`: Use project's create-worktree.sh if available. Reference WORKTREE-ENFORCEMENT rule. Copy .env files, settings, run install. Use EnterWorktree as fallback if no script exists.
- `finishing-branch`: Use AskUserQuestion to present options (merge, PR, keep worktree, discard). Verify all tests pass first. Use verifying-completion skill before presenting options.

**Verify:** Frontmatter valid, body < 3000 words, imperative form.

**Commit:**
```bash
git add plugins/qwickapps-sdlc/skills/creating-worktree plugins/qwickapps-sdlc/skills/finishing-branch
git commit -m "feat(sdlc): add git workflow skills"
```

---

## Task 10: Project Management Skills (tracking-issues, starting-sprint, closing-sprint)

**Files:**
- Create: `plugins/qwickapps-sdlc/skills/tracking-issues/SKILL.md`
- Create: `plugins/qwickapps-sdlc/skills/starting-sprint/SKILL.md`
- Create: `plugins/qwickapps-sdlc/skills/closing-sprint/SKILL.md`

**Source material:**
- `tracking-issues` is new. Write from scratch.
- `starting-sprint` and `closing-sprint`: Reference ai-sdlc-workflows commands `/start-sprint` and `/close-sprint` if they exist, otherwise write from scratch.

**Requirements:**
- `tracking-issues`: Create GitHub issue via gh CLI (AskUserQuestion for permission first). Store local context in QwickBrain (set_memory). Commits reference issue numbers. Close issues on completion. Labels per command type (feature, bug, research, refactor, chore).
- `starting-sprint`: Load previous sprint handoff from QwickBrain (get_memory). Review open issues (gh issue list). Set sprint goals. Create sprint backlog using TaskCreate.
- `closing-sprint`: Create handoff document. Lessons learned. Store handoff in QwickBrain (create_document type: memory). Update GitHub project if applicable.

**Verify:** Frontmatter valid, body < 3000 words, imperative form, references gh CLI and QwickBrain MCP.

**Commit:**
```bash
git add plugins/qwickapps-sdlc/skills/tracking-issues plugins/qwickapps-sdlc/skills/starting-sprint plugins/qwickapps-sdlc/skills/closing-sprint
git commit -m "feat(sdlc): add project management skills"
```

---

## Task 11: Design and Release Skills (designing-ux, planning-release, deploying)

**Files:**
- Create: `plugins/qwickapps-sdlc/skills/designing-ux/SKILL.md`
- Create: `plugins/qwickapps-sdlc/skills/planning-release/SKILL.md`
- Create: `plugins/qwickapps-sdlc/skills/deploying/SKILL.md`

**Source material:** All new skills. Write from scratch. Reference ai-sdlc-workflows `/release` command for planning-release content.

**Requirements:**
- `designing-ux`: Generic UX guidance. Accessibility (WCAG). Responsive patterns. Component architecture. Color contrast. Keyboard navigation. Works alongside qwickapps-ux-design plugin (which adds framework-specific enforcement). Auto-loads when building UI/frontend.
- `planning-release`: Semantic versioning strategy (when to bump major/minor/patch). Changelog generation from commit messages and issue labels. Breaking change identification. Migration guide writing. Release notes drafting.
- `deploying`: CI/CD pipeline patterns. Environment promotion (dev, staging, production). Rollback strategies. Health checks. Docker deployment patterns. Infrastructure as code awareness.

**Verify:** Frontmatter valid, body < 3000 words, imperative form.

**Commit:**
```bash
git add plugins/qwickapps-sdlc/skills/designing-ux plugins/qwickapps-sdlc/skills/planning-release plugins/qwickapps-sdlc/skills/deploying
git commit -m "feat(sdlc): add design and release skills"
```

---

## Task 12: Commands Batch 1 (feature, bug, research)

**Files:**
- Create: `plugins/qwickapps-sdlc/commands/feature.md`
- Create: `plugins/qwickapps-sdlc/commands/bug.md`
- Create: `plugins/qwickapps-sdlc/commands/research.md`

**Source material:**
- `~/Projects/ai-sdlc-workflows/claude/.claude/commands/feature.md`
- `~/Projects/ai-sdlc-workflows/claude/.claude/commands/bug.md`
- `~/Projects/ai-sdlc-workflows/claude/.claude/commands/spike.md` (research replaces spike)

**Format:** YAML frontmatter with name + description, then markdown body.

**Requirements:**
- `/feature`: Full SDLC. Phases: Requirements (tracking-issues, brainstorming, AskUserQuestion) -> Design (brainstorming, designing-ux if frontend, EnterPlanMode for complex) -> Planning (writing-plans, TaskCreate) -> Implementation (creating-worktree, executing-plans OR delegating-tasks, writing-tests per task) -> Review (requesting-review, verifying-completion) -> Documentation (tech-writer persona) -> Commit (finishing-branch). Each phase uses AskUserQuestion for approval gates.
- `/bug`: Investigation (debugging, tracking-issues, root cause before fix) -> Fix (writing-tests for regression first, coder persona) -> Verification (verifying-completion, E2E) -> Commit (references issue).
- `/research`: Define question (AskUserQuestion) -> Create issue (tracking-issues) -> Investigation (RESEARCH-DEPTH, INVESTIGATION-METHODS rules, Explore agent, Grep, WebFetch, WebSearch, QwickBrain) -> Document findings (structured output: question, methods, evidence, options, unknowns, confidence, recommendation) -> Save to QwickBrain (create_document type: spike) -> Close issue.

**Verify:** YAML frontmatter valid, commands reference skills by name, use Claude Code capabilities (AskUserQuestion, TaskCreate, EnterPlanMode, Task subagents, gh CLI, QwickBrain MCP).

**Commit:**
```bash
git add plugins/qwickapps-sdlc/commands/feature.md plugins/qwickapps-sdlc/commands/bug.md plugins/qwickapps-sdlc/commands/research.md
git commit -m "feat(sdlc): add feature, bug, and research commands"
```

---

## Task 13: Commands Batch 2 (refactor, chore, review)

**Files:**
- Create: `plugins/qwickapps-sdlc/commands/refactor.md`
- Create: `plugins/qwickapps-sdlc/commands/chore.md`
- Create: `plugins/qwickapps-sdlc/commands/review.md`

**Source material:**
- `~/Projects/ai-sdlc-workflows/claude/.claude/commands/refactor.md`
- `~/Projects/ai-sdlc-workflows/claude/.claude/commands/code-review.md` (review replaces code-review)
- `chore` is new

**Requirements:**
- `/refactor`: Analysis (brainstorming for impact, architect persona) -> Plan (writing-plans, before/after) -> Implementation (creating-worktree, writing-tests for behavior preservation first) -> Verification (verifying-completion, prove no behavior change) -> Commit.
- `/chore`: Lighter than /feature. Define scope (AskUserQuestion) -> Implementation (relevant skills per task, writing-tests if code changes) -> Verification (verifying-completion) -> Commit. Labels: `chore`.
- `/review`: Load code-reviewer agent. Assess: security, quality, patterns, correctness. Output: issue list with file:line, severity, fix recommendations. Comment on PR if applicable (gh CLI).

**Verify:** YAML frontmatter valid, commands reference skills, use Claude Code capabilities.

**Commit:**
```bash
git add plugins/qwickapps-sdlc/commands/refactor.md plugins/qwickapps-sdlc/commands/chore.md plugins/qwickapps-sdlc/commands/review.md
git commit -m "feat(sdlc): add refactor, chore, and review commands"
```

---

## Task 14: Commands Batch 3 (commit, release, docs)

**Files:**
- Create: `plugins/qwickapps-sdlc/commands/commit.md`
- Create: `plugins/qwickapps-sdlc/commands/release.md`
- Create: `plugins/qwickapps-sdlc/commands/docs.md`

**Source material:**
- `~/Projects/ai-sdlc-workflows/claude/.claude/commands/commit.md`
- `~/Projects/ai-sdlc-workflows/claude/.claude/commands/release.md`
- `~/Projects/ai-sdlc-workflows/claude/.claude/commands/docs.md`

**Requirements:**
- `/commit`: Run validation gates (VALIDATION-GATES.md): build passes, tests pass, no critical warnings. Show diff summary (AskUserQuestion for confirmation). Generate commit message referencing issue. Commit (never push without explicit approval).
- `/release`: planning-release skill + engineering-manager persona. Version bump (AskUserQuestion: major/minor/patch). Changelog from issue labels. Migration guide if breaking changes. deploying skill for CI/CD. tech-writer persona for release docs.
- `/docs`: tech-writer persona. Identify what changed (git diff, issue context). Update relevant docs (README, CHANGELOG, API docs). Verify accuracy against code.

**Verify:** YAML frontmatter valid, commands reference skills, use Claude Code capabilities.

**Commit:**
```bash
git add plugins/qwickapps-sdlc/commands/commit.md plugins/qwickapps-sdlc/commands/release.md plugins/qwickapps-sdlc/commands/docs.md
git commit -m "feat(sdlc): add commit, release, and docs commands"
```

---

## Task 15: Agent Personas (all 8)

**Files:**
- Create: `plugins/qwickapps-sdlc/agents/code-reviewer.md`
- Create: `plugins/qwickapps-sdlc/agents/product-manager.md`
- Create: `plugins/qwickapps-sdlc/agents/architect.md`
- Create: `plugins/qwickapps-sdlc/agents/quality-engineer.md`
- Create: `plugins/qwickapps-sdlc/agents/coder.md`
- Create: `plugins/qwickapps-sdlc/agents/tech-writer.md`
- Create: `plugins/qwickapps-sdlc/agents/engineering-manager.md`
- Create: `plugins/qwickapps-sdlc/agents/devops.md`

**Source material:**
- `~/Projects/ai-sdlc-workflows/shared/agents/*.md` (8 agent personas)
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/4.3.1/agents/code-reviewer.md`

**Format:** YAML frontmatter with description and capabilities. Markdown body with detailed instructions.

**Requirements:**
- Rewrite each from scratch in qwickapps-sdlc voice
- Each agent should describe: role, focus areas, which commands load it, key principles
- `code-reviewer`: Reviews against plans and coding standards. Security, patterns, correctness. Issue list with file:line, severity, fixes.
- `product-manager`: User needs, acceptance criteria, success metrics. Uses AskUserQuestion for requirements gathering.
- `architect`: Technical feasibility, pattern reuse, minimal design. REUSE FIRST principle.
- `quality-engineer`: Edge cases, failure modes, test coverage. Test strategy planning.
- `coder`: Clean code, YAGNI, no over-engineering. Writing-tests skill always active.
- `tech-writer`: Accurate, minimal, user-facing documentation.
- `engineering-manager`: Multi-team coordination, prioritization, roadmap.
- `devops`: CI/CD, infrastructure, monitoring, deployment.

**Verify:** YAML frontmatter valid with description, body describes role clearly.

**Commit:**
```bash
git add plugins/qwickapps-sdlc/agents
git commit -m "feat(sdlc): add 8 agent personas"
```

---

## Task 16: Hooks (skill-activation, pre-commit-validation)

**Files:**
- Create: `plugins/qwickapps-sdlc/hooks/hooks.json`

**Requirements:**

Two hooks:

1. **skill-activation** (SessionStart): Prompt-based hook that loads getting-started skill at session start. Reminds agent to check for applicable skills before any response.

2. **pre-commit-validation** (PreToolUse on Bash): Intercepts git commit commands. Validates: build passes, tests pass. Blocks commit if gates fail. References VALIDATION-GATES.md rule.

**Hook format** (from plugin-dev:hook-development):
```json
{
  "SessionStart": [{
    "hooks": [{
      "type": "prompt",
      "prompt": "..."
    }]
  }],
  "PreToolUse": [{
    "matcher": "Bash",
    "hooks": [{
      "type": "prompt",
      "prompt": "..."
    }]
  }]
}
```

**Verify:** hooks.json is valid JSON. Hook events are valid (SessionStart, PreToolUse). Matchers correct.

**Commit:**
```bash
git add plugins/qwickapps-sdlc/hooks
git commit -m "feat(sdlc): add skill-activation and pre-commit-validation hooks"
```

---

## Task 17: Integration Validation

**Files:** No new files. Validation only.

**Step 1: Verify plugin structure**

```bash
find plugins/qwickapps-sdlc -type f | sort | wc -l
```

Expected: ~50 files (1 plugin.json + 23 SKILL.md + 9 commands + 8 agents + 1 hooks.json + 2 scripts + 10 rules + 8 templates = ~62 files).

**Step 2: Validate plugin.json**

```bash
python3 -c "import json; json.load(open('plugins/qwickapps-sdlc/.claude-plugin/plugin.json')); print('Valid JSON')"
```

**Step 3: Validate hooks.json**

```bash
python3 -c "import json; json.load(open('plugins/qwickapps-sdlc/hooks/hooks.json')); print('Valid JSON')"
```

**Step 4: Check all skills have SKILL.md with frontmatter**

```bash
for skill in plugins/qwickapps-sdlc/skills/*/SKILL.md; do
  echo "=== $skill ==="
  head -5 "$skill"
  echo ""
done
```

Expected: Each SKILL.md starts with `---` (YAML frontmatter).

**Step 5: Check all commands have frontmatter**

```bash
for cmd in plugins/qwickapps-sdlc/commands/*.md; do
  echo "=== $cmd ==="
  head -5 "$cmd"
  echo ""
done
```

Expected: Each command starts with `---` (YAML frontmatter).

**Step 6: Check all agents have frontmatter**

```bash
for agent in plugins/qwickapps-sdlc/agents/*.md; do
  echo "=== $agent ==="
  head -5 "$agent"
  echo ""
done
```

Expected: Each agent starts with `---` (YAML frontmatter).

**Step 7: Check no superpowers references remain**

```bash
grep -r "superpowers" plugins/qwickapps-sdlc/ || echo "No superpowers references found"
```

Expected: No matches (except possibly in design doc references).

**Step 8: Word count check for skills**

```bash
for skill in plugins/qwickapps-sdlc/skills/*/SKILL.md; do
  words=$(wc -w < "$skill")
  echo "$skill: $words words"
done
```

Expected: Each skill between 500-3000 words.

**Step 9: Final commit if any fixes needed**

Only commit if validation found issues that were fixed.
