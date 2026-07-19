# discord-notifier

PR の作成・コミット (Fix)・push・タスク完了を Discord に通知する Claude Code hook プラグインです。

## 動作

- **PR 作成（PostToolUse: `Bash` / `mcp__github__create_pull_request`）** — `gh pr create` の実行、または GitHub MCP ツールでの PR 作成を検知して通知します。ツールの出力から PR の URL が取得できた場合は通知に含めます。
- **コミット (Fix)（PostToolUse: `Bash`）** — `git commit` を検知し、直近のコミットメッセージ（subject）を添えて通知します。
- **push（PostToolUse: `Bash`）** — `git push` を検知し、現在のブランチ名を添えて通知します。
- **タスク完了（Stop）** — Claude が応答を完了したタイミングで通知します。

`git commit && git push` のような複合コマンドでは、影響の大きいイベント（PR 作成 > push > コミット）を 1 件だけ通知します。

通知は Discord の embed 形式で、リポジトリ名・セッション ID（先頭 8 文字）・タイムスタンプを含みます。

## セットアップ

1. このプラグインを Claude Code のプラグインとして有効化してください。
2. Discord サーバーの「サーバー設定 → 連携サービス → ウェブフック」で Webhook を作成し、その URL を環境変数に設定してください。

```bash
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/xxxx/yyyy"
```

`DISCORD_WEBHOOK_URL` が未設定の場合、hook は何もせず正常終了します（作業をブロックしません）。通知の送信に失敗した場合も同様です。

`setup` スキルを実行すると、環境変数の設定状況の確認・export スニペットの提示・テスト通知を対話形式で行えます（スキル自体はファイルへの書き込みを行いません）。

> **注意:** Webhook URL は秘密情報です。リポジトリ管理下のファイルには書き込まず、環境変数（シェルの設定ファイル等）で管理してください。

## 設定

Webhook URL を残したまま一時的に通知を止めたい場合は、`DISCORD_NOTIFY_ENABLED` を `false`（または `0` / `no` / `off`）に設定してください。既定は有効です。

```bash
export DISCORD_NOTIFY_ENABLED=false
```

通知するイベントは `DISCORD_NOTIFY_EVENTS` 環境変数（カンマ区切り）で絞り込めます。既定はすべて有効です。

```bash
# PR 作成とタスク完了だけ通知する例
export DISCORD_NOTIFY_EVENTS="pr,stop"
```

| イベント | 内容 |
| --- | --- |
| `pr` | PR 作成（`gh pr create` / GitHub MCP） |
| `commit` | `git commit` |
| `push` | `git push` |
| `stop` | タスク完了（Stop hook） |

## 依存

- `jq`
- `curl`
