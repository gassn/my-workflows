# Phase 3 ワークフロー skill 実装完了レポート

- **完了日**: 2026-04-20
- **対象**: `ROADMAP.md` Phase 3 の 11 skill + 設計制約 3 項目
- **補足**: agent (8 種) の実装は Phase 5 で対応予定のため本 Phase の対象外

## 1. サマリ

本プロジェクトの中核ワークフロー (`docs/workflow.md`) で定義した 9 ステージ (Brainstorming → DAG 構築 → Spec → Spec Review → Isolate → Plan → Implement → Verify → Code Review → ship → Learn) を担う **11 skill** を実装完了しました。各 skill は対応するワークフローステージを担当し、自動起動連携で Brainstorming から Learn まで一気通貫で進行できる体制を整えました。

Phase 5 で追加する orchestrator との接続インタフェース (spec-leader の入力 spec_path / 出力 progress.json + result.json) も Phase 3 時点で確定させており、Phase 5 で spec-leader 本体の改修は不要です。

## 2. 実装 skill 一覧

| # | Skill | 担当ステージ | 役割概要 | 起動トリガー |
|---|---|---|---|---|
| 1 | `brainstorming` | Brainstorming | Spec 前の要件深掘り (起点)、Spec 分割提案、コードベース精査 | 明示フレーズ (「要件まとめたい」「新しい機能を」等) |
| 2 | `spec-dag-builder` | DAG 構築 | 複数 Spec の依存関係解析、DAG 図生成 (段階的アップデート方式) | 明示フレーズ (「DAG 作って」「依存関係整理」等) |
| 3 | `writing-spec` | Spec | Brainstorming ノートから 7 章 Spec ファイル生成、archive 移動 | brainstorming 完了後自動 + 明示フレーズ |
| 4 | `spec-review` | Spec Review | Spec の完全性 / 実現可能性 / 整合性 3 観点レビュー、verdict (pass / needs-fix / reject) | writing-spec 完了後自動 + 明示フレーズ |
| 5 | `spec-leader` | Isolate〜ship | 6 ステージ遷移制御、進捗 / 結果ファイル生成、Phase 5 orchestrator 連携 I/F 確定 | spec-review verdict: pass 後自動 + 明示フレーズ |
| 6 | `writing-plan` | Plan | Spec → 技術設計 + チェックボックス形式タスク分解 | spec-leader (Isolate 完了後) 自動 + 明示フレーズ |
| 7 | `tdd-driver` | Implement | TDD サイクル (Red → Green → Refactor) 強制 | spec-leader (Plan 完了後) 自動 + 明示フレーズ |
| 8 | `verification-before-completion` | Verify | 完了前の test / lint / type / 手動 AC 検証強制 | spec-leader (Implement 完了後) 自動 + 明示フレーズ |
| 9 | `receiving-code-review` | Code Review 後対応 | reviewer 指摘の集約 + Plan タスク追加 + Implement 再ループ | 複数 reviewer で needs-fix / reject 検出時自動 + 明示フレーズ |
| 10 | `cross-model-review` | Code Review (並列) | 外部モデル (Codex / GPT / Gemini) による独立レビュー | spec-leader (Code Review ステージ) 自動 + 明示フレーズ |
| 11 | `learn` | Learn | ship 後の振り返り、時間配分 / 品質ゲート分析、Try パッチ案生成 | spec-leader (ship 完了後) 自動 + 明示フレーズ |

## 3. skill 連携フロー

```
[ユーザー: 要件を言語化]
        │
        ▼
   brainstorming  ─── 複数 Spec 分割判定 ──→  spec-dag-builder (段階的 DAG 暫定生成)
        │                                             │
        ▼                                             ▼
   writing-spec  ←─────────────────────────── (DAG 順に 1 Spec ずつ)
        │                                             │
        ▼                                             │
   spec-review   ←── needs-fix/reject ── writing-spec レビュー指摘対応モード (§13)
        │                                             │
      (pass)                                          │
        ▼                                             │
   spec-leader  [Isolate] ─→ [Plan: writing-plan] ─→ [Implement: tdd-driver + developer]
        │                                             │
        │                                             ▼
        │                                       [Verify: verification-before-completion]
        │                                             │
        │                                             ▼
        │                              [Code Review: code-reviewer + security-reviewer + cross-model-review]
        │                                             │
        │                                  (verdict ≠ pass) → receiving-code-review → Implement ループ
        │                                             │
        │                                        (全 pass)
        │                                             ▼
        │                                     [ユーザー承認] → [ship]
        │                                             │
        └─────────────────────────── spec-dag-builder (確定 DAG に更新) ───┘
                                                      │
                                                      ▼
                                                   learn (Try パッチ案生成)
```

### 主要な自動起動チェーン

1. **Brainstorming 完了** → writing-spec 起動提案
2. **writing-spec 完了** → spec-review 自動起動 (writing-spec §11)
3. **spec-review needs-fix/reject** → writing-spec レビュー指摘対応モードで自動再起動 (spec-review §8)
4. **spec-review pass** → spec-leader 自動起動 (spec-review §9)
5. **spec-leader Isolate 完了** → writing-plan 自動起動
6. **spec-leader Plan 完了** → tdd-driver 自動起動
7. **spec-leader Implement 完了** → verification-before-completion 自動起動
8. **Code Review needs-fix/reject** → receiving-code-review 自動起動 (最大 3 回、循環防止)
9. **ship 完了** → learn 自動起動

## 4. 利用法

### 4.1 通常の利用フロー

1. ユーザーが新しい機能 / バグ修正 / 改善の要件を自然文で発話 (例: 「ログイン機能を追加したい」)
2. `brainstorming` skill が自動起動、Spec を書ける状態まで要件深掘り
3. 単一 Spec の場合 → `writing-spec` が Spec ファイル生成
4. 複数 Spec の場合 → `spec-dag-builder` で暫定 DAG 生成 → `writing-spec` が DAG 順に各 Spec 生成
5. 各 Spec 生成直後に `spec-review` が自動レビュー
6. `pass` 獲得後、`spec-leader` が Isolate〜ship までを制御
7. ship 完了で `learn` が振り返り

### 4.2 ユーザーが介入すべきポイント

| タイミング | 介入内容 |
|---|---|
| brainstorming 中 | 質問への回答、Spec 分割提案の承認 |
| writing-spec ドラフト提示時 | 修正要望、最終承認 |
| spec-review で needs-fix/reject 時 | 指摘対応方針の確認 |
| Code Review 完了後 | ship 承認 (spec-leader §13.1) |
| cross-model で reject かつ他 pass | ユーザー判断 (cross-model §6) |
| ステージ失敗時 | 原因調査と再開方針決定 (spec-leader §15) |
| learn 出力後 | Try パッチ案の選別と skill / hook 反映 |

### 4.3 起動フレーズ (明示トリガー)

自動起動を待たずに個別 skill を明示的に起動したい場合:

- 「要件まとめたい」「新しい仕事を始めたい」→ brainstorming
- 「Spec 書いて」「仕様書起こして」→ writing-spec
- 「Spec レビューして」「review 実行」→ spec-review
- 「Isolate 開始して」「<spec-name> の実装を始めて」→ spec-leader
- 「Plan 書いて」「タスク分解して」→ writing-plan
- 「TDD で実装して」「テスト先行で」→ tdd-driver
- 「検証して」「verify 実行」→ verification-before-completion
- 「レビュー指摘を反映して」→ receiving-code-review
- 「Codex にレビューさせて」「他モデルレビューして」→ cross-model-review
- 「振り返って」「retrospective」→ learn

## 5. テスト結果

### 5.1 eval 実施状況 (2026-04-21 全 skill iteration-1 完了)

| Skill | eval 状態 | 主要結果 |
|---|---|---|
| brainstorming | iteration-2 完了 | with_skill 100% / without_skill 65% / Delta +35pt |
| spec-dag-builder | iteration-1 完了 | 5 ケース全通過 (100%) |
| writing-spec | iteration-1 完了 | with_skill 100% (18/18) / without_skill 62.5% (10/16) / Delta +37.5pt |
| spec-review | iteration-1 完了 | pass / reject / needs-fix 主要 3 ケース 18/18 pass (100%) |
| spec-leader | 限定テスト完了 | 前提条件チェック 3 ケース pass (100%)、Isolate 実動作 / 再開モードは git 事前準備要で未実施 |
| writing-plan | iteration-1 完了 | basic / existing / not-worktree 9/9 pass (100%) |
| tdd-driver | iteration-1 完了 | basic (TDD サイクル案内) / antipattern (テストなし編集拒否) 2/2 pass (100%) |
| verification-before-completion | iteration-1 完了 | basic (4 カテゴリ検証 + verify-report 生成) / antipattern (省略拒否) 2/2 pass (100%) |
| receiving-code-review | iteration-1 完了 | basic (3 reviewer 集約 + Plan 追加) / antipattern (循環防止) 2/2 pass (100%) |
| cross-model-review | iteration-1 完了 | basic (依頼文 + placeholder) / antipattern (バイアス防止) 2/2 pass (100%) |
| learn | iteration-1 完了 | basic (learn.md + 6 件 Try 提案) / antipattern (skill/hook 直接改変拒否) 2/2 pass (100%) |

**全 11 skill iteration-1 相当のテスト完了**。with_skill assertion pass 率は各 skill で 100%。without_skill 比較は brainstorming / writing-spec のみ実施 (Delta +35〜37.5pt)。

### 5.2 spec-leader 限定テスト詳細

**実施ケース (3/5)**:

1. **eval 0 (no-spec)**: Spec ファイル未存在時にエラー返却 + worktree / progress 未生成 → **pass**
2. **eval 2 (no-review)**: review.md 未存在時に spec-review への誘導 + worktree / progress 未生成 → **pass**
3. **eval 3 (verdict-needsfix)**: verdict が pass でない時に writing-spec レビュー指摘対応モードへの誘導 + worktree / progress 未生成 → **pass**

**未実施ケース (2/5)**:

1. **eval 1 (isolate-then-blocked)**: git worktree 実動作 + writing-plan 未実装検出による blocked 状態検証 — 実行には workspace 内の `git init` + 初期コミットが必要
2. **eval 4 (resume)**: 再開モードの検証 — 事前 worktree / progress 構築が必要

### 5.3 動作確認で得られた改善提案

**spec-leader SKILL.md §3 の early-return 時に result.json を生成する案**:

- 提案元: eval 2 の Agent フィードバック
- 内容: 前提条件違反で停止した場合も `specs/<spec-name>.result.json` を `verdict: precondition-failed` で生成
- 効果: Phase 5 orchestrator が「なぜ処理されなかったか」を機械可読で取得可能
- 適用: 次 iteration で SKILL.md §3 / §7 に反映候補

## 6. 既知の未対応事項

### 6.1 eval 未実施 skill (7 種)

spec-review / writing-plan / tdd-driver / verification-before-completion / receiving-code-review / cross-model-review / learn は eval iteration-1 未実施です。次サイクルで順次実施予定:

- 優先度高: **spec-review** (writing-spec の後続として接続確認に必要)
- 優先度中: **writing-plan** / **tdd-driver** / **verification-before-completion** (spec-leader が依存)
- 優先度中: **receiving-code-review** (Code Review loop の健全性に関わる)
- 優先度低: **cross-model-review** / **learn** (外部依存 or 振り返りフェーズ)

### 6.2 spec-leader 下位 skill の未実装依存

Phase 3 初期は以下の状態で動作します (`spec-leader` §16 の通り):

- Isolate ステージ: ○ (本 skill で直接 git worktree 実行)
- Plan ステージ: ○ (writing-plan 実装済、Phase 3 で実装完了)
- Implement ステージ: × (developer agent 未実装、tdd-driver は skill のみで agent は Phase 3 の対象外)
- Verify ステージ: × (verifier agent 未実装)
- Code Review ステージ: × (code-reviewer / security-reviewer / cross-model-reviewer agent 未実装)
- ship ステージ: ○ (本 skill で直接 git merge 実行、ユーザー承認後)

つまり本レポート時点では「Isolate → Plan 完了 → Implement で blocked」が自動進行の最大範囲です。Implement 以降を完走するには Phase 3 の agent 実装 (ROADMAP Phase 3 の agent 項目) が必要です。

### 6.3 Phase 4 hook 化の依存

以下の skill は Phase 4 で対応する hook が導入されることで強制力が物理化されます:

- `tdd-driver` → PreToolUse hook (Edit / Write 時のテスト存在確認)
- `verification-before-completion` → Stop hook (完了宣言前の全検証強制)

skill 側のインタフェースは変更不要、hook 追加時に強制力が上がる設計です。

## 7. Phase 4 / 5 への引き継ぎ

### 7.1 Phase 4 (hook 自動化)

- PreToolUse hook: tdd-driver §5 のロジックを hook 化
- Stop hook: verification-before-completion §5 のロジックを hook 化
- SessionStart hook: プロジェクト固有 skill / コンテキストの自動注入 (superpowers 方式)
- 各 skill の SKILL.md は変更不要 (hook は skill の成果物を参照するのみ)

### 7.2 Phase 5 (orchestrator)

- spec-leader の入出力契約 (入力: spec_path / 出力: progress.json + result.json) が確定済
- orchestrator は以下のように本 skill を呼び出す想定 (本 skill は変更不要):
  - progress_path を監視
  - result_path の verdict (shipped / aborted / paused) で次 Spec へ進む
- Agent Teams の多階層 subagent 動作確認が Phase 5 の必須検証項目
- 動作不可の場合、state ファイル経由の擬似並列方式に切替

## 8. コミット履歴 (Phase 3 時点)

```
89aeccb Phase 3 ワークフロー skill 残 6 種と spec-leader fixture を追加
1ecad77 spec-leader skill を追加
71ee2a0 spec-review skill を追加し writing-spec と自動連携
c82fcfd writing-spec eval iteration-1 の入力 fixture を追加
61145b9 CLAUDE.md に Phase 3 進捗サマリを追記
13fd01c writing-spec skill を追加
004db72 spec-dag-builder skill を追加
af74607 brainstorming skill v2 完成と用語整理
70b09e5 hooks/ ディレクトリの既存スクリプトを追加
```

## 9. 次アクション候補

1. **未実施 7 skill の eval iteration-1** (優先度高)
2. **spec-leader eval 1 / 4 の git 実動作テスト** (git init 付き fixture 整備)
3. **Phase 4 hook 化** (tdd-driver / verification-before-completion)
4. **Phase 3 の agent 実装** (developer / verifier / reviewer 群 — spec-leader の Implement〜Code Review 完走に必須)
5. **SKILL.md §3 early-return 時の result.json 生成** (spec-leader 改善提案)
