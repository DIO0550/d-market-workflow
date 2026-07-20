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

# pr_url_for_branch <input_json> — 現在のブランチに紐づく open な PR の URL を取得する
# 優先順位: gh CLI > GitHub API（$GITHUB_TOKEN が必要）
# どちらも失敗した場合は無音で終了する（PR リンクを付けないだけで通知自体は送る）。
pr_url_for_branch() {
  local input="$1" cwd branch owner_repo owner repo url
  cwd="$(hook_cwd "$input")"
  branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  [ -n "$branch" ] && [ "$branch" != "HEAD" ] || return 1

  if command -v gh >/dev/null 2>&1; then
    url="$(GH_PAGER='' gh -R "$cwd" pr view "$branch" --json url --jq .url 2>/dev/null || true)"
    if [ -z "$url" ]; then
      url="$(cd "$cwd" && GH_PAGER='' gh pr view "$branch" --json url --jq .url 2>/dev/null || true)"
    fi
    if [ -n "$url" ]; then
      printf '%s\n' "$url"
      return 0
    fi
  fi

  if [ -n "${GITHUB_TOKEN:-}" ]; then
    owner_repo="$(repo_full_name "$input" || true)"
    [ -n "$owner_repo" ] || return 1
    owner="${owner_repo%/*}"
    repo="${owner_repo#*/}"
    url="$(curl -sS --max-time 3 \
      -H "Authorization: Bearer ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/${owner}/${repo}/pulls?head=${owner}:${branch}&state=open&per_page=1" \
      2>/dev/null \
      | jq -r '.[0].html_url // empty' 2>/dev/null || true)"
    if [ -n "$url" ]; then
      printf '%s\n' "$url"
      return 0
    fi
  fi

  return 1
}

# send_embed <input_json> <event_label> <details> <color> [<pr_url_override>]
#
# レイアウト方針:
#   - タイトル（最大サイズ）にリポジトリ名（owner/repo）を出し、GitHub リポジトリへリンクさせる
#   - 本文冒頭でイベント名を見出し (###) にし、続けてブランチ名を太字＋絵文字で目立たせる
#   - PR URL は override が渡されればそれを、無ければ現在のブランチから解決してリンクを付ける
#   - セッション ID は footer に小さく載せるだけ（識別用のおまけ）
send_embed() {
  local input="$1" event="$2" details="$3" color="$4" pr_override="${5:-}"
  local cwd repo_name branch session_id pr_url repo_url description payload

  cwd="$(hook_cwd "$input")"
  # ディレクトリ名はクローン先の名前次第でリポジトリ名と食い違うため、
  # origin の URL を優先し、取れない場合のみディレクトリ名に倒す
  repo_name="$(repo_full_name "$input" || true)"
  [ -n "$repo_name" ] || repo_name="$(basename "$cwd")"
  branch="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  session_id="$(jq -r '.session_id // empty' <<< "$input" | cut -c1-8)"

  if [ -n "$pr_override" ]; then
    pr_url="$pr_override"
  else
    pr_url="$(pr_url_for_branch "$input" 2>/dev/null || true)"
  fi

  # 本文: 見出し（イベント名） → ブランチ → 詳細 → PR リンク
  description="### ${event}"
  if [ -n "$branch" ]; then
    description+=$'\n'"**🌿 \`${branch}\`**"
  fi
  if [ -n "$details" ]; then
    description+=$'\n\n'"${details}"
  fi
  if [ -n "$pr_url" ]; then
    description+=$'\n\n'"[🔀 Pull Request](${pr_url})"
  fi

  # owner/repo 形式なら GitHub の URL を作ってタイトルをクリック可能にする
  case "$repo_name" in
    */*) repo_url="https://github.com/${repo_name}" ;;
    *)   repo_url="" ;;
  esac

  payload="$(jq -n \
    --arg title "$repo_name" \
    --arg url "$repo_url" \
    --arg description "$description" \
    --arg session "$session_id" \
    --argjson color "$color" \
    '{
      embeds: [(
        {
          title: $title,
          description: $description,
          color: $color,
          timestamp: (now | todate)
        }
        + (if $url != "" then { url: $url } else {} end)
        + (if $session != "" then { footer: { text: "session: \($session)" } } else {} end)
      )]
    }')"

  curl -sS --max-time 5 \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "$webhook" >/dev/null 2>&1 || true
}
