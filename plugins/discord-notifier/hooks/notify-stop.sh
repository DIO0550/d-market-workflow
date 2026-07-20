#!/usr/bin/env bash
# タスク完了（Stop hook）を Discord に通知する
# 通知は失敗しても作業をブロックしない（常に exit 0）
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

input="$(cat)"
notify_configured "$input" || exit 0
event_enabled "$input" stop || exit 0

send_embed "$input" "✅ タスク完了" "Claude が応答を完了しました。" 5763719
exit 0
