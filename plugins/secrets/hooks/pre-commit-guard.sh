#!/usr/bin/env bash
# PreToolUse hook for secrets plugin
# Intercepts git add/commit of environments.yml and verifies it's encrypted

set -euo pipefail

# Read tool input from stdin (JSON with a "command" field for Bash calls)
TOOL_INPUT=$(cat)
COMMAND=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null || echo "")

# Only check git add/commit commands that reference environments.yml
if echo "$COMMAND" | grep -qE 'git\s+(add|commit)' && echo "$COMMAND" | grep -q 'environments.yml'; then
  # Check if environments.yml exists and is unencrypted
  env_yml=""
  if [[ -f "./environments.yml" ]]; then
    env_yml="./environments.yml"
  fi

  if [[ -n "$env_yml" ]]; then
    # Check if file contains "sops:" key (SOPS places it at end of file)
    if ! grep -q "^sops:" "$env_yml"; then
      cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "BLOCKED: environments.yml appears UNENCRYPTED. Do NOT stage or commit it. Re-encrypt first: sops -e -i environments.yml. Then retry the git command."
  }
}
EOF
      exit 0
    fi
  fi

  # File is encrypted or doesn't exist locally, pass through
  echo '{}'
else
  # Not a relevant git command, pass through
  echo '{}'
fi

exit 0
