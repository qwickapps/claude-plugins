#!/usr/bin/env bash
# hooks/bash-intercept.sh
#
# PreToolUse hook for Claude Code.
#
# 1. Evaluates the command using oracle verdicts.
# 2. Keeps short-lived one-time approval tokens for sensitive operations.
# 3. For generic policy violations, prompts use of BashWithReason.
#
# Exit codes:
#   0  allow the tool call to proceed
#   1  blocked with legacy error code
#   2  blocked and message printed (used by existing Sentinel flow)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${SENTINEL_HOME+x}" ]]; then
  SENTINEL_HOME="$(cd "${SCRIPT_DIR}/.." && pwd)"
else
  SENTINEL_HOME="${SENTINEL_HOME:-${HOME}/.qwickapps/sentinel}"
fi
export SENTINEL_HOME
APPROVALS_DIR="${SENTINEL_HOME}/approvals"
TOKEN_TTL_SECONDS=300

# ---------------------------------------------------------------------------
# Read and normalize payload.
# ---------------------------------------------------------------------------

input="$(cat)"

extract_json_field() {
  local field="$1"
  local json="$2"
  printf '%s' "$json" \
    | grep -o '"'${field}'"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\(.*\)\".*/\1/" \
    || true
}

extract_command() {
  printf '%s' "$input" \
    | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/' \
    || true
}

tool_name="$(extract_json_field "tool_name" "$input")"
command_str="$(extract_command)"

if [[ "$tool_name" != "Bash" ]]; then
  exit 0
fi

if [[ -z "$command_str" ]]; then
  printf 'Use BashWithReason("missing command", "<cmd>") instead.\n'
  exit 2
fi

# ---------------------------------------------------------------------------
# Merge-reject guardrail: block direct `gh pr merge` from worker roles.
# Workers (coder, tester, ops, worker) must report readiness via
# report("TASK DONE: ready to merge PR #N") instead of merging directly.
# Also validates that the target PR exists and is open.
# NOTE: guardrail is called AFTER trust-token checks (line ~370) so that
# trusted sessions (leads without CLAUDE_ROLE set) can still merge.
# ---------------------------------------------------------------------------

detect_current_role() {
  local role=""
  if [[ -n "${CLAUDE_ROLE:-}" ]]; then
    role="$CLAUDE_ROLE"
  elif [[ -n "${SENTINEL_ROLE:-}" ]]; then
    role="$SENTINEL_ROLE"
  fi
  printf '%s' "${role:-worker}"
}

is_worker_role() {
  local role="$1"
  case "$role" in
    coder|tester|ops|worker|reviewer) return 0 ;;
    *) return 1 ;;
  esac
}

check_merge_guardrail() {
  local cmd="$1"

  # Only intercept gh pr merge commands
  case "$cmd" in
    *"gh pr merge"*) ;;
    *) return 0 ;;
  esac

  local role
  role="$(detect_current_role)"

  # Block worker roles from direct merges
  if is_worker_role "$role"; then
    printf 'MERGE GUARDRAIL: role "%s" cannot merge PRs directly.\n' "$role"
    printf 'Use: report "TASK DONE: ready to merge PR #N — <summary>"\n'
    printf 'The manager/sentinel will handle the merge after review.\n'
    exit 2
  fi

  # For non-worker roles: validate the PR number exists and is open
  local pr_num=""
  pr_num="$(printf '%s' "$cmd" | grep -o -- '--squash\|--merge\|--rebase\|[0-9]\+' | grep -o '[0-9]\+' | head -1 || true)"
  if [[ -n "$pr_num" ]]; then
    local repo_flag=""
    repo_flag="$(printf '%s' "$cmd" | grep -o -- '-R [^ ]*\|--repo [^ ]*' | head -1 || true)"
    local repo=""
    repo="$(printf '%s' "$repo_flag" | sed 's/-R //;s/--repo //' | tr -d '"' || true)"

    local pr_state=""
    if [[ -n "$repo" ]]; then
      pr_state="$(gh pr view "$pr_num" --repo "$repo" --json state -q '.state' 2>/dev/null || true)"
    else
      pr_state="$(gh pr view "$pr_num" --json state -q '.state' 2>/dev/null || true)"
    fi

    if [[ -z "$pr_state" ]]; then
      printf 'MERGE GUARDRAIL: PR #%s not found or no GitHub access.\n' "$pr_num"
      printf 'Verify the PR exists before merging.\n'
      exit 2
    fi

    if [[ "$pr_state" != "OPEN" ]]; then
      printf 'MERGE GUARDRAIL: PR #%s is %s (not OPEN) — cannot merge.\n' "$pr_num" "$pr_state"
      exit 2
    fi
  fi

  return 0
}

now_epoch() { date +%s; }

hash_command() {
  local value="$1"
  local hash=""
  if command -v sha256sum >/dev/null 2>&1; then
    hash="$(printf '%s' "$value" | sha256sum | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    hash="$(printf '%s' "$value" | shasum -a 256 | awk '{print $1}')"
  else
    hash="$(printf '%s' "$value" | awk '{print length, $0}')"
  fi
  printf '%s' "$hash"
}

command_hash() {
  printf '%s' "$(hash_command "$1")"
}

COMMAND_HASH="$(command_hash "$command_str")"

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/\"/\\\"/g'
}

extract_oracle_field() {
  local field="$1"
  local json="$2"
  printf '%s' "$json" \
    | grep -o '"'${field}'"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 \
    | sed "s/.*\"${field}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/" \
    || true
}

log_approval_event() {
  local label="$1"
  local detail="$2"
  local log_dir="${SENTINEL_HOME}/logs"
  mkdir -p "$log_dir" 2>/dev/null || true
  printf '[%s] %s (%s): %s\n' \
    "$(date -u +\"%Y-%m-%dT%H:%M:%SZ\")" "$label" "$detail" "$command_str" \
    >> "${log_dir}/trusted.log"
}

is_token_valid() {
  local token_file="$1"
  local now="$2"

  [[ -f "$token_file" ]] || return 1

  local expires=""
  expires="$(head -1 "$token_file" | tr -d '[:space:]')"
  if [[ "$expires" =~ ^[0-9]+$ ]] && (( now < expires )); then
    return 0
  fi

  return 1
}

consume_approval_token() {
  local token_file="$1"
  local now="$2"

  if is_token_valid "$token_file" "$now"; then
    rm -f "$token_file" || true
    return 0
  fi

  # Remove stale token so stale entries don't accumulate.
  rm -f "$token_file" 2>/dev/null || true
  return 1
}

lookup_oracle() {
  local oracle_bin="$1"
  local classify_bin="$2"
  local reason="$3"
  local cmd="$4"

  local op_class=""
  local oracle_input=""
  local raw_result=""
  local verdict="approve"
  local guidance=""
  local redirect=""

  if [[ -x "$classify_bin" ]]; then
    op_class="$(printf '{"reason":"%s","command":"%s"}' \
      "$(json_escape "$reason")" "$(json_escape "$cmd")" \
      | "$classify_bin" 2>/dev/null \
      | extract_oracle_field "op_class" || true)"
  fi

  if [[ -z "$op_class" ]]; then
    op_class="UnknownOp"
  fi

  if [[ -x "$oracle_bin" ]]; then
    oracle_input="$(printf '{"op_class":"%s","reason":"%s","command":"%s"}' \
      "$(json_escape "$op_class")" "$(json_escape "$reason")" "$(json_escape "$cmd")")"
    raw_result="$(printf '%s' "$oracle_input" | "$oracle_bin" 2>/dev/null || true)"
    if [[ -n "$raw_result" ]]; then
      verdict="$(extract_oracle_field "verdict" "$raw_result")"
      guidance="$(extract_oracle_field "guidance" "$raw_result")"
      redirect="$(extract_oracle_field "tool_redirect" "$raw_result")"
      [[ -z "$verdict" ]] && verdict="approve"
    fi
  fi

  printf '%s\t%s\t%s\t%s\n' "$verdict" "$guidance" "$redirect" "$op_class"
}

send_telegram() {
  local message="$1"

  if command -v mcp >/dev/null 2>&1; then
    mcp call mcp__qwickapps__send_telegram --message "$message" >/dev/null 2>&1 || true
    return 0
  fi

  if command -v mcp__qwickapps__send_telegram >/dev/null 2>&1; then
    mcp__qwickapps__send_telegram --message "$message" >/dev/null 2>&1 || true
    mcp__qwickapps__send_telegram "$message" >/dev/null 2>&1 || true
    return 0
  fi

  return 1
}

challenge_code_for_command() {
  local challenge_file="$1"
  local now="$2"

  mkdir -p "$APPROVALS_DIR"

  if [[ -f "$challenge_file" ]]; then
    local saved_code saved_at
    saved_code="$(sed -n '1p' "$challenge_file" | tr -d '[:space:]')"
    saved_at="$(sed -n '2p' "$challenge_file" | tr -d '[:space:]')"

    if [[ "$saved_code" =~ ^[0-9A-F]{4}$ && "$saved_at" =~ ^[0-9]+$ ]]; then
      if (( now - saved_at <= TOKEN_TTL_SECONDS )); then
        printf '%s' "$saved_code"
        return 0
      fi
      rm -f "$challenge_file"
    else
      rm -f "$challenge_file"
    fi
  fi

  local new_code=""
  new_code="$(od -An -N2 -tx2 /dev/urandom 2>/dev/null | tr -dc 'A-F0-9' | tr '[:lower:]' '[:upper:]' | head -c 4)"
  [[ ${#new_code} -lt 4 ]] && new_code="$(date +%s | tail -c 5)"

  printf '%s\n%s\n' "$new_code" "$now" > "$challenge_file"
  printf '%s' "$new_code"
}

# ---------------------------------------------------------------------------
# 1) Single-use approval token check first (high-priority bypass for AAL).
# ---------------------------------------------------------------------------

mkdir -p "$APPROVALS_DIR" 2>/dev/null || true
TOKEN_FILE="${APPROVALS_DIR}/${COMMAND_HASH}.token"
NOW_TS="$(now_epoch)"

if consume_approval_token "$TOKEN_FILE" "$NOW_TS"; then
  log_approval_event "approved" "single_use_token hash=${COMMAND_HASH}"
  exit 0
fi

# ---------------------------------------------------------------------------
# 2) Oracle verdict lookup.
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORACLE_BIN="${SCRIPT_DIR}/oracle.sh"
CLASSIFY_BIN="${SCRIPT_DIR}/classify.sh"

read -r ORACLE_VERDICT ORACLE_GUIDANCE ORACLE_TOOL_REDIRECT ORACLE_OP_CLASS <<< "$(lookup_oracle \"$ORACLE_BIN\" \"$CLASSIFY_BIN\" \"Bash command intercepted\" \"$command_str\")"
[[ -z "$ORACLE_VERDICT" ]] && ORACLE_VERDICT="approve"

# ---------------------------------------------------------------------------
# 3) approval_required => challenge + telegram block.
# ---------------------------------------------------------------------------

if [[ "$ORACLE_VERDICT" == "approval_required" ]]; then
  CHALLENGE_FILE="${APPROVALS_DIR}/${COMMAND_HASH}.challenge"
  CHALLENGE_CODE="$(challenge_code_for_command "$CHALLENGE_FILE" "$NOW_TS")"

  BLOCK_MESSAGE="Approval required for Bash operation. Challenge code: ${CHALLENGE_CODE} — reply with your Authify TOTP + this code to proceed."
  TELEGRAM_MESSAGE="${BLOCK_MESSAGE} (command hash: ${COMMAND_HASH}, op: ${ORACLE_OP_CLASS:-UnknownOp})"

  send_telegram "$TELEGRAM_MESSAGE" || true

  printf '%s\n' "$BLOCK_MESSAGE"
  log_approval_event "approval_required" "hash=${COMMAND_HASH} challenge=${CHALLENGE_CODE}"
  exit 2
fi

# ---------------------------------------------------------------------------
# 4) Legacy trust-token flow remains for non-sensitive approvals.
# ---------------------------------------------------------------------------

# Resolve session ID
if [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
  _raw_session="$CLAUDE_SESSION_ID"
elif [[ -n "${TMUX_PANE:-}" ]]; then
  _raw_session="$TMUX_PANE"
else
  _raw_session="default"
fi

_safe_session="${_raw_session//[\/: ]/_}"
_safe_session="$(printf '%s' "$_safe_session" | tr '[:space:]' '_')"
TOKEN_PATH="${SENTINEL_HOME}/trust-tokens/${_safe_session}"

if [[ -f "$TOKEN_PATH" ]]; then
  token_expiry="$(head -1 "$TOKEN_PATH" | tr -d '[:space:]')"
  if [[ "$token_expiry" =~ ^[0-9]+$ ]] && (( NOW_TS < token_expiry )); then
    log_approval_event "trusted-session" "session=${_raw_session} expires=${token_expiry}"
    exit 0
  fi
fi

if [[ -n "${AAL_TRUSTED_SESSION:-}" ]] && [[ "$AAL_TRUSTED_SESSION" =~ ^[0-9]+$ ]] && (( NOW_TS < AAL_TRUSTED_SESSION )); then
  log_approval_event "trusted-session" "expires=${AAL_TRUSTED_SESSION}"
  exit 0
fi

# ---------------------------------------------------------------------------
# 4b) Merge-reject guardrail (after trust-token checks so leads with no
#     CLAUDE_ROLE in env can still merge via a trust token).
# ---------------------------------------------------------------------------

check_merge_guardrail "$command_str"

# ---------------------------------------------------------------------------
# 4c) CapRover/Coolify live-app write guard.
#
# Blocks two categories of dangerous raw API writes:
#   1. Any POST/PUT/PATCH/DELETE to /api/v*/ against a *-live app — agents
#      must use the blue-green CI deploy pipeline, not direct production edits.
#   2. Any appDefinitions/update call missing the full envVars array — the
#      Coolify envVars-clearing bug silently wipes all env vars when omitted.
#
# Bypass: valid single-use approval token (section 1) or session trust token
# (section 4) — for genuine emergency manual operations only.
# ---------------------------------------------------------------------------

check_caprover_live_guard() {
  local cmd="$1"

  # Only intercept HTTP client commands
  case "$cmd" in
    *curl*|*wget*) ;;
    *) return 0 ;;
  esac

  # Detect write HTTP methods
  local is_write=0
  # Explicit -X POST / -XPOST / --request POST (case-insensitive)
  if printf '%s' "$cmd" | grep -qiE '(-X[[:space:]]*(POST|PUT|PATCH|DELETE)|--request[[:space:]]+(POST|PUT|PATCH|DELETE))'; then
    is_write=1
  fi
  # Implicit POST: -d / --data present without an explicit -X GET
  if printf '%s' "$cmd" | grep -qE '( -d | --data[ =])' && \
     ! printf '%s' "$cmd" | grep -qiE '(-X[[:space:]]*GET|--request[[:space:]]+GET)'; then
    is_write=1
  fi
  # wget --post-data / --post-file
  case "$cmd" in
    *"--post-data"*|*"--post-file"*) is_write=1 ;;
  esac

  [[ $is_write -eq 0 ]] && return 0

  # Only act on CapRover/Coolify API paths (/api/v1/, /api/v2/, …)
  if ! printf '%s' "$cmd" | grep -qE '/api/v[0-9]+/'; then
    return 0
  fi

  # Guard 1: Block writes against *-live app identifiers in the URL/body
  if printf '%s' "$cmd" | grep -qE '[a-z0-9]+-live([^a-z0-9]|$)'; then
    printf 'CAPROVER LIVE GUARD: direct API writes to *-live apps are blocked.\n'
    printf 'Use the blue-green CI deploy pipeline, not a raw production edit.\n'
    printf 'See: Blue-Green Deployment SOP (KB docs 68648962 / 68485124)\n'
    exit 2
  fi

  # Guard 2: Block appDefinitions/update without the full envVars array
  if printf '%s' "$cmd" | grep -q 'appDefinitions/update'; then
    local has_env_vars=0
    printf '%s' "$cmd" | grep -q 'envVars' && has_env_vars=1
    # Also check body from @file reference
    if [[ $has_env_vars -eq 0 ]]; then
      local data_file
      data_file="$(printf '%s' "$cmd" | grep -oE '@[^[:space:]]+' | head -1 | sed 's/^@//' || true)"
      if [[ -n "$data_file" && -f "$data_file" ]]; then
        grep -q 'envVars' "$data_file" 2>/dev/null && has_env_vars=1
      fi
    fi
    if [[ $has_env_vars -eq 0 ]]; then
      printf 'CAPROVER ENV GUARD: appDefinitions/update without envVars array.\n'
      printf 'Omitting envVars silently wipes ALL environment variables.\n'
      printf 'Always include the complete envVars array in every appDefinitions/update call.\n'
      exit 2
    fi
  fi

  return 0
}

check_caprover_live_guard "$command_str"

# ---------------------------------------------------------------------------
# 5) Block with context when oracle asked for review.
# ---------------------------------------------------------------------------

case "$ORACLE_VERDICT" in
  approve)
    exit 0
    ;;
  reject)
    if [[ -n "$ORACLE_GUIDANCE" ]]; then
      printf 'Oracle rejected command: %s\n' "$ORACLE_GUIDANCE"
    else
      printf 'Oracle rejected command. Use BashWithReason to review.\n'
    fi
    ;;
  redirect)
    if [[ -n "$ORACLE_TOOL_REDIRECT" ]]; then
      printf 'Oracle redirect: use %s. %s\n' "$ORACLE_TOOL_REDIRECT" "${ORACLE_GUIDANCE}"
    else
      printf '%s\n' "${ORACLE_GUIDANCE:-Oracle requested redirect; use BashWithReason instead.}"
    fi
    ;;
  *)
    if [[ -n "$ORACLE_GUIDANCE" ]]; then
      printf '%s\n' "$ORACLE_GUIDANCE"
    else
      printf 'Use BashWithReason("%s", "%s") instead.\n' "Oracle check" "$(printf '%s' "$command_str" | head -c 120 | sed 's/%/%%/g')"
    fi
    ;;
esac

exit 2
