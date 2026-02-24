#!/usr/bin/env bash
# PreToolUse hook for qwickapps-sdlc plugin
# Intercepts git commit commands and reminds about validation gates
#
# This hook checks if the Bash tool is about to run a git commit command.
# If so, it injects a reminder about VALIDATION-GATES.md requirements.

set -euo pipefail

TOOL_INPUT="${1:-}"

# Check if this is a git commit command
if echo "$TOOL_INPUT" | grep -qE 'git\s+commit'; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "VALIDATION GATE REMINDER: Before committing, confirm that build passes, tests pass, and no critical warnings exist. Reference VALIDATION-GATES.md. If validation was not run in this session, run it now before proceeding with the commit."
  }
}
EOF
else
  # Not a git commit, pass through
  echo '{}'
fi

exit 0
