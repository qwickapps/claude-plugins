---
name: review
description: Code quality assessment. Reviews code, PRs, or diffs for security, quality, patterns, and correctness. Outputs issues with file:line, severity, and fix recommendations.
---

The /review command performs a thorough code quality assessment. Never auto-comment on PRs or post findings anywhere without explicit user approval.

## Argument

Accept an optional argument: a PR number, a branch name, or one or more file paths. If no argument is provided, review staged and unstaged changes in the current branch.

## Workflow

### Step 1: Identify Scope

Determine what to review based on the argument:

**PR number (e.g., `123` or `#123`):**
- Fetch the PR: `gh pr view 123`
- Fetch the diff: `gh pr diff 123`
- Note the base branch, target branch, and PR description for context

**Branch name (e.g., `feature-auth`):**
- Fetch the diff against main: `git diff main...feature-auth`
- Fetch commit history: `git log main...feature-auth --oneline`

**File paths (e.g., `src/auth.ts src/middleware.ts`):**
- Read each specified file
- Fetch recent changes to those files: `git log --oneline -10 -- <file>`

**No argument:**
- Fetch staged changes: `git diff --staged`
- Fetch unstaged changes: `git diff`
- If both are empty, use AskUserQuestion to ask the user what to review before proceeding

### Step 2: Gather Context

Before assessing any code, gather the context needed to review it fairly.

Identify test files associated with the changed code. Read them to understand the intended behavior.

If reviewing a PR, read the PR description for stated intent. Use the stated intent when evaluating whether the code does what it claims.

Use Grep to find existing patterns in the codebase for any area where the changed code introduces a new approach. Deviating from an established pattern is a finding only if the deviation is unjustified. If the new code sets a better pattern, note it as a positive.

Adopt the code-reviewer agent persona for the assessment.

Apply RESEARCH-DEPTH.md. Do not assert that code has a problem without evidence (file:line). Do not assert compatibility or security concerns without tracing the actual code path.

### Step 3: Assess

Evaluate the code across five dimensions. For each finding, note the file:line, the dimension, the severity, and a concrete fix recommendation.

**Security**
Apply the OWASP Top 10 as a checklist. Look for:
- Input validation: is user input sanitized before use?
- Output encoding: is dynamic content encoded before rendering?
- Authentication: are protected routes actually protected?
- Authorization: are permission checks present and correct?
- Injection: is dynamic content ever interpolated into SQL, shell commands, or HTML?
- Sensitive data exposure: are secrets, tokens, or PII handled safely?

Load `sdlc:securing-code` for deeper security analysis if the code touches authentication, authorization, or data access paths.

**Quality**
Look for:
- DRY violations: is the same logic duplicated in multiple places?
- YAGNI violations: is there code that was not requested and does not serve a stated requirement?
- Naming: do names accurately describe what they hold or do?
- Readability: would a new contributor understand this code without asking?
- Error handling: are errors caught, logged, and surfaced appropriately?
- Dead code: is there code that cannot be reached or is never called?

**Patterns**
Look for:
- Consistency with established codebase conventions (verified by Grep, not assumed)
- Inconsistent use of async/await vs. promises vs. callbacks
- Inconsistent use of error handling patterns
- Any pattern introduced here that conflicts with patterns in neighboring files

**Correctness**
Look for:
- Logic errors: conditions that evaluate to the wrong value in edge cases
- Off-by-one errors in loops or array access
- Race conditions: shared state accessed without synchronization
- Null or undefined dereferences: missing null checks before property access
- Type mismatches: values used in a context that expects a different type

**Testing**
Look for:
- Missing tests for the changed code
- Tests that pass trivially and do not exercise real behavior
- Missing edge case coverage (null inputs, empty collections, error paths)
- Tests that assert implementation details instead of behavior

### Step 4: Output Findings

Present findings as a structured list ordered by severity. Use plain text, no emojis.

For each finding:

```
[SEVERITY] file:line
Description: What the issue is and why it matters.
Fix: Concrete recommendation. Include example code if the fix is non-obvious.
```

Severity levels:
- CRITICAL: security vulnerability, data loss risk, or crash in normal usage
- HIGH: incorrect behavior, missing required validation, or significant regression risk
- MEDIUM: pattern inconsistency, readability problem, or missing coverage for important edge cases
- LOW: style issue, naming improvement, or minor readability suggestion

After the findings list, present a summary:
- Total issues by severity: N critical, N high, N medium, N low
- Overall assessment: one of `Approve`, `Approve with comments`, `Request changes`
- Key strengths: at most three things done well, with file:line references

Apply SATISFACTORY-CRITERIA.md before presenting the output. Findings without file:line evidence are not acceptable. Do not include vague assessments ("this might cause issues") without concrete evidence.

Apply WRITING-STYLE.md throughout. Keep sentences short. One finding per entry. No hedging without explanation.

### Step 5: Post to PR (optional)

If reviewing a PR, use AskUserQuestion to ask the user whether to post the findings as a PR review comment.

Wait for explicit approval before taking any action. If the user approves:
- Use `gh pr review <number> --comment --body "<findings>"` for a comment-only review
- Use `gh pr review <number> --request-changes --body "<findings>"` only if the user explicitly asks to request changes
- Use `gh pr review <number> --approve --body "<findings>"` only if the user explicitly asks to approve

Never auto-post. Never choose the review type (comment, approve, request-changes) without asking the user which they want.
