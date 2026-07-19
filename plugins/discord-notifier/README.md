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

すべての通知は `hooks/lib/common.sh` の `send_embed` が生成する共通の embed フォーマットで送られます。各 hook が渡すのはタイトル・詳細・色だけです。

```
┌─────────────────────────────────┐
│ ⬆️ push 完了                     │  ← タイトル（絵文字 + イベント名）
│ リモートへ push しました。         │  ← 本文（イベントごとの詳細）
│                                 │
│ リポジトリ    ブランチ   セッション │  ← 共通フィールド
│ my-repo      main      abc12345 │
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

## devcontainer での利用

ホスト側の環境変数をそのままコンテナに引き継ぐには、ホストで永続化した上で `devcontainer.json` の `${localEnv:...}` を使います。

1. ホスト側で環境変数を OS レベルで永続化する。シェルの設定ファイル（`~/.bashrc` 等）はそのシェルから起動したプロセスにしか効かないため、GUI からエディタを起動する場合は次の方法で登録する:

| ホスト OS | 方法 |
| --- | --- |
| Windows | `setx DISCORD_WEBHOOK_URL "https://discord.com/api/webhooks/xxxx/yyyy"`（または「システムのプロパティ → 環境変数」。反映にはエディタの再起動が必要） |
| macOS | ログイン時に `launchctl setenv DISCORD_WEBHOOK_URL ...` を実行する LaunchAgent を登録する（または常にターミナルから `code .` で起動する運用にして `~/.zshrc` に export） |
| Linux | `~/.config/environment.d/discord-notifier.conf` に `DISCORD_WEBHOOK_URL=https://...` を記載（systemd ユーザーセッション。再ログインで反映） |

2. `devcontainer.json` でホストの値をコンテナへ引き継ぐ:

```json
{
  "remoteEnv": {
    "DISCORD_WEBHOOK_URL": "${localEnv:DISCORD_WEBHOOK_URL}"
  }
}
```

- `remoteEnv` はエディタ経由のプロセス（統合ターミナルやそこから起動する Claude Code）に反映され、設定変更はウィンドウのリロードだけで反映されます。コンテナ内のすべてのプロセスに必要な場合は `containerEnv`（反映にはコンテナの Rebuild が必要）を使ってください
- `${localEnv:...}` はエディタのプロセスから見える環境変数を参照します。上の表のように OS レベルで登録してあれば、GUI から起動しても届きます。シェルの設定ファイルにしか書いていない場合は、そのシェルのターミナルから `code .` などで起動しない限り値が空になります
- 値そのものを `devcontainer.json` に直接書かないでください（コミットされて Webhook URL が漏えいします）

## 依存

- `jq`
- `curl`
