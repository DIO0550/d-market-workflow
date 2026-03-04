---
name: setup
description: compact後に自動再読み込みするドキュメントの一覧を設定する（docs-list.txt の作成・編集）
disable-model-invocation: true
allowed-tools: Read, Glob, Write, Edit, Bash, AskUserQuestion
---

# post-compact-docs-loader セットアップ

compact（コンテキスト圧縮）完了後にAIが自動で再読み込みするドキュメントファイルの一覧を設定する。
設定内容は `plugins/post-compact-docs-loader/docs-list.txt` に保存される。

## 前提情報

- このプラグインは compact 完了後の `SessionStart` hook で `load-docs.sh` を実行する
- `load-docs.sh` は `docs-list.txt` に記載されたファイルパスを読み取り、AIに Read ツールでの再読み込みを指示する
- 相対パスはプロジェクトルート（`$CLAUDE_PROJECT_DIR`）を基準に解決される
- 絶対パスはそのまま使用される

## 手順

### ステップ1: 既存設定の確認

`plugins/post-compact-docs-loader/docs-list.txt` を Read で読み取る。

- コメント行（`#` で始まる行）と空行を除いた実パスの一覧を把握する
- 既にエントリがある場合は、現在の設定内容をユーザーに提示し、AskUserQuestion で「追加・変更するか、最初から設定し直すか」を確認する
- エントリが空の場合はそのままステップ2に進む

### ステップ2: プロジェクト内のドキュメント探索

以下の Glob パターンでプロジェクト内のドキュメント候補を探索する:

```
CLAUDE.md
**/CLAUDE.md
docs/**/*.md
*.md
```

**除外すべきパス:**
- `node_modules/` 配下
- `.git/` 配下
- `plugins/` 配下（プラグイン自身の README 等は対象外）
- その他のビルド成果物ディレクトリ（`dist/`, `build/` 等）

探索結果が 0 件の場合は、ユーザーに「ドキュメントファイルが見つかりませんでした。手動でパスを入力しますか？」と確認する。

### ステップ3: ユーザーへの提示と選択

見つかったファイルをディレクトリ別にグループ化し、番号付きリストで提示する:

```
compact後に再読み込みするドキュメントを選んでください:

[プロジェクトルート]
  1. CLAUDE.md
  2. README.md

[docs/]
  3. docs/architecture.md
  4. docs/api-spec.md
```

- AskUserQuestion を使い、番号をカンマ区切りで選択してもらう（例: 1,3,4）
- 追加で手動入力したいパスがあれば、あわせて受け付ける
- ステップ1で既存エントリがあり「追加」を選んだ場合は、既存エントリも保持する

### ステップ4: docs-list.txt への書き込み

選択されたファイルを `plugins/post-compact-docs-loader/docs-list.txt` に Write ツールで書き込む。

フォーマット:
```
# compact後に再読み込みするドキュメント
CLAUDE.md
docs/architecture.md
docs/api-spec.md
```

- パスはプロジェクトルートからの相対パスで記述する（先頭に `/` や `./` をつけない）
- ステップ1で「追加」を選んだ場合は既存エントリと統合し、重複を除去する

### ステップ5: hook スクリプトの実行権限確認

Bash で以下を実行する:

```bash
ls -l plugins/post-compact-docs-loader/hooks/load-docs.sh
```

実行権限（`x`）がない場合は以下を実行:

```bash
chmod +x plugins/post-compact-docs-loader/hooks/load-docs.sh
```

### ステップ6: 検証と完了報告

書き込んだ `docs-list.txt` を Read で再読み込みし、内容が正しいことを確認する。

以下の形式で完了報告する:

```
セットアップが完了しました。

登録されたドキュメント:
- CLAUDE.md
- docs/architecture.md

compact が実行されると、これらのファイルが自動的に再読み込みされます。
設定を変更したい場合は、再度このスキルを実行するか、
plugins/post-compact-docs-loader/docs-list.txt を直接編集してください。
```
