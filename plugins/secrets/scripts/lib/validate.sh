#!/usr/bin/env bash
# validate.sh - Schema validation and listing

do_validate() {
  local yml
  yml=$(decrypt_yml 2>/dev/null || sops -d "$ENVIRONMENTS_YML" 2>/dev/null)
  if [[ -z "$yml" ]]; then
    echo -e "${RED}FAIL: Cannot decrypt environments.yml${NC}"
    exit 1
  fi

  local errors=0

  # Check required top-level keys
  for key in global projects; do
    if [[ "$(echo "$yml" | yq -r ".$key // \"\"" 2>/dev/null)" == "" ]]; then
      echo -e "${RED}FAIL: Missing required top-level key: $key${NC}"
      ((errors++))
    fi
  done

  # Check each project has required structure
  local projects
  projects=$(echo "$yml" | yq -r '.projects | keys[]' 2>/dev/null)
  for proj in $projects; do
    # Must have environments block
    local envs
    envs=$(echo "$yml" | yq -r ".projects.\"${proj}\".environments // \"\"" 2>/dev/null)
    if [[ -z "$envs" || "$envs" == "null" ]]; then
      echo -e "${YELLOW}WARN: project '$proj' has no environments block${NC}"
    fi

    # Check for unresolved ${VAR} references
    local all_env_keys
    all_env_keys=$(echo "$yml" | yq -r ".projects.\"${proj}\".environments // {} | keys[]" 2>/dev/null)
    for env in $all_env_keys; do
      # Resolve and check for warnings
      local resolve_output
      resolve_output=$(resolve_vars "$proj" "$env" 2>&1 >/dev/null || true)
      if echo "$resolve_output" | grep -q "unresolved reference"; then
        echo -e "${YELLOW}WARN: $proj/$env has unresolved \${VAR} references:${NC}"
        echo "$resolve_output" | grep "unresolved" | sed 's/^/  /'
      fi
    done
  done

  if [[ $errors -gt 0 ]]; then
    echo -e "${RED}Validation failed with $errors error(s)${NC}"
    exit 1
  fi

  echo -e "${GREEN}Validation passed${NC}"
  echo "Projects: $(echo "$projects" | wc -w | xargs)"
}

do_list() {
  local yml
  yml=$(sops -d "$ENVIRONMENTS_YML" 2>/dev/null)
  if [[ -z "$yml" ]]; then
    echo -e "${RED}Error: Cannot decrypt environments.yml${NC}"
    exit 1
  fi

  echo -e "${CYAN}=== Projects & Environments ===${NC}"
  echo ""

  local projects
  projects=$(echo "$yml" | yq -r '.projects | keys[]' 2>/dev/null)
  for proj in $projects; do
    local app_name
    app_name=$(echo "$yml" | yq -r ".projects.\"${proj}\".config.APP_NAME // \"$proj\"" 2>/dev/null)
    echo -e "${GREEN}$proj${NC} (app: $app_name)"

    local config_count
    config_count=$(echo "$yml" | yq -r ".projects.\"${proj}\".config // {} | length" 2>/dev/null)
    local secret_count
    secret_count=$(echo "$yml" | yq -r ".projects.\"${proj}\".secrets // {} | length" 2>/dev/null)
    echo "  Base: ${config_count} config, ${secret_count} secrets"

    local envs
    envs=$(echo "$yml" | yq -r ".projects.\"${proj}\".environments // {} | keys[]" 2>/dev/null)
    for env in $envs; do
      local env_config
      env_config=$(echo "$yml" | yq -r ".projects.\"${proj}\".environments.\"${env}\".config // {} | length" 2>/dev/null)
      local env_secret
      env_secret=$(echo "$yml" | yq -r ".projects.\"${proj}\".environments.\"${env}\".secrets // {} | length" 2>/dev/null)
      echo "  - $env: +${env_config} config, +${env_secret} secrets"
    done
    echo ""
  done

  # Show global counts
  local global_config
  global_config=$(echo "$yml" | yq -r '.global.config // {} | length' 2>/dev/null)
  local global_secret
  global_secret=$(echo "$yml" | yq -r '.global.secrets // {} | length' 2>/dev/null)
  echo -e "${CYAN}Global: ${global_config} config, ${global_secret} secrets${NC}"
}
