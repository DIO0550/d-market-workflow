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

通知は Discord の embed 形式で、リポジトリ名・セッション ID（先頭 8 文字）・タイムスタンプを含みます。共通処理は `hooks/lib/common.sh` にあります。

## セットアップ

1. このプラグインを Claude Code のプラグインとして有効化してください。
2. Discord サーバーの「サーバー設定 → 連携サービス → ウェブフック」で Webhook を作成し、その URL を環境変数に設定してください。

```bash
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/xxxx/yyyy"
```

`DISCORD_WEBHOOK_URL` が未設定の場合、hook は何もせず正常終了します（作業をブロックしません）。通知の送信に失敗した場合も同様です。

> **注意:** Webhook URL は秘密情報です。リポジトリ管理下のファイルには書き込まず、環境変数で管理してください。

## 設定

- **通知するパターンの選択** — `hooks/hooks.json` から不要なパターンのエントリを削除してください。`setup` スキルを実行すると、パターンを選んで hooks.json を書き換えられます。
- **一時的な OFF** — `DISCORD_NOTIFY_ENABLED` を `false`（または `0` / `no` / `off`）に設定すると、Webhook URL を残したまますべての通知を止められます。既定は有効です。

```bash
export DISCORD_NOTIFY_ENABLED=false
```

## 依存

- `jq`
- `curl`
