#!/usr/bin/env bash
# Validates that all skill cross-references in dev-guide resolve to existing skills.
# Run from the plugin root: bash scripts/validate-cross-refs.sh

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$PLUGIN_DIR/skills"
EXIT_CODE=0

# Collect all skill directory names (these are the valid skill names)
VALID_SKILLS=()
for dir in "$SKILLS_DIR"/*/; do
  if [ -f "$dir/SKILL.md" ]; then
    VALID_SKILLS+=("$(basename "$dir")")
  fi
done

echo "Found skills: ${VALID_SKILLS[*]}"
echo "---"

# Check each SKILL.md and references/ file for skill references
# Looks for patterns like: `skill-name` skill  or  `skill-name` for
while IFS= read -r -d '' file; do
  rel_path="${file#"$PLUGIN_DIR"/}"

  # Known cross-plugin skill references (from other plugins in the marketplace)
  CROSS_PLUGIN_SKILLS="frontend-design ux-design"

  grep -oE '`[a-z][a-z0-9-]+` (skill|for)' "$file" 2>/dev/null | \
    sed 's/`//g; s/ .*//' | sort -u | while read -r ref; do
    # Skip known cross-plugin references
    case " $CROSS_PLUGIN_SKILLS " in
      *" $ref "*) continue ;;
    esac
    found=false
    for valid in "${VALID_SKILLS[@]}"; do
      if [ "$ref" = "$valid" ]; then
        found=true
        break
      fi
    done
    if [ "$found" = false ]; then
      echo "BROKEN REF: $rel_path references skill '$ref' but no skills/$ref/SKILL.md exists"
      EXIT_CODE=1
    fi
  done
done < <(find "$SKILLS_DIR" -name '*.md' -print0)

# Check that all SKILL.md files have required frontmatter fields
for dir in "$SKILLS_DIR"/*/; do
  skill_md="$dir/SKILL.md"
  if [ ! -f "$skill_md" ]; then
    continue
  fi
  skill_name="$(basename "$dir")"

  if ! grep -q '^name:' "$skill_md"; then
    echo "MISSING FIELD: skills/$skill_name/SKILL.md has no 'name:' in frontmatter"
    EXIT_CODE=1
  fi
  if ! grep -q '^description:' "$skill_md"; then
    echo "MISSING FIELD: skills/$skill_name/SKILL.md has no 'description:' in frontmatter"
    EXIT_CODE=1
  fi
done

# Check for stale references to old skill names
OLD_NAMES=("build-with-cms" "build-with-server" "build-frontend-app")
for old in "${OLD_NAMES[@]}"; do
  while IFS= read -r -d '' file; do
    rel_path="${file#"$PLUGIN_DIR"/}"
    if grep -q "$old" "$file" 2>/dev/null; then
      echo "STALE REF: $rel_path still references old skill name '$old'"
      EXIT_CODE=1
    fi
  done < <(find "$SKILLS_DIR" -name '*.md' -print0)
done

if [ "$EXIT_CODE" -eq 0 ]; then
  echo "All cross-references valid."
else
  echo "---"
  echo "Validation failed. Fix the issues above."
fi

exit $EXIT_CODE
