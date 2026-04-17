# ロードマップ

本プロジェクトは Claude Code の環境を自分用に最適化するためのものです。以下のフェーズに分けて段階的に進めていきます。

## Phase 1: 基礎整備 (現在)

既存の優良フレームワークを調査し、設計パターンを抽出するフェーズです。

- [x] プロジェクトディレクトリの作成 (`~/my-workflows/`)
- [x] git リポジトリの初期化 (main ブランチ)
- [x] superpowers の構造解析 (SessionStart hook + skills の相互参照モデル)
- [x] 参考フレームワークの一次調査 (superpowers / gstack / spec-kit / oh-my-claudecode / claude-scrum-team 等)
- [x] 初号 skill の作成 (`genshijin-without-docs`: 会話圧縮 + ドキュメント丁寧維持)
- [ ] 参考フレームワーク一覧ドキュメントの整備 (`docs/frameworks.md`)
- [ ] 各フレームワークの中核 skill / hook / agent パターンの分類表作成

## Phase 2: コア skill 群の構築

日常的な開発ループで頻出する挙動を skill として定義します。

- [ ] **brainstorming skill**: 要件の未確定段階で質問を深掘りする (superpowers の brainstorming 参考)
- [ ] **spec-driven workflow skill**: Specify → Plan → Tasks の 3-phase 進行 (spec-kit 参考)
- [ ] **TDD driver skill**: テスト先行の強制と systematic debugging (superpowers 参考)
- [ ] **verification-before-completion skill**: 完了宣言前の検証コマンド実行強制 (superpowers 参考)
- [ ] **code-review 受け取り skill**: PR レビュー指摘への技術的に厳密な対応 (superpowers の receiving-code-review 参考)
- [ ] **plan 作成 skill**: 実装前の詳細計画ドキュメント作成 (superpowers の writing-plans 参考)

## Phase 3: agent teams の活用

Claude Code の Agent Teams 機能 (v2.1.32+, research preview) を前提に、複数エージェントの並列実行を設計します。

- [ ] **Agent Teams** 機能の動作確認と制約把握
- [ ] **role-based agents** の定義 (gstack の役割分担を参考: PM / Designer / Eng Manager / QA 等)
- [ ] **subagent orchestration skill**: 並列タスク分解と統合 (oh-my-claudecode の Autopilot 参考)
- [ ] **cross-model review**: Codex など他モデルによる独立レビュー (claude-scrum-team 参考)
- [ ] **long-running task 管理**: tmux + TUI ダッシュボード等による可視化検討 (claude-scrum-team 参考)

## Phase 4: 自動化基盤

hook を活用して挙動を強制する層を構築します。

- [ ] **SessionStart hook**: プロジェクト起動時に必要な skill / コンテキストを自動投入 (superpowers の方式参考)
- [ ] **PreToolUse / PostToolUse hook**: 危険操作の事前検証、完了後の検証コマンド強制
- [ ] **Stop hook**: セッション終了時のメモリ更新や未コミット変更の警告
- [ ] **hookify 連携**: 会話履歴から自動的にルール化する仕組みの活用

## Phase 5: 統合と改善ループ

Phase 2〜4 で構築した要素を組み合わせた統合ワークフローを設計し、実利用での継続的な改善ループを回します。

- [ ] **統合ワークフロー**: 要件抽出 → 計画 → TDD 実装 → レビュー → マージ までの一貫フロー
- [ ] **skill-creator による iteration**: 各 skill の定量評価と反復改善
- [ ] **CLAUDE.md の体系化**: プロジェクト横断の共通ルールと個別ルールの分離
- [ ] **memory 運用の最適化**: 記憶すべき情報とそうでない情報の線引き整備

## Phase 6: 共有と文書化

十分に安定した時点で、プロジェクトとしての公開や他者への展開を検討します。

- [ ] プロジェクト全体のドキュメント整備
- [ ] 各 skill の利用例とベストプラクティス集
- [ ] ライセンス選定
- [ ] GitHub への公開 (任意)

## 優先順位の考え方

- 日常的に遭遇する摩擦が大きい部分から着手します。
- 既存フレームワークをそのまま使える場合は、自作よりも流用を優先します。
- skill の粒度は小さく保ち、組み合わせで柔軟性を得る方針を取ります。
- 自動化 (hook) は skill が十分に成熟してから導入します。早すぎる自動化は挙動の制御を失わせます。
