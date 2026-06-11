#!/usr/bin/env bash
# hooks/tool-recorder.sh
#
# PreToolUse hook (matcher: .*) — records every tool invocation to a JSONL session log.
#
# Appends one line to $SENTINEL_HOME/sessions/<session_id>.jsonl:
#   {"ts":"...","tool":"Read","summary":"path=/tmp/foo","session_id":"abc","seq":1}
#
# Set SENTINEL_RECORD_TOOLS=0 to disable recording entirely.
# Never logs file contents, command output, or other sensitive data.
# Must not block — any failure exits 0 silently.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${SENTINEL_HOME+x}" ]]; then
  SENTINEL_HOME="$(cd "${SCRIPT_DIR}/.." && pwd)"
else
  SENTINEL_HOME="${SENTINEL_HOME:-${HOME}/.qwickapps/sentinel}"
fi
export SENTINEL_HOME

if [[ "${SENTINEL_RECORD_TOOLS:-}" == "0" ]]; then
  exit 0
fi

input="$(cat 2>/dev/null)" || exit 0

_extract_field() {
  local field="$1"
  printf '%s' "$input" | awk -v field="$field" '
    {
      regex = "\"" field "\"[[:space:]]*:[[:space:]]*\""
      if (match($0, regex)) {
        start = RSTART + RLENGTH
        value = ""
        escape = 0
        for (i = start; i <= length($0); i++) {
          ch = substr($0, i, 1)
          if (escape) {
            value = value ch
            escape = 0
            continue
          }
          if (ch == "\\") {
            escape = 1
            continue
          }
          if (ch == "\"") {
            break
          }
          value = value ch
        }
        print value
        exit
      }
    }
  '
}

tool_name="$(_extract_field "tool_name")"
[[ -z "$tool_name" ]] && exit 0

if [[ -n "${SENTINEL_SESSION_ID:-}" ]]; then
  _raw_session="$SENTINEL_SESSION_ID"
elif [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
  _raw_session="$CLAUDE_SESSION_ID"
elif [[ -n "${TMUX_PANE:-}" ]]; then
  _raw_session="$TMUX_PANE"
else
  _raw_session="default"
fi

_safe_session="${_raw_session//[\/: ]/_}"
_safe_session="$(printf '%s' "$_safe_session" | tr '[:space:]' '_')"

SESSIONS_DIR="${SENTINEL_HOME}/sessions"
mkdir -p "$SESSIONS_DIR" 2>/dev/null || exit 0

SEQ_FILE="${SESSIONS_DIR}/${_safe_session}.seq"
JSONL_FILE="${SESSIONS_DIR}/${_safe_session}.jsonl"

_increment_seq() {
  local seq=0
  if [[ -f "$SEQ_FILE" ]]; then
    seq="$(head -1 "$SEQ_FILE" | tr -d '[:space:]')"
    [[ "$seq" =~ ^[0-9]+$ ]] || seq=0
  fi
  seq=$(( seq + 1 ))
  printf '%d\n' "$seq" > "$SEQ_FILE"
  printf '%d' "$seq"
}

if command -v flock >/dev/null 2>&1; then
  seq="$(flock -x "$SESSIONS_DIR" bash -c "
    SEQ_FILE='${SEQ_FILE}'
    seq=0
    if [[ -f \"\$SEQ_FILE\" ]]; then
      seq=\"\$(head -1 \"\$SEQ_FILE\" | tr -d '[:space:]')\"
      [[ \"\$seq\" =~ ^[0-9]+\$ ]] || seq=0
    fi
    seq=\$(( seq + 1 ))
    printf '%d\\n' \"\$seq\" > \"\$SEQ_FILE\"
    printf '%d' \"\$seq\"
  " 2>/dev/null)" || seq="$(_increment_seq)"
else
  seq="$(_increment_seq)"
fi

[[ "$seq" =~ ^[0-9]+$ ]] || seq=1

case "$tool_name" in
  Bash)
    payload="$(_extract_field "command")"
    summary="command=${payload:0:60}"
    ;;
  Read|Write|Edit)
    path="$(_extract_field "file_path")"
    [[ -z "$path" ]] && path="$(_extract_field "path")"
    summary="path=${path}"
    ;;
  WebFetch)
    summary="url=$(_extract_field "url")"
    ;;
  WebSearch)
    url="$(_extract_field "query")"
    [[ -z "$url" ]] && url="$(_extract_field "url")"
    summary="url=${url}"
    ;;
  *)
    summary="tool=${tool_name}"
    ;;
esac

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)"

escape() {
  printf '%s' "$1" \
    | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g'
}

printf '{"ts":"%s","tool":"%s","summary":"%s","session_id":"%s","seq":%d}\n' \
  "$ts" \
  "$(escape "$tool_name")" \
  "$(escape "$summary")" \
  "$(escape "$_raw_session")" \
  "$seq" >> "$JSONL_FILE" 2>/dev/null || true

exit 0
