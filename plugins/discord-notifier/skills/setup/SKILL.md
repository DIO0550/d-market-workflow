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

1. `git rev-parse --path-format=absolute --git-common-dir` の親ディレクトリを取り、リポジトリのメイン working tree（`$ROOT`）を確定する。git 管理下でなければ `${CLAUDE_PROJECT_DIR:-.}` を `$ROOT` に使う
   （git worktree 内で実行しても常にメイン working tree に書き込むことで、worktree 間で設定を共有し hook 側の読み取りと一致させる）
2. `$ROOT/.plugin-workspace/discord-notifier/config.json` を Read し、存在すれば現在の設定を提示する
3. AskUserQuestion（multiSelect）で通知するパターン（PR 作成 / コミット (Fix) / push / タスク完了）を選んでもらう
4. Bash で `mkdir -p "$ROOT/.plugin-workspace/discord-notifier"` を実行し、上のフォーマットで config.json を Write する（選ばれなかったパターンは `false`）
5. `$ROOT/.gitignore` に `.plugin-workspace/` が含まれるか確認し、なければ追記する
6. `DISCORD_WEBHOOK_URL` が未設定なら通知されないこと（`export DISCORD_WEBHOOK_URL=...` が必要）を案内して完了
