#!/usr/bin/env bash
# git commit を検知して Discord に通知する
# 通知は失敗しても作業をブロックしない（常に exit 0）
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

input="$(cat)"
notify_configured || exit 0
event_enabled commit || exit 0

command="$(bash_command "$input")"
grep -qE '(^|[^[:alnum:]_-])git[[:space:]]+commit' <<< "$command" || exit 0
# push / PR 作成を含む複合コマンドは、影響の大きいそちらの hook に任せる
grep -qE '(^|[^[:alnum:]_-])git[[:space:]]+push|(^|[^[:alnum:]_-])gh[[:space:]]+pr[[:space:]]+create' <<< "$command" && exit 0

subject="$(git -C "${CLAUDE_PROJECT_DIR:-.}" log -1 --pretty=%s 2>/dev/null || true)"
description="変更をコミットしました。${subject:+
> ${subject}}"

send_embed "$input" "🔧 コミット (Fix)" "$description" 16426522
exit 0
