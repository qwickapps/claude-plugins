#!/usr/bin/env bash
set -euo pipefail

# sync-env - Centralized environment variable management
#
# Usage:
#   sync-env <command> [options]
#
# Commands:
#   validate                     Validate environments.yml schema
#   resolve  --project P --env E Output merged KEY=VALUE pairs
#   local    --project P --env E Generate .env files for local dev
#   github   --project P --env E Push secrets to GitHub Actions
#   caprover --project P --env E Push env vars to CapRover app
#   diff     --project P         Compare resolved vs current target
#   worktree --project P         Generate .env files for a worktree
#   list                         List all projects and environments
#
# Options:
#   --project, -p  Project name (e.g., faabzi)
#   --env, -e      Environment (e.g., prod, uat, dev)
#   --dry-run      Show what would happen without doing it
#   --output, -o   Output file path (for local/worktree)
#
# Environment:
#   ENVIRONMENTS_YML  Path to environments.yml (overrides auto-detection)
#   SOPS_AGE_KEY_FILE Path to age key (overrides auto-detection)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# --- Resolution chains ---

# Find environments.yml: $ENVIRONMENTS_YML -> ./environments.yml -> ~/Projects/environments.yml
_find_environments_yml() {
  [[ -n "${ENVIRONMENTS_YML:-}" && -f "$ENVIRONMENTS_YML" ]] && echo "$ENVIRONMENTS_YML" && return
  [[ -f "./environments.yml" ]] && echo "./environments.yml" && return
  [[ -f "$HOME/Projects/environments.yml" ]] && echo "$HOME/Projects/environments.yml" && return
  echo ""
}

# Find age key: $SOPS_AGE_KEY_FILE -> ~/.config/sops/age/keys.txt -> ~/Projects/keys/environments.age.key
_find_age_key() {
  [[ -n "${SOPS_AGE_KEY_FILE:-}" && -f "$SOPS_AGE_KEY_FILE" ]] && echo "$SOPS_AGE_KEY_FILE" && return
  [[ -f "$HOME/.config/sops/age/keys.txt" ]] && echo "$HOME/.config/sops/age/keys.txt" && return
  [[ -f "$HOME/Projects/keys/environments.age.key" ]] && echo "$HOME/Projects/keys/environments.age.key" && return
  echo ""
}

ENVIRONMENTS_YML="$(_find_environments_yml)"
export SOPS_AGE_KEY_FILE="$(_find_age_key)"

COMMAND=""
PROJECT=""
ENV=""
DRY_RUN=false
OUTPUT=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
  sed -n '3,20p' "$0"
  exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    validate|resolve|local|github|github-infra|caprover|diff|worktree|list)
      COMMAND="$1"; shift ;;
    --project|-p)
      PROJECT="$2"; shift 2 ;;
    --env|-e)
      ENV="$2"; shift 2 ;;
    --dry-run)
      DRY_RUN=true; shift ;;
    --output|-o)
      OUTPUT="$2"; shift 2 ;;
    -h|--help)
      usage ;;
    *)
      echo -e "${RED}Unknown argument: $1${NC}"; usage ;;
  esac
done

if [[ -z "$COMMAND" ]]; then
  echo -e "${RED}Error: command required${NC}"
  usage
fi

# Validate prerequisites
if [[ -z "$ENVIRONMENTS_YML" ]]; then
  echo -e "${RED}Error: environments.yml not found${NC}"
  echo "Searched: \$ENVIRONMENTS_YML, ./environments.yml, ~/Projects/environments.yml"
  echo "Run /secrets-init to bootstrap, or set ENVIRONMENTS_YML."
  exit 1
fi

if [[ ! -f "$ENVIRONMENTS_YML" ]]; then
  echo -e "${RED}Error: environments.yml not found at $ENVIRONMENTS_YML${NC}"
  exit 1
fi

for tool in sops yq; do
  if ! command -v "$tool" &>/dev/null; then
    echo -e "${RED}Error: $tool not found. Install with: brew install $tool${NC}"
    exit 1
  fi
done

if [[ -z "$SOPS_AGE_KEY_FILE" ]]; then
  echo -e "${RED}Error: age key not found${NC}"
  echo "Searched: \$SOPS_AGE_KEY_FILE, ~/.config/sops/age/keys.txt, ~/Projects/keys/environments.age.key"
  exit 1
fi

# Export for lib scripts
export ENVIRONMENTS_YML PROJECT ENV DRY_RUN OUTPUT
export RED GREEN YELLOW CYAN NC

# Source and dispatch
case "$COMMAND" in
  validate)
    source "$LIB_DIR/validate.sh"
    do_validate
    ;;
  resolve)
    source "$LIB_DIR/resolve.sh"
    [[ -z "$PROJECT" ]] && { echo -e "${RED}Error: --project required${NC}"; exit 1; }
    [[ -z "$ENV" ]] && { echo -e "${RED}Error: --env required${NC}"; exit 1; }
    resolve_vars "$PROJECT" "$ENV"
    ;;
  local)
    source "$LIB_DIR/resolve.sh"
    source "$LIB_DIR/runtime.sh"
    [[ -z "$PROJECT" ]] && { echo -e "${RED}Error: --project required${NC}"; exit 1; }
    [[ -z "$ENV" ]] && { echo -e "${RED}Error: --env required${NC}"; exit 1; }
    do_local "$PROJECT" "$ENV"
    ;;
  github)
    source "$LIB_DIR/resolve.sh"
    source "$LIB_DIR/github.sh"
    [[ -z "$PROJECT" ]] && { echo -e "${RED}Error: --project required${NC}"; exit 1; }
    [[ -z "$ENV" ]] && { echo -e "${RED}Error: --env required${NC}"; exit 1; }
    do_github "$PROJECT" "$ENV"
    ;;
  github-infra)
    source "$LIB_DIR/resolve.sh"
    source "$LIB_DIR/github.sh"
    do_github_infra
    ;;
  caprover)
    source "$LIB_DIR/resolve.sh"
    source "$LIB_DIR/caprover.sh"
    [[ -z "$PROJECT" ]] && { echo -e "${RED}Error: --project required${NC}"; exit 1; }
    [[ -z "$ENV" ]] && { echo -e "${RED}Error: --env required${NC}"; exit 1; }
    do_caprover "$PROJECT" "$ENV"
    ;;
  diff)
    source "$LIB_DIR/resolve.sh"
    source "$LIB_DIR/diff.sh"
    [[ -z "$PROJECT" ]] && { echo -e "${RED}Error: --project required${NC}"; exit 1; }
    do_diff "$PROJECT"
    ;;
  worktree)
    source "$LIB_DIR/resolve.sh"
    source "$LIB_DIR/worktree.sh"
    [[ -z "$PROJECT" ]] && { echo -e "${RED}Error: --project required${NC}"; exit 1; }
    do_worktree "$PROJECT"
    ;;
  list)
    source "$LIB_DIR/validate.sh"
    do_list
    ;;
esac
