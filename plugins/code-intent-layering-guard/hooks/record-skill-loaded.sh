#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"
tool_name="$(jq -r '.tool_name // empty' <<< "$input")"

# Skill ツールでの発火、または SKILL.md の Read を「読み込み済み」とみなす
case "$tool_name" in
  Skill)
    skill="$(jq -r '.tool_input.skill // empty' <<< "$input")"
    case "$skill" in
      code-intent-layering|*:code-intent-layering) ;;
      *) exit 0 ;;
    esac
    ;;
  Read)
    file="$(jq -r '.tool_input.file_path // empty' <<< "$input")"
    case "$file" in
      */skills/code-intent-layering/SKILL.md|skills/code-intent-layering/SKILL.md) ;;
      *) exit 0 ;;
    esac
    ;;
  *) exit 0 ;;
esac

session_id="$(jq -r '.session_id // empty' <<< "$input")"
[ -z "$session_id" ] && exit 0
session_id="$(echo "$session_id" | sed 's/[^a-zA-Z0-9_-]/_/g')"

marker_dir="${CLAUDE_PROJECT_DIR:-.}/.plugin/skill-fired/${session_id}"
mkdir -p "$marker_dir"
touch "$marker_dir/code-intent-layering"
