---
name: release
description: Version release management. Determines version bump, generates changelog, creates migration guide if needed, tags release, and creates GitHub release.
---

The /release command manages the full release process from changelog generation through GitHub release creation.

## Argument

Accept an optional argument: a version number (e.g., `1.4.0`) or bump type (`major`, `minor`, `patch`, `prerelease`). If provided, skip the version strategy step and use the given value. If not provided, determine the version bump from the evidence in Phase 2.

## Phases

### Phase 1: Gather Changes

Load `sdlc:planning-release` for context on the release process.

Collect changes since the last release tag:

```
git log $(git describe --tags --abbrev=0)..HEAD --oneline
```

If no previous tag exists, collect all commits: `git log --oneline`.

List closed issues since the last release. Use `gh issue list --state closed` and filter by milestone or date if available.

Identify breaking changes: look for commits with `!` after the type (e.g., `feat!:`) or a `BREAKING CHANGE:` footer in commit bodies (`git log --format="%B" $(git describe --tags --abbrev=0)..HEAD`).

### Phase 2: Version Strategy

If the argument did not specify a version or bump type, use AskUserQuestion to confirm the bump type. Present the evidence:
- List breaking changes found (if any) → recommends major
- List new features found (if any, no breaking changes) → recommends minor
- List only bug fixes and chores → recommends patch

Show the recommended bump type and the evidence for it. Wait for user confirmation before proceeding.

### Phase 3: Changelog

Generate a changelog grouped in this order:
1. Breaking Changes (if any)
2. Features
3. Bug Fixes
4. Chores

Each entry must reference its issue or PR number using `#N` notation. Derive entries from commit messages and closed issues. Do not include entries without a clear user-visible effect unless they are breaking changes.

Write the changelog to `CHANGELOG.md`. If the file already exists, prepend the new section. Do not overwrite previous entries.

### Phase 4: Migration Guide

If the version bump is major, write a migration guide.

For each breaking change:
- State what changed
- Show a before/after code example
- List any required manual steps

Write the guide to `MIGRATION.md` or append to an existing migrations directory if one exists. Reference the migration guide in the changelog under Breaking Changes.

If the version bump is not major, skip this phase.

### Phase 5: Pre-release Checklist

Verify all of the following before tagging. If any item fails, STOP and report it. Do not tag a release with failing gates.

Run build:
- `pnpm build` or `npm run build`

Run tests:
- `pnpm test` or `npm test`

Check for open release-blocker issues:
- `gh issue list --label release-blocker --state open`

If any release-blocker issues are open, report them and stop. Do not proceed until they are closed or the user explicitly approves continuing.

Run dependency audit:
- `pnpm audit` or `npm audit`

Report any high or critical vulnerabilities. Use AskUserQuestion to ask whether to proceed if vulnerabilities are found.

### Phase 6: Tag and Release

Use AskUserQuestion to present the full release summary before tagging:
- New version number
- Changelog content
- Any migration guide created
- Pre-release checklist results

Wait for explicit user approval.

Once approved, bump the version:
- `pnpm version <version>` or `npm version <version>`

This creates a version commit and a git tag. Push the tag:
- `git push --follow-tags`

Create the GitHub release:
- `gh release create <tag> --title "<tag>" --notes-file <changelog-section>`

For pre-releases, add the `--prerelease` flag to the `gh release create` command.

### Phase 7: Post-release

If deployment is needed after the release, load `sdlc:deploying` to handle the deployment steps.

Close the release milestone if one exists:
- `gh api repos/:owner/:repo/milestones` to find it
- `gh api --method PATCH repos/:owner/:repo/milestones/<number> -f state=closed`

Report the completed release: tag name, GitHub release URL, and any deployment status.
