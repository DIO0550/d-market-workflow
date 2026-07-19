#!/usr/bin/env bash
# git push を検知して Discord に通知する
# 通知は失敗しても作業をブロックしない（常に exit 0）
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

input="$(cat)"
notify_configured || exit 0

command="$(bash_command "$input")"
grep -qE '(^|[^[:alnum:]_-])git[[:space:]]+push' <<< "$command" || exit 0
# PR 作成を含む複合コマンドは notify-pr.sh 側に任せる
grep -qE '(^|[^[:alnum:]_-])gh[[:space:]]+pr[[:space:]]+create' <<< "$command" && exit 0

branch="$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
description="リモートへ push しました。${branch:+
ブランチ: \`${branch}\`}"

send_embed "$input" "⬆️ push 完了" "$description" 3447003
exit 0
