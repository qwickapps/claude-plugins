#!/usr/bin/env bash
# sops-pre-commit.sh - Verify environments.yml is encrypted before commit
#
# Install:
#   cp scripts/sync-env/sops-pre-commit.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit

check_sops_encryption() {
  local yml_file="environments.yml"

  if ! git diff --cached --name-only | grep -q "^${yml_file}$"; then
    return 0
  fi

  local staged_content
  staged_content=$(git show ":${yml_file}" 2>/dev/null)
  [[ -z "$staged_content" ]] && return 0

  if ! echo "$staged_content" | grep -q "^sops:"; then
    echo "ERROR: environments.yml appears to be UNENCRYPTED!"
    echo "Re-encrypt before committing: sops -e -i environments.yml"
    return 1
  fi

  if echo "$staged_content" | grep -q "NPM_TOKEN: npm_"; then
    echo "ERROR: environments.yml contains plaintext secrets!"
    echo "Re-encrypt: sops -e -i environments.yml"
    return 1
  fi

  echo "environments.yml: encryption verified"
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  check_sops_encryption || exit 1
fi
