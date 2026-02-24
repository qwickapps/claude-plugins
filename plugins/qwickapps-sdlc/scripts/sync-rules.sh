#!/bin/bash
# Sync quality rules from ai-sdlc-workflows/shared/rules/ into plugin
# Usage: sync-rules.sh [source-dir]
# Default source: ~/Projects/ai-sdlc-workflows/shared/rules
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${SCRIPT_DIR}/../rules"
SOURCE_DIR="${1:-${HOME}/Projects/ai-sdlc-workflows/shared/rules}"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory not found: $SOURCE_DIR"
  echo "Clone ai-sdlc-workflows to ~/Projects/ai-sdlc-workflows first,"
  echo "or pass the source directory as an argument: $0 /path/to/rules"
  exit 1
fi

mkdir -p "$TARGET_DIR"
cp "$SOURCE_DIR"/*.md "$TARGET_DIR/"

count=$(ls -1 "$TARGET_DIR"/*.md 2>/dev/null | wc -l | tr -d ' ')
echo "Synced $count rules from $SOURCE_DIR to $TARGET_DIR"
