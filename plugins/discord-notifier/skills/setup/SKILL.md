---
name: setup
description: 通知するパターン（pr / commit / push / stop）を選んで hooks/hooks.json を設定する
disable-model-invocation: true
allowed-tools: Read, Write, AskUserQuestion
---

# discord-notifier セットアップ

hook は通知パターンごとにスクリプトが分かれており、`hooks/hooks.json` に登録されているものだけが通知される。
このスキルは、通知したいパターンを選んで `plugins/discord-notifier/hooks/hooks.json` を書き換えるだけのもの。

Webhook URL は環境変数 `DISCORD_WEBHOOK_URL` で設定する（このスキルでは扱わない）。

## 手順

1. `plugins/discord-notifier/hooks/hooks.json` を Read し、現在登録されているパターンを提示する
2. AskUserQuestion（multiSelect）で通知するパターンを選んでもらう:
   - PR 作成（`notify-pr.sh`）
   - コミット (Fix)（`notify-commit.sh`）
   - push（`notify-push.sh`）
   - タスク完了（`notify-stop.sh`）
3. 下のテンプレートから選ばれたパターンのエントリだけを残した JSON を Write する
4. `DISCORD_WEBHOOK_URL` が未設定なら通知されないこと（`export DISCORD_WEBHOOK_URL=...` が必要）を案内して完了

## hooks.json テンプレート（全パターン有効時）

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash|mcp__github__create_pull_request",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/notify-pr.sh" }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/notify-push.sh" }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/notify-commit.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/notify-stop.sh" }
        ]
      }
    ]
  }
}
```

- 不要なパターンは対応するエントリごと削除する（`PostToolUse` / `Stop` が空になる場合はキーごと削除する）
- hooks.json の変更は新しいセッションから反映される
