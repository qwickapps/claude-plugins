#!/usr/bin/env bash
# QwickApps Framework Usage Enforcement Hook
# Type: PreToolUse:Edit, PreToolUse:Write, PreToolUse:MultiEdit
#
# Blocks MUI imports, hardcoded colors, and inline styles in QwickApps client code.
# Does NOT fire on: framework source, stories, config files, server components, API routes.

# Emergency bypass
if [[ "$QWICKAPPS_BYPASS_FRAMEWORK_CHECK" == "true" ]]; then
  exit 0
fi

# Read tool input from stdin (JSON)
INPUT=$(cat)

# Extract file path (.tool_input.file_path is Claude's standard field name)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

# Only check TSX and JSX files
if [[ "$FILE_PATH" != *.tsx ]] && [[ "$FILE_PATH" != *.jsx ]]; then
  exit 0
fi

# Excluded paths — do not enforce on these
EXCLUDED_PATTERNS=(
  "qwickapps-react-framework"
  "node_modules"
  ".stories.tsx"
  ".stories.jsx"
  ".config."
  "/api/"
  "route.ts"
  "route.tsx"
  ".test."
  ".spec."
)

for pattern in "${EXCLUDED_PATTERNS[@]}"; do
  if [[ "$FILE_PATH" == *"$pattern"* ]]; then
    exit 0
  fi
done

# Extract content being written
# Handles Edit (new_string), Write (content), and MultiEdit (edits[].new_string)
CONTENT=$(echo "$INPUT" | jq -r '
  .tool_input.new_string //
  .tool_input.content //
  (if .tool_input.edits then (.tool_input.edits | map(.new_string // "") | join(" ")) else "" end) //
  ""
')

ERRORS=()

# Rule 1: No MUI material imports (bare or sub-path: '@mui/material/Button' etc.)
if echo "$CONTENT" | grep -qE "from ['\"]@mui/material"; then
  ERRORS+=("MUI import detected: @mui/material
   -> Run the find-component skill to find the @qwickapps/react-framework equivalent
   -> If no match exists, run extend-framework to add it")
fi

# Rule 2: No MUI icons imports
if echo "$CONTENT" | grep -qE "from ['\"]@mui/icons-material"; then
  ERRORS+=("MUI icons detected: @mui/icons-material
   -> Add required icons to @qwickapps/react-framework via extend-framework skill")
fi

# Rule 3: No inline style objects (style={{ }})
# Exception: allow the extend-framework placeholder pattern (must contain "issue #N")
if echo "$CONTENT" | grep -qE "style=\{\{"; then
  if ! echo "$CONTENT" | grep -qE "issue #[0-9]+"; then
    ERRORS+=("Inline style detected: style={{ ... }}
   -> Use sx prop with --theme-* CSS variables instead
   -> Example: sx={{ color: 'var(--theme-primary)', background: 'var(--theme-surface)' }}
   -> Only allowed in extend-framework placeholders with issue reference")
  fi
fi

# Rule 4: No hardcoded hex colors
if echo "$CONTENT" | grep -qE "['\"]#[0-9a-fA-F]{3,8}['\"]"; then
  ERRORS+=("Hardcoded hex color detected
   -> Use a --theme-* CSS variable instead
   -> Run find-component skill to see available theme variables
   -> Example: 'var(--theme-primary)' instead of '#667eea'")
fi

# Rule 5: No hardcoded rgba/rgb colors
if echo "$CONTENT" | grep -qE "rgba?\([[:space:]]*[0-9]"; then
  ERRORS+=("Hardcoded rgba/rgb color detected
   -> Use a --theme-* CSS variable instead
   -> Example: 'var(--theme-overlay-80)' instead of 'rgba(0,0,0,0.8)'")
fi

if [ ${#ERRORS[@]} -gt 0 ]; then
  MESSAGE="QwickApps Framework Enforcement\n\nFile: $FILE_PATH\n\n"
  for err in "${ERRORS[@]}"; do
    MESSAGE+="${err}\n\n"
  done
  MESSAGE+="Available skills: frontend-design  find-component  extend-framework\nEmergency bypass: QWICKAPPS_BYPASS_FRAMEWORK_CHECK=true"

  jq -n --arg reason "$MESSAGE" '{
    "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": $reason
    }
  }'
fi

exit 0
