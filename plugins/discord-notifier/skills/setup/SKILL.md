---
name: setup
description: Discord 通知の設定を行う（Webhook URL・通知イベント・ON/OFF を .plugin-workspace/discord-notifier/config に保存）
disable-model-invocation: true
allowed-tools: Read, Glob, Write, Edit, Bash, AskUserQuestion
---

# discord-notifier セットアップ

PR 作成・コミット・push・タスク完了を Discord に通知するための設定を行う。
設定内容はワークスペースの `.plugin-workspace/discord-notifier/config` に保存される。

## 前提情報

- hook スクリプト（`notify-discord.sh`）は次の優先順位で設定を解決する:
  1. 環境変数（`DISCORD_WEBHOOK_URL` / `DISCORD_NOTIFY_ENABLED` / `DISCORD_NOTIFY_EVENTS`）
  2. `${CLAUDE_PROJECT_DIR}/.plugin-workspace/discord-notifier/config`（`KEY=VALUE` 形式）
  3. 既定値（enabled: `true`、events: `pr,commit,push,stop`）
- Webhook URL は秘密情報のため、`.plugin-workspace/` は必ず Git 管理外にする
- URL が未設定の場合、hook は何もせず正常終了する（作業をブロックしない）

## 手順

### ステップ1: 既存設定の確認

`.plugin-workspace/discord-notifier/config` を Read で読み取る。

- ファイルが存在する場合は現在の設定を提示する。ただし **Webhook URL は末尾 8 文字以外を `*` でマスクして表示する**（例: `https://discord.com/api/webhooks/****...****abcd1234`）
- AskUserQuestion で「このまま使う / 一部変更する / 最初から設定し直す」を確認する
- ファイルが存在しない場合はそのままステップ2に進む

### ステップ2: Webhook URL の入力

ユーザーに Discord Webhook URL を確認する。

- 未取得の場合の案内: Discord の「サーバー設定 → 連携サービス → ウェブフック → 新しいウェブフック」で作成し、「ウェブフック URL をコピー」で取得できる
- AskUserQuestion（Other での自由入力）で URL を受け取る
- 入力された URL が `https://discord.com/api/webhooks/` または `https://discordapp.com/api/webhooks/` で始まることを確認する。形式が違う場合は再入力を促す

### ステップ3: 通知イベントの選択

AskUserQuestion（multiSelect）で通知するイベントを選んでもらう:

| 選択肢 | 保存値 |
| --- | --- |
| PR 作成 | `pr` |
| コミット (Fix) | `commit` |
| push | `push` |
| タスク完了 | `stop` |

- 既定はすべて選択（全イベント通知）
- 何も選ばれなかった場合は「通知するイベントがありません。全イベントを有効にしますか？」と確認する

### ステップ4: config への書き込み

Bash で `mkdir -p "${CLAUDE_PROJECT_DIR:-.}/.plugin-workspace/discord-notifier"` を実行してから、Write ツールで `config` を書き込む。

フォーマット（値はクォートなしの `KEY=VALUE`）:

```
# discord-notifier の設定（このファイルは Git 管理外にすること）
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/xxxx/yyyy
DISCORD_NOTIFY_ENABLED=true
DISCORD_NOTIFY_EVENTS=pr,commit,push,stop
```

### ステップ5: .gitignore の確認

Webhook URL の漏えいを防ぐため、リポジトリルートの `.gitignore` に `.plugin-workspace/` が含まれるか Read で確認する。

- 含まれていない場合は Edit で追記する
- `.gitignore` 自体が存在しない場合は `.plugin-workspace/` の 1 行で新規作成する
- 念のため Bash で `git check-ignore .plugin-workspace/discord-notifier/config` を実行し、無視されていること（exit 0）を確認する。無視されていない場合は原因を調べて解消するまで先に進まない

### ステップ6: テスト通知

AskUserQuestion で「テスト通知を送りますか？」と確認し、希望された場合は Bash で実行する:

```bash
bash -c 'source_url="$(sed -n "s/^DISCORD_WEBHOOK_URL=//p" "${CLAUDE_PROJECT_DIR:-.}/.plugin-workspace/discord-notifier/config" | tail -1)"; curl -sS --max-time 5 -H "Content-Type: application/json" -d "{\"content\":\"discord-notifier のセットアップが完了しました 🎉\"}" "$source_url"'
```

- 成功（レスポンスが空 or エラーなし）ならそのまま完了報告へ
- 失敗した場合はエラー内容を提示し、URL の再確認を促す

### ステップ7: 完了報告

以下の形式で完了報告する:

```
セットアップが完了しました。

- 設定ファイル: .plugin-workspace/discord-notifier/config（Git 管理外）
- 通知イベント: pr, commit, push, stop
- 通知: 有効

一時的に通知を止めたい場合は config の DISCORD_NOTIFY_ENABLED を false に
変更してください。設定を変え直す場合は再度このスキルを実行してください。
環境変数（DISCORD_WEBHOOK_URL 等）を設定している場合はそちらが優先されます。
```
