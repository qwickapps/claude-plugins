#!/bin/bash
# Centralized lifecycle-hook router
#
# Dispatches Claude Code lifecycle events to registered handlers.
# Reads event type + payload from stdin, routes to the appropriate handler,
# and returns the correct output shape per event (additionalContext for injection,
# allow/block for intercepts, exit 0 for fire-and-forget).
#
# Usage:
#   echo '{"event": "SessionStart", ...}' | hook-router.sh <event>
#   or via Claude Code settings.json hooks configuration
#
# Design: fail-safe (handler errors never break a session), bash 3.2 safe,
# role-aware via detect-role.sh.
#
# SessionStart: merges inject-protocol (role protocol) + brain-inject (brain index)
#   into a single additionalContext response.
# PreCompact/SessionEnd: runs session-snapshot (local log) + brain-compile
#   (flush learnings to brain vault, fire-and-forget).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SENTINEL_HOME="${SENTINEL_HOME:-${HOME}/.qwickapps/sentinel}"
HANDLERS_DIR="${SCRIPT_DIR}/handlers"
BRAIN_DIR="${HOME}/.qwickapps/brain"
LOG_FILE="${SENTINEL_HOME}/logs/hooks.log"

# Events we handle
EVENT="${1:-}"

if [[ -z "$EVENT" ]]; then
  printf 'ERROR: event type required\n' >&2
  exit 1
fi

# Create log directory if needed
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Read payload from stdin
payload=""
if [[ -t 0 ]]; then
  payload="{}"
else
  payload="$(cat)"
fi

# ---------------------------------------------------------------------------
# Fail-safe single-handler runner
# ---------------------------------------------------------------------------

run_handler_safe() {
  local handler_name="$1"
  local handler_path="${HANDLERS_DIR}/${handler_name}.sh"

  if [[ ! -x "$handler_path" ]]; then
    printf '[WARN] Hook handler not found: %s\n' "$handler_path" >&2
    printf '[%s] %s: handler not found\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$EVENT" >> "$LOG_FILE" 2>/dev/null || true
    return 0
  fi

  local output=""
  output=$(bash "$handler_path" <<< "$payload" 2>&1) || true

  printf '[%s] %s: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$EVENT" "$handler_name" >> "$LOG_FILE" 2>/dev/null || true

  printf '%s\n' "$output"
  return 0
}

# ---------------------------------------------------------------------------
# SessionStart: merge inject-protocol + brain-inject into one additionalContext
# ---------------------------------------------------------------------------

run_session_start() {
  local handler_path="${HANDLERS_DIR}/inject-protocol.sh"
  local brain_inject="${BRAIN_DIR}/scripts/brain-inject.sh"

  local protocol_text=""
  local brain_text=""

  # Get role protocol (inject-protocol outputs {"additionalContext": "...", "metadata": {...}})
  if [[ -x "$handler_path" ]]; then
    local proto_out
    proto_out=$(bash "$handler_path" <<< "$payload" 2>/dev/null || true)
    if command -v jq &>/dev/null && [[ -n "$proto_out" ]]; then
      protocol_text=$(jq -r '.additionalContext // empty' <<< "$proto_out" 2>/dev/null || true)
    fi
    # Fallback: treat whole output as text
    if [[ -z "$protocol_text" ]]; then
      protocol_text="$proto_out"
    fi
  fi

  # Get brain index (brain-inject outputs {"context": "...", "role": "..."})
  if [[ -f "$brain_inject" ]]; then
    local brain_out
    brain_out=$(bash "$brain_inject" 2>/dev/null || true)
    if command -v jq &>/dev/null && [[ -n "$brain_out" ]]; then
      brain_text=$(jq -r '.context // empty' <<< "$brain_out" 2>/dev/null || true)
    fi
    # Fallback: treat whole output as text
    if [[ -z "$brain_text" ]]; then
      brain_text="$brain_out"
    fi
  fi

  # Merge both into single additionalContext
  local combined=""
  if [[ -n "$protocol_text" && -n "$brain_text" ]]; then
    combined="${protocol_text}

---

${brain_text}"
  elif [[ -n "$protocol_text" ]]; then
    combined="$protocol_text"
  elif [[ -n "$brain_text" ]]; then
    combined="$brain_text"
  fi

  # Emit in the SessionStart hook output shape Claude Code actually reads:
  # hookSpecificOutput.additionalContext. The previous top-level {"additionalContext"}
  # form was silently ignored, so NO agent ever received its injected protocol.
  if [[ -n "$combined" ]]; then
    if command -v jq &>/dev/null; then
      jq -n --arg ctx "$combined" \
        '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
    else
      python3 -c "
import json, sys
ctx = sys.stdin.read()
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': ctx}}))
" <<< "$combined" 2>/dev/null || true
    fi
  fi

  printf '[%s] SessionStart: inject-protocol+brain merged (proto=%s brain=%s)\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" \
    "$([ -n "$protocol_text" ] && echo yes || echo no)" \
    "$([ -n "$brain_text" ] && echo yes || echo no)" \
    >> "$LOG_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Stop: behavior-monitor (sync, may block) → escalate-dont-stall → decision-discipline
# ---------------------------------------------------------------------------

run_stop() {
  local bm_out=""
  bm_out="$(bash "${HANDLERS_DIR}/behavior-monitor.sh" <<< "$payload" 2>/dev/null || true)"
  if [[ -n "$bm_out" ]]; then
    printf '%s\n' "$bm_out"
    printf '[%s] Stop: behavior-monitor blocked\n' \
      "$(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>/dev/null || true
    exit 0
  fi
  printf '[%s] Stop: behavior-monitor clean\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE" 2>/dev/null || true
  run_handler_safe "escalate-dont-stall"
  run_handler_safe "decision-discipline-guard"
}

# ---------------------------------------------------------------------------
# PreCompact / SessionEnd: session-snapshot + brain-compile (both fire-and-forget)
# ---------------------------------------------------------------------------

run_compaction() {
  # 1. Local session snapshot (log to ~/.qwickapps/sentinel/logs/)
  run_handler_safe "session-snapshot"

  # 2. Brain flush: extract learnings → write to brain vault
  #    brain-compile.sh calls flush.py which forks immediately — returns fast
  local brain_compile="${BRAIN_DIR}/scripts/brain-compile.sh"
  if [[ -f "$brain_compile" ]]; then
    bash "$brain_compile" <<< "$payload" 2>/dev/null || true
    printf '[%s] %s: brain-compile fired\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$EVENT" >> "$LOG_FILE" 2>/dev/null || true
  fi
}

# ---------------------------------------------------------------------------
# Route to handler based on event type
# ---------------------------------------------------------------------------

case "$EVENT" in
  SessionStart)
    run_session_start
    ;;
  UserPromptSubmit)
    # Optional: context injection (future)
    exit 0
    ;;
  PreToolUse)
    run_handler_safe "bash-intercept"
    ;;
  Stop)
    run_stop
    ;;
  PreCompact|SessionEnd)
    run_compaction
    ;;
  *)
    printf 'WARN: unknown event: %s\n' "$EVENT" >&2
    exit 0
    ;;
esac

exit 0
