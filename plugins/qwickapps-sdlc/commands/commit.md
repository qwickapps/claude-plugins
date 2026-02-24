---
name: commit
description: Controlled commit with validation gates. Runs build, tests, and quality checks before committing. Generates commit message referencing the active issue.
---

The /commit command enforces quality before every commit.

## Argument

Accept an optional argument: the commit message. If provided, use it as the basis for the commit subject but still run all validation gates. Never skip gates regardless of the argument.

## Workflow

### Step 1: Pre-commit Validation

Run the following gates in order. If any gate fails, STOP. Show the exact failure output. Do not proceed to the next step.

Run build:
- `pnpm build` if `pnpm-lock.yaml` exists
- `npm run build` otherwise

Run tests:
- `pnpm test` if `pnpm-lock.yaml` exists
- `npm test` otherwise

Run lint:
- `pnpm lint` if `pnpm-lock.yaml` exists
- `npm run lint` otherwise

If a command is not defined in `package.json`, skip it and note the omission. Do not treat a missing script as a failure.

Reference VALIDATION-GATES.md for the full gate checklist. All applicable gates must pass before proceeding.

### Step 2: Review Changes

Run `git diff --staged` to see staged changes. Run `git diff` to see unstaged changes.

If nothing is staged:
- Show the unstaged changes
- Use AskUserQuestion to ask the user which files or hunks to stage before continuing

If changes are staged, show a summary of staged files and the diff.

### Step 3: Generate Commit Message

Analyze the staged diff and draft a commit message:
- Use conventional commits format: `feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `test:`, `perf:`
- Keep the subject line under 72 characters
- Add a blank line and body for non-trivial changes, explaining what and why (not how)
- Reference the active issue number if known: `feat: add auth flow (#42)`
- Do not invent an issue number. Omit the reference if no issue is known.

If the user provided a commit message as an argument, use it as the subject line but verify it follows the conventional commits format. Adjust the type prefix if it is missing.

### Step 4: Confirm

Use AskUserQuestion to present:
- The staged files list
- The full commit message

Ask the user to approve or revise. Wait for explicit approval before committing.

### Step 5: Commit

Execute `git commit -m "<message>"`.

Rules:
- Never use `--no-verify`
- Never use `--amend` unless the user explicitly requests it
- Never push. Pushing requires separate explicit user instruction.
- If the pre-commit hook fails, show the hook output and stop. Do not retry or work around the hook.
