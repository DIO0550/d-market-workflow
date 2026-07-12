# code-intent-layering-guard

プログラミング言語ファイルを編集する前に、`skills/code-intent-layering/SKILL.md` が読み込まれていることを要求する Claude Code hook プラグインです。

## 動作

- `Edit`、`MultiEdit`、`Write` の実行前に対象ファイルを確認します。
- 対象がプログラミング言語ファイルの場合、会話 transcript に `skills/code-intent-layering/SKILL.md` を `Read` した記録があるか確認します。
- 読み込み記録がなければ hook がブロックし、先に Skill を読むよう促します。

## セットアップ

このプラグインを `plugins/` 配下に置き、Claude Code のプラグインとして有効化してください。
