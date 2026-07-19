---
name: setup
description: 通知するパターン（pr / commit / push / stop）を選んで .plugin-workspace/discord-notifier/config.json を作成する
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Bash, AskUserQuestion
---

# discord-notifier セットアップ

通知パターンの ON/OFF を設定ファイル `.plugin-workspace/discord-notifier/config.json` に書き込む。
Webhook URL は環境変数 `DISCORD_WEBHOOK_URL` で設定するもので、このスキルでは扱わない（設定ファイルにも決して書かない）。

## 設定ファイルのフォーマット

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

- `enabled` — 全体の ON/OFF。環境変数 `DISCORD_NOTIFY_ENABLED` が設定されていればそちらが優先される
- `events.*` — パターンごとの ON/OFF
- ファイル自体・各キーとも省略時は `true`（設定ファイルがなくても全パターン通知される）

## 手順

1. `.plugin-workspace/discord-notifier/config.json` を Read し、存在すれば現在の設定を提示する
2. AskUserQuestion（multiSelect）で通知するパターン（PR 作成 / コミット (Fix) / push / タスク完了）を選んでもらう
3. Bash で `mkdir -p "${CLAUDE_PROJECT_DIR:-.}/.plugin-workspace/discord-notifier"` を実行し、上のフォーマットで config.json を Write する（選ばれなかったパターンは `false`）
4. リポジトリルートの `.gitignore` に `.plugin-workspace/` が含まれるか確認し、なければ追記する
5. `DISCORD_WEBHOOK_URL` が未設定なら通知されないこと（`export DISCORD_WEBHOOK_URL=...` が必要）を案内して完了
