---
name: secrets-init
description: Bootstrap a new repo with encrypted environments.yml and .sops.yaml configuration.
---

The /secrets-init command bootstraps the current repository with SOPS+age encrypted environment management.

## What it does

1. Checks prerequisites (sops, age, yq)
2. Finds or generates an age keypair
3. Creates `.sops.yaml` from template
4. Creates `environments.yml` from template
5. Encrypts `environments.yml` with SOPS
6. Updates `.gitignore`

## Execution

### Phase 1: Check prerequisites

Run these checks and report any failures before proceeding:

```bash
command -v sops && command -v age-keygen && command -v yq
```

If any missing, tell the user to install them:
```
brew install sops age yq
```

Do not proceed until all three are installed.

### Phase 2: Find or create age key

Check for an existing age key using the resolution chain:

1. `$SOPS_AGE_KEY_FILE` (if set and file exists)
2. `~/.config/sops/age/keys.txt` (SOPS standard path)
3. `~/Projects/keys/environments.age.key` (legacy path)

If found, extract the public key:
```bash
grep "^# public key:" <key_file> | cut -d' ' -f4
```

If NOT found, ask the user: "No age key found. Generate a new keypair at `~/.config/sops/age/keys.txt`?"

If approved, generate:
```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt 2>&1
```

Extract the public key from the output.

### Phase 3: Check for existing files

Before creating files, check if they already exist:

```bash
ls -la .sops.yaml environments.yml 2>/dev/null
```

If either exists, ask the user whether to overwrite or abort.

### Phase 4: Create .sops.yaml

Read the template from the plugin:
```bash
cat "${CLAUDE_PLUGIN_ROOT}/templates/sops.yaml.example"
```

Replace `__AGE_PUBLIC_KEY__` with the actual public key from Phase 2. Write the result to `.sops.yaml` in the current directory.

### Phase 5: Create environments.yml

Read the template:
```bash
cat "${CLAUDE_PLUGIN_ROOT}/templates/environments.yml.example"
```

Ask the user for the project name (suggest the current directory name as default). Replace `__PROJECT_NAME__` with their answer. Write the result to `environments.yml`.

Then encrypt it in place:
```bash
sops -e -i environments.yml
```

Verify encryption succeeded by checking the file starts with `sops:`:
```bash
head -1 environments.yml
```

### Phase 6: Update .gitignore

Append these entries to `.gitignore` if not already present:

```
# secrets - age keys and local env files
*.age.key
.env.local
.env*.local
```

Read `.gitignore` first and only add lines that are missing.

### Phase 7: Summary

Print a summary of what was created:

```
Secrets initialized:
  .sops.yaml          - SOPS configuration (commit this)
  environments.yml    - Encrypted env vars (commit this)
  .gitignore          - Updated with secret exclusions

Age key: <path>
Public key: <public_key>

Next steps:
  sops environments.yml          # Edit variables (decrypts in $EDITOR)
  /secrets list                  # Show all projects
  /secrets resolve -p <project> -e dev  # Preview resolved variables
```
