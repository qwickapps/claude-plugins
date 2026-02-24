#!/usr/bin/env bash
# SessionStart hook for qwickapps-sdlc plugin
# Injects the SDLC skill system into conversation context

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Read getting-started skill content
getting_started_content=$(cat "${PLUGIN_ROOT}/skills/getting-started/SKILL.md" 2>&1 || echo "Error reading getting-started skill")

# Escape string for JSON embedding
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

getting_started_escaped=$(escape_for_json "$getting_started_content")

session_context="<IMPORTANT>\nThe qwickapps-sdlc plugin is active.\n\nAvailable commands: /feature, /bug, /research, /refactor, /chore, /review, /commit, /release, /docs\n\nAll work starts with an issue. Use the appropriate command for the type of work.\n\nSkills auto-load based on context. If a skill might apply, load it.\n\nFor the full guide, invoke the qwickapps-sdlc:getting-started skill.\n</IMPORTANT>"

cat <<EOF
{
  "additional_context": "${session_context}",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${session_context}"
  }
}
EOF

exit 0
