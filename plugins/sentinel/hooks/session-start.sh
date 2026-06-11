#!/usr/bin/env bash
# SessionStart hook for sentinel plugin
# Injects sentinel context — confirms enforcement is active and
# summarises the classify -> oracle -> AI pipeline.

set -euo pipefail

session_context="<IMPORTANT>\nSentinel is active.\n\nSentinel intercepts every tool call, classifies intent (classify.sh), and enforces SOP rules (oracle.sh). Any operation that violates sop-rules.yaml is blocked or redirected before it reaches Claude.\n\nHooks wired:\n  PreToolUse  (Bash)  -> bash-intercept.sh  (classify + oracle + AI check)\n  PreToolUse  (.*)    -> tool-recorder.sh   (session recording)\n  PostToolUse (.*)    -> tool-outcome.sh    (async outcome logging)\n  Stop        (.*)    -> hook-router.sh Stop         (escalate-dont-stall)\n  PreCompact  (.*)    -> hook-router.sh PreCompact   (session snapshot + brain flush)\n  SessionEnd  (.*)    -> hook-router.sh SessionEnd   (session snapshot + brain flush)\n\nConfig: ~/.qwickapps/sentinel/config.yaml\nRules:  ~/.qwickapps/sentinel/sop-rules.yaml (project-local: .sentinel/sop-rules.yaml)\nLogs:   ~/.qwickapps/sentinel/logs/\n\nTo reinstall or update: bash ~/.sentinel-src/install.sh\n</IMPORTANT>"

cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${session_context}"
  }
}
EOF

exit 0
