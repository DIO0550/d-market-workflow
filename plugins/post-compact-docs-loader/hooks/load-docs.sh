#!/bin/bash
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DOCS_LIST="$PLUGIN_DIR/docs-list.txt"

if [ ! -f "$DOCS_LIST" ]; then
  echo "Warning: docs-list.txt not found at $DOCS_LIST" >&2
  exit 0
fi

OUTPUT="[Post-Compact Reminder] Context was compacted. Please re-read the following documentation files before continuing:"
OUTPUT="$OUTPUT"$'\n'

while IFS= read -r line || [ -n "$line" ]; do
  # skip empty lines and comments
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

  # resolve relative paths from project root
  if [[ "$line" != /* ]]; then
    RESOLVED="$CLAUDE_PROJECT_DIR/$line"
  else
    RESOLVED="$line"
  fi

  if [ -f "$RESOLVED" ]; then
    OUTPUT="$OUTPUT- $RESOLVED"$'\n'
  else
    OUTPUT="$OUTPUT- $RESOLVED (file not found, skip)"$'\n'
  fi
done < "$DOCS_LIST"

OUTPUT="$OUTPUT"$'\n'"Please use the Read tool to read each file listed above and incorporate their contents into your working context."

echo "$OUTPUT"
exit 0
