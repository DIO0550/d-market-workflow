#!/usr/bin/env bash
# 通知は失敗しても作業をブロックしない（常に exit 0）
set -uo pipefail

mode="${1:-post-tool}"
input="$(cat)"

# 設定の優先順位: 環境変数 > .plugin-workspace の設定ファイル > 既定値
config_file="${CLAUDE_PROJECT_DIR:-.}/.plugin-workspace/discord-notifier/config"

cfg() {
  [ -f "$config_file" ] || return 0
  sed -n "s/^[[:space:]]*$1=//p" "$config_file" | tail -1 | sed 's/^["'\'']//; s/["'\'']$//'
}

webhook="${DISCORD_WEBHOOK_URL:-$(cfg DISCORD_WEBHOOK_URL)}"
[ -z "$webhook" ] && exit 0

# URL を残したまま一時的に通知を止めるための明示スイッチ
enabled="${DISCORD_NOTIFY_ENABLED:-$(cfg DISCORD_NOTIFY_ENABLED)}"
case "${enabled:-true}" in
  false|0|no|off) exit 0 ;;
esac

# 通知するイベントをカンマ区切りで指定（既定はすべて）
events="${DISCORD_NOTIFY_EVENTS:-$(cfg DISCORD_NOTIFY_EVENTS)}"
events="${events:-pr,commit,push,stop}"

enabled() {
  case ",${events}," in
    *",$1,"*) return 0 ;;
  esac
  return 1
}

repo_name="$(basename "${CLAUDE_PROJECT_DIR:-$(pwd)}")"
session_id="$(jq -r '.session_id // empty' <<< "$input" | cut -c1-8)"

event=""
title=""
description=""
color=0

if [ "$mode" = "stop" ]; then
  enabled stop || exit 0
  event="stop"
  title="✅ タスク完了"
  description="Claude が応答を完了しました。"
  color=5763719 # green
else
  tool_name="$(jq -r '.tool_name // empty' <<< "$input")"

  find_pr_url() {
    jq -r '.tool_response | tostring' <<< "$input" \
      | grep -oE 'https://github\.com/[^"[:space:]\\]+/pull/[0-9]+' \
      | head -1
  }

  if [ "$tool_name" = "mcp__github__create_pull_request" ]; then
    enabled pr || exit 0
    event="pr"
    title="🔀 PR 作成"
    description="Pull Request が作成されました。"
    pr_url="$(find_pr_url || true)"
    [ -n "$pr_url" ] && description="Pull Request が作成されました。
${pr_url}"
    color=7506394 # blurple
  elif [ "$tool_name" = "Bash" ]; then
    command="$(jq -r '.tool_input.command // empty' <<< "$input")"
    [ -z "$command" ] && exit 0

    # 複合コマンド（commit && push など）は影響の大きいイベントを優先
    if grep -qE '(^|[^[:alnum:]_-])gh[[:space:]]+pr[[:space:]]+create' <<< "$command"; then
      enabled pr || exit 0
      event="pr"
      title="🔀 PR 作成"
      description="Pull Request が作成されました。"
      pr_url="$(find_pr_url || true)"
      [ -n "$pr_url" ] && description="Pull Request が作成されました。
${pr_url}"
      color=7506394
    elif grep -qE '(^|[^[:alnum:]_-])git[[:space:]]+push' <<< "$command"; then
      enabled push || exit 0
      event="push"
      title="⬆️ push 完了"
      branch="$(git -C "${CLAUDE_PROJECT_DIR:-.}" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
      description="リモートへ push しました。${branch:+
ブランチ: \`${branch}\`}"
      color=3447003 # blue
    elif grep -qE '(^|[^[:alnum:]_-])git[[:space:]]+commit' <<< "$command"; then
      enabled commit || exit 0
      event="commit"
      title="🔧 コミット (Fix)"
      subject="$(git -C "${CLAUDE_PROJECT_DIR:-.}" log -1 --pretty=%s 2>/dev/null || true)"
      description="変更をコミットしました。${subject:+
> ${subject}}"
      color=16426522 # yellow
    else
      exit 0
    fi
  else
    exit 0
  fi
fi

[ -z "$event" ] && exit 0

payload="$(jq -n \
  --arg title "$title" \
  --arg description "$description" \
  --arg repo "$repo_name" \
  --arg session "$session_id" \
  '{
    embeds: [{
      title: $title,
      description: $description,
      color: '"$color"',
      fields: ([
        { name: "リポジトリ", value: $repo, inline: true },
        (if $session != "" then { name: "セッション", value: $session, inline: true } else empty end)
      ]),
      timestamp: (now | todate)
    }]
  }')"

curl -sS --max-time 5 \
  -H "Content-Type: application/json" \
  -d "$payload" \
  "$webhook" >/dev/null 2>&1 || true

exit 0
