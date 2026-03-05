#!/usr/bin/env bash
# caprover.sh - Push env vars to CapRover app
#
# Generates flat KEY=VALUE file compatible with configure-caprover-app.sh --env-file
# Can also call configure-caprover-app.sh directly if available.

do_caprover() {
  local project="$1"
  local env="$2"

  local resolved
  resolved=$(resolve_vars "$project" "$env")

  if [[ -z "$resolved" ]]; then
    echo -e "${RED}Error: No variables resolved for $project/$env${NC}"
    exit 1
  fi

  local var_count
  var_count=$(echo "$resolved" | wc -l | xargs)

  # Try to resolve CapRover target from infrastructure section
  local yml
  yml=$(decrypt_yml)

  local caprover_url=""
  local caprover_password=""

  # Map env to infrastructure target (convention: prod=oci-main, dev=oci-dev)
  local infra_target=""
  case "$env" in
    prod) infra_target="oci-main" ;;
    dev)  infra_target="oci-dev" ;;
    uat)  infra_target="oci-dev" ;;
    *)    infra_target="oci-main" ;;
  esac

  caprover_url=$(echo "$yml" | yq -r ".infrastructure.caprover.\"${infra_target}\".url // \"\"" 2>/dev/null)
  caprover_password=$(echo "$yml" | yq -r ".infrastructure.caprover.\"${infra_target}\".password // \"\"" 2>/dev/null)

  echo -e "${CYAN}Project: $project | Env: $env | Target: $infra_target${NC}"
  echo -e "${CYAN}CapRover: $caprover_url${NC}"
  echo "Variables: $var_count"
  echo ""

  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}=== DRY RUN: env file content ===${NC}"
    echo "$resolved" | while IFS='=' read -r key value; do
      [[ -z "$key" ]] && continue
      if [[ ${#value} -gt 12 ]]; then
        printf "  %-40s=%s...%s\n" "$key" "${value:0:4}" "${value: -4}"
      else
        printf "  %-40s=%s\n" "$key" "$value"
      fi
    done
    return
  fi

  # Write env file for configure-caprover-app.sh
  local env_file
  if [[ -n "$OUTPUT" ]]; then
    env_file="$OUTPUT"
  else
    env_file=$(mktemp /tmp/sync-env-caprover-XXXXXX.env)
  fi

  echo "$resolved" > "$env_file"
  echo -e "${GREEN}Wrote $var_count vars to $env_file${NC}"

  # Check if configure-caprover-app.sh is available
  local configure_script=""
  local candidates=(
    "$HOME/Projects/qwickapps/.github/scripts/configure-caprover-app.sh"
    "$(dirname "$SCRIPT_DIR")/../qwickapps/.github/scripts/configure-caprover-app.sh"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      configure_script="$candidate"
      break
    fi
  done

  if [[ -n "$configure_script" && -n "$caprover_url" ]]; then
    echo ""
    echo "To apply, run:"
    echo "  $configure_script \\"
    echo "    --name srv-captain--${project} \\"
    echo "    --url \"$caprover_url\" \\"
    echo "    --password \"****\" \\"
    echo "    --env-file \"$env_file\""
  else
    echo ""
    echo "Use the generated env file with your CapRover deployment tool."
  fi

  # Clean up temp file only if we created it and no --output
  if [[ -z "$OUTPUT" ]]; then
    echo ""
    echo -e "${YELLOW}Temp file: $env_file (will persist until reboot)${NC}"
  fi
}
