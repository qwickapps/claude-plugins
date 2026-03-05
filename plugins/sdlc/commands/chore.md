---
name: chore
description: Maintenance and cleanup tasks. Lighter workflow for dependency updates, CI fixes, config changes, and other non-feature work that still needs discipline.
---

The /chore command provides disciplined maintenance without full feature ceremony. Issue tracking and verification are still required.

## Argument

Accept an optional argument: a description of the chore. If not provided, use AskUserQuestion to ask the user what maintenance work needs to be done before proceeding.

## Workflow

### Step 1: Define Scope

Load `sdlc:tracking-issues` to create a new GitHub issue with the label `chore`. If the user provided an existing issue number, link to it rather than creating a new one.

If the scope is ambiguous, use AskUserQuestion to clarify:
- What specifically needs to change
- What is out of scope for this chore
- Whether there are any compatibility or environment constraints

Restate the agreed scope explicitly before proceeding. Do not begin implementation until scope is clear.

### Step 2: Implementation

Choose the approach based on the type of chore.

**Dependency updates:**
- Identify the dependency and the target version
- Check the package's changelog for breaking changes between the current version and the target
- Update the dependency in `package.json` or equivalent
- Run `pnpm install` (or `npm install`) to update the lockfile
- Run the full test suite immediately after updating
- If tests fail, investigate whether the failure is caused by the update before concluding anything
- Apply FACT-VERIFICATION.md: do not assert compatibility without running the tests

**CI/CD changes:**
- Load `sdlc:deploying` for context on the deployment pipeline
- Read the relevant CI configuration files before making any changes
- Make the minimum change needed to address the issue
- Verify the change is syntactically valid (e.g., `yamllint` for YAML files)
- Document what the change does and why in the issue

**Configuration changes:**
- Read the existing configuration at the relevant file:line before modifying it
- Verify the target environment requirements before applying the change
- Apply the minimum change needed
- Confirm the change is consistent with other environments (local, staging, production)

**Code cleanup and other changes:**
- Load `sdlc:writing-tests` if the cleanup touches behavior (e.g., removes a workaround, fixes a misnamed function)
- Make the minimum change needed
- Run linting after cleanup: `pnpm lint` or `npm run lint`

Apply RESEARCH-DEPTH.md for any chore where the impact is not fully understood before starting. Do not make changes based on assumptions.

Load `sdlc:creating-worktree` to set up an isolated workspace if the change involves code or configuration files. Follow WORKTREE-ENFORCEMENT.md: use the create-worktree.sh script.

### Step 3: Verification

Load `sdlc:verifying-completion`.

Run the applicable gates from VALIDATION-GATES.md based on what was changed:

Run build:
- `pnpm build` if `pnpm-lock.yaml` exists
- `npm run build` otherwise

Run tests:
- `pnpm test` if `pnpm-lock.yaml` exists
- `npm test` otherwise

Run lint:
- `pnpm lint` if `pnpm-lock.yaml` exists
- `npm run lint` otherwise

If a command is not defined in `package.json`, skip it and note the omission.

If any gate fails, STOP. Show the exact failure output. Do not proceed until the failure is resolved or the user explicitly approves continuing with a documented reason.

Apply SATISFACTORY-CRITERIA.md before marking verification complete. The original problem stated in the issue must be solved, not just addressed superficially.

### Step 4: Commit and Close

Commit with a message that:
- Uses `chore:` conventional commits prefix
- Describes what was done and why in the subject line
- References the issue number using `#N` notation: `chore: update eslint to v9 (#88)`

Include in the commit or PR description:
- What changed and the motivation
- What was verified (test results, build results)
- Any follow-up work that was intentionally left out of scope

Close the GitHub issue on merge. Do not close it before the PR is merged.
