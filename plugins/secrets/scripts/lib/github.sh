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

  # Naming convention: <PROJECT>_<KEY> (e.g., FAABZI_DATABASE_URL)
  local prefix
  prefix=$(echo "$project" | tr '[:lower:]-' '[:upper:]_')

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
