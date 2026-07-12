#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"

# Edit / Write / MultiEdit の対象パスをすべて集める
files="$(jq -r '
  [
    (.tool_input.file_path? // empty),
    (.tool_input.path? // empty),
    ((.tool_input.edits // [])[] | (.file_path? // .path? // empty))
  ] | .[]
' <<< "$input")"
[ -z "$files" ] && exit 0

is_programming_file() {
  local file="$1"
  local lower="${file,,}"
  case "$(basename "$file")" in
    Dockerfile|Makefile|Rakefile|Gemfile|CMakeLists.txt) return 0 ;;
  esac
  case "$lower" in
    *.c|*.cc|*.clj|*.cljs|*.cpp|*.cs|*.dart|*.ex|*.exs|\
    *.fs|*.fsx|*.go|*.groovy|*.h|*.hpp|*.hs|*.lhs|*.java|*.js|\
    *.jsx|*.kt|*.kts|*.lua|*.m|*.mm|*.php|*.pl|*.pm|\
    *.py|*.pyw|*.r|*.rb|*.rs|*.scala|*.sh|*.swift|\
    *.ts|*.tsx|*.vue|*.zig) return 0 ;;
  esac
  return 1
}

targets=()
while IFS= read -r file; do
  [ -z "$file" ] && continue
  # マーカー置き場やプラグイン・依存ディレクトリ内はゲート対象外
  case "$file" in
    */.plugin/*|*/.claude/*|*/node_modules/*|.plugin/*|.claude/*|node_modules/*) continue ;;
  esac
  if is_programming_file "$file"; then
    targets+=("$file")
  fi
done <<< "$files"

[ ${#targets[@]} -eq 0 ] && exit 0

session_id="$(jq -r '.session_id // empty' <<< "$input")"
[ -z "$session_id" ] && exit 0
session_id="$(echo "$session_id" | sed 's/[^a-zA-Z0-9_-]/_/g')"

marker="${CLAUDE_PROJECT_DIR:-.}/.plugin/skill-fired/${session_id}/code-intent-layering"
[ -f "$marker" ] && exit 0

target_list=""
for file in "${targets[@]}"; do
  target_list="${target_list}
- ${file}"
done

jq -n --arg targets "$target_list" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: ("プログラミング言語ファイルを変更する前に code-intent-layering スキルを読み込んでください。\n\nSkill ツールで code-intent-layering を実行するか、skills/code-intent-layering/SKILL.md を Read してください。\nこのスキルは、コード=How、テスト=What、コミット=Why、コメント=Why-not/局所的なWhy のレイヤリングを確認するために必要です。\n\n対象:" + $targets)
  }
}'
