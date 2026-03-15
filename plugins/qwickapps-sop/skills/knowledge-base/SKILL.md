---
name: knowledge-base
description: >
  QwickApps knowledge base configuration. Maps SDLC knowledge base variables (KB_*, DOC_TYPE_*)
  to mcp__qwickapps__ document tools backed by Confluence. This skill is auto-configured by the
  qwickapps-sop session-start hook. Reference it when you need to understand how documents are
  stored and retrieved in the QwickApps ecosystem.
---

# QwickApps Knowledge Base

The QwickApps knowledge base uses Confluence (via the Documents API and mcp__qwickapps__ MCP tools)
to store and retrieve team knowledge: ADRs, spikes, designs, FRDs, reviews, and specs.

---

## Tool Mapping

| SOP Variable | MCP Tool | Notes |
|-------------|----------|-------|
| `KB_CREATE_DOCUMENT` | `mcp__qwickapps__create_document` | Requires: title, type, content |
| `KB_GET_DOCUMENT` | `mcp__qwickapps__get_document` | Requires: document_id |
| `KB_LIST_DOCUMENTS` | `mcp__qwickapps__list_documents` | Filter by type, spaceId |
| `KB_SEARCH_DOCUMENTS` | `mcp__qwickapps__search_documents` | Full-text search via Confluence CQL |
| `KB_UPDATE_DOCUMENT` | `mcp__qwickapps__update_document` | Requires: document_id |
| `KB_DELETE_DOCUMENT` | `mcp__qwickapps__delete_document` | Requires: document_id |

---

## Document Types

| SOP Variable | Confluence Type | Usage |
|-------------|----------------|-------|
| `DOC_TYPE_SPIKE` | `spike` | Research findings, investigations, sprint artifacts |
| `DOC_TYPE_ADR` | `adr` | Architecture Decision Records |
| `DOC_TYPE_FRD` | `frd` | Functional Requirements Documents |
| `DOC_TYPE_DESIGN` | `architecture` | Design documents, system architecture |
| `DOC_TYPE_REVIEW` | `review` | Code review reports |
| `DOC_TYPE_SPEC` | `spec` | Technical specifications |

---

## Creating a Document

```
mcp__qwickapps__create_document:
  title: "ADR: Use JWT for session management"
  type: "adr"
  labels: ["auth", "session-management"]
  content: |
    # ADR: Use JWT for Session Management

    ## Status
    Accepted

    ## Context
    [Decision context]

    ## Decision
    [What was decided]

    ## Consequences
    [Impact of the decision]
```

---

## Searching for Existing Knowledge

Before creating new documents, always search for existing knowledge:

```
mcp__qwickapps__search_documents:
  q: "JWT session"
  type: "adr"
```

This prevents duplicate ADRs and ensures past decisions are respected.

---

## Labels Convention

Use labels to categorize and retrieve documents:

- **By topic:** `auth`, `payments`, `api`, `database`
- **By sprint:** `sprint-4`, `sprint-plan`, `sprint-handoff`
- **By issue:** `issue-42`, `issue-context`
- **By product:** `faabzi`, `work-macha`

Labels enable efficient retrieval without knowing document IDs.

---

## Approval Workflow

Documents support an approval workflow via the Documents API:

1. Create document (status: draft)
2. Request approval: `mcp__qwickapps__request_document_approval`
3. Reviewer approves/rejects: `mcp__qwickapps__approve_document` / `reject_document`

Use approvals for ADRs and FRDs that need team sign-off before implementation.
