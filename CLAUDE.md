# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクトの性質

このリポジトリは Claude Code 環境を個人用に最適化するための skills / agents / hooks / commands を段階的に構築するプロジェクトです。**コード実行基盤ではなく、Claude Code 自体を拡張する定義ファイル群** を管理します。ビルド・テストフレームワーク・パッケージマネージャは使用していません。

## 現在の状態 (2026-04-23 時点)

- **Phase 1 (基礎整備)**: ✅ 完了
- **Phase 2 (ワークフロー骨子定義)**: ✅ 完了
- **Phase 3 (skill + agent 実装 + eval)**: ✅ 完了 (12 skill / 7 agent、iter-3/4/5 統合完走 shipped)
- **Phase 4 (hook 自動化)**: ✅ 完了 (5 hook 実装 + hookify 方針確定)
- **Phase 5 (orchestrator + 並列実行)**: ✅ 実質完了 (orchestrator skill + 3 hook + 2 agent、Agent Teams 多階層禁止対応込み)
- **Phase 6 (統合改善 + 公開検討)**: 🚧 着手中 (ドキュメント整備 / ドッグフーディング / 公開準備)

詳細は各 Phase 完了レポート (`docs/phase3-completion.md` / `docs/phase4-completion.md` / `docs/phase5-completion.md`) と `ROADMAP.md` を参照してください。

## 設計思想 (README.md より)

- **Fork しない**: 既存プラグインを直接改変せず、参考にしながら独自のワークフローを定義する
- **段階的構築**: 大規模な仕組みを一度に目指さず、小さな skill から検証・改善サイクルを回す
- **自分専用の最適化**: 一般向けフレームワークの冗長な指示を削ぎ、個人の開発習慣に合わせる
- **自動化は skill が成熟してから**: 早すぎる hook 化は挙動の制御を失わせる (Phase 4 で skill → hook の順に段階化)
- **fallback 設計の予防投資**: 不確実な技術前提 (例: Agent Teams 多階層) には ROADMAP に fallback を明記、判明時の転換コストを最小化

## ディレクトリ構造

```
~/my-workflows/
├── README.md                          # プロジェクト概要と設計思想 (公開向け)
├── ROADMAP.md                         # Phase 1〜6 の段階的構築計画
├── CLAUDE.md                          # 本ファイル (Claude Code へのガイダンス)
├── docs/
│   ├── workflow.md                    # 開発ワークフロー定義 (9 ステージ + 3 層階層)
│   ├── components-map.md              # skill + agent + hook の俯瞰 (Mermaid 図 + 使用ツール + worktree 4 系統比較)
│   ├── glossary.md                    # 用語集 (Project Phase / Workflow Stage / Release Phase / Spec)
│   ├── frameworks.md                  # 参考フレームワーク一覧と取捨選択方針
│   ├── genshijin.md                   # genshijin モードの使い方メモ
│   ├── hookify-setup.md               # hookify プラグイン導入ガイド (Phase 6 で有効化予定)
│   ├── memory-operation.md            # Claude Code auto memory の本プロジェクト運用方針
│   ├── phase3-completion.md           # Phase 3 完了レポート
│   ├── phase4-completion.md           # Phase 4 完了レポート
│   └── phase5-completion.md           # Phase 5 完了レポート
├── hooks/                             # 9 スクリプト (Phase 4-5 実装 hook 8 種 + statusline)
├── agents/                            # 7 agent (subagent 定義、frontmatter + プロンプト)
└── skills/
    ├── <skill-name>/
    │   ├── SKILL.md                   # skill 本体 (frontmatter + 本文)
    │   └── evals/evals.json           # skill の評価セット (skill-creator 互換)
    └── <skill-name>-workspace/        # skill-creator が生成する eval 実行結果 (.gitignore で除外)
```

## skill / agent / hook の全体像

詳細は **`docs/components-map.md`** に集約されています (Mermaid 関係図 + 各 skill / agent / hook の説明 + 使用ツール / コマンドマトリクス + Phase 別進化)。

簡略サマリ:

- **skill 12 種**: Brainstorming → DAG 構築 → Spec → Spec Review → Plan → Isolate → Implement → Verify → Code Review → ship → Learn の 9 ステージカバー + orchestrator (複数 Spec 統括) + genshijin-without-docs (会話圧縮)
- **agent 7 種**: spec-leader 配下の worker 5 種 (developer / verifier / code-reviewer / security-reviewer / cross-model-reviewer) + Phase 5 新設 2 種 (investigator / spec-reviewer)
- **hook 8 種**: SessionStart / PreToolUse (TDD 強制) / PostToolUse (自動テスト) / Stop / InstructionsLoaded / WorktreeCreate / WorktreeRemove / TaskCompleted

## skill / agent の配置と有効化

開発はリポジトリ内で行い、`~/.claude/skills/` / `~/.claude/agents/` へシンボリックリンクで公開します:

```bash
ln -sfn ~/my-workflows/skills/<skill-name> ~/.claude/skills/<skill-name>
ln -sfn ~/my-workflows/agents/<agent-name>.md ~/.claude/agents/<agent-name>.md
```

`-workspace` ディレクトリは skill-creator の iteration 出力で、skill 本体ではないためリンク対象外です (.gitignore で除外済)。

### SKILL.md 作成時の frontmatter

各 skill は最低限 `SKILL.md` を持ち、冒頭に以下の frontmatter を含みます:

```markdown
---
name: <skill-name>
description: >
  起動条件・効果・用途を 1〜3 文で記述。トリガーフレーズや強度オプションもここに書く。
---
```

`description` は将来の Claude が skill を選ぶ判断材料なので、**起動すべき状況を具体的に** 書きます (superpowers の「pushy な description」方針)。

eval セット (`evals/evals.json`) は skill-creator 互換形式で、`id` / `prompt` / `expected_output` / `files` を持ちます。

## 参考フレームワークの優先順位 (docs/frameworks.md より)

新規 skill / agent を設計する際の参照順:

1. **superpowers**: skill 核設計 (相互参照・SessionStart hook・pushy description)
2. **spec-kit**: 仕様駆動のフェーズ設計 (Specify → Plan → Tasks)
3. **claude-scrum-team**: 長時間タスク可視化・phase gate・cross-model review
4. **oh-my-claudecode**: Agent Teams と trigger phrase 設計
5. **gstack**: 役割分離の粒度
6. **everything-claude-code**: 大規模化時の組織化

## ドキュメント記述のルール

`.md` ファイルは `genshijin-without-docs` skill の対象外です。**常に通常の丁寧な日本語で記述** してください (「です/ます」体、完結した文章)。コードコメント・コミットメッセージ・PR 本文も同様です。圧縮モードは会話返答のみに適用します。

## Git 運用

- **main ブランチで直接作業** しています (Phase 6 でブランチ戦略を整理予定)
- コミットメッセージは**日本語**で記述
- コミットメッセージは「タイトル行 + 本文」形式、本文で変更理由・影響範囲・検証結果を説明

## Claude Code の worktree 採用方針

本プロジェクトでは `git worktree add` (Bash) を主要手段として採用し、`EnterWorktree` / `Agent isolation:"worktree"` / `WorktreeCreate hook` は補助的・特定シナリオでの利用に限定します。判断基準と 4 系統比較は `docs/components-map.md §8.3.1` を参照してください。

## memory 運用

Claude Code の auto memory (`~/.claude/projects/.../memory/`) は本プロジェクトでは現状**未使用**。設計知識は docs/ / SKILL.md / ROADMAP に集約することで、将来セッション / 第三者にも参照可能にする方針です。詳細は `docs/memory-operation.md` を参照してください。

## Phase 進捗の最新状況を知りたい時

以下の順で参照:

1. **ROADMAP.md**: 全 Phase の目標と完了項目
2. **docs/phase<N>-completion.md** (N=3,4,5): 各 Phase の完了レポート (実装詳細 + 動作検証 + 知見)
3. **docs/components-map.md**: skill / agent / hook の現在地
4. **docs/workflow.md**: ワークフロー定義
