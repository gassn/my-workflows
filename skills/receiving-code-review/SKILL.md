---
name: receiving-code-review
description: >
  Code Review ステージで差戻し (needs-fix / reject) となった際、レビュー指摘を
  読み取って実装に反映する skill。本ワークフロー (docs/workflow.md) の
  Code Review 後の対応フローを担います。
  spec-leader skill が Code Review verdict 不一致時に自動起動します。
  加えて「レビュー指摘を反映して」「review コメント対応」「receiving-code-review 起動」等の
  明示フレーズでも起動します。
  対応完了後は Implement → Verify → Code Review のループを再実行します
  (最大 3 回、超過時は循環防止で停止)。superpowers の receiving-review skill 思想を踏襲します。
---

# Receiving Code Review Skill

Code Review ステージで差戻しとなった際、レビュー指摘をコード修正に反映する skill です。本プロジェクトのワークフロー (`docs/workflow.md`) における Code Review 後の対応フローを担います。

## 1. 役割と位置づけ

```
... → Code Review (reviewers: needs-fix / reject) → [receiving-code-review (本 skill)]
         → Implement (修正) → Verify → Code Review (再) → pass なら ship
```

複数 reviewer (code / security / cross-model) からの指摘を優先度順に整理し、Plan にタスク追加してから developer agent に修正を指示します。

## 2. 起動トリガー

### 2.1 自動起動

spec-leader が Code Review ステージで少なくとも 1 reviewer の verdict が `needs-fix` または `reject` を検出した直後。入力:

- `worktrees/<spec-name>/reviews/code.md`
- `worktrees/<spec-name>/reviews/security.md`
- `worktrees/<spec-name>/reviews/cross-model.md`
- (該当するもののみ存在)

### 2.2 明示フレーズ

- 「レビュー指摘を反映して」「review コメント対応」
- 「receiving-code-review 起動」「Code Review の指摘を直して」

## 3. 処理手順

### 3.1 指摘の集約

各 reviewer の指摘を 1 つのリストに集約します。

- **ID 規則**: `CR-<reviewer>-<severity>-<番号>` (例: `CR-code-Critical-1`, `CR-security-Major-2`)
- **優先度**: Critical → Major → Minor の順
- **重複排除**: 複数 reviewer が同一箇所を指摘している場合、統合してまとめる

集約結果を `worktrees/<spec-name>/reviews/consolidated.md` に出力。

### 3.2 Plan への追加

Plan (`plans/<spec-name>.md`) §5.1 タスクリストに修正タスクを追加:

```markdown
### 5.X レビュー指摘対応タスク (iteration-N)

- [ ] T-fix-N-1: CR-code-Critical-1 の対応 (<要約>)
  - 該当ファイル: <path>
  - 修正内容: <要約>
  - 追加テスト: <必要なら>
  - files_touched: [<path>, ...]  # writing-plan §5.1.1 準拠、並列判定用
```

#### 3.2.1 Plan frontmatter 更新ルール (2026-04-22 iter-3 改修)

追加タスクを記述するだけでなく、Plan frontmatter に以下を必ず更新してください。iteration トレーサビリティを skill 横断で担保するため:

```yaml
status: plan-revised         # plan-complete から変更
revised: YYYY-MM-DD          # 本日付を追加
review_iteration: N          # 何回目の review 反映か (1 始まり)
```

#### 3.2.2 Plan §2 アーキテクチャ記述の追従 (2026-04-22 iter-3 改修)

T-fix タスクが**実装配置の変更** (ファイル新設 / 削除 / モジュール分割再編 等) を伴う場合、Plan §2 アーキテクチャ記述との乖離が発生すると code-reviewer が Plan 実装乖離 (code-Major 相当) を再指摘する原因になります。

これを防ぐため、以下のいずれかを**必ず T-fix タスクとペアで実施**:

- **(a) T-fix タスク本体で §2 も更新**: T-fix タスクの修正内容に「Plan §2 アーキテクチャ記述の追従更新」を含める (推奨、1 タスクで完結)
- **(b) 専用 T-fix-docs タスクを追加**: 実装変更が広範で §2 更新も独立タスク化が妥当な場合、`T-fix-N-M: Plan §2 更新 (<変更概要>)` を追加

判定基準:

| 実装変更の種類 | §2 更新の必要性 | 推奨方式 |
|---|---|---|
| 同一ファイル内の修正 (内部関数・テスト追記等) | 不要 | 従来通り |
| 既存ファイルの小改修 (関数シグネチャ変更・小規模抽出) | 基本不要、ただし API 設計 §4 の変更を伴えば更新 | (a) 推奨 |
| 新規ファイル / モジュール追加 / 既存ファイル削除 | **必要** | (a) 推奨 |
| モジュール分割 / 配置再編 | **必要** | (b) 推奨 (実装と同 commit に収めない) |

この運用により、code-reviewer の Major-2 型 (Plan 実装乖離) 指摘が次 iteration で再発する確率を大幅に低減します。

### 3.3 Implement への引き継ぎ

tdd-driver skill と developer agent を起動し、追加タスクを順次処理:

- Critical 指摘: 必ず対応 (reject の主因を解消)
- Major 指摘: 原則対応 (後回し判断は reviewer に相談)
- Minor 指摘: 工数と効用を比較して判断、対応しない場合は理由を `consolidated.md` に記載

### 3.4 再 Verify / 再 Code Review

- Implement 完了後 verification-before-completion を実行
- 通過したら Code Review ステージへ再度遷移

## 4. 循環防止

同一 Spec で Implement → Verify → Code Review のループが 3 回を超えた場合、**自動再実行を停止** してユーザーに相談します。

- 設計レベルの問題 → Spec Review への差戻し
- Spec 自体の曖昧さ → writing-spec レビュー指摘対応モード
- Plan の構成問題 → writing-plan 再起動

## 5. 複数 reviewer の verdict 統合ルール

| reviewers の verdict | 統合判定 |
|---|---|
| 全員 pass | pass (本 skill 起動せず、ship に進む) |
| 1 人以上 needs-fix、reject なし | needs-fix (本 skill が Major/Critical を反映) |
| 1 人以上 reject | reject (本 skill が Critical を最優先で反映) |

統合判定は `consolidated.md` の冒頭に記録。

## 6. spec-review skill との差別化

| 項目 | spec-review | receiving-code-review |
|---|---|---|
| 対象 | Spec ファイル (spec.md) | 実装コード (Spec に沿った結果) |
| レビュー実施者 | AI 3 観点 (完全性 / 実現可能性 / 整合性) | reviewer agents 3 種 (code / security / cross-model) |
| 出力 | spec.md への修正指示 | Plan へのタスク追加 + コード修正 |
| 対応先 | writing-spec レビュー指摘対応モード | Implement 再実行ループ |

## 7. 失敗時の対応

- 指摘が曖昧でタスク化できない → reviewer に確認を要求 (複数モデル経由)
- 指摘同士が矛盾 → ユーザーに優先度判断を委ねる
- 修正が広範すぎる → Spec / Plan に戻して再設計提案

## 8. アンチパターン

- ❌ reject 指摘を無視して ship する
- ❌ reviewer 指摘を Plan に追加せず直接コード修正する (トレーサビリティ喪失)
- ❌ Critical を Minor 扱いに格下げして省略する
- ❌ 循環防止を超えて自動再実行を続ける
- ❌ consolidated.md を生成せずに個別 review.md だけで進める (後続の verification 困難)
- ❌ 修正後に verification-before-completion を省略する
