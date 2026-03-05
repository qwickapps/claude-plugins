---
name: docs
description: Documentation updates. Identifies what changed, updates relevant docs (README, CHANGELOG, API docs), and verifies accuracy against code.
---

The /docs command keeps documentation accurate and synchronized with the codebase.

## Argument

Accept an optional argument: the topic or file to document (e.g., `auth flow`, `README setup section`, `payments API`). If provided, scope all phases to that topic. If not provided, derive the scope from the current branch or recent changes.

## Workflow

### Step 1: Identify Scope

Adopt the tech-writer agent persona.

Determine what needs documenting using the following priority order:

1. If an argument was provided, use it as the scope. Proceed to Step 2.
2. If on a feature branch, run `git diff main...HEAD --name-only` to find changed files. Use those files to infer the scope.
3. If an issue number is in context (e.g., from the branch name or a recent TaskCreate), retrieve that issue with `gh issue view <number>` and use the issue title and body to infer the scope.
4. If none of the above apply, use AskUserQuestion to ask the user what to document before proceeding.

### Step 2: Assess Documentation Scope

For the identified scope, check which of the following need updates. Read each file before assessing it.

README.md:
- Setup instructions
- Features list
- Configuration reference
- Environment variables

CHANGELOG.md:
- New version entry (if this docs update follows a code change)

API documentation (look for `docs/api/`, `openapi.yaml`, `swagger.json`, or similar):
- New or changed endpoints
- Updated request/response shapes
- Deprecated fields

Code comments:
- Functions or modules with non-obvious logic added or changed
- Public API surface with missing or outdated JSDoc/TSDoc

Type definitions:
- Public types and interfaces that form the external API surface

Use Grep to search for references to the changed symbols or features across existing documentation. Note which references are outdated.

### Step 3: Write Updates

For each document identified in Step 2:

1. Read the current content using Read.
2. Identify what is outdated or missing by comparing against the actual code.
3. Write the update.

Rules for writing:
- Verify every file path, function signature, and behavior claim against the actual code using Read or Grep before writing it into documentation
- Include code examples only if they can be verified against the implementation
- Do not duplicate what the code already says clearly in well-named variables and functions
- Keep documentation minimal and accurate; prefer removing outdated content over leaving it

For API documentation, read the route handler or controller to confirm the documented behavior matches the implementation.

For README updates, read the relevant source files (config loaders, environment variable usage) to confirm setup instructions are accurate.

### Step 4: Verify Accuracy

After writing, cross-reference every factual claim in the updated documentation against the code.

Use Grep to confirm:
- Function names exist where documented
- File paths are correct
- Environment variable names match actual usage in code

Use Read to confirm:
- Code examples match actual signatures and return types
- Configuration options match actual config schema

Apply FACT-VERIFICATION.md: every claim must have a verification method. Do not publish documentation with unverified claims.

### Step 5: Stage and Commit

Stage only documentation files. Do not stage unrelated code changes.

Use a conventional commit for the documentation update:
- `docs: update README setup instructions`
- `docs: document payments API endpoints`
- `docs: add migration guide for v2 auth changes`

Present the staged files and commit message to the user via AskUserQuestion. Wait for approval before committing.

Run the commit using `git commit`. Do not push.
