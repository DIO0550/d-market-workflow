#!/usr/bin/env bash
# discord-notifier の共通処理（各 hook スクリプトから source される）

webhook="${DISCORD_WEBHOOK_URL:-}"

# hook_cwd <input_json> — hook 発火時のツール実行 cwd を返す
# 優先順位: 入力 JSON の cwd（ツールが実際に走ったディレクトリ）> CLAUDE_PROJECT_DIR > 現在の cwd。
# worktree で作業していた場合、CLAUDE_PROJECT_DIR はメインの working tree を指し得るため、
# 入力 cwd を優先することで worktree 側のブランチ/コミット情報を取得できる。
hook_cwd() {
  local cwd
  cwd="$(jq -r '.cwd // empty' <<< "$1" 2>/dev/null || true)"
  if [ -n "$cwd" ] && [ -d "$cwd" ]; then
    printf '%s\n' "$cwd"
    return
  fi
  printf '%s\n' "${CLAUDE_PROJECT_DIR:-$(pwd)}"
}

# workspace_root <input_json> — 設定ファイル探索の起点となるワークスペースルート
# git worktree の中で発火した場合はメインの working tree を返す（common .git の親）。
# git 管理下でなければ hook_cwd をそのまま返す。
workspace_root() {
  local cwd common_dir root
  cwd="$(hook_cwd "$1")"
  common_dir="$(git -C "$cwd" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -n "$common_dir" ] && [ -d "$common_dir" ]; then
    root="$(dirname "$common_dir")"
    if [ -d "$root" ]; then
      printf '%s\n' "$root"
      return
    fi
  fi
  printf '%s\n' "$cwd"
}

# config_file_path <input_json> — 設定ファイルの絶対パス
config_file_path() {
  printf '%s/.plugin-workspace/discord-notifier/config.json\n' "$(workspace_root "$1")"
}

# 通知可能な状態か（URL 未設定・一時 OFF なら通知しない）
# ON/OFF の優先順位: 環境変数 DISCORD_NOTIFY_ENABLED > config.json の enabled > 既定 true
notify_configured() {
  [ -n "$webhook" ] || return 1
  local enabled config_file
  enabled="${DISCORD_NOTIFY_ENABLED:-}"
  if [ -z "$enabled" ]; then
    config_file="$(config_file_path "$1")"
    if [ -f "$config_file" ]; then
      # jq の // は false も空扱いするため使わず、null との比較で既定値に倒す
      enabled="$(jq -r '.enabled' "$config_file" 2>/dev/null || true)"
      [ "$enabled" = "null" ] && enabled=""
    fi
  fi
  case "${enabled:-true}" in
    false|0|no|off) return 1 ;;
  esac
  return 0
}

# event_enabled <input_json> <pr|commit|push|stop>
# config.json でパターンが無効化されていないか（既定: 有効）
event_enabled() {
  local config_file
  config_file="$(config_file_path "$1")"
  [ -f "$config_file" ] || return 0
  local v
  v="$(jq -r --arg e "$2" '.events[$e]' "$config_file" 2>/dev/null || true)"
  [ "$v" != "false" ]
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

# repo_full_name <input_json> — origin の URL から owner/repo を取り出す（取得できなければ失敗）
# https / ssh / git プロトコルいずれの URL 形式にも対応する
repo_full_name() {
  local url cwd
  cwd="$(hook_cwd "$1")"
  url="$(git -C "$cwd" remote get-url origin 2>/dev/null || true)"
  [ -n "$url" ] || return 1
  url="${url%/}"
  url="${url%.git}"
  grep -oE '[^/:]+/[^/:]+$' <<< "$url"
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
  local cwd repo_name branch session_id payload
  cwd="$(hook_cwd "$input")"
  # ディレクトリ名はクローン先の名前次第でリポジトリ名と食い違うため、
  # origin の URL を優先し、取れない場合のみディレクトリ名に倒す
  repo_name="$(repo_full_name "$input" || true)"
  [ -n "$repo_name" ] || repo_name="$(basename "$cwd")"
  branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
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
