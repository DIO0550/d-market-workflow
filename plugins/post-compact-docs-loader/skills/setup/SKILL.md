---
name: setup
description: post-compact-docs-loader プラグインのセットアップを行う。compact後に再読み込みするドキュメントファイルを設定する。
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, AskUserQuestion
---

# post-compact-docs-loader セットアップ

このスキルは、compact（コンテキスト圧縮）完了後にAIが自動で再読み込みするドキュメントファイルの一覧を設定します。

## 手順

1. まず、プロジェクト内のドキュメント系ファイル（`.md`, `CLAUDE.md`, `docs/` 配下など）をGlobで探索する
2. 見つかったファイル一覧をユーザーに提示し、compact後に再読み込みさせたいファイルを選んでもらう
3. 選択されたファイルを `docs-list.txt` に書き込む
4. hookスクリプトに実行権限があることを確認する
5. 設定完了を報告する

## 重要なルール

- `docs-list.txt` の場所: このスキルと同じプラグインディレクトリ内の `docs-list.txt`
  - パス: `plugins/post-compact-docs-loader/docs-list.txt`
- ファイルパスはプロジェクトルートからの相対パスで記述する
- `#` で始まる行はコメント
- 空行は無視される
- ユーザーが手動でパスを追加したい場合にも対応する
- hookスクリプトのパス: `plugins/post-compact-docs-loader/hooks/load-docs.sh`

## docs-list.txt のフォーマット例

```
# compact後に再読み込みするドキュメント
CLAUDE.md
docs/architecture.md
docs/api-spec.md
```
