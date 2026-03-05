---
name: secrets
description: Manage encrypted environment variables. Subcommands: list, resolve, local, github, caprover, diff, worktree, validate.
---

The /secrets command manages encrypted environment variables stored in `environments.yml` (SOPS+age encrypted).

## Argument

Accept a required subcommand as the first argument, followed by optional flags:

```
/secrets <subcommand> [--project <name>] [--env <env>] [--dry-run] [--output <path>]
```

Subcommands:
- `list` - List all projects and environments
- `resolve` - Output merged KEY=VALUE pairs (requires --project, --env)
- `local` - Generate .env files for local dev (requires --project, --env)
- `github` - Push secrets to GitHub Actions (requires --project, --env)
- `caprover` - Generate CapRover env file (requires --project, --env)
- `diff` - Compare resolved vs current targets (requires --project)
- `worktree` - Generate .env files for a worktree (requires --project)
- `validate` - Validate environments.yml schema

## Execution

### Step 1: Parse the user's argument

Extract the subcommand and any flags from the argument string. If no argument provided, default to `list`.

Map common natural language to subcommands:
- "show me all projects" -> `list`
- "generate env for faabzi dev" -> `local --project faabzi --env dev`
- "push faabzi prod to github" -> `github --project faabzi --env prod`
- "what's different for faabzi" -> `diff --project faabzi`

### Step 2: Build and run the command

Construct the bash command:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sync-env.sh" <subcommand> [flags]
```

Examples:
```bash
# List all projects
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sync-env.sh" list

# Resolve faabzi prod
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sync-env.sh" resolve --project faabzi --env prod

# Generate local .env
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sync-env.sh" local --project faabzi --env dev --output ./clients/faabzi/client/.env.local

# Dry run github sync
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sync-env.sh" github --project faabzi --env prod --dry-run

# Worktree env generation
bash "${CLAUDE_PLUGIN_ROOT}/scripts/sync-env.sh" worktree --project faabzi --output .
```

Run the command using the Bash tool.

### Step 3: Present results

Show the command output to the user. For `list` and `resolve`, display the full output. For `local`, `github`, `caprover`, confirm what was written or pushed. For `diff`, highlight any missing secrets.

If the command fails, check:
1. Is `sops` installed? (`brew install sops`)
2. Is `yq` installed? (`brew install yq`)
3. Does `environments.yml` exist? (run `/secrets-init` to bootstrap)
4. Is the age key accessible? (check `~/.config/sops/age/keys.txt`)
