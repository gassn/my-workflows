# ロードマップ

本プロジェクトは Claude Code の環境を自分用に最適化するためのものです。`docs/workflow.md` で定義したワークフロー (8 フェーズ + 3 層階層構造) を段階的に実装していきます。

## Phase 1: 基礎整備 (完了)

既存の優良フレームワークを調査し、設計パターンを抽出するフェーズです。

- [x] プロジェクトディレクトリの作成 (`~/my-workflows/`)
- [x] git リポジトリの初期化 (main ブランチ)
- [x] superpowers の構造解析 (SessionStart hook + skills の相互参照モデル)
- [x] 参考フレームワークの一次調査 (superpowers / gstack / spec-kit / oh-my-claudecode / claude-scrum-team 等)
- [x] 初号 skill の作成 (`genshijin-without-docs`: 会話圧縮 + ドキュメント丁寧維持)
- [x] 参考フレームワーク一覧ドキュメントの整備 (`docs/frameworks.md`)
- [x] 各フレームワークの中核 skill / hook / agent パターンの分類表作成 (`docs/frameworks.md` § 11)

## Phase 2: ワークフロー骨子定義 (現在)

複数フレームワークから良い部分を独自合成し、本プロジェクト標準のワークフローを定義するフェーズです。

- [x] `docs/workflow.md` 作成 (8 フェーズ + 3 層階層 + Mermaid 図)
- [x] `ROADMAP.md` 再構成 (Phase 2-6 を `docs/workflow.md` 駆動に統合)
- [ ] settings.json 最新仕様の参照ドキュメント整備 (任意、Phase 4 開始前)

**完了条件**: ワークフロー全体像と各フェーズの責務が確定し、Phase 3 以降の実装方針が明確になっていること。

## Phase 3: 単一 Spec 版 skill / agent 実装

`docs/workflow.md` で定義した 9 フェーズ (Spec / Spec Review / Isolate / Plan / Implement / Verify / Code Review / ship / Learn) を **単一 Spec 前提** で動作するよう実装します。orchestrator は Phase 5 で追加します。

### skill (10 種)

- [ ] `brainstorming` (Spec 前段の要件深掘り、superpowers 参考)
- [ ] `writing-spec` (軽量 Markdown 仕様作成、OpenSpec 参考)
- [ ] `spec-review` (AI 自動 Spec レビュー、claude-scrum-team 参考)
- [ ] `spec-leader` (Isolate → Code Review のフェーズ遷移制御、独自)
- [ ] `writing-plan` (技術計画 + タスク分解、superpowers + spec-kit 参考)
- [ ] `tdd-driver` (テスト先行強制、superpowers 参考)
- [ ] `verification-before-completion` (完了前検証強制、superpowers 参考)
- [ ] `receiving-code-review` (レビュー指摘対応、superpowers 参考)
- [ ] `cross-model-review` (Codex 等の独立モデルレビュー、claude-scrum-team 参考)
- [ ] `learn` (振り返り + 改善提案、独自)

### agent (7 種、orchestrator は Phase 5)

- [ ] `developer` (タスク単位の TDD 実装)
- [ ] `code-reviewer` (コード品質レビュー)
- [ ] `security-reviewer` (セキュリティ観点レビュー)
- [ ] `cross-model-reviewer` (他モデル経由のレビュー)
- [ ] `verifier` (全検証 test / lint / type 実行)
- [ ] `spec-reviewer` (Spec の完全性 / 実現可能性 / 整合性レビュー)
- [ ] `investigator` (コードベース / 依存 / 類似実装の調査、Plan フェーズ用)

### 設計制約

- specLeader は **単独動作可能** に作る (orchestrator 不在前提)
- 将来 orchestrator から呼ばれる前提のインタフェースを Phase 3 時点で確定する
  - 入力: spec ファイルパス
  - 出力: 進捗ファイル + 結果ファイルのパス
- これにより Phase 5 で orchestrator 追加時、specLeader の改修を不要にする

**完了条件**: 単一 Spec を入力として、Spec Review → ship → Learn まで人間最小介入で完走できること。

## Phase 4: hook 自動化

skill 単体では強制力が弱いため、hook で挙動を物理的に固定化します。

- [ ] **SessionStart hook**: プロジェクト固有 skill / コンテキストの自動注入 (superpowers 方式参考)
- [ ] **PreToolUse hook (Edit/Write)**: TDD 強制 (実装ファイル編集前にテスト存在を確認、なければブロック)
- [ ] **PostToolUse hook (Edit/Write)**: テストファイル変更時の自動テスト実行
- [ ] **Stop hook**: 完了宣言前の全検証強制 (test / lint / type)
- [ ] **WorktreeCreate hook**: worktree 初期化 (Spec ファイルコピー、ブランチ確認)
- [ ] **WorktreeRemove hook**: worktree 削除前の未コミット警告
- [ ] **TaskCompleted hook**: タスク完了時の進捗ファイル更新
- [ ] **InstructionsLoaded hook**: CLAUDE.md / Spec ファイルロード時の追加コンテキスト
- [ ] hookify 連携検証 (会話履歴から hook ルールを自動生成)

**完了条件**: Phase 3 で実装した skill が hook なしでは挙動しなくなる (= 強制力が効いている) こと。

## Phase 5: orchestrator 追加 (複数 Spec 並列)

複数 Spec を並列実行する orchestrator agent を追加します。Phase 3 で確定したインタフェースに沿って specLeader を呼び出し、specLeader 自体は改修不要にします。

- [ ] **orchestrator agent** 実装 (複数 Spec の DAG 管理、specLeader 起動、merge 順序制御)
- [ ] **DAG 管理**: Spec 間依存関係の定義と解決
- [ ] **Agent Teams 多階層 subagent の動作検証**: orchestrator → specLeader → workers の 3 層が動作するか確認
  - 動作しない場合: state ファイル経由の擬似並列方式に切り替え
- [ ] **merge 順序制御**: 並列完了後の統合順序 (依存順 + コンフリクト解決)
- [ ] **並列実行時のリソース上限**: 同時起動可能 specLeader 数の制限
- [ ] **長時間タスクの可視化**: tmux + TUI ダッシュボード検討 (claude-scrum-team 参考)

**完了条件**: 2 つ以上の Spec を並列入力して、orchestrator が specLeader を並列起動し、依存順に ship まで完走できること。

## Phase 6: 統合改善ループ + 公開検討

ワークフロー全体の継続的改善とプロジェクト公開を検討します。

- [ ] **全フェーズの統合テスト**: 実プロジェクトでの試用 (本リポジトリ自身を題材にドッグフーディング)
- [ ] **skill-creator による各 skill の eval iteration**: 定量評価と反復改善
- [ ] **CLAUDE.md の体系化**: プロジェクト横断の共通ルールと個別ルールの分離
- [ ] **memory 運用の最適化**: 記憶すべき情報とそうでない情報の線引き整備
- [ ] **プロジェクト全体のドキュメント整備**
- [ ] **各 skill の利用例とベストプラクティス集**
- [ ] **ライセンス選定**
- [ ] **GitHub への公開** (任意)

**完了条件**: 第三者が本リポジトリを clone して、最小手順で本ワークフローを自分の環境に適用できること。

## 優先順位の考え方

- 日常的に遭遇する摩擦が大きい部分から着手します
- 既存フレームワークをそのまま使える場合は、自作よりも流用を優先します
- skill の粒度は小さく保ち、組み合わせで柔軟性を得る方針を取ります
- 自動化 (hook) は skill が十分に成熟してから導入します。早すぎる自動化は挙動の制御を失わせます
- specLeader / worker のインタフェースは Phase 3 時点で確定し、Phase 5 で改修不要にします
