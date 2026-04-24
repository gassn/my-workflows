# my-workflows

[![CI](https://github.com/gassn/my-workflows/actions/workflows/ci.yml/badge.svg)](https://github.com/gassn/my-workflows/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-gassn%2Fmy--workflows-blue.svg)](https://github.com/gassn/my-workflows)

Claude Code 環境を個人用に最適化するためのプロジェクトです。既存の優れたフレームワーク群 (superpowers / spec-kit / claude-scrum-team 等) を参考にしつつ、自身の開発スタイルに合った skills / agents / hooks を段階的に構築しています。

**公開 URL**: https://github.com/gassn/my-workflows

## 設計思想

- **Fork しない**: 既存プラグインを直接改変せず、参考にしながら独自のワークフローを定義します
- **段階的構築**: いきなり大規模な仕組みを目指さず、小さな skill から検証と改善のサイクルを回します
- **自分専用の最適化**: 一般向けフレームワークが含む冗長な指示を削ぎ、個人の開発習慣と合致する挙動を作ります
- **資産化**: ドキュメントやコードコメントは将来の自分が読む資産として丁寧に維持します
- **fallback 設計の予防投資**: 不確実な技術前提には ROADMAP に fallback を明記、判明時の転換コストを最小化します

## 現在の状態 (2026-04-24 時点)

| Phase | 内容 | 状態 |
|---|---|---|
| 1 | 基礎整備 | ✅ 完了 |
| 2 | ワークフロー骨子定義 | ✅ 完了 |
| 3 | skill + agent 実装 + eval | ✅ 完了 (12 skill / 7 agent、iter-3/4/5 統合完走 verdict: shipped) |
| 4 | hook 自動化 | ✅ 完了 (8 hook 実装 + hookify 方針確定) |
| 5 | orchestrator + 並列実行 | ✅ 実質完了 (orchestrator skill + 3 hook + 2 agent、Agent Teams 多階層禁止対応込み) |
| 6 | 統合改善 + 公開検討 | 🚧 着手中 (バッチ 1 完了: CLAUDE.md 体系化 / ドキュメント整備 / MIT License 採択 / ベストプラクティス集。バッチ 2 (a) 完了: tmux ダッシュボード MVP ドッグフーディング shipped-cross-model-pending + skill 改修 4 件反映) |

## ワークフロー全体像

```
Brainstorming → DAG 構築 → Spec → Spec Review → Plan → Isolate → Implement → Verify → Code Review → ship → Learn
```

9 ステージを 12 skill + 7 agent + 8 hook でカバーし、単一 Spec も複数 Spec (orchestrator skill 経由) も扱えます。

詳細:

- **docs/workflow.md**: ワークフロー定義 (9 ステージ + 3 層階層)
- **docs/components-map.md**: skill + agent + hook の全体像 (Mermaid 図 + 使用ツール + worktree 4 系統比較)
- **docs/phase3-completion.md** / **phase4-completion.md** / **phase5-completion.md**: 各 Phase の完了レポート

## 主要コンポーネント

### skill (12 種)

| skill | 役割 |
|---|---|
| `brainstorming` | Spec 前の要件深掘り + 分割提案 + コードベース精査 (ワークフロー起点) |
| `spec-dag-builder` | Spec 間の依存関係解析、DAG 構築 (単一 Spec も 1 ノード DAG) |
| `writing-spec` | Brainstorming ノートから 7 章 Spec 生成、レビュー指摘対応モード |
| `spec-review` | Spec の 3 観点 (完全性 / 実現可能性 / 整合性) 自動レビュー |
| `writing-plan` | Spec → 技術設計 + タスク分解 (main 側 `specs/<spec>.plan.md` 配置) |
| `spec-leader` | Isolate → Implement → Verify → Code Review → ship の 5 ステージ制御 |
| `tdd-driver` | TDD サイクル (Red → Green → Refactor) 強制 |
| `verification-before-completion` | 完了前の 4 カテゴリ検証強制 (test / lint / type / 手動 AC) |
| `receiving-code-review` | 3 reviewer 結果の集約 + Plan への T-fix 追加 + 修正ループ |
| `cross-model-review` | 外部モデル (Codex / GPT / Gemini) による独立レビュー |
| `learn` | ship 後の振り返り (Keep / Problem / Try 具体パッチ案) |
| `orchestrator` | 複数 Spec 統括 (DAG 順の spec-leader 逐次起動 + merge 順序制御) |

加えて会話モード系 skill (`genshijin-without-docs`、会話圧縮) が独立系統で提供されます。

### agent (7 種)

| agent | 役割 |
|---|---|
| `developer` | Plan のタスク 1 件を TDD で実装 (allowed_files コントラクト遵守) |
| `verifier` | 4 カテゴリ検証並列実行 + verify-report.md 生成 |
| `code-reviewer` | コード品質観点レビュー |
| `security-reviewer` | セキュリティ観点レビュー (OWASP Top 10 等) |
| `cross-model-reviewer` | 外部モデル経由の独立レビュー |
| `investigator` | codebase / other-plans / dependencies の並列調査 |
| `spec-reviewer` | spec-review 3 観点の独立並列判定 |

### hook (8 種)

| hook | モード | 役割 |
|---|---|---|
| SessionStart (`load-session-skills.sh`) | context 注入 | skill インデックス常駐 + genshijin 全文 |
| PreToolUse (`pre-tool-use-tdd.sh`) | **ブロック** | worktree 内で実装ファイル編集前のテスト存在を強制 |
| PostToolUse (`post-tool-use-auto-test.sh`) | warning | テストファイル変更時の自動テスト実行 |
| Stop (`stop-verify-before-completion.sh`) | warning | 完了宣言前の verify-report.md + verdict: pass 確認 |
| InstructionsLoaded (`instructions-loaded-context.sh`) | context 注入 | CLAUDE.md / specs/*.md ロード時に関連ファイル提示 |
| WorktreeCreate (`worktree-create-init.sh`) | 自動処理 | Spec/Plan/Review の worktree 自動コピー + progress.md 初期化 |
| WorktreeRemove (`worktree-remove-check.sh`) | 警告 + backup | 削除前の確認 + progress.md の archive バックアップ |
| TaskCompleted (`task-completed-progress.sh`) | 自動処理 | worktree 内 progress.md へのタスク完了ログ追記 |

## ディレクトリ構成

```
~/my-workflows/
├── README.md                         # 本ファイル
├── LICENSE                           # MIT License
├── CLAUDE.md                         # Claude Code へのガイダンス
├── ROADMAP.md                        # Phase 1〜6 の段階的構築計画
├── tools/                            # ドッグフーディング成果物 (tmux ダッシュボード 2 スクリプト)
├── tests/                            # tools/ のテスト (bash 構文 + エラーパス 10 ケース)
├── specs/                            # Spec 作業領域
│   └── archive/                      # ship 済 Spec の集約 (tmux-dashboard-mvp.* 9 ファイル)
├── docs/
│   ├── workflow.md                   # ワークフロー定義
│   ├── components-map.md             # skill/agent/hook 俯瞰 (Mermaid 図 + 使用ツール)
│   ├── glossary.md                   # 用語集
│   ├── frameworks.md                 # 参考フレームワーク一覧
│   ├── phase3-completion.md          # Phase 3 完了レポート
│   ├── phase4-completion.md          # Phase 4 完了レポート
│   ├── phase5-completion.md          # Phase 5 完了レポート
│   ├── phase6-progress.md            # Phase 6 進捗レポート (中間)
│   ├── hookify-setup.md              # hookify プラグイン導入ガイド
│   ├── memory-operation.md           # Claude Code auto memory 運用方針
│   ├── best-practices.md             # 利用例 + ハマりどころ + 他プロジェクト持ち込みガイド + FAQ
│   ├── tmux-dashboard-operation.md   # tmux ダッシュボード運用ガイド (ドッグフーディング成果)
│   └── genshijin.md                  # genshijin モード使い方メモ
├── hooks/                            # 8 hook スクリプト + statusline
├── agents/                           # 7 agent 定義
└── skills/
    ├── <skill-name>/
    │   ├── SKILL.md
    │   └── evals/evals.json
    └── <skill-name>-workspace/       # eval 実行結果 (.gitignore 除外)
```

## 配置方法

開発はこのリポジトリ内で行い、`~/.claude/skills/` / `~/.claude/agents/` にシンボリックリンクで公開します:

```bash
# 全 skill / agent を一括で公開
for s in $(ls skills/ | grep -v workspace); do
  ln -sfn ~/my-workflows/skills/$s ~/.claude/skills/$s
done

for a in agents/*.md; do
  base=$(basename "$a")
  ln -sfn ~/my-workflows/agents/$base ~/.claude/agents/$base
done
```

hook は `.claude/settings.json` (project local、commit 済) で登録されており、本リポジトリ内で Claude Code を起動すれば自動有効化されます。

## 利用開始

### 単一 Spec を開発する場合

1. 「要件をまとめたい」「機能を追加したい」と発話 → `brainstorming` skill が起動
2. 要件が固まったら自動で `spec-dag-builder` → `writing-spec` → `spec-review` → `writing-plan` → `spec-leader` へ連鎖
3. `spec-leader` が Isolate → Implement → Verify → Code Review → ship を統括
4. ship 完了後、`learn` skill で振り返りと改善提案

### 複数 Spec を並列開発する場合 (Phase 5)

1. `brainstorming` で Spec を分割
2. `spec-dag-builder` が DAG 生成
3. `orchestrator` skill が DAG 順に `spec-leader` を逐次起動
4. 各 Spec ship 後に統合

詳細は `docs/components-map.md` の自動起動チェーン図を参照してください。

### さらに詳しく

初めて使う方は以下の順で読むのがお勧めです。

1. **`docs/best-practices.md`**: 12 skill の利用例、ハマりどころ集、Phase 4 hook 連携、他プロジェクトへの持ち込みガイド、FAQ
2. **`docs/components-map.md`**: skill / agent / hook の関係と全自動起動チェーンの Mermaid 図
3. **`docs/workflow.md`**: 9 ステージ + 3 層階層のワークフロー定義
4. **`specs/archive/tmux-dashboard-mvp.learn.md`**: 最初のドッグフーディング振り返り (Keep / Problem / Try 具体例)
5. **`docs/tmux-dashboard-operation.md`**: 上記ドッグフーディングで作成したツールの運用ガイド

## 参考フレームワーク

本プロジェクトは以下を参考にしています (優先度順):

1. **superpowers**: skill 核設計 (相互参照・SessionStart hook・pushy description)
2. **spec-kit**: 仕様駆動のフェーズ設計 (Specify → Plan → Tasks)
3. **claude-scrum-team**: 長時間タスク可視化・phase gate・cross-model review
4. **oh-my-claudecode**: Agent Teams と trigger phrase 設計
5. **gstack**: 役割分離の粒度
6. **everything-claude-code**: 大規模化時の組織化

各フレームワークの取捨選択方針は `docs/frameworks.md` を参照してください。

## ライセンス

[MIT License](LICENSE) で公開しています。商用利用 / 改変 / 再配布すべて自由です。`LICENSE` ファイル内の著作権表示とライセンス文を保持することのみ条件としてください。

## 貢献 / フォーク

本プロジェクトは「個人用の Claude Code 環境最適化」を目的としています。Fork や改変は自由ですが、本プロジェクト自身の設計思想「Fork しない (既存プラグインを直接改変せず、参考にしながら独自のワークフローを定義)」を踏まえ、参考資料としての利用を推奨します。
