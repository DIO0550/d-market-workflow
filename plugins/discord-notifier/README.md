# discord-notifier

PR の作成・コミット (Fix)・push・タスク完了を Discord に通知する Claude Code hook プラグインです。

## 動作

hook は通知パターンごとにスクリプトが分かれており、`hooks/hooks.json` に登録されているものだけが動きます。

| パターン | hook | 内容 |
| --- | --- | --- |
| PR 作成 | `notify-pr.sh`（PostToolUse: `Bash` / `mcp__github__create_pull_request`） | `gh pr create` または GitHub MCP での PR 作成を検知。出力から PR の URL が取得できた場合は通知に含める |
| コミット (Fix) | `notify-commit.sh`（PostToolUse: `Bash`） | `git commit` を検知し、直近のコミットメッセージを添えて通知 |
| push | `notify-push.sh`（PostToolUse: `Bash`） | `git push` を検知し、現在のブランチ名を添えて通知 |
| タスク完了 | `notify-stop.sh`（Stop） | Claude が応答を完了したタイミングで通知 |

`git commit && git push` のような複合コマンドでは、影響の大きいパターン（PR 作成 > push > コミット）だけが通知します。

## 通知の基本フォーマット

すべての通知は `hooks/lib/common.sh` の `send_embed` が生成する共通の embed フォーマットで送られます。各 hook が渡すのはイベント名・詳細・色（と PR 作成時は PR URL）だけです。リポジトリ名は origin の URL から `owner/repo` 形式で取得し、リモートが取得できない場合のみプロジェクトディレクトリ名を使います。

レイアウト方針:

- **リポジトリ名は embed のタイトル**（一番大きく表示される要素）に置き、`owner/repo` の場合は GitHub のリポジトリページへリンクします
- **ブランチ名は本文冒頭に太字＋🌿 絵文字**で目立たせます
- **PR リンクはどの通知にも付きます**。現在のブランチに紐づく open な PR を `gh` CLI もしくは GitHub API（`$GITHUB_TOKEN` が必要）で解決し、取得できた場合のみ `🔀 Pull Request` として本文末尾にリンクします
- セッション ID は footer に小さく載せるだけ（識別用のおまけ）

```
┌────────────────────────────────────────┐
│ owner/my-repo                          │  ← タイトル（リポジトリ、クリックで GitHub へ）
│ ### ⬆️ push 完了                        │  ← 本文の見出し（イベント名）
│ **🌿 `feature/awesome-branch`**         │  ← ブランチを太字＋絵文字で強調
│                                        │
│ リモートへ push しました。               │  ← 詳細
│                                        │
│ 🔀 Pull Request                        │  ← 現在ブランチの PR リンク（取得できた場合）
│ ────────────────────────────────────── │
│ session: abc12345      2026-07-19 14:00│  ← footer（小さく）＋タイムスタンプ
└────────────────────────────────────────┘
```

| パターン | イベント名（見出し） | 色 | 詳細 |
| --- | --- | --- | --- |
| PR 作成 | 🔀 PR 作成 | 紫 | 作成直後のツール出力から取得した PR URL |
| コミット (Fix) | 🔧 コミット (Fix) | 黄 | 直近のコミットメッセージ |
| push | ⬆️ push 完了 | 青 | 「リモートへ push しました。」 |
| タスク完了 | ✅ タスク完了 | 緑 | 「Claude が応答を完了しました。」 |

### PR リンクの解決について

PR 作成通知以外（コミット・push・タスク完了）でも、現在のブランチに open な PR が存在すればリンクを追加します。解決順は次のとおりで、どちらも失敗した場合は PR リンクを付けずに通知を送ります（通知自体は必ず送られます）。

1. `gh` CLI が使えて認証済み: `gh pr view <branch> --json url`
2. 環境変数 `GITHUB_TOKEN` が設定されている: GitHub REST API `GET /repos/{owner}/{repo}/pulls?head={owner}:{branch}&state=open`

## セットアップ

1. このプラグインを Claude Code のプラグインとして有効化してください。
2. Discord サーバーの「サーバー設定 → 連携サービス → ウェブフック」で Webhook を作成し、その URL を環境変数に設定してください。

```bash
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/xxxx/yyyy"
```

`DISCORD_WEBHOOK_URL` が未設定の場合、hook は何もせず正常終了します（作業をブロックしません）。通知の送信に失敗した場合も同様です。

> **注意:** Webhook URL は秘密情報です。リポジトリ管理下のファイルには書き込まず、環境変数で管理してください。

## 設定ファイル

通知パターンの ON/OFF などの非秘密設定は、ワークスペースの `.plugin-workspace/discord-notifier/config.json` で行います。`setup` スキルを実行すると、パターンを選んでこのファイルを作成できます。

```json
{
  "enabled": true,
  "events": {
    "pr": true,
    "commit": true,
    "push": true,
    "stop": true
  }
}
```

| キー | 内容 | 既定値 |
| --- | --- | --- |
| `enabled` | 全体の ON/OFF。環境変数 `DISCORD_NOTIFY_ENABLED`（`false` / `0` / `no` / `off`）が設定されていればそちらが優先 | `true` |
| `events.pr` | PR 作成の通知 | `true` |
| `events.commit` | コミット (Fix) の通知 | `true` |
| `events.push` | push の通知 | `true` |
| `events.stop` | タスク完了の通知 | `true` |

- 設定ファイル自体・各キーとも省略可能で、省略時はすべて有効です（ファイルがなくても動きます）
- **Webhook URL はこのファイルには書けません**。秘密情報のため環境変数 `DISCORD_WEBHOOK_URL` でのみ受け取ります
- `.plugin-workspace/` はワークスペースローカルな設定置き場のため Git 管理外にしてください
- `git worktree` 内で hook が発火した場合も、設定ファイルはリポジトリのメイン working tree にある `.plugin-workspace/discord-notifier/config.json` が参照されます。通知に載るブランチ・コミットメッセージは worktree の HEAD が使われます

## devcontainer での利用

1. ホストのシェル設定ファイルに書き込んで永続化する:

bash の場合:

```bash
echo 'export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/xxxx/yyyy"' >> ~/.bashrc
source ~/.bashrc
```

zsh の場合:

```bash
echo 'export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/xxxx/yyyy"' >> ~/.zshrc
source ~/.zshrc
```

2. `devcontainer.json` でホストの値をコンテナへ引き継ぐ:

```json
{
  "remoteEnv": {
    "DISCORD_WEBHOOK_URL": "${localEnv:DISCORD_WEBHOOK_URL}"
  }
}
```

値そのものを `devcontainer.json` に直接書かないでください（コミットされて Webhook URL が漏えいします）。

## 依存

- `jq`
- `curl`
