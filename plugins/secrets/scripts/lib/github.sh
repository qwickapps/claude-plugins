#!/usr/bin/env bash
# github.sh - Push secrets to GitHub Actions

do_github() {
  local project="$1"
  local env="$2"

  if ! command -v gh &>/dev/null; then
    echo -e "${RED}Error: gh CLI not found. Install with: brew install gh${NC}"
    exit 1
  fi

  local resolved
  resolved=$(resolve_vars "$project" "$env")

  if [[ -z "$resolved" ]]; then
    echo -e "${RED}Error: No variables resolved for $project/$env${NC}"
    exit 1
  fi

  # Naming convention: <PROJECT>_<ENV>_<KEY> (e.g., FAABZI_DEV_DATABASE_URL)
  # Includes environment to allow multiple envs in the same GitHub org.
  local project_upper env_upper prefix
  project_upper=$(echo "$project" | tr '[:lower:]-' '[:upper:]_')
  env_upper=$(echo "$env" | tr '[:lower:]-' '[:upper:]_')
  prefix="${project_upper}_${env_upper}"

  local org="qwickapps"
  local visibility="all"
  local var_count=0

  echo -e "${CYAN}Target: GitHub org '$org' (visibility: $visibility)${NC}"
  echo -e "${CYAN}Prefix: ${prefix}_${NC}"
  echo ""

  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}=== DRY RUN ===${NC}"
    while IFS='=' read -r key value; do
      [[ -z "$key" ]] && continue
      local secret_name="${prefix}_${key}"
      local masked
      if [[ ${#value} -gt 12 ]]; then
        masked="${value:0:4}...${value: -4}"
      else
        masked="****"
      fi
      printf "  gh secret set %-45s [%s]\n" "$secret_name" "$masked"
      ((var_count++))
    done <<< "$resolved"
    echo ""
    echo "Would set $var_count secrets"
    return
  fi

  local success=0
  local failed=0

  while IFS='=' read -r key value; do
    [[ -z "$key" ]] && continue
    local secret_name="${prefix}_${key}"

    if echo "$value" | gh secret set "$secret_name" --org "$org" --visibility "$visibility" 2>/dev/null; then
      printf "  %-50s ${GREEN}[OK]${NC}\n" "$secret_name"
      ((success++))
    else
      printf "  %-50s ${RED}[FAILED]${NC}\n" "$secret_name"
      ((failed++))
    fi
  done <<< "$resolved"

  echo ""
  echo -e "Sync complete: ${GREEN}$success set${NC}, ${RED}$failed failed${NC}"
}

# Push infrastructure secrets (CapRover, global) to GitHub org secrets.
# Naming: <SERVER>_CAPROVER_URL, <SERVER>_CAPROVER_PASSWORD, GHCR_PULL_TOKEN, etc.
do_github_infra() {
  if ! command -v gh &>/dev/null; then
    echo -e "${RED}Error: gh CLI not found. Install with: brew install gh${NC}"
    exit 1
  fi

  local yml
  yml=$(decrypt_yml)

  local org="qwickapps"
  local visibility="all"
  local success=0
  local failed=0

  echo -e "${CYAN}Target: GitHub org '$org' (visibility: $visibility)${NC}"
  echo -e "${CYAN}Pushing infrastructure secrets...${NC}"
  echo ""

  # CapRover servers: infrastructure.caprover.<server>.url / .password
  local servers server server_upper url password name
  servers=$(echo "$yml" | yq -r '.infrastructure.caprover // {} | keys[]' 2>/dev/null || true)

  while IFS= read -r server; do
    [[ -z "$server" ]] && continue
    server_upper=$(echo "$server" | tr '[:lower:]-' '[:upper:]_')

    url=$(echo "$yml" | yq -r ".infrastructure.caprover.\"${server}\".url // \"\"" 2>/dev/null)
    password=$(echo "$yml" | yq -r ".infrastructure.caprover.\"${server}\".password // \"\"" 2>/dev/null)

    if [[ -n "$url" && "$url" != "null" ]]; then
      name="${server_upper}_CAPROVER_URL"
      if [[ "$DRY_RUN" == "true" ]]; then
        printf "  gh secret set %-45s [%s]\n" "$name" "${url:0:20}..."
      elif echo "$url" | gh secret set "$name" --org "$org" --visibility "$visibility" 2>/dev/null; then
        printf "  %-50s ${GREEN}[OK]${NC}\n" "$name"
        ((success++))
      else
        printf "  %-50s ${RED}[FAILED]${NC}\n" "$name"
        ((failed++))
      fi
    fi

    if [[ -n "$password" && "$password" != "null" ]]; then
      name="${server_upper}_CAPROVER_PASSWORD"
      if [[ "$DRY_RUN" == "true" ]]; then
        printf "  gh secret set %-45s [****]\n" "$name"
      elif echo "$password" | gh secret set "$name" --org "$org" --visibility "$visibility" 2>/dev/null; then
        printf "  %-50s ${GREEN}[OK]${NC}\n" "$name"
        ((success++))
      else
        printf "  %-50s ${RED}[FAILED]${NC}\n" "$name"
        ((failed++))
      fi
    fi
  done <<< "$servers"

  # Global secrets: GHCR_PULL_TOKEN, VPS_SSH_KEY, etc.
  local global_secrets
  global_secrets=$(echo "$yml" | yq -r '.global.secrets // {} | to_entries[] | .key + "=" + (.value | tostring)' 2>/dev/null || true)

  while IFS='=' read -r key value; do
    [[ -z "$key" ]] && continue
    if [[ "$DRY_RUN" == "true" ]]; then
      printf "  gh secret set %-45s [****]\n" "$key"
    elif echo "$value" | gh secret set "$key" --org "$org" --visibility "$visibility" 2>/dev/null; then
      printf "  %-50s ${GREEN}[OK]${NC}\n" "$key"
      ((success++))
    else
      printf "  %-50s ${RED}[FAILED]${NC}\n" "$key"
      ((failed++))
    fi
  done <<< "$global_secrets"

  echo ""
  if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}DRY RUN - no secrets were pushed${NC}"
  else
    echo -e "Infra sync complete: ${GREEN}$success set${NC}, ${RED}$failed failed${NC}"
  fi
}
