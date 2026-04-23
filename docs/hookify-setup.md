# hookify プラグインの導入ガイド

Phase 4 の ROADMAP 項目「hookify 連携検証 (会話履歴から hook ルールを自動生成)」の導入手順と本プロジェクトでの想定活用シナリオをまとめます。

## hookify とは

Anthropic 公式の Claude Code プラグインで、**会話履歴や自然言語の説明から hook ルール (実行ブロック / 警告ルール) を自動生成** します。

主要機能:

- **`/hookify` (引数なし)**: 直近の会話から「ユーザーが避けたい挙動」を検出し、それをブロックする hook ルールを自動生成
- **`/hookify <自然言語による挙動記述>`**: 「`rm -rf` を警告したい」等のテキスト指示から hook ルール (regex マッチ / YAML frontmatter 付きマークダウン設定) を自動生成
- **即座に有効**: 再起動不要で hook ルールが `.claude/rules/` 等に配置され有効化される

参考: <https://github.com/anthropics/claude-code/tree/main/plugins/hookify>

## 導入手順

### 1. プラグイン有効化

user settings (`~/.claude/settings.json`) の `enabledPlugins` に追加:

```json
{
  "enabledPlugins": {
    "skill-creator@claude-plugins-official": true,
    "hookify@claude-plugins-official": true
  }
}
```

または Claude Code CLI から `/plugin install hookify` 相当のコマンド (プラグイン管理 UI 経由、詳細は公式ドキュメント参照)。

### 2. 動作確認

```
/hookify
```

プラグインが有効なら「最近の会話から hook ルール候補を提示します」等の応答が返る。

## 本プロジェクトでの活用シナリオ

Phase 3 / Phase 4 で手動実装した hook (pre-tool-use-tdd / post-tool-use-auto-test / stop-verify-before-completion / instructions-loaded-context / load-session-skills) の設計は hookify で生成すると:

### シナリオ 1: 学習したアンチパターンから hook 生成

iter-3 / iter-4 / iter-5 で発生した問題の会話ログ (例: 並列 developer の git index 競合 / merge 時 __pycache__ 競合 / Isolate の mv による plan.md 消失) から、自然に hook ルールを派生させる:

```
/hookify 並列 developer 実行時に git worktree 共有 index へ commit しようとしたら警告して
```

→ `.claude/rules/` にブロックルールが自動生成され、Phase 5 並列化時の事故を予防。

### シナリオ 2: skill / workflow 規約の物理化

workflow.md / SKILL.md に規定している規約 (例:「writing-plan skill は main 側でのみ起動、worktree 内起動禁止」) を hookify で hook 化:

```
/hookify worktree 内 (パスに /worktrees/ を含む時) に writing-plan skill を起動したら拒否
```

→ skill SKILL.md 内のアンチパターン記述を、hookify で実効性のある hook に昇格。

### シナリオ 3: learn skill の Try 提案の自動 hook 化

iter-3/4/5 で learn skill が生成した「Try パッチ案」のうち、hook 化可能なもの (「XX を禁止すべき」「YY を警告すべき」形式) を hookify で一括生成:

```
/hookify learn.md の Try §5.1 を読み、該当する挙動を hook 化して
```

→ ワークフローの自己改善ループが、skill → hookify → hook という自動化経路で完結する可能性。

## 本プロジェクトの現状 (2026-04-23)

- **未導入**: 現時点では hookify プラグインを有効化していない
- **手動で同等の効果を達成**: Phase 4 バッチ 1-3 で重要 hook を手動実装済 (TDD 強制 / Verify 確認 / 自動テスト / InstructionsLoaded context)
- **Phase 6 で本格活用検討**: 本プロジェクトが多くの learn.md を蓄積した段階 (10-20 Spec 完走後) で、蓄積されたパターンを hookify で一括 hook 化する用途が本命

## 注意事項

- hookify が生成する hook は regex マッチング等の軽量ロジック。複雑な条件判定 (言語別テストファイル命名 / frontmatter verdict パース 等) には本プロジェクトで手動実装した hook のような詳細制御が必要
- hookify で生成されたルールは `.claude/rules/` 配下に配置されるため、本プロジェクトで settings.json 経由で管理している hook との両立に注意
- 有効化前に `.claude/rules/` のバックアップ + 動作試験環境 (別 branch / worktree) で検証することを推奨

## ROADMAP との対応

- Phase 4 残項目「hookify 連携検証」の実装方針確定 (本ドキュメント) により、Phase 4 の設計フェーズは完了
- 実際の hookify 有効化は Phase 6 のドッグフーディング段階で、蓄積した learn.md が十分な量になってから着手
