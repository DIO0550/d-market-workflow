---
name: setup
description: Discord 通知の設定を行う（環境変数の設定状況の確認・export スニペットの提示・テスト通知）
disable-model-invocation: true
allowed-tools: Read, Bash, AskUserQuestion
---

# discord-notifier セットアップ

PR 作成・コミット・push・タスク完了を Discord に通知するための環境変数の設定を案内する。
設定はすべて環境変数で行い、このスキルはファイルへの書き込みを行わない。

## 前提情報

- hook スクリプト（`notify-discord.sh`）は以下の環境変数を参照する:
  - `DISCORD_WEBHOOK_URL` — 通知先の Webhook URL（必須。未設定なら hook は何もせず正常終了する）
  - `DISCORD_NOTIFY_ENABLED` — `false` / `0` / `no` / `off` で一時的に通知を停止（既定: 有効）
  - `DISCORD_NOTIFY_EVENTS` — 通知するイベントのカンマ区切りリスト（既定: `pr,commit,push,stop`）
- Webhook URL は秘密情報のため、リポジトリ管理下のファイルには決して書き込まない。表示する際も末尾 8 文字以外はマスクする

## 手順

### ステップ1: 現在の設定状況の確認

Bash で環境変数の設定状況を確認する（URL の値そのものは表示しない）:

```bash
bash -c 'u="${DISCORD_WEBHOOK_URL:-}"; if [ -n "$u" ]; then echo "DISCORD_WEBHOOK_URL: 設定済み (...${u: -8})"; else echo "DISCORD_WEBHOOK_URL: 未設定"; fi; echo "DISCORD_NOTIFY_ENABLED: ${DISCORD_NOTIFY_ENABLED:-（未設定: 有効扱い）}"; echo "DISCORD_NOTIFY_EVENTS: ${DISCORD_NOTIFY_EVENTS:-（未設定: pr,commit,push,stop）}"'
```

結果をユーザーに提示する。すべて希望通りに設定済みならステップ4（テスト通知）へ進んでよいか確認する。

### ステップ2: Webhook URL の準備の案内

`DISCORD_WEBHOOK_URL` が未設定の場合、取得方法を案内する:

1. Discord の通知先チャンネルがあるサーバーで「サーバー設定 → 連携サービス → ウェブフック → 新しいウェブフック」を開く
2. 通知先チャンネルを選び「ウェブフック URL をコピー」で URL を取得する

URL 自体をチャットに貼ってもらう必要はない（秘密情報のため、ユーザー自身のシェルで設定してもらう）。

### ステップ3: 通知イベントの選択と export スニペットの提示

AskUserQuestion（multiSelect）で通知するイベントを選んでもらう:

| 選択肢 | 値 |
| --- | --- |
| PR 作成 | `pr` |
| コミット (Fix) | `commit` |
| push | `push` |
| タスク完了 | `stop` |

選択結果をもとに、シェルの設定ファイル（`~/.bashrc` / `~/.zshrc` 等）に追記する export スニペットを提示する:

```bash
export DISCORD_WEBHOOK_URL="<コピーした Webhook URL>"
export DISCORD_NOTIFY_EVENTS="pr,stop"   # 全イベントの場合はこの行ごと不要
```

- 全イベントが選ばれた場合は `DISCORD_NOTIFY_EVENTS` の行は不要（既定値のため）と伝える
- 追記後、新しいシェルを開くか `source ~/.bashrc` 等で反映が必要なことを伝える
- ユーザーの設定作業が終わるのを待ってからステップ4へ進む

### ステップ4: テスト通知

AskUserQuestion で「テスト通知を送りますか？」と確認し、希望された場合は Bash で実行する:

```bash
bash -c '[ -n "${DISCORD_WEBHOOK_URL:-}" ] || { echo "DISCORD_WEBHOOK_URL が未設定です"; exit 1; }; curl -sS --max-time 5 -H "Content-Type: application/json" -d "{\"content\":\"discord-notifier のセットアップが完了しました 🎉\"}" "$DISCORD_WEBHOOK_URL"'
```

- 「未設定です」と出た場合: このセッションに環境変数が反映されていない。シェルで設定したばかりの変数は既存の Claude Code セッションには反映されないため、新しいセッションで確認するよう案内する
- 送信に失敗した場合はエラー内容を提示し、URL の再確認を促す

### ステップ5: 完了報告

以下の形式で完了報告する:

```
セットアップが完了しました。

- DISCORD_WEBHOOK_URL: 設定済み
- 通知イベント: pr, stop

一時的に通知を止めたい場合は DISCORD_NOTIFY_ENABLED=false を設定してください。
環境変数を変更した場合は、新しいセッションから反映されます。
```
