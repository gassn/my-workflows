---
name: learn
description: >
  ship ステージ完了後の振り返りを実施し、skill / hook / ワークフローの改善提案を
  生成する skill。本ワークフロー (docs/workflow.md) の Learn ステージを担います。
  spec-leader skill が ship ステージ完了後に自動起動します (結果ファイル verdict: shipped)。
  加えて「振り返って」「retrospective」「learn 実行」「<spec-name> の振り返り」等の
  明示フレーズでも起動します。
  出力は specs/archive/<spec-name>.learn.md。改善提案は対応する skill / hook /
  workflow.md への具体的パッチ案として記述します。
---

# Learn Skill

ship ステージ完了後の振り返りを実施し、skill / hook / ワークフローの改善提案を生成する skill です。本プロジェクトのワークフロー (`docs/workflow.md`) における Learn ステージを担います。

## 1. 役割と位置づけ

```
... → ship (verdict: shipped) → [learn (本 skill)] → 改善提案 → skill / hook / workflow.md 更新
```

1 Spec の完走サイクルを通して得られた学びを次サイクルに反映する、継続改善の入口です。単なる感想ではなく、**具体的な改善パッチ案** (skill の §追加 / hook の条件変更 / workflow.md の文言変更) を生成します。

## 2. 起動トリガー

### 2.1 自動起動

spec-leader skill の ship ステージ完了時 (`result.json` の `verdict: shipped`)。入力:

- `specs/<spec-name>.progress.json`
- `specs/<spec-name>.result.json`
- `specs/archive/<spec-name>.md` (ship で archive 移動済)
- `worktrees/<spec-name>/` は削除済のため参照不可 (必要ログは progress.md から抽出)

### 2.2 明示フレーズ

- 「振り返って」「retrospective」
- 「learn 実行」「<spec-name> の振り返り」

## 3. 振り返り観点

### 3.1 時間配分分析

progress.json の各ステージ `started_at` / `completed_at` から、ステージ別所要時間を算出:

- 想定より時間がかかったステージ
- やり直し (loop 発生) が多かったステージ
- スキップされたステージ / blocked が多かったステージ

### 3.2 品質ゲート突破率

- spec-review の verdict 変遷 (needs-fix / reject の回数)
- Code Review の verdict 変遷
- verification-before-completion の fail 回数

### 3.3 手戻り箇所

- Brainstorming → Spec Review → Spec 再書き換え の発生
- Plan → Implement → Code Review → Plan 追加 の発生
- 受け入れ基準の変更 (Spec Review 後の追加)

### 3.4 ツール / skill の過不足

- 途中で blocked になった下位 skill
- ユーザー手動介入が必要だった箇所 (自動化候補)
- 複数 Spec 間で共有できる資産の再発見

## 4. learn.md 出力仕様

パス: `specs/archive/<spec-name>.learn.md`

````markdown
---
spec: <spec-name>
learned: YYYY-MM-DD
shipped_at: YYYY-MM-DDTHH:MM:SSZ
total_duration_minutes: NNN
---

# Learn: <spec-name>

## 1. サマリ

1-3 文で今回のサイクルを要約。

## 2. 時間配分

| ステージ | 所要時間 | 備考 |
|---|---|---|
| Brainstorming | XX 分 | |
| Spec | XX 分 | |
| Spec Review | XX 分 | N 回 loop |
| Isolate | XX 分 | |
| Plan | XX 分 | |
| Implement | XX 分 | |
| Verify | XX 分 | |
| Code Review | XX 分 | N 回 loop |
| ship | XX 分 | |

## 3. うまくいったこと (Keep)

- 箇条書き 3-5 項目

## 4. 改善したいこと (Problem)

- 箇条書き 3-5 項目、各項目に具体的な原因

## 5. 改善提案 (Try)

具体的パッチ案として記述。対応する skill / hook / workflow.md の変更を明記。

### 5.1 <提案タイトル>

- **対象ファイル**: `skills/<skill-name>/SKILL.md`
- **変更内容**: §X に「〜を追加」「〜を削除」
- **期待効果**: 次サイクルで <問題> を削減

### 5.2 ...

## 6. 共有資産 / 再発見したパターン

- 他 Spec でも利用可能な抽象化
- 繰り返し発生した設計パターン

## 7. 次サイクルへの引き継ぎ事項

- 本 Spec の延長で発生する可能性のある追加 Spec
- 未解決事項のうち将来対応予定のもの
````

## 5. 改善提案の具体性ガイドライン

漠然とした提案 (「もっと効率的にすべき」) は書きません。以下の 3 要素を必ず含めます。

1. **対象**: どのファイル / 章 / 行を変えるか
2. **内容**: 何を追加 / 削除 / 変更するか
3. **効果**: どの問題がどう減るか

例:

- 悪い: 「Spec Review を改善すべき」
- 良い: 「`spec-review` skill §4.1 完全性観点に『TBD カウント閾値超過で Major 扱い』を追加。効果: TBD 未解消で後続ステージが blocked する事例 (2 回発生) を減らす」

## 6. 提案の適用フロー

本 skill は **提案を生成するまで** が責務。実際の skill / hook / workflow.md への適用は:

1. learn.md を main agent + ユーザーで確認
2. 採用する提案を選別
3. 該当ファイルに手動 or 別 skill (`skill-creator` 等) で反映
4. 次サイクルでの検証

本 skill が勝手に skill / hook を書き換えてはいけません (レビューなしの変更は混乱源)。

## 7. 複数 Spec サイクル後のメタ分析

複数 Spec で learn.md が蓄積された後 (10-20 サイクル目安)、以下を検討:

- 繰り返し同じ改善提案が出る場合 → 優先度最高で実施
- 特定ステージで常に loop が発生 → 該当 skill の根本改修が必要
- 特定の workflow 設計が常にボトルネック → workflow.md 改訂を検討

Phase 6 の「ワークフロー全体の統合改善ループ」は本 skill の集計を主要入力とします。

## 8. 失敗時の対応

- progress.json / result.json が不完全 → 読める範囲でのみ振り返り、不足を明示
- データが乏しく改善提案が出せない → 「次回は <計測項目> を記録してほしい」と次サイクルへの要望として書く
- skill / hook の改修範囲が広すぎる → 小さく段階的な提案に分解

## 9. アンチパターン

- ❌ 感想だけで具体的パッチ案を書かない
- ❌ 「時間がかかった」などの表面的問題で止まる (原因まで掘り下げない)
- ❌ 本 skill が勝手に skill / hook を書き換える (提案に留める)
- ❌ 他 Spec との比較を無視して個別 Spec だけで完結する
- ❌ learn.md を生成せずに「振り返り済」と報告する
- ❌ 成功事例 (Keep) を省略する (繰り返すべきパターンの消失)
