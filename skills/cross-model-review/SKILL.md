---
name: cross-model-review
description: >
  Claude 以外の独立モデル (Codex / GPT 等) に Code Review を依頼する skill。
  本ワークフロー (docs/workflow.md) の Code Review ステージの一部として、
  code-reviewer / security-reviewer と並列に実行されます。
  spec-leader skill が Code Review ステージで自動起動します。
  加えて「cross-model-review 起動」「Codex にレビューさせて」「他モデルレビューして」等の
  明示フレーズでも起動します。
  同一モデルによるレビューでは見落とされがちなバイアス / 思考パターンの偏りを
  検出することが目的です。claude-scrum-team の cross-model-review 思想を踏襲します。
---

# Cross-Model Review Skill

Claude とは独立したモデル (Codex / GPT / その他) に Code Review を依頼する skill です。本プロジェクトのワークフロー (`docs/workflow.md`) における Code Review ステージの一部として、`code-reviewer` / `security-reviewer` と並列に実行されます。

## 1. 役割と位置づけ

```
... → Code Review ステージ
          ├─ code-reviewer (Claude)
          ├─ security-reviewer (Claude)
          └─ [cross-model-review (本 skill、別モデル経由)]
```

同一モデル内レビューで陥りがちな**思考パターンの偏り / 盲点 / 同じ誤りを見逃す傾向** を、独立モデルの視点で検出することが本 skill の目的です。

## 2. 起動トリガー

### 2.1 自動起動

spec-leader が Code Review ステージに入った際、`code-reviewer` / `security-reviewer` と同時に本 skill を起動します。

### 2.2 明示フレーズ

- 「cross-model-review 起動」「Codex にレビューさせて」「他モデルレビューして」
- 「独立モデルで見直して」

## 3. 対象モデルの選定

Phase 3 時点で対象とする外部モデル候補:

- **OpenAI Codex / GPT-5** (CLI or API 経由)
- **Gemini** (Google AI Studio 経由)
- **Cursor / Aider** 等の別エージェント環境

呼び出し方法はプロジェクトの設定 (環境変数 / CLI 利用可能性) に依存します。Phase 3 では「呼び出し方法のドラフト」を SKILL.md に記述し、具体的な実装は利用環境に合わせて随時詳細化します。

## 4. レビュー依頼のフォーマット

### 4.1 渡す情報

- Spec ファイル (`specs/<spec-name>.md`)
- Plan ファイル (`plans/<spec-name>.md`)
- 差分 (`git diff main...spec/<spec-name>`)
- 既存の code-reviewer / security-reviewer のレビュー結果 (コンセンサス形成目的)

### 4.2 レビュー観点の指示

```
【タスク】
以下の実装を独立した視点で Code Review してください。

【観点】
1. 設計・可読性 (他 reviewer の観点と重複して構いません、独立判断を重視)
2. 見落とし可能性 (バグ / エッジケース / セキュリティホール / パフォーマンス)
3. 他 reviewer の指摘への反証 or 補強

【出力形式】
- verdict (pass / needs-fix / reject)
- Critical / Major / Minor の分類
- 他 reviewer との相違点 (あれば特に強調)
```

### 4.3 出力の保存

`worktrees/<spec-name>/reviews/cross-model.md` に保存。他 reviewer の結果と同じ形式。

## 5. 独立性の担保

### 5.1 バイアス防止

- code-reviewer / security-reviewer の結果を **レビュー後** に参照させる (独自判断を先に取る)
- 「同意」だけで終わる結果にならないよう、相違点を必ず問う

### 5.2 モデル固有の強み活用

- Codex 系: コード生成能力 (修正提案の質)
- GPT-5: 抽象推論 / 長文理解
- Gemini: コンテキスト長 / multi-modal

依頼時にモデル固有の強みを意識した観点を追加することを推奨。

## 6. 他 reviewer との統合 (receiving-code-review へ引き継ぎ)

本 skill の結果 (`cross-model.md`) は `receiving-code-review` skill に集約されます。他 reviewer との verdict 統合ルール:

| 状況 | 統合判定 |
|---|---|
| 全 reviewer (code / security / cross-model) pass | pass |
| cross-model のみ needs-fix、他 pass | needs-fix (cross-model の独立視点を尊重) |
| cross-model のみ reject、他 pass | reject に引き上げず、**ユーザー判断** (Claude 内で見えていない問題の可能性大) |

## 7. Phase 3 時点の実装制約

Phase 3 では外部モデルの呼び出し基盤が未整備です。以下で運用します。

- **Phase 3 初期**: ユーザーに手動で Codex 等に依頼する指示を提示 (skill は依頼文テンプレートを生成するに留める)
- **Phase 3 後期**: MCP / Agent SDK 経由で外部モデル呼び出しを自動化 (設定次第)
- **Phase 4 以降**: hook 連動で自動呼び出し

本 skill のインタフェース (入力: 差分等、出力: cross-model.md) は Phase 3 時点で固定、内部実装は段階的に進化。

## 8. 失敗時の対応

- 外部モデルにアクセスできない → 手動依頼テンプレートを提示、cross-model.md は placeholder を生成
- 結果が著しく異質 (他 reviewer と真逆) → 両方を ユーザーに提示して判断
- レビュー結果が返ってこない (タイムアウト) → spec-leader に `failed` を返して全停止

## 9. アンチパターン

- ❌ Claude 内部の別エージェントを使って「独立レビュー」と称する (独立性が担保できない)
- ❌ 他 reviewer の結果を先に見せてバイアスを与える
- ❌ cross-model の reject を他 reviewer が pass なら無視する
- ❌ 呼び出し先モデルを明示せず曖昧にレビューする (再現性喪失)
- ❌ cross-model.md の生成を省略して「cross-model review 済」と報告する
