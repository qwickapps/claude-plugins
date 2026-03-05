#!/bin/bash
# Sync document templates from ai-sdlc-workflows/shared/templates/ into plugin
# Usage: sync-templates.sh [source-dir]
# Default source: ~/Projects/ai-sdlc-workflows/shared/templates
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${SCRIPT_DIR}/../templates"
SOURCE_DIR="${1:-${HOME}/Projects/ai-sdlc-workflows/shared/templates}"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory not found: $SOURCE_DIR"
  echo "Clone ai-sdlc-workflows to ~/Projects/ai-sdlc-workflows first,"
  echo "or pass the source directory as an argument: $0 /path/to/templates"
  exit 1
fi

mkdir -p "$TARGET_DIR"
cp "$SOURCE_DIR"/*.md "$TARGET_DIR/"

count=$(ls -1 "$TARGET_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
echo "Synced $count templates from $SOURCE_DIR to $TARGET_DIR"
