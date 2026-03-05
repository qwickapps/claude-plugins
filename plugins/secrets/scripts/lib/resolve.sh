#!/usr/bin/env bash
# resolve.sh - Decrypt and merge environment variables
#
# Merge cascade: global -> project -> environment
# Handles _null removal and ${VAR} interpolation
# Compatible with macOS bash 3.2 (no associative arrays)

# Decrypt environments.yml and cache the result for the session
_DECRYPTED_YML=""

decrypt_yml() {
  if [[ -z "$_DECRYPTED_YML" ]]; then
    _DECRYPTED_YML=$(sops -d "$ENVIRONMENTS_YML" 2>/dev/null)
    if [[ $? -ne 0 || -z "$_DECRYPTED_YML" ]]; then
      echo -e "${RED}Error: Failed to decrypt environments.yml${NC}" >&2
      echo "Check SOPS_AGE_KEY_FILE: $SOPS_AGE_KEY_FILE" >&2
      exit 1
    fi
  fi
  echo "$_DECRYPTED_YML"
}

# Extract flat KEY=VALUE from a YAML path's config + secrets blocks
extract_vars() {
  local yml="$1"
  local path="$2"
  local result=""

  local config_vars
  config_vars=$(echo "$yml" | yq -r "${path}.config // {} | to_entries[] | .key + \"=\" + (.value | tostring)" 2>/dev/null || true)
  if [[ -n "$config_vars" ]]; then
    result="$config_vars"
  fi

  local secret_vars
  secret_vars=$(echo "$yml" | yq -r "${path}.secrets // {} | to_entries[] | .key + \"=\" + (.value | tostring)" 2>/dev/null || true)
  if [[ -n "$secret_vars" ]]; then
    if [[ -n "$result" ]]; then
      result="$result"$'\n'"$secret_vars"
    else
      result="$secret_vars"
    fi
  fi

  echo "$result"
}

# Merge two KEY=VALUE streams using awk. Later values override earlier.
# _null values remove the key entirely.
merge_vars() {
  local base="$1"
  local overlay="$2"

  printf '%s\n%s\n' "$base" "$overlay" | awk -F'=' '
  {
    if (NF < 2 || $0 == "") next
    key = $1
    val = substr($0, length(key) + 2)
    if (!(key in seen_order)) {
      order[++n] = key
      seen_order[key] = 1
    }
    vals[key] = val
  }
  END {
    for (i = 1; i <= n; i++) {
      k = order[i]
      if (vals[k] != "_null") {
        print k "=" vals[k]
      }
    }
  }'
}

# Interpolate ${VAR} references in values using the current merged set
interpolate_vars() {
  local input="$1"

  echo "$input" | awk -F'=' '
  # First pass: collect all vars
  {
    if (NF < 2 || $0 == "") next
    key = $1
    val = substr($0, length(key) + 2)
    keys[++n] = key
    vals[key] = val
  }
  END {
    for (i = 1; i <= n; i++) {
      k = keys[i]
      v = vals[k]
      # Replace ${VAR} patterns (up to 5 passes for chained refs)
      for (pass = 0; pass < 5; pass++) {
        changed = 0
        while (match(v, /\$\{[A-Za-z_][A-Za-z0-9_]*\}/)) {
          ref = substr(v, RSTART + 2, RLENGTH - 3)
          if (ref in vals) {
            v = substr(v, 1, RSTART - 1) vals[ref] substr(v, RSTART + RLENGTH)
            changed = 1
          } else {
            break
          }
        }
        if (!changed) break
      }
      print k "=" v
    }
  }'
}

# Main resolve function: merge global -> project -> environment
resolve_vars() {
  local project="$1"
  local env="$2"
  local yml
  yml=$(decrypt_yml)

  # Validate project exists
  local project_exists
  project_exists=$(echo "$yml" | yq -r ".projects.\"${project}\" // \"\"" 2>/dev/null)
  if [[ -z "$project_exists" || "$project_exists" == "null" ]]; then
    echo -e "${RED}Error: project '$project' not found in environments.yml${NC}" >&2
    echo "Available projects:" >&2
    echo "$yml" | yq -r '.projects | keys[]' 2>/dev/null | sed 's/^/  /' >&2
    exit 1
  fi

  # Validate environment exists
  local env_exists
  env_exists=$(echo "$yml" | yq -r ".projects.\"${project}\".environments.\"${env}\" // \"\"" 2>/dev/null)
  if [[ -z "$env_exists" || "$env_exists" == "null" ]]; then
    echo -e "${RED}Error: environment '$env' not found for project '$project'${NC}" >&2
    echo "Available environments:" >&2
    echo "$yml" | yq -r ".projects.\"${project}\".environments | keys[]" 2>/dev/null | sed 's/^/  /' >&2
    exit 1
  fi

  # Layer 1: Global
  local global_vars
  global_vars=$(extract_vars "$yml" ".global")

  # Layer 2: Project
  local project_vars
  project_vars=$(extract_vars "$yml" ".projects.\"${project}\"")

  # Layer 3: Environment
  local env_vars
  env_vars=$(extract_vars "$yml" ".projects.\"${project}\".environments.\"${env}\"")

  # Merge: global -> project -> environment
  local merged
  merged=$(merge_vars "$global_vars" "$project_vars")
  merged=$(merge_vars "$merged" "$env_vars")

  # Interpolate ${VAR} references
  interpolate_vars "$merged"
}
