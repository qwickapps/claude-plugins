#!/usr/bin/env bash
# hooks/tool-outcome.sh
#
# PostToolUse hook (matcher: .*) — audit-log every tool outcome.
#
# Appends a compact JSONL record to ~/.qwickapps/sentinel/logs/tool-use.jsonl.
# Always exits 0 — never blocks.
#
# Record format:
#   {"ts":"ISO8601","event":"post","tool":"ToolName","ok":true}

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${SENTINEL_HOME+x}" ]]; then
  SENTINEL_HOME="$(cd "${SCRIPT_DIR}/.." && pwd)"
else
  SENTINEL_HOME="${SENTINEL_HOME:-${HOME}/.qwickapps/sentinel}"
fi
export SENTINEL_HOME
LOG_FILE="${SENTINEL_HOME}/logs/tool-use.jsonl"

input="$(cat)"

field() {
  printf '%s' "$input" \
    | grep -o "\"${1}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -1 \
    | sed "s/.*\"${1}\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/" \
    || true
}

tool="$(field tool_name)"
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || true)"

escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

ok="true"
if printf '%s' "$input" | grep -q '"isError"[[:space:]]*:[[:space:]]*true'; then
  ok="false"
fi

mkdir -p "$(dirname "$LOG_FILE")"
printf '{"ts":"%s","event":"post","tool":"%s","ok":%s}\n' \
  "$ts" "$(escape "$tool")" "$ok" >> "$LOG_FILE" 2>/dev/null || true

exit 0
