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

すべての通知は `hooks/lib/common.sh` の `send_embed` が生成する共通の embed フォーマットで送られます。各 hook が渡すのはタイトル・詳細・色だけです。リポジトリ名は origin の URL から `owner/repo` 形式で取得し、リモートが取得できない場合のみプロジェクトディレクトリ名を使います。

```
┌─────────────────────────────────┐
│ ⬆️ push 完了                     │  ← タイトル（絵文字 + イベント名）
│ リモートへ push しました。         │  ← 本文（イベントごとの詳細）
│                                 │
│ リポジトリ         ブランチ  セッション │  ← 共通フィールド
│ owner/my-repo    main     abc12345 │
│ 2026-07-19 14:00                │  ← タイムスタンプ
└─────────────────────────────────┘
```

| パターン | タイトル | 色 | 本文の詳細 |
| --- | --- | --- | --- |
| PR 作成 | 🔀 PR 作成 | 紫 | PR の URL（取得できた場合） |
| コミット (Fix) | 🔧 コミット (Fix) | 黄 | 直近のコミットメッセージ |
| push | ⬆️ push 完了 | 青 | なし |
| タスク完了 | ✅ タスク完了 | 緑 | なし |

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
