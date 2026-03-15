---
name: sprint-conventions
description: >
  QwickApps sprint naming conventions and artifact storage patterns. Loaded automatically
  by the qwickapps-sop session-start hook. Defines how sprint handoffs, plans, and summaries
  are named and stored in Confluence via mcp__qwickapps__ MCP tools.
---

# QwickApps Sprint Conventions

This skill defines QwickApps-specific conventions for sprint artifacts. The SDLC plugin's
starting-sprint and closing-sprint skills reference SOP variables; this skill documents
how those variables resolve in the QwickApps context.

---

## Sprint Artifact Naming

| Artifact | Title Pattern | Type | Labels |
|----------|--------------|------|--------|
| Sprint Plan | `Sprint {N} Plan - {project}` | spike | `sprint-plan`, `sprint-{N}` |
| Sprint Handoff | `Sprint {N} Handoff - {project}` | spike | `sprint-handoff`, `sprint-{N}` |
| Sprint Summary | `Sprint {N} Summary - {project}` | spike | `sprint-summary`, `sprint-{N}` |

**Project names:** Use the GitHub repo name (e.g., `faabzi`, `work-macha`, `qwickapps`).

---

## Issue Context Storage

Issue context is stored using the Projects API's item context feature:

```
mcp__qwickapps__add_item_context:
  item_id: [the item UUID from the projects service]
  type: "note"
  content: |
    Issue: #{N} - {title}
    Label: {label}
    Branch: {branch-name}
    Approach: {strategy}
    Key files: {file list}
    Dependencies: {packages/services}
    Notes: {decisions, ADR refs}
    Status: {current status}
```

If the issue is not tracked in the Projects API (only in GitHub), fall back to storing
context as a document:

```
mcp__qwickapps__create_document:
  title: "Issue #{N} Context - {title}"
  type: "spike"
  labels: ["issue-context", "issue-{N}"]
  content: [context entry]
```

---

## Retrieving Sprint Artifacts

To find the latest sprint handoff:

```
mcp__qwickapps__search_documents:
  q: "sprint handoff"
  type: "spike"
```

To find a specific sprint's artifacts:

```
mcp__qwickapps__search_documents:
  q: "Sprint {N}"
  type: "spike"
```

---

## Confluence Space

All QwickApps sprint artifacts are stored in the **QwickForge** Confluence space
(spaceId: `18022403`). The documents API uses this as the default space when no
spaceId is specified.

---

## Cross-Repo Issues

When working in the qwickapps monorepo with issues from product repos (e.g., faabzi):

- Use `Closes qwickapps/faabzi#{N}` in PR descriptions to close cross-repo issues
- Label sprint artifacts with both the monorepo name and the product name
- Example labels: `sprint-plan`, `sprint-4`, `faabzi`
