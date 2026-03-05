#!/usr/bin/env bash
# PreToolUse hook for sdlc plugin
# Intercepts git commit commands and reminds about validation gates
#
# This hook checks if the Bash tool is about to run a git commit command.
# If so, it injects a reminder about VALIDATION-GATES.md requirements.

set -euo pipefail

# Read tool input from stdin (JSON with a "command" field for Bash calls)
TOOL_INPUT=$(cat)
COMMAND=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null || echo "")

# Check if this is a git commit command
if echo "$COMMAND" | grep -qE 'git\s+commit'; then
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
