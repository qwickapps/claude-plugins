---
name: env-management
description: >
  How to use the secrets system for encrypted environment variable management.
  Covers the merge cascade, variable interpolation, _null removal, team setup,
  and troubleshooting. Load this skill when working with environments.yml,
  .env files, or SOPS encryption. Trigger phrases: 'environment variables',
  'secrets management', 'env files', 'sops', 'encrypted config'.
---

# Environment Management with the Secrets Plugin

## Overview

The secrets plugin manages environment variables in a single encrypted YAML file (`environments.yml`). Variables are organized hierarchically and resolved through a merge cascade.

## Architecture

### Merge Cascade

Variables resolve in three layers. Later layers override earlier ones:

```
global -> project -> environment
```

Example: If `global` sets `NODE_ENV=development` and `projects.faabzi.environments.prod` sets `NODE_ENV=production`, the resolved value for faabzi/prod is `production`.

### Variable Interpolation

Values can reference other variables with `${VAR}` syntax:

```yaml
config:
  BASE_URL: https://example.com
  API_URL: ${BASE_URL}/api
  WEBHOOK_URL: ${API_URL}/webhooks
```

Interpolation runs up to 5 passes to resolve chained references.

### _null Removal

Set a value to `_null` to remove a key inherited from a parent layer:

```yaml
global:
  config:
    DEBUG: "true"

projects:
  myapp:
    environments:
      prod:
        config:
          DEBUG: _null   # Removes DEBUG entirely in prod
```

## File Structure

```yaml
global:
  config:
    KEY: value           # Non-secret config shared by all projects
  secrets:
    SECRET_KEY: value    # Secrets shared by all projects

projects:
  project-name:
    config:
      APP_NAME: myapp    # Project-level config
    secrets:
      DB_PASSWORD: xxx   # Project-level secrets
    environments:
      dev:
        config: {}       # Environment-specific overrides
        secrets: {}
      prod:
        config:
          NODE_ENV: production
        secrets:
          DB_PASSWORD: prod-password  # Overrides project-level
```

## Commands

### /secrets list
Show all projects with variable counts per environment.

### /secrets resolve --project P --env E
Output the final merged KEY=VALUE pairs after cascade + interpolation.

### /secrets local --project P --env E [--output path]
Generate a `.env` file for local development. Use `--dry-run` to preview with masked values.

### /secrets worktree --project P [--env E] [--output dir]
Generate `.env.local` files in the correct locations for a worktree. Defaults to `dev` environment. Knows project-specific paths (e.g., faabzi writes to both `clients/faabzi/client/` and `clients/faabzi/control-panel/`).

### /secrets github --project P --env E
Push secrets to GitHub Actions organization secrets. Names follow the convention `<PROJECT>_<KEY>`.

### /secrets caprover --project P --env E
Generate an env file for CapRover deployment. Maps environments to infrastructure targets (prod -> oci-main, dev/uat -> oci-dev).

### /secrets diff --project P
Compare resolved variables against what's currently in GitHub Actions secrets. Shows missing secrets per environment.

### /secrets validate
Validate the environments.yml schema and check for unresolved `${VAR}` references.

### /secrets-init
Bootstrap a new repo with `.sops.yaml` and encrypted `environments.yml`.

## Encryption

### Editing
```bash
sops environments.yml       # Opens decrypted in $EDITOR, re-encrypts on save
```

### Manual encrypt/decrypt
```bash
sops -e -i environments.yml  # Encrypt in place
sops -d environments.yml     # Decrypt to stdout
```

### Key Location (resolution chain)
1. `$SOPS_AGE_KEY_FILE` environment variable
2. `~/.config/sops/age/keys.txt` (SOPS standard)
3. `~/Projects/keys/environments.age.key` (legacy)

## Team Setup

### New team member
1. Install tools: `brew install sops age yq`
2. Get the age private key from a team member (secure channel)
3. Save to `~/.config/sops/age/keys.txt`
4. Verify: `sops -d environments.yml | head`

### Adding a new project
1. `sops environments.yml` (opens editor)
2. Add project block under `projects:`
3. Save (auto-encrypts)
4. `/secrets list` to verify

### Adding a new team member's key
1. Get their public key (`grep "public key" ~/.config/sops/age/keys.txt`)
2. Add to `.sops.yaml` (comma-separated age recipients)
3. Re-encrypt: `sops updatekeys environments.yml`

## Troubleshooting

### "Failed to decrypt"
- Check age key exists at one of the resolution chain paths
- Verify key matches: `grep "public key" <key_file>` should match `.sops.yaml`

### "environments.yml not found"
- Run `/secrets-init` to bootstrap
- Or set `ENVIRONMENTS_YML=/path/to/environments.yml`

### "yq/sops not found"
- `brew install sops age yq`

### Unencrypted file warning
- The pre-commit guard hook blocks staging unencrypted `environments.yml`
- Fix: `sops -e -i environments.yml`

### Git pre-commit hook
- Install: `cp <plugin>/scripts/sops-pre-commit.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit`
- Or use with husky/lefthook by referencing the script path
