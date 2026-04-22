# Phase 3 ワークフロー skill 実装完了レポート

- **skill 実装完了日**: 2026-04-20
- **eval iteration-1 相当完了日**: 2026-04-21 (主要 skill は iteration-2 まで実施)
- **対象**: `ROADMAP.md` Phase 3 の 11 skill + 設計制約 3 項目
- **補足**: agent (8 種) の実装は Phase 3 の残タスクとして継続、orchestrator (1 種) は Phase 5 対応

## 1. サマリ

本プロジェクトの中核ワークフロー (`docs/workflow.md`) で定義した 9 ステージ (Brainstorming → DAG 構築 → Spec → Spec Review → Isolate → Plan → Implement → Verify → Code Review → ship → Learn) を担う **11 skill** を実装完了し、全 skill について **eval iteration-1 相当以上のテストを実施して with_skill 100% pass** を達成しました。

達成事項:

- 11/11 skill 実装完了、自動起動チェーンで Brainstorming から Learn まで一気通貫進行
- 25 eval ケース実施、with_skill 全ケース期待挙動通り (pass 率 100%)
- spec-review / spec-leader は iteration-2 まで実施 (整合性観点 + 再レビューサイクル + git 実動作 + 再開モードを含む全機能確認)
- without_skill 比較は brainstorming (Δ+35pt) / writing-spec (Δ+37.5pt) で実施、skill 独自価値を定量確認
- Phase 5 orchestrator 連携インタフェース (spec-leader の入力 spec_path / 出力 progress.json + result.json) を確定、Phase 5 で spec-leader 本体の改修不要

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
| spec-review | iteration-1 + iteration-2 完了 | 全 5 ケース pass (100%)。3 verdict 各 2 回 + 整合性コードベース走査 (7/7 検出) + 再レビューサイクル (Major 3 件解消確認) |
| spec-leader | iteration-1 + iteration-2 完了 | 全 5 ケース pass (100%)。iteration-1: 前提条件 3 ケース、iteration-2: Isolate 実 git worktree 動作 + developer agent blocked 検出 + 再開モードの 2 ケース |
| writing-plan | iteration-1 完了 | basic / existing / not-worktree 9/9 pass (100%) |
| tdd-driver | iteration-1 完了 | basic (TDD サイクル案内) / antipattern (テストなし編集拒否) 2/2 pass (100%) |
| verification-before-completion | iteration-1 完了 | basic (4 カテゴリ検証 + verify-report 生成) / antipattern (省略拒否) 2/2 pass (100%) |
| receiving-code-review | iteration-1 完了 | basic (3 reviewer 集約 + Plan 追加) / antipattern (循環防止) 2/2 pass (100%) |
| cross-model-review | iteration-1 完了 | basic (依頼文 + placeholder) / antipattern (バイアス防止) 2/2 pass (100%) |
| learn | iteration-1 完了 | basic (learn.md + 6 件 Try 提案) / antipattern (skill/hook 直接改変拒否) 2/2 pass (100%) |

**全 11 skill iteration-1 相当のテスト完了**。with_skill assertion pass 率は各 skill で 100%。without_skill 比較は brainstorming / writing-spec のみ実施 (Delta +35〜37.5pt)。

### 5.1.1 Phase 3 agent iteration-1 結果 (2026-04-21)

Phase 3 で実装した 5 agent についても iteration-1 単体動作確認を実施、全 agent pass:

| agent | シナリオ | 結果 |
|---|---|---|
| developer | 電卓 add() の TDD 実装 (Python + pytest) | Red→Green→Refactor 完走、5/5 テスト pass、禁止事項 7 項目全クリア |
| verifier | 仮想ログイン機能の 4 カテゴリ検証 | verify-report.md 完備 (テスト 42/42 / Lint 0 / 型 0 / AC 3/3)、verdict: pass |
| code-reviewer | 品質問題 + セキュリティ問題混在の login.ts | verdict: needs-fix (Major 3 / Minor 4)、**セキュリティ観点に不侵犯** (責務境界遵守) |
| security-reviewer | 意図的セキュリティ欠陥 6 件の login.ts | verdict: reject (Critical 3 / Major 3 / Minor 1)、**意図的問題 6/6 検出 (100%)**、OWASP カテゴリ併記 |
| cross-model-reviewer | Phase 3 制約下での依頼文生成 | 手動依頼テンプレート生成、**バイアス防止順序遵守** (他 reviewer 結果を先に見せない)、verdict: PENDING placeholder |

**5/5 agent pass (100%)**。code-reviewer と security-reviewer が同じ login.ts を見ても責務境界を守って独立判定することを確認 (被り指摘なし)。3 reviewer 体制の独立性が機能することを Phase 5 の並列化前提で確認済み。

### 5.1.2 spec-leader iteration-3 統合完走テスト (2026-04-21〜22)

skill 11 種 + agent 5 種の連携で Brainstorming → ship の一気通貫完走を検証:

**題材**: Python 電卓ライブラリ (add / subtract + docstring 検証、3 タスク)

**結果: 完走 ✅ (verdict: shipped)**

全 6 ステージ + Learn が完走、1 回のレビュー loop を経て最終 pass。所要時間 約 25 分。

| ステージ | 実施 | 結果 |
|---|---|---|
| Isolate | 手動 | worktree 作成、spec/calculator branch |
| Plan | writing-plan skill | 3 タスク + 7 章構成 |
| Implement (T-1/T-2 並列 + T-3) | developer agent × 3 | 12/12 tests pass |
| Verify (iter-1) | verifier agent | 4 カテゴリ pass、12/12 tests |
| Code Review (iter-1) | 3 reviewer 並列 | code: needs-fix / security: pass / cross-model: PENDING |
| receiving-code-review | skill | 統合 needs-fix、T-fix-iter-1-1〜4 Plan 追加 |
| Implement (T-fix) | developer agent | core.py 集約 + DRY 解消、16/16 tests |
| Verify (iter-2) | verifier agent | 16/16 tests pass |
| Code Review (iter-2) | code-reviewer | Major 3 件解消確認、verdict: pass |
| ship | 手動 | main merge、worktree 削除、spec archive |
| Learn | learn skill | Try 6 件の改善提案生成 |

**確認できた事項**:
- skill 間自動連携 (writing-plan → developer → verifier → reviewer 群) が機能
- 責務境界の堅牢性 (code / security reviewer が同じコードを見ても被り指摘なし)
- レビュー loop の有効性 (Major 3 件が 1 iteration で pass に転じ、循環防止内で完走)
- cross-model-reviewer の Phase 3 運用 (PENDING placeholder で他 reviewer 判定を妨げない)

**判明した問題 (learn.md §4 Problem、§5.3 改善提案に反映)**:
- 並列 developer の git index 競合 (T-2 commit 消失 → 手動補完で復旧)
- Plan と実装の乖離 (実装変更時に Plan §2 が追従せず Minor 化)
- progress.json の更新ロス (plan stage が in_progress のまま残り result.json と不整合)
- 並列競合の不可視化 (stages_failed に記録されず手動復旧で隠蔽)

### 5.2 spec-leader 全 5 ケーステスト詳細

**iteration-1 (前提条件チェック系、3 ケース)**:

1. **eval 0 (no-spec)**: Spec ファイル未存在時にエラー返却 + worktree / progress 未生成 → **pass**
2. **eval 2 (no-review)**: review.md 未存在時に spec-review への誘導 + worktree / progress 未生成 → **pass**
3. **eval 3 (verdict-needsfix)**: verdict が pass でない時に writing-spec レビュー指摘対応モードへの誘導 + worktree / progress 未生成 → **pass**

**iteration-2 (git 実動作系、2 ケース)**:

4. **eval 1 (isolate-then-blocked)**: Agent が workspace 内で実 `git init` + 初期 commit を実行、skill が `git worktree add worktrees/login -b spec/login` で worktree 作成、spec.md コピー、progress.json / progress.md 生成を完遂。Plan ステージは writing-plan 模擬起動で completed 扱い、**Implement ステージで developer agent 未実装を検出して blocked**、result.json を verdict: paused で生成 → **pass**。SKILL.md §16.3 で想定された「Isolate → Plan 完了 → Implement で blocked」動作が正確に再現
5. **eval 4 (resume)**: 既存 progress.json + worktrees/ の状態で skill を起動、§14.1 判定 2 条件で再開モードを認識、progress.json から current_stage=plan / blocked 状態を読取、ユーザーに 3 択 (Plan 再実行 / 手動完了扱いで Implement から / 中止) を提示、progress.json / progress.md を一切変更せず、新 worktree も未作成、result.json も未生成 (ユーザー確認前は状態不変) → **pass**

**合計 5/5 pass (100%)**

### 5.3 動作確認で得られた改善提案 (iteration 横断)

eval 実行中に Agent / 動作結果から抽出した skill / SKILL.md への改善提案です。

**適用状況 (2026-04-22): 全 11 件適用完了**。コミット `a7c1ef9` / `0696562` / `3966f17` / `7441a12` / `18ea2e0` の 5 バッチで段階的に反映しました (No.5 はバッチ 3 §3.2.1 に統合反映、個別改修不要と判断)。

1. **spec-leader §3 early-return 時に result.json を生成する案** (提案元: spec-review iteration-1 eval 2 Agent)
   - 内容: 前提条件違反で停止した場合も `specs/<spec-name>.result.json` を `verdict: precondition-failed` で生成
   - 効果: Phase 5 orchestrator が「なぜ処理されなかったか」を機械可読で取得可能
   - 適用先: `skills/spec-leader/SKILL.md` §3 分岐表 + §7 結果ファイル仕様 (`precondition-failed` verdict を追加)

2. **spec-leader §14 再開モードで「中止」選択時の result.json 仕様** (提案元: spec-leader iteration-2 eval 4 benchmark)
   - 内容: ユーザーが再開モードで中止を選んだ場合、`verdict: aborted-on-resume` で result.json を生成
   - 効果: 再開モード終了後の状態を機械可読で残せる
   - 適用先: `skills/spec-leader/SKILL.md` §14.3

3. **spec-leader Isolate 実動作テストを CI 可能にする fixture テンプレート** (提案元: spec-leader iteration-2 benchmark)
   - 内容: `evals/fixtures/git-repo-template/` に `git init + 初期 commit` 済みのテスト用 fixture を配置、Agent の事前 `git init` 手順を省略可能に
   - 効果: CI / 再実行時の再現性向上
   - 適用先: `skills/spec-leader/evals/fixtures/` 新設 (将来の Phase 4/5 CI 対応時)

4. **learn skill の入力データ整合性チェック強化** (提案元: learn eval 0 Agent による副次的発見)
   - 内容: progress.json の blocked 状態と result.json の verdict: shipped の矛盾をエラー/警告として扱う
   - 効果: 上流 skill (spec-leader) のデータ生成バグ検出が可能に
   - 適用先: `skills/learn/SKILL.md` §8 失敗時の対応

5. **receiving-code-review の Plan 更新書式の明文化** (提案元: receiving-code-review eval 0)
   - 内容: 追加タスクの frontmatter 更新ルール (`status: plan-revised` / `revised` / `review_iteration`) を SKILL.md §3.2 に明記
   - 効果: iteration トレーサビリティが skill 横断で担保される
   - 適用先: `skills/receiving-code-review/SKILL.md` §3.2

6. **Plan §5.2 に `files_touched` フィールドを必須化** (提案元: 統合テスト iteration-3 learn §5.1)
   - 内容: 各タスクに編集予定ファイルの一覧を明記、developer agent 並列実行時の競合を事前検出
   - 効果: T-1/T-2 並列実行で発生した `calculator/__init__.py` + git index 競合を予防
   - 適用先: `skills/writing-plan/SKILL.md` §5.1 タスクテンプレート拡張

7. **developer agent の `allowed_files` コントラクト** (提案元: 統合テスト learn §5.2)
   - 内容: developer agent のプロンプトに編集許可ファイル一覧を渡し、`git diff --name-only` で自己検査
   - 効果: agent が意図せず他タスクファイルを編集することを防ぐ
   - 適用先: `agents/developer.md` §入力 / §完了条件

8. **spec-leader 並列 Implement で独立 worktree 必須化 or コミット前ロック** (提案元: 統合テスト learn §5.3)
   - 内容: 並列 developer agent には sub-worktree を割り当てるか、`git add` / `git commit` を直列化する lock 機構
   - 効果: git index 競合を物理的に排除、Phase 5 orchestrator の並列起動準備
   - 適用先: `skills/spec-leader/SKILL.md` §10 Implement

9. **receiving-code-review で Plan §2 更新を必須化** (提案元: 統合テスト learn §5.4)
   - 内容: T-fix タスク実装時に実装配置変更があれば Plan §2 アーキテクチャ記述の追従を強制
   - 効果: Plan と実装の乖離 (Major-2 再発リスク) を防ぐ
   - 適用先: `skills/receiving-code-review/SKILL.md` §3.2

10. **progress.json 更新契約の強化** (提案元: 統合テスト learn §5.5)
    - 内容: spec-leader が各ステージ遷移時に atomic に progress 更新、中断時も整合性維持
    - 効果: progress.json と result.json の不整合を防止 (統合テストで blocked 状態のまま shipped になった問題)
    - 適用先: `skills/spec-leader/SKILL.md` §5.2 更新タイミング + §6.1 schema

11. **spec-leader result.json 整合性チェック** (提案元: 統合テスト learn §5.6)
    - 内容: result.json 生成時に progress.json の `stages` 状態と `stages_completed` の整合を検証
    - 効果: 手動復旧での隠蔽を防止、並列競合事故を可視化
    - 適用先: `skills/spec-leader/SKILL.md` §7 結果ファイル仕様 + 生成ロジック

## 6. 既知の未対応事項

### 6.1 eval 未対応項目 (skill 単位ではすべて iteration-1 相当完了)

全 11 skill の iteration-1 相当テストは完了していますが、以下は次 iteration 以降に持ち越しています:

- **without_skill 比較未実施** (skill 9 種): brainstorming / writing-spec のみ Delta 測定済 (+35pt / +37.5pt)。spec-dag-builder / spec-review / spec-leader / writing-plan / tdd-driver / verification-before-completion / receiving-code-review / cross-model-review / learn は with_skill のみで採点。skill 独自価値の定量化は今後の課題
- **eval iteration 深化**: 主要 skill (spec-review / spec-leader) は iteration-2 まで実施済、他 skill は iteration-1 の代表ケース (2-3 件) のみ。エッジケース / 組み合わせテストは未カバー

### 6.2 Phase 3 の agent 実装が完走の鍵

Phase 3 の ROADMAP では skill (11 種) と agent (8 種) が対象で、agent は未実装のままです。現時点の spec-leader 実行フローでは以下で停止します (`spec-leader` §16.3 の通り):

- Isolate ステージ: ○ (本 skill で直接 git worktree 実行)
- Plan ステージ: ○ (writing-plan 実装済)
- **Implement ステージ: × developer agent 未実装で blocked**
- Verify ステージ: × (verifier agent 未実装、未到達)
- Code Review ステージ: × (code-reviewer / security-reviewer / cross-model-reviewer agent 未実装、未到達)
- ship ステージ: ○ (本 skill で直接 git merge 実行、ユーザー承認後)

本レポート時点で自動進行の最大範囲は「Isolate → Plan 完了 → Implement で blocked」。完走には **Phase 3 agent 群 (developer / verifier / code-reviewer / security-reviewer / cross-model-reviewer、5 種)** の実装が必要です。残 agent (investigator / spec-reviewer) と orchestrator は Phase 5 対応。

### 6.3 Phase 4 hook 化の依存

以下の skill は Phase 4 で対応する hook が導入されることで強制力が物理化されます:

- `tdd-driver` → PreToolUse hook (Edit / Write 時のテスト存在確認)
- `verification-before-completion` → Stop hook (完了宣言前の全検証強制)
- `spec-leader` → TaskCompleted hook / WorktreeCreate hook / WorktreeRemove hook
- (全 skill 横断) → SessionStart hook (プロジェクト固有 skill / コンテキストの自動注入)

skill 側のインタフェースは変更不要、hook 追加時に強制力が上がる設計です。Phase 3 の skill で「指導 / 提案」として機能している部分が Phase 4 で「物理的ブロック」に昇格します。

## 7. Phase 4 / 5 への引き継ぎ

### 7.1 Phase 3 残タスク (agent 実装) — 本 Phase 継続分

Phase 3 ROADMAP の agent 8 種のうち、以下 5 種が spec-leader の Implement〜Code Review 完走に必須:

- `developer`: タスク単位の TDD 実装 (tdd-driver と連携)
- `verifier`: 全検証 (test / lint / type) 並列実行 (verification-before-completion と連携)
- `code-reviewer`: コード品質レビュー
- `security-reviewer`: セキュリティ観点レビュー
- `cross-model-reviewer`: 外部モデル経由の独立レビュー (cross-model-review と連携)

残 agent:

- `investigator`: コードベース調査 (writing-plan と連携、Phase 5 で brainstorming にも拡張)
- `spec-reviewer`: Spec の 3 観点レビュー (spec-review と連携、Phase 5 で agent 3 並列化)
- `orchestrator`: 複数 Spec の DAG 管理 (Phase 5 専任)

### 7.2 Phase 4 (hook 自動化)

- **PreToolUse hook (Edit/Write)**: tdd-driver §5 のロジックを hook 化、実装ファイル編集前のテスト存在確認を物理ブロック
- **Stop hook**: verification-before-completion §5 のロジックを hook 化、verify-report.md 存在 + verdict: pass を完了宣言前に強制
- **PostToolUse hook (Edit/Write)**: テストファイル変更時の自動テスト実行
- **WorktreeCreate hook**: worktree 初期化 (Spec ファイルコピー、ブランチ確認) — spec-leader §8.1 を hook 化
- **WorktreeRemove hook**: worktree 削除前の未コミット警告
- **TaskCompleted hook**: タスク完了時の progress 自動更新
- **SessionStart hook**: プロジェクト固有 skill / コンテキストの自動注入 (superpowers 方式)

各 skill の SKILL.md は変更不要 (hook は skill の成果物を参照するのみ)。

### 7.3 Phase 5 (orchestrator)

- spec-leader の入出力契約 (入力: spec_path / 出力: progress.json + result.json) が確定済、改修不要
- orchestrator は以下のように本 skill を呼び出す想定:
  - progress_path を監視 (poll or watch)
  - result_path の verdict (shipped / aborted / paused) で次 Spec へ進む
- **Agent Teams の多階層 subagent 動作確認** が Phase 5 の必須検証項目
  - 動作不可の場合、state ファイル経由の擬似並列方式に切替
- spec-review iteration-2 で整合性コードベース走査の実用性を確認済 → Phase 5 の agent 3 並列化で各観点担当 agent に分割可能
- merge 順序制御 (複数 Spec 完了時の依存順 + コンフリクト解決) は Phase 5 で設計

## 8. コミット履歴 (Phase 3 skill 関連、新しい順)

```
0ed8bc8 spec-review eval 3/4 を iteration-2 で実施、全 5 ケース pass
c1874ca spec-leader eval 1/4 を iteration-2 で実施、全 5 ケース pass
7b51b87 残 5 skill の eval iteration-1 を一括実施
0a4e0fe writing-plan eval iteration-1 を実施
bd42ba6 spec-review eval iteration-1 を実施
af9a080 Phase 3 ワークフロー skill 実装完了レポートを追加
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

## 9. 次アクション候補 (優先度順)

1. **Phase 3 agent 5 種の実装** (最優先): developer / verifier / code-reviewer / security-reviewer / cross-model-reviewer。spec-leader の Implement〜Code Review を完走可能にする鍵
2. **Phase 4 hook 自動化着手**: PreToolUse / Stop / WorktreeCreate 等、物理強制力の付与
3. **§5.3 改善提案 5 件の適用**: spec-leader early-return result.json 生成 / 中止時 verdict 追加 / git fixture テンプレート化 / learn データ整合性 / receiving-code-review frontmatter 明文化
4. **without_skill Delta 計測** (skill 9 種): skill 独自価値の定量確認、SKILL.md 改修の判断材料
5. **ドッグフーディング**: 本リポジトリ自身の改修を題材にワークフロー完走を試行 (Phase 6 の統合改善ループへの布石)

## 10. 本 Phase の総括

Phase 3 で目指した「Brainstorming → Learn の 9 ステージを単一 Spec 前提で動作可能な形に実装する」という目標に対し、以下を達成:

- ✅ 11 skill 実装完了 (自動起動チェーンで連携)
- ✅ 全 skill with_skill 100% pass (25 eval ケース)
- ✅ 主要 skill は iteration-2 で深化 (整合性観点 + 再レビュー + git 実動作 + 再開モード)
- ✅ Phase 5 改修不要インタフェースを spec-leader で確定
- ✅ 下位 skill 未実装時の blocked 判定を明文化 (§16.3)
- ✅ without_skill Delta を主要 2 skill で確認 (brainstorming +35pt / writing-spec +37.5pt)
- ✅ **Phase 3 agent 5 種 (developer / verifier / code-reviewer / security-reviewer / cross-model-reviewer) 実装完了** (2026-04-21)
- ✅ **agent iteration-1 単体動作確認 100% pass** (責務境界 + TDD 遵守 + バイアス防止を確認)
- ✅ **spec-leader iteration-3 統合完走テスト完了** (2026-04-22、skill + agent 連携で Brainstorming → ship 一気通貫 verdict: shipped、25 分で完走)
- ⏳ 残 agent 3 種 (investigator / spec-reviewer / orchestrator) は Phase 5 対応
- ✅ **§5.3 改善提案 11 件すべて適用完了** (2026-04-22、5 バッチで段階反映)

spec-leader の「Phase 5 改修不要」という設計制約を Phase 3 時点で確定させた点は特に重要で、Phase 5 orchestrator 追加時の spec-leader 改修を不要にする体制を整えました。統合完走テスト (iteration-3) で skill + agent 連携が意図通り機能することを実証、同時に並列 developer の git index 競合など Phase 5 並列化時の具体的課題も可視化できました。ワークフロー全体の見通しが確立し、Phase 4 hook / Phase 5 orchestrator 着手の基盤が整いました。
