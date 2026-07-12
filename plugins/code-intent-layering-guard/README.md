# code-intent-layering-guard

プログラミング言語ファイルを編集する前に、`code-intent-layering` スキルが読み込まれていることを要求する Claude Code hook プラグインです。

## 動作

d-market-typescript の `typescript-rules-plugin` と同じマーカーファイル方式のスキルゲートです。

- **記録（PostToolUse: `Read` / `Skill`）** — `record-skill-loaded.sh` が、`Skill` ツールでの `code-intent-layering` 発火、または `skills/code-intent-layering/SKILL.md` の `Read` を検知し、`.plugin/skill-fired/<session_id>/code-intent-layering` にマーカーファイルを作成します。
- **ゲート（PreToolUse: `Edit` / `MultiEdit` / `Write`）** — `ensure-skill-loaded.sh` が、対象がプログラミング言語ファイルの場合に `.plugin/` 内のマーカーファイルの存在を確認します。存在しなければ編集を deny し、先にスキルを読み込むよう促します。

マーカーはセッションごとに分かれるため、新しいセッションでは再度スキルの読み込みが必要です。

## セットアップ

1. このプラグインを Claude Code のプラグインとして有効化してください。
2. マーカー置き場の `.plugin/` は Git 管理不要のため、リポジトリの `.gitignore` に追加してください。

```gitignore
.plugin/
```
