# ロードマップ

本プロジェクトは Claude Code の環境を自分用に最適化するためのものです。`docs/workflow.md` で定義したワークフロー (9 ステージ + 3 層階層構造) を Phase 1〜6 で段階的に実装していきます。公開 URL: https://github.com/gassn/my-workflows

## Phase 1: 基礎整備 (完了)

既存の優良フレームワークを調査し、設計パターンを抽出するフェーズです。

- [x] プロジェクトディレクトリの作成 (`~/my-workflows/`)
- [x] git リポジトリの初期化 (main ブランチ)
- [x] superpowers の構造解析 (SessionStart hook + skills の相互参照モデル)
- [x] 参考フレームワークの一次調査 (superpowers / gstack / spec-kit / oh-my-claudecode / claude-scrum-team 等)
- [x] 初号 skill の作成 (`genshijin-without-docs`: 会話圧縮 + ドキュメント丁寧維持)
- [x] 参考フレームワーク一覧ドキュメントの整備 (`docs/frameworks.md`)
- [x] 各フレームワークの中核 skill / hook / agent パターンの分類表作成 (`docs/frameworks.md` § 11)

## Phase 2: ワークフロー骨子定義 (完了)

複数フレームワークから良い部分を独自合成し、本プロジェクト標準のワークフローを定義するフェーズです。

- [x] `docs/workflow.md` 作成 (8 フェーズ + 3 層階層 + Mermaid 図)
- [x] `ROADMAP.md` 再構成 (Phase 2-6 を `docs/workflow.md` 駆動に統合)
- [x] settings.json 最新仕様の参照ドキュメント整備 (Phase 4 で `.claude/settings.json` 実装 + `docs/hookify-setup.md` で hook 仕様参照済)

**完了条件**: ワークフロー全体像と各フェーズの責務が確定し、Phase 3 以降の実装方針が明確になっていること。 → 達成

## Phase 3: 単一 Spec 版 skill / agent 実装 (完了)

`docs/workflow.md` で定義した 9 フェーズ (Spec / Spec Review / Isolate / Plan / Implement / Verify / Code Review / ship / Learn) を **単一 Spec 前提** で動作するよう実装しました。orchestrator は Phase 5 で追加。詳細は `docs/phase3-completion.md` を参照してください。

### skill (11 種、orchestrator は Phase 5 で追加)

- [x] `brainstorming` (Spec 前段の要件深掘り + Spec 分割提案 + コードベース精査、superpowers 参考、commit `af74607`)
- [x] `spec-dag-builder` (複数 Spec の依存関係解析、DAG 構築、段階的アップデート、2026-04-22 改修で単一 Spec も 1 ノード DAG 生成、独自)
- [x] `writing-spec` (Brainstorming ノートから 7 章 Spec 生成、archive 移動、DAG 順処理、OpenSpec + 独自)
- [x] `spec-review` (AI 自動 Spec レビュー、claude-scrum-team 参考)
- [x] `spec-leader` (Isolate → Code Review のステージ遷移制御、独自、Phase 5 改修不要インタフェース確定)
- [x] `writing-plan` (技術計画 + タスク分解、2026-04-22 改修で main 側動作 + files_touched 必須、superpowers + spec-kit 参考)
- [x] `tdd-driver` (テスト先行強制、superpowers 参考)
- [x] `verification-before-completion` (完了前検証強制、superpowers 参考)
- [x] `receiving-code-review` (レビュー指摘対応、superpowers 参考)
- [x] `cross-model-review` (Codex 等の独立モデルレビュー、Phase 3 は PENDING placeholder 運用、claude-scrum-team 参考)
- [x] `learn` (振り返り + 改善提案、独自)

### agent (7 種)

- [x] `developer` (タスク単位の TDD 実装、2026-04-21 実装)
- [x] `code-reviewer` (コード品質レビュー、2026-04-21 実装)
- [x] `security-reviewer` (セキュリティ観点レビュー、2026-04-21 実装)
- [x] `cross-model-reviewer` (他モデル経由のレビュー、2026-04-21 実装)
- [x] `verifier` (全検証 test / lint / type 実行、2026-04-21 実装)
- [x] `spec-reviewer` (Spec の完全性 / 実現可能性 / 整合性レビュー、Phase 5 で新設)
- [x] `investigator` (コードベース / 依存 / 類似実装の調査、Plan フェーズ用、Phase 5 で新設)

### 設計制約

- specLeader は **単独動作可能** に作る (orchestrator 不在前提)
- 将来 orchestrator から呼ばれる前提のインタフェースを Phase 3 時点で確定する
  - 入力: spec ファイルパス
  - 出力: 進捗ファイル + 結果ファイルのパス
- これにより Phase 5 で orchestrator 追加時、specLeader の改修を不要にする

**完了条件**: 単一 Spec を入力として、Spec Review → ship → Learn まで人間最小介入で完走できること。 → 達成 (iter-3/4/5 統合完走 verdict: shipped で確認、Phase 6 バッチ 2 (a) `tmux-dashboard-mvp` でも再検証済)

## Phase 4: hook 自動化 (完了)

skill 単体では強制力が弱いため、hook で挙動を物理的に固定化します。

- [x] **SessionStart hook**: 2026-04-23 バッチ 2 で brainstorming を追加 (`hooks/load-session-skills.sh`、起点 skill のみ常駐で context 膨張を抑制、他 Phase 3 skill は自動起動チェーンで連鎖読込)
- [x] **PreToolUse hook (Edit/Write)**: TDD 強制 (実装ファイル編集前にテスト存在を確認、なければ exit 2 でブロック)。2026-04-23 バッチ 1 実装 (`hooks/pre-tool-use-tdd.sh`、worktree 内のみ強制、SKIP_TDD_HOOK=1 で bypass 可)
- [x] **PostToolUse hook (Edit/Write)**: テストファイル変更時の自動テスト実行 (warning レベル)。2026-04-23 バッチ 2 実装 (`hooks/post-tool-use-auto-test.sh`、worktree 内のみ対象、Python/TS/JS/Go/Rust/Ruby 対応、timeout 30s、SKIP_AUTO_TEST_HOOK=1 で bypass 可)
- [x] **Stop hook**: 完了宣言前の検証状態確認 (warning 運用、2026-04-23 バッチ 1 実装: `hooks/stop-verify-before-completion.sh`、worktree 内で verify-report.md + verdict: pass 確認、Phase 4 後期でブロック化検討)
- [x] **WorktreeCreate hook**: 2026-04-23 Phase 5 バッチ 2 実装 (`hooks/worktree-create-init.sh`)。Claude Code 管理 worktree (EnterWorktree / Agent isolation) 作成時に main 側の Spec/Plan/Review を worktree にコピー + progress.md 初期化を自動実行。Phase 3 spec-leader Bash 手動 add には発火しない (設計通り)
- [x] **WorktreeRemove hook**: 2026-04-23 Phase 5 バッチ 2 実装 (`hooks/worktree-remove-check.sh`)。削除前の未コミット / archive 未完警告 + progress.md を main 側 archive にバックアップ (learn skill 入力用)
- [x] **TaskCompleted hook**: 2026-04-23 Phase 5 バッチ 2 実装 (`hooks/task-completed-progress.sh`)。Claude Code の Task 系 (TaskUpdate status=completed) で発火、worktree 内の progress.md にタスク完了ログを自動追記
- [x] **InstructionsLoaded hook**: 2026-04-23 バッチ 3 実装 (`hooks/instructions-loaded-context.sh`)。CLAUDE.md ロード時に Phase 進捗サマリ、`specs/*.md` ロード時に関連ファイル (plan.md / review.md / progress.json / archive / worktree) 参照リストを additionalContext として追加
- [x] **hookify 連携検証**: 2026-04-23 バッチ 3 で設計方針確定 (`docs/hookify-setup.md`)。Phase 4 では導入方針とシナリオをドキュメント化、実際の有効化は Phase 6 のドッグフーディング段階で learn.md 蓄積後に実施予定

**完了条件**: Phase 3 で実装した skill が hook なしでは挙動しなくなる (= 強制力が効いている) こと。

**Phase 4 現状 (2026-04-23)**: 9 項目中 6 実装済 + 2 は Phase 5 連携依存として先送り + 1 は設計方針確定 (Phase 6 で有効化)。TDD 強制 (PreToolUse) / 自動テスト (PostToolUse) / Verify 状態確認 (Stop) / SKILL 常駐インデックス (SessionStart) / 関連ファイル提示 (InstructionsLoaded) が動作し、Phase 3 skill の強制力は当初想定の大半を物理化。WorktreeCreate/Remove と TaskCompleted は Phase 5 Agent isolation 移行時に合わせて再実装するのが自然なため、Phase 4 は実質完了扱い。

## Phase 5: orchestrator 追加 (複数 Spec 並列、実質完了)

複数 Spec を並列実行する機構を追加します。Phase 3 で確定したインタフェースに沿って specLeader を呼び出し、specLeader 自体は改修不要にします。

**重要な設計変更 (2026-04-23 Phase 5 バッチ 3 判明事項)**: Claude Code 公式仕様「Subagents cannot spawn their own subagents」により、当初計画の agent 3 階層 (orchestrator → spec-leader → workers) は動作不可。orchestrator は agent → skill に再設計し、main agent が本 skill を実行する 1 階層設計に変更しました。

- [x] **orchestrator skill** 実装 (2026-04-23 Phase 5 バッチ 3、`skills/orchestrator/SKILL.md`): 複数 Spec の DAG 管理、spec-leader 逐次起動、merge 順序制御、単一 Spec 時スキップ、再開モード。当初 agent 設計から skill に転換、main agent が orchestrator skill + spec-leader skill を兼任実行
- [x] **investigator agent 役割拡張**: 2026-04-23 Phase 5 バッチ 1 実装 (`agents/investigator.md`、3 responsibility: codebase / other-plans / dependencies)。writing-plan / brainstorming から並列起動可能
- [x] **DAG 管理**: spec-dag-builder + writing-plan + orchestrator skill で実現 (Phase 3 / Phase 5 複数 skill で分担)
- [x] **Agent Teams 多階層 subagent の動作検証** (2026-04-23): 公式仕様で禁止と判明 → state ファイル経由 + 1 階層設計に切り替え済
- [x] **merge 順序制御** (orchestrator skill §4.4): dependency-order / completion-order / manual の 3 方式、Phase 5 時点は dependency-order が実質稼働
- [x] **並列実行時のリソース上限** (orchestrator skill §5): max_parallel=1 (main agent 逐次実行)、workers 並列は spec-leader に委譲、Phase 6 でマルチセッション並列化を検討
- [ ] **長時間タスクの可視化**: tmux + TUI ダッシュボード検討 (claude-scrum-team 参考、Phase 6 実装予定)

**完了条件**: 2 つ以上の Spec を入力して、orchestrator skill が spec-leader を逐次起動し、依存順に ship まで完走できること (並列は Phase 6 以降)。

## Phase 6: 統合改善ループ + 公開検討 (🚧 バッチ 1 完了 / バッチ 2 (a) 完了)

ワークフロー全体の継続的改善とプロジェクト公開を検討します。

- [x] **全フェーズの統合テスト**: ドッグフーディング 4 Spec 完走。バッチ 2 (a) `tmux-dashboard-mvp` (1 loop) / (b) `tmux-dashboard-v2-responsive` (initial pass) / (c) `dashboard-color` + `dashboard-color-themes` (2 Spec 依存あり、3 連続 initial pass)。複数 Spec DAG 順起動 + archive plan.md の worktree 参照経路 + spec-reviewer 2 並列動作 + writing-plan 連続実測の 6 検証項目すべて成立。詳細は `specs/archive/batch-2c-orchestrator.learn.md` 参照
- [~] **skill-creator による各 skill の eval iteration**: 2026-04-24 時点で記述ベース実証完了 (spec-leader iter-5 / writing-plan iter-5 / learn iter-2 の 3 skill で Try 5.1 / 5.3 / 5.4 / 5.5 の改修効果を SKILL.md 反映整合性として検証済、docs/phase6-progress.md §4 参照)。LLM 再実行による定量 Delta 測定 (without_skill vs with_skill の出力比較) は Phase 6 バッチ 3 以降の専用セッションで実施予定
- [x] **CLAUDE.md の体系化**: プロジェクト横断の共通ルールと個別ルールの分離 (2026-04-23 バッチ 1 完了、160→128 行スリム化、skill/agent 詳細を components-map に委任)
- [x] **memory 運用の最適化**: 記憶すべき情報とそうでない情報の線引き整備 (2026-04-23 バッチ 1 完了、`docs/memory-operation.md` 新設で方針明文化)
- [x] **プロジェクト全体のドキュメント整備** (2026-04-23 バッチ 1 で README / CLAUDE.md 更新、Phase 3-5 完了レポート 3 点セット + components-map + hookify-setup + memory-operation で体系完成)
- [x] **各 skill の利用例とベストプラクティス集** (2026-04-24 完了、`docs/best-practices.md` 新設、8 章構成で skill 別利用例 / ハマりどころ 10 件 / hook 連携 / orchestrator 活用 / 他プロジェクト持ち込みガイド / FAQ を網羅)
- [x] **ライセンス選定** (2026-04-24 MIT 採択): `LICENSE` ファイル作成、README.md に明示。MIT 選定理由は「最も短文かつ商用/改変/再配布すべて自由で採用ハードル最低」「Claude Code 関連 OSS でも最多の採用実績」
- [x] **GitHub への公開** (2026-04-24 完了): https://github.com/gassn/my-workflows (public、MIT License、topics: claude-code / claude-skills / spec-driven-development / ai-workflow / workflow-automation)
- [x] **GitHub Actions CI** (2026-04-24 完了): `.github/workflows/ci.yml` を追加、4 ジョブ (tools テスト / skill & agent frontmatter 検証 / hook 構文チェック / 秘密情報スキャン) を push / PR / 手動実行で走らせる。README にバッジ追加
- [x] **security Minor 対応: allowlist 強化** (2026-04-24 完了): dashboard / dashboard-pane の SPEC_NAME_PATTERN を `^[A-Za-z0-9][A-Za-z0-9._-]*$` に更新、dot-only / dot-starting / hyphen-starting Spec 名を拒否。回帰テスト T-test-8a〜8d (4 ケース) を追加、14/14 pass。security-reviewer iter-2 の残 Minor を解消
- [x] **Agent Teams 機能の有効化** (2026-04-23 設定): user settings の env セクションに `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 追加 (Claude Code v2.1.32 以上、本プロジェクトは v2.1.118 で確認)。subagents は Agent Teams 無効時も利用可のため Phase 3-5 成果物への影響なし。詳細は `docs/phase5-completion.md §0` 参照

**完了条件**: 第三者が本リポジトリを clone して、最小手順で本ワークフローを自分の環境に適用できること。

## 優先順位の考え方

- 日常的に遭遇する摩擦が大きい部分から着手します
- 既存フレームワークをそのまま使える場合は、自作よりも流用を優先します
- skill の粒度は小さく保ち、組み合わせで柔軟性を得る方針を取ります
- 自動化 (hook) は skill が十分に成熟してから導入します。早すぎる自動化は挙動の制御を失わせます
- specLeader / worker のインタフェースは Phase 3 時点で確定し、Phase 5 で改修不要にします
