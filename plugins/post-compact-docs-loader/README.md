# post-compact-docs-loader

Compact（コンテキスト圧縮）完了後に、指定したドキュメントファイルをAIに再読み込みさせるClaude Code hookプラグイン。

## 課題

Claude Codeのcompact機能でコンテキストが圧縮されると、事前に読み込んでいたドキュメントの内容が失われることがあります。このプラグインは、compact後に自動で特定のドキュメントの再読み込みを指示します。

## セットアップ

1. このプラグインをプロジェクトの `plugins/` ディレクトリに配置
2. `docs-list.txt` に再読み込みさせたいファイルパスを記述
3. スクリプトに実行権限を付与:

```bash
chmod +x plugins/post-compact-docs-loader/hooks/load-docs.sh
```

## 設定

`docs-list.txt` に1行1ファイルパスで記述します。プロジェクトルートからの相対パス、または絶対パスが使えます。

```text
# アーキテクチャドキュメント
docs/architecture.md

# プロジェクト規約
CLAUDE.md

# API仕様
docs/api-spec.md
```

`#` で始まる行と空行は無視されます。

## 動作の仕組み

1. Claude Codeでcompactが実行される
2. compact後のセッション再開時に `SessionStart` (matcher: `compact`) が発火
3. `load-docs.sh` が `docs-list.txt` を読み取り、ファイル一覧をstdoutに出力
4. Claude Codeがその出力をコンテキストに注入し、AIが各ファイルをReadツールで再読み込み
