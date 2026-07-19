#!/usr/bin/env bash
# discord-notifier の共通処理（各 hook スクリプトから source される）

webhook="${DISCORD_WEBHOOK_URL:-}"

# 通知可能な状態か（URL 未設定・一時 OFF なら通知しない）
notify_configured() {
  [ -n "$webhook" ] || return 1
  case "${DISCORD_NOTIFY_ENABLED:-true}" in
    false|0|no|off) return 1 ;;
  esac
  return 0
}

# bash_command <input_json> — Bash ツールの実行コマンドを取り出す（Bash 以外は空）
bash_command() {
  jq -r 'select(.tool_name == "Bash") | .tool_input.command // empty' <<< "$1"
}

# find_pr_url <input_json> — ツール出力から PR の URL を取り出す
find_pr_url() {
  jq -r '.tool_response | tostring' <<< "$1" \
    | grep -oE 'https://github\.com/[^"[:space:]\\]+/pull/[0-9]+' \
    | head -1
}

# send_embed <input_json> <title> <description> <color>
#
# 全通知共通の基本フォーマット:
#   - タイトル: 絵文字 + イベント名
#   - 本文: イベントごとの詳細（PR の URL、コミットメッセージ等）
#   - フィールド: リポジトリ / ブランチ / セッション（先頭 8 文字）
#   - タイムスタンプ
send_embed() {
  local input="$1" title="$2" description="$3" color="$4"
  local repo_name branch session_id payload
  repo_name="$(basename "${CLAUDE_PROJECT_DIR:-$(pwd)}")"
  branch="$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  session_id="$(jq -r '.session_id // empty' <<< "$input" | cut -c1-8)"

  payload="$(jq -n \
    --arg title "$title" \
    --arg description "$description" \
    --arg repo "$repo_name" \
    --arg branch "$branch" \
    --arg session "$session_id" \
    --argjson color "$color" \
    '{
      embeds: [{
        title: $title,
        description: $description,
        color: $color,
        fields: ([
          { name: "リポジトリ", value: $repo, inline: true },
          (if $branch != "" then { name: "ブランチ", value: $branch, inline: true } else empty end),
          (if $session != "" then { name: "セッション", value: $session, inline: true } else empty end)
        ]),
        timestamp: (now | todate)
      }]
    }')"

  curl -sS --max-time 5 \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$webhook" >/dev/null 2>&1 || true
}
