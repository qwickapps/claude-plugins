---
name: planning-release
description: >
  This skill should be used when preparing a version release, bumping the version number,
  writing a changelog, identifying breaking changes, or coordinating the publication of a
  new version. Trigger phrases include: "release", "version bump", "prepare release",
  "write the changelog", "ship it", "tag a release", "publish a new version",
  "what changed since last release", "breaking changes", "migration guide".
  Load this skill at the start of any /release command workflow.
---

# Planning a Release

A release is not a deployment. A release is a versioned, documented artifact that communicates
what changed, at what version, and how to adopt it. This skill covers the full process from
version decision to published release on GitHub.

---

## The Release Process at a Glance

```
Determine version bump type
        |
        v
Confirm with user (AskUserQuestion)
        |
        v
Gather changes from git log and issues
        |
        v
Identify breaking changes
        |
        v
Write changelog
        |
        v
Write migration guide (if breaking)
        |
        v
Write release notes (user-facing)
        |
        v
Run pre-release checklist
        |
        v
Bump version in package.json (and related files)
        |
        v
Tag and create release via gh CLI
```

Never tag or publish before the pre-release checklist passes. Never bump the version before
the changelog and release notes are written. Order matters.

---

## 1. Semantic Versioning Decision

Every release falls into one of three categories. Determine the correct bump before writing
anything.

### Version Bump Rules

| Bump | When | Example |
|------|------|---------|
| Major (X.0.0) | Breaking change — existing consumers must change code to upgrade | API renamed, config key removed, required arg added |
| Minor (x.Y.0) | New feature — backward compatible, no consumer changes required | New endpoint, new optional config key, new export |
| Patch (x.y.Z) | Bug fix or internal change — no new features, no breaking changes | Fixed edge case, corrected error message, docs update |

### Breaking Change Criteria

A change is breaking when it requires any existing consumer to modify their code, config, or
environment to upgrade without error. Examples:

- A public function signature changed (parameter added, removed, or reordered)
- A config key renamed or removed
- An environment variable renamed or removed
- A data schema changed in a way that breaks existing data
- A dependency updated with breaking changes that leak into the public API
- Default behavior changed in a way that existing users relied upon

When in doubt, treat it as a breaking change. Mis-labeling a breaking change as minor harms
consumers more than a conservative major bump.

### Confirm the Version Bump

Before doing any work, confirm the bump type with the user:

```
I believe this release is a MINOR bump because [reason].
The new version would be X.Y.0.

Is that correct, or should it be a major or patch bump instead?
```

Wait for explicit confirmation before proceeding. Do not assume approval because the user
said "release" without specifying a version number.

---

## 2. Gather Changes

Collect all changes since the last release using git log and the GitHub issues list.

### Find the Last Release Tag

```bash
git describe --tags --abbrev=0
# Example output: v1.4.2
```

If no tags exist, the base is the initial commit.

### Get All Commits Since Last Release

```bash
git log v1.4.2..HEAD --oneline --no-merges
```

Review every commit. Categorize each one:

| Category | Commit Markers |
|----------|---------------|
| Breaking Change | `!`, `BREAKING CHANGE:` in footer, or identified via code inspection |
| Feature | `feat:`, `feature:`, issues labeled `feature` |
| Bug Fix | `fix:`, `bugfix:`, issues labeled `bug` |
| Chore | `chore:`, `refactor:`, `docs:`, `ci:`, `test:`, `build:` |

### Get Closed Issues Since Last Release

```bash
gh issue list --state closed --label feature --json number,title,closedAt
gh issue list --state closed --label bug --json number,title,closedAt
gh issue list --state closed --label breaking-change --json number,title,closedAt
```

Cross-reference issue numbers with commit messages. Every commit that references an issue
number should be linked to that issue in the changelog.

---

## 3. Identify Breaking Changes in Detail

For each potential breaking change, verify it is actually breaking by inspecting the diff:

```bash
git diff v1.4.2..HEAD -- src/
```

For each confirmed breaking change, document:

- What changed (the old behavior and the new behavior)
- Why it changed (the reason for the breaking change)
- What consumers must do to migrate (specific steps)
- What error they will see if they do not migrate (the failure message)

This information becomes the migration guide.

---

## 4. Write the Changelog

The changelog is the developer-facing record of every change. It is committed to the
repository as `CHANGELOG.md`.

### Changelog Format

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Breaking Changes

- **[#123]** Renamed `config.apiKey` to `config.secretKey`. Update all references in
  configuration files. ([#123](https://github.com/org/repo/issues/123))

### Features

- **[#118]** Added support for webhook retry on transient failures. Retries up to 3 times
  with exponential backoff. ([#118](https://github.com/org/repo/issues/118))

### Bug Fixes

- **[#120]** Fixed pagination returning incorrect total count when filters are applied.
  ([#120](https://github.com/org/repo/issues/120))

### Chores

- Updated `typescript` to 5.4.0.
- Migrated CI pipeline to GitHub Actions.
```

### Changelog Rules

- [ ] Breaking Changes section appears first, always
- [ ] Each entry references the issue or PR number with a link
- [ ] Each entry is one sentence describing the user-visible impact — not the implementation
- [ ] Chores that have no user-visible impact are listed briefly, without issue links
- [ ] Entries within each section are in reverse chronological order (newest first)
- [ ] Prepend the new section at the top of CHANGELOG.md — do not replace the file

---

## 5. Write the Migration Guide

Required when there are breaking changes. The migration guide belongs in `MIGRATION.md` at the
repository root, or in a `docs/migration/vX.md` file for projects with multiple major versions.

### Migration Guide Structure

```markdown
# Migration Guide: v{X-1} to v{X}

## Overview

{One paragraph: what changed at a high level and why}

## Breaking Changes

### {Change Name} (#123)

**Before:**
\`\`\`typescript
// How consumers wrote this before
\`\`\`

**After:**
\`\`\`typescript
// How consumers must write this now
\`\`\`

**Steps to migrate:**
1. {Specific action}
2. {Specific action}

**Error if you do not migrate:**
\`\`\`
{The exact error message they will see}
\`\`\`
```

### Migration Guide Rules

- [ ] Every breaking change has a before/after code example
- [ ] Every breaking change has numbered step-by-step migration instructions
- [ ] Every breaking change documents the error the consumer will see if they skip migration
- [ ] Language is imperative and specific — no vague instructions

---

## 6. Write the Release Notes

Release notes are the user-facing summary. They are shorter than the changelog and written
for the consumer, not the developer.

### Audience

Release notes are read by the person deciding whether to upgrade and by the person doing
the upgrade. Write for both. Assume technical competence but no knowledge of implementation
details.

### Release Notes Format

```markdown
## v{X.Y.Z}

Released {Month DD, YYYY}.

{One to three sentences: what is the headline of this release?}

### What's New

- {Feature}: {User-visible benefit in one sentence}
- {Feature}: {User-visible benefit in one sentence}

### Bug Fixes

- {Fixed}: {What the user experienced before, in past tense}

### Breaking Changes

This release contains breaking changes. See the [migration guide](MIGRATION.md) for
step-by-step upgrade instructions.

- {Breaking change}: {What changes for the user}
```

### Release Notes Rules

- [ ] Headline captures the most important change — what the user should know first
- [ ] Each feature entry states the user-visible benefit, not the implementation
- [ ] Bug fix entries describe the behavior the user observed, not the code that was wrong
- [ ] Breaking changes section is present and links to the full migration guide
- [ ] Tone is direct and informative — no marketing language

---

## 7. Pre-Release Checklist

Run through every item before bumping the version or tagging. All items must pass.

### Code Quality

- [ ] All CI checks pass on the release branch (`gh run list --branch release/vX.Y.Z`)
- [ ] No open issues labeled `release-blocker` (`gh issue list --label release-blocker`)
- [ ] All tests pass locally: `npm test` or `pnpm test`
- [ ] Build succeeds: `npm run build` or `pnpm build`
- [ ] No critical or high-severity audit advisories: `npm audit` or `pnpm audit`

### Documentation

- [ ] CHANGELOG.md updated with new section at the top
- [ ] MIGRATION.md updated (if breaking changes exist)
- [ ] README.md updated if default configuration, setup steps, or requirements changed
- [ ] JSDoc or TypeDoc comments present on all new public API surface

### Version References

- [ ] `package.json` version reflects the new version number (do not bump yet — just verify
      the new number is correct before bumping)
- [ ] Any other files that embed the version number are identified (lockfiles update
      automatically; constants files or docs may need manual updates)

---

## 8. Bump the Version

After the checklist passes, bump the version:

```bash
# Using npm
npm version patch    # 1.2.3 -> 1.2.4
npm version minor    # 1.2.3 -> 1.3.0
npm version major    # 1.2.3 -> 2.0.0

# Using pnpm
pnpm version patch
pnpm version minor
pnpm version major
```

`npm version` / `pnpm version` updates `package.json`, creates a commit, and creates a tag.
Review the version commit and tag before pushing.

If the project uses a different version management mechanism (monorepo, Changesets, etc.),
follow that project's version bump procedure instead.

---

## 9. Tag and Create the Release

Push the tag and create the GitHub release:

```bash
# Push the tag created by npm version
git push origin v{X.Y.Z}

# Create the release on GitHub
gh release create v{X.Y.Z} \
  --title "v{X.Y.Z}" \
  --notes-file release-notes.md \
  --verify-tag
```

For pre-releases:

```bash
gh release create v{X.Y.Z}-rc.1 \
  --title "v{X.Y.Z} Release Candidate 1" \
  --notes-file release-notes.md \
  --prerelease \
  --verify-tag
```

### After Creating the Release

- [ ] Verify the release appears at `https://github.com/{org}/{repo}/releases`
- [ ] Verify the release notes are correctly formatted
- [ ] Verify the tag points to the expected commit: `git show v{X.Y.Z} --stat`
- [ ] Close the release milestone on GitHub: `gh api repos/{org}/{repo}/milestones --jq '.[] | select(.title == "v{X.Y.Z}") | .number'` then `gh api repos/{org}/{repo}/milestones/{number} --method PATCH --field state=closed`

---

## 10. Reference: RELEASE.md Template

The `templates/RELEASE.md` file in this plugin contains a structured release planning
document. Fill it out before beginning any release to record the release plan, approvals,
and post-release verification status. Use it as a tracking document during the release
process, not a deliverable.

---

## Common Mistakes

| Mistake | Consequence |
|---------|-------------|
| Tagging before tests pass | Tag must be deleted and re-created after fix |
| Writing changelog after creating the release | Release notes are incomplete or inconsistent |
| Calling a breaking change a minor bump | Consumers upgrade and their code breaks |
| Missing a migration step | Consumers cannot upgrade without searching issues |
| Using imperative future tense in changelog | "Will fix" — changelog records the past |
| Skipping the user confirmation on version bump | Wrong version type shipped |

---

## Release Verification Checklist

After publishing, verify the release:

- [ ] Release visible on GitHub with correct notes
- [ ] Tag points to the correct commit
- [ ] Package published to registry (if applicable) with correct version
- [ ] Milestone closed on GitHub
- [ ] Changelog committed and pushed to main/trunk
- [ ] Migration guide committed and pushed (if applicable)
