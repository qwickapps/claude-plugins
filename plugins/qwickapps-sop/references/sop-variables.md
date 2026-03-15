# SOP Variable Reference

This document defines all SOP (Standard Operating Procedures) variables used by the SDLC plugin. SOP variables decouple the SDLC workflow methodology from specific tools and services.

## How It Works

1. The SDLC plugin references abstract variables like `KB_CREATE_DOCUMENT` in its skills and commands.
2. An optional SOP plugin (e.g., `qwickapps-sop`) provides a `session-start.sh` hook that outputs a `<sop-config>` block mapping each variable to a concrete tool or action.
3. At runtime, the AI resolves variables against the sop-config block.
4. If no SOP plugin is installed, SDLC skills fall back to local file operations.

## Creating Your Own SOP Plugin

To create an SOP plugin for your team:

1. Create a new plugin directory: `plugins/my-team-sop/`
2. Add `.claude-plugin/plugin.json` with your plugin metadata
3. Create `hooks/hooks.json` and `hooks/session-start.sh`
4. In `session-start.sh`, output a `<sop-config>` block mapping the variables below to your team's tools
5. Register the plugin in `marketplace.json`

Example for a team using Notion + Linear:

```
KB_CREATE_DOCUMENT = notion_create_page
KB_SEARCH_DOCUMENTS = notion_search
CTX_STORE_ISSUE = linear_add_comment
WORKTREE_ENFORCED = false
```

---

## Variable Definitions

### Knowledge Base (KB_*)

Document storage and retrieval for team knowledge: ADRs, spikes, designs, FRDs.

| Variable | Purpose | Parameters | Fallback (no SOP) |
|----------|---------|------------|-------------------|
| `KB_CREATE_DOCUMENT` | Create a document | title, type, content, labels | Save to `docs/{type}s/{name}.md` |
| `KB_GET_DOCUMENT` | Retrieve a document by ID | document_id | Read from `docs/` directory |
| `KB_LIST_DOCUMENTS` | List documents by type | type, limit | `ls docs/{type}s/` |
| `KB_SEARCH_DOCUMENTS` | Full-text search | query, type | `grep -r` in `docs/` directory |
| `KB_UPDATE_DOCUMENT` | Update existing document | document_id, content | Edit file in `docs/` |
| `KB_DELETE_DOCUMENT` | Delete a document | document_id | Remove file from `docs/` |

### Document Types (DOC_TYPE_*)

Abstract document categories mapped to the knowledge base's type system.

| Variable | Purpose | Typical Value |
|----------|---------|---------------|
| `DOC_TYPE_SPIKE` | Research findings, investigations | `spike` |
| `DOC_TYPE_ADR` | Architecture Decision Records | `adr` |
| `DOC_TYPE_FRD` | Functional Requirements Documents | `frd` |
| `DOC_TYPE_DESIGN` | Design documents, proposals | `architecture` or `design` |
| `DOC_TYPE_REVIEW` | Code review reports | `review` |
| `DOC_TYPE_SPEC` | Technical specifications | `spec` |

### Issue Context (CTX_*)

Working memory for issues — investigation notes, key files, approach, status.

| Variable | Purpose | Parameters | Fallback (no SOP) |
|----------|---------|------------|-------------------|
| `CTX_STORE_ISSUE` | Save/update issue context | key, content | Save to `.claude/issue-context/issue-{N}.md` |
| `CTX_GET_ISSUE` | Retrieve issue context | key | Read from `.claude/issue-context/issue-{N}.md` |
| `CTX_ISSUE_KEY_FORMAT` | Naming pattern for context keys | Template string | `issue-{N}` |

### Sprint Management (SPRINT_*)

Sprint artifacts: handoffs, plans, summaries.

| Variable | Purpose | Resolution | Fallback (no SOP) |
|----------|---------|-----------|-------------------|
| `SPRINT_HANDOFF_STORE` | Save sprint handoff | `KB_CREATE_DOCUMENT` with handoff labels | Save to `docs/sprints/sprint-{N}-handoff.md` |
| `SPRINT_PLAN_STORE` | Save sprint plan | `KB_CREATE_DOCUMENT` with plan labels | Save to `docs/sprints/sprint-{N}-plan.md` |
| `SPRINT_HANDOFF_GET` | Retrieve sprint handoff | `KB_SEARCH_DOCUMENTS` with handoff query | Read from `docs/sprints/` |
| `SPRINT_KEY_FORMAT` | Naming pattern for sprint artifacts | Template string | `sprint-{N}-handoff` |

### Audit Trail (AUDIT_*)

Workflow action logging for traceability.

| Variable | Purpose | Parameters | Fallback (no SOP) |
|----------|---------|------------|-------------------|
| `AUDIT_LOG` | Log a workflow action | agent, event, payload | Skip (no audit logging) |

### Worktree / Branch Isolation (WORKTREE_*)

Configuration for isolated workspaces during development.

| Variable | Purpose | Typical Values | Fallback (no SOP) |
|----------|---------|---------------|-------------------|
| `WORKTREE_ENFORCED` | Whether worktree usage is mandatory | `true` / `false` | `false` |
| `WORKTREE_SCRIPT` | Path to custom worktree creation script | `.claude/scripts/create-worktree.sh` | Use `EnterWorktree` tool |
| `WORKTREE_PREFIX` | Directory prefix for worktrees | `qwickapps-wt-` | `wt-` |
| `PROTECTED_BRANCHES` | Branches that require worktree isolation | `main,dev` | `main` |
| `PACKAGE_MANAGER` | Dependency installer | `pnpm` / `npm` / `yarn` | Auto-detect from lockfile |

### Project Management (PM_*)

Goals, items, and task tracking via a project management backend.

| Variable | Purpose | Fallback (no SOP) |
|----------|---------|-------------------|
| `PM_CREATE_GOAL` | Create a sprint goal | Use GitHub milestones |
| `PM_LIST_GOALS` | List active goals | `gh api` milestones |
| `PM_CREATE_ITEM` | Create a tracked work item | `gh issue create` |
| `PM_UPDATE_ITEM` | Update work item status | `gh issue edit` |
| `PM_LIST_ITEMS` | List work items | `gh issue list` |

### Secrets (SECRETS_*)

Encrypted configuration and environment variable management.

| Variable | Purpose | Fallback (no SOP) |
|----------|---------|-------------------|
| `SECRETS_GET` | Retrieve a secret value | Read from `.env` files |
| `SECRETS_LIST` | List available secrets | `cat .env` |
| `SECRETS_SET` | Store a secret value | Manual `.env` editing |

---

## Resolution Order

When an SDLC skill references a variable:

1. Check if a `<sop-config>` block exists in the conversation context
2. If yes, resolve the variable to the mapped tool/action
3. If no sop-config exists, use the fallback behavior (local files)

The SOP plugin's session-start hook is responsible for injecting the sop-config block. Multiple SOP plugins should not be installed simultaneously — only one should map the variables.
