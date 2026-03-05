#!/usr/bin/env bash
# SessionStart hook for sdlc plugin
# Injects the SDLC skill system into conversation context

set -euo pipefail

session_context="<IMPORTANT>\nThe sdlc plugin is active.\n\nAvailable commands: /feature, /bug, /research, /refactor, /chore, /review, /commit, /release, /docs\n\nAll work starts with an issue. Use the appropriate command for the type of work.\n\nSkills auto-load based on context. If a skill might apply, load it.\n\nFor the full guide, invoke the sdlc:getting-started skill.\n</IMPORTANT>"

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
