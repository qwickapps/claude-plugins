#!/usr/bin/env bash
# SessionStart hook for secrets plugin
# Checks prerequisites and reports status

set -euo pipefail

warnings=""
status_ok=true

# Check required tools
for tool in sops age-keygen yq; do
  if ! command -v "$tool" &>/dev/null; then
    warnings="${warnings}  - ${tool} not installed (brew install ${tool})\\n"
    status_ok=false
  fi
done

# Check environments.yml exists (resolution chain)
env_yml=""
if [[ -n "${ENVIRONMENTS_YML:-}" && -f "$ENVIRONMENTS_YML" ]]; then
  env_yml="$ENVIRONMENTS_YML"
elif [[ -f "./environments.yml" ]]; then
  env_yml="./environments.yml"
elif [[ -f "$HOME/Projects/environments.yml" ]]; then
  env_yml="$HOME/Projects/environments.yml"
fi

if [[ -z "$env_yml" ]]; then
  warnings="${warnings}  - environments.yml not found (run /secrets-init to bootstrap)\\n"
  status_ok=false
fi

# Check age key exists (resolution chain)
age_key=""
if [[ -n "${SOPS_AGE_KEY_FILE:-}" && -f "$SOPS_AGE_KEY_FILE" ]]; then
  age_key="$SOPS_AGE_KEY_FILE"
elif [[ -f "$HOME/.config/sops/age/keys.txt" ]]; then
  age_key="$HOME/.config/sops/age/keys.txt"
elif [[ -f "$HOME/Projects/keys/environments.age.key" ]]; then
  age_key="$HOME/Projects/keys/environments.age.key"
fi

if [[ -z "$age_key" ]]; then
  warnings="${warnings}  - age key not found (run /secrets-init or set SOPS_AGE_KEY_FILE)\\n"
  status_ok=false
fi

# Escape paths for safe JSON embedding (handle \ and " in paths)
_json_escape() { echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
env_yml_safe=$(_json_escape "$env_yml")
age_key_safe=$(_json_escape "$age_key")

# Build context message
if [[ "$status_ok" == "true" ]]; then
  session_context="<IMPORTANT>\nThe secrets plugin is active. /secrets and /secrets-init commands available.\nEnvironments: ${env_yml_safe}\nAge key: ${age_key_safe}\n</IMPORTANT>"
else
  session_context="<IMPORTANT>\nThe secrets plugin is active but has warnings:\n${warnings}\nRun /secrets-init to set up, or install missing tools.\n</IMPORTANT>"
fi

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
