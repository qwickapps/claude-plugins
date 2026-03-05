#!/usr/bin/env bash
# diff.sh - Compare resolved vars against current deployment targets

do_diff() {
  local project="$1"

  local yml
  yml=$(decrypt_yml)

  # Get all environments for this project
  local envs
  envs=$(echo "$yml" | yq -r ".projects.\"${project}\".environments // {} | keys[]" 2>/dev/null)

  if [[ -z "$envs" ]]; then
    echo -e "${RED}Error: No environments found for project '$project'${NC}"
    exit 1
  fi

  echo -e "${CYAN}=== Diff: $project ===${NC}"
  echo ""

  for env in $envs; do
    echo -e "${GREEN}--- $project/$env ---${NC}"

    local resolved
    resolved=$(resolve_vars "$project" "$env")
    local resolved_count
    resolved_count=$(echo "$resolved" | wc -l | xargs)
    echo "  Resolved vars: $resolved_count"

    # Compare against GitHub secrets if gh available
    if command -v gh &>/dev/null; then
      local prefix
      prefix=$(echo "$project" | tr '[:lower:]-' '[:upper:]_')
      local gh_secrets
      gh_secrets=$(gh secret list --org qwickapps 2>/dev/null | awk '{print $1}' || true)

      if [[ -n "$gh_secrets" ]]; then
        local expected_in_gh=0
        local found_in_gh=0
        local missing_from_gh=()

        while IFS='=' read -r key value; do
          [[ -z "$key" ]] && continue
          local secret_name="${prefix}_${key}"
          ((expected_in_gh++))
          if echo "$gh_secrets" | grep -q "^${secret_name}$"; then
            ((found_in_gh++))
          else
            missing_from_gh+=("$secret_name")
          fi
        done <<< "$resolved"

        echo "  GitHub secrets: $found_in_gh/$expected_in_gh present"
        if [[ ${#missing_from_gh[@]} -gt 0 ]]; then
          echo -e "  ${YELLOW}Missing from GitHub:${NC}"
          for name in "${missing_from_gh[@]}"; do
            echo "    - $name"
          done
        fi
      else
        echo "  GitHub: cannot list secrets (check gh auth)"
      fi
    else
      echo "  GitHub: gh CLI not available"
    fi

    echo ""
  done
}
