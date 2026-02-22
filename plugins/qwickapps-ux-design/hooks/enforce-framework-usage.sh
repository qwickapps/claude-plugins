#!/usr/bin/env bash
# QwickApps Framework Usage Enforcement Hook
# Type: PreToolUse:Edit, PreToolUse:Write, PreToolUse:MultiEdit
#
# Blocks MUI imports, hardcoded colors, and inline styles in QwickApps client code.
# Does NOT fire on: framework source, stories, config files, server components, API routes.

set -euo pipefail

# Read tool input from stdin (JSON)
INPUT=$(cat)

# Extract file path
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
print(d.get('file_path', d.get('path', '')))
" 2>/dev/null || echo "")

# Extract content being written
CONTENT=$(echo "$INPUT" | python3 -c "
import sys, json
d = json.load(sys.stdin)
content = d.get('new_string', d.get('content', ''))
if not content and 'edits' in d:
    content = ' '.join(e.get('new_string', '') for e in d.get('edits', []))
print(content)
" 2>/dev/null || echo "")

# Only check TSX and JSX files
if [[ "$FILE_PATH" != *.tsx ]] && [[ "$FILE_PATH" != *.jsx ]]; then
  exit 0
fi

# Excluded paths — do not enforce on these
EXCLUDED_PATTERNS=(
  "qwickapps-react-framework"
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

ERRORS=()

# Rule 1: No MUI material imports (bare or sub-path: '@mui/material/Button' etc.)
if echo "$CONTENT" | grep -qE "from ['\"]@mui/material"; then
  ERRORS+=("❌ MUI import detected: @mui/material
   → Run the find-component skill to find the @qwickapps/react-framework equivalent
   → If no match exists, run extend-framework to add it")
fi

# Rule 2: No MUI icons imports
if echo "$CONTENT" | grep -qE "from ['\"]@mui/icons-material"; then
  ERRORS+=("❌ MUI icons detected: @mui/icons-material
   → Add required icons to @qwickapps/react-framework via extend-framework skill")
fi

# Rule 3: No inline style objects (style={{ }})
# Exception: allow the extend-framework placeholder pattern
if echo "$CONTENT" | grep -qE "style=\{\{"; then
  if ! echo "$CONTENT" | grep -qE "Placeholder:.*issue #[0-9]+"; then
    ERRORS+=("❌ Inline style detected: style={{ ... }}
   → Use sx prop with --theme-* CSS variables instead
   → Example: sx={{ color: 'var(--theme-primary)', background: 'var(--theme-surface)' }}
   → Only allowed in extend-framework placeholders with issue reference")
  fi
fi

# Rule 4: No hardcoded hex colors
if echo "$CONTENT" | grep -qE "['\"]#[0-9a-fA-F]{3,8}['\"]"; then
  ERRORS+=("❌ Hardcoded hex color detected
   → Use a --theme-* CSS variable instead
   → Run find-component skill to see available theme variables
   → Example: 'var(--theme-primary)' instead of '#667eea'")
fi

# Rule 5: No hardcoded rgba/rgb colors
if echo "$CONTENT" | grep -qE "rgba?\([[:space:]]*[0-9]"; then
  ERRORS+=("❌ Hardcoded rgba/rgb color detected
   → Use a --theme-* CSS variable instead
   → Example: 'var(--theme-overlay-80)' instead of 'rgba(0,0,0,0.8)'")
fi

if [ ${#ERRORS[@]} -gt 0 ]; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║          QwickApps Framework Enforcement                    ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""
  echo "File: $FILE_PATH"
  echo ""
  for err in "${ERRORS[@]}"; do
    printf "%b\n\n" "$err"
  done
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📚 Available skills: frontend-design  find-component  extend-framework"
  echo ""
  exit 1
fi

exit 0
