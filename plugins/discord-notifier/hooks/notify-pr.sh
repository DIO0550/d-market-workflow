#!/usr/bin/env bash
# PR 作成（gh pr create / GitHub MCP）を検知して Discord に通知する
# 通知は失敗しても作業をブロックしない（常に exit 0）
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

input="$(cat)"
notify_configured || exit 0

tool_name="$(jq -r '.tool_name // empty' <<< "$input")"
if [ "$tool_name" != "mcp__github__create_pull_request" ]; then
  command="$(bash_command "$input")"
  grep -qE '(^|[^[:alnum:]_-])gh[[:space:]]+pr[[:space:]]+create' <<< "$command" || exit 0
fi

description="Pull Request が作成されました。"
pr_url="$(find_pr_url "$input" || true)"
[ -n "$pr_url" ] && description="Pull Request が作成されました。
${pr_url}"

send_embed "$input" "🔀 PR 作成" "$description" 7506394
exit 0
