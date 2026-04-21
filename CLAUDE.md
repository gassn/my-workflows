# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクトの性質

このリポジトリは Claude Code 環境を個人用に最適化するための skills / agents / hooks / commands を段階的に構築するプロジェクトです。**コード実行基盤ではなく、Claude Code 自体を拡張する定義ファイル群** を管理します。ビルド・テストフレームワーク・パッケージマネージャは使用していません。

## 設計思想 (README.md より)

- **Fork しない**: 既存プラグインを直接改変せず、参考にしながら独自のワークフローを定義する
- **段階的構築**: 大規模な仕組みを一度に目指さず、小さな skill から検証・改善サイクルを回す
- **自分専用の最適化**: 一般向けフレームワークの冗長な指示を削ぎ、個人の開発習慣に合わせる
- 自動化 (hook) は skill が十分に成熟してから導入する — 早すぎる自動化は挙動の制御を失わせる

## ディレクトリ構造

```
~/my-workflows/
├── README.md                          # プロジェクト概要と設計思想
├── ROADMAP.md                         # Phase 1〜6 の段階的構築計画
├── docs/
│   ├── genshijin.md                   # genshijin モードの使い方メモ
│   ├── frameworks.md                  # 参考フレームワーク一覧と取捨選択方針
│   ├── workflow.md                    # 開発ワークフロー定義 (9 ステージ + 3 層階層)
│   └── glossary.md                    # 用語集 (Project Phase / Workflow Stage / Release Phase / Spec)
├── hooks/                             # 既存スクリプト (SessionStart 等、Phase 4 で本格統合予定)
├── agents/                            # subagent 定義 (Phase 3 で 5 種実装、残 3 種は Phase 5)
│   └── <agent-name>.md                # 単一 Markdown ファイル (frontmatter + プロンプト)
└── skills/
    ├── <skill-name>/
    │   ├── SKILL.md                   # skill 本体 (frontmatter + 本文)
    │   └── evals/evals.json           # skill の評価セット (skill-creator 互換)
    └── <skill-name>-workspace/        # skill-creator が生成する eval 実行結果 (.gitignore で除外)
        └── iteration-N/eval-X-.../
            ├── with_skill/outputs/    # skill 有効時の出力
            └── without_skill/outputs/ # skill 無効時の比較出力 (省略時あり)
```

## skill の配置と有効化

開発はリポジトリ内で行い、`~/.claude/skills/` へシンボリックリンクで公開します:

```bash
ln -sfn ~/my-workflows/skills/<skill-name> ~/.claude/skills/<skill-name>
```

`-workspace` ディレクトリは skill-creator の iteration 出力で、skill 本体ではないためリンク対象外です。

## agent の配置と有効化

agent も同様にリポジトリ内で開発し、`~/.claude/agents/` へシンボリックリンクで公開します:

```bash
ln -sfn ~/my-workflows/agents/<agent-name>.md ~/.claude/agents/<agent-name>.md
```

各 agent は単一 Markdown ファイルで、frontmatter (`name` / `description`) と本文 (プロンプト定義) を持ちます。Phase 3 では spec-leader 配下の 5 種 (developer / verifier / code-reviewer / security-reviewer / cross-model-reviewer) を実装しました。残 3 種 (investigator / spec-reviewer / orchestrator) は Phase 5 で対応します。

## skill 作成時の構造

各 skill は最低限 `SKILL.md` を持ち、冒頭に以下の frontmatter を含みます:

```markdown
---
name: <skill-name>
description: >
  起動条件・効果・用途を1〜3文で記述。トリガーフレーズや強度オプションもここに書く。
---
```

`description` は将来の Claude が skill を選ぶ判断材料なので、**起動すべき状況を具体的に** 書きます (superpowers の「pushy な description」方針)。

eval セット (`evals/evals.json`) は skill-creator 互換形式で、`id` / `prompt` / `expected_output` / `files` を持ちます。

## 参考フレームワークの優先順位 (docs/frameworks.md より)

新規 skill を設計する際の参照順:

1. **superpowers**: skill 核設計 (相互参照・SessionStart hook・pushy description)
2. **spec-kit**: 仕様駆動のフェーズ設計 (Specify → Plan → Tasks)
3. **claude-scrum-team**: 長時間タスク可視化・phase gate・cross-model review
4. **oh-my-claudecode**: Agent Teams と trigger phrase 設計
5. **gstack**: 役割分離の粒度
6. **everything-claude-code**: 大規模化時の組織化

## 既存 skill

### genshijin-without-docs

会話返答を圧縮 (トークン約75%削減) しつつ、**ドキュメント・コードコメント・コミットメッセージ・PR・.md ファイル** は通常の丁寧な日本語を維持する skill です。強度は `丁寧 / 通常 / 極限 (デフォルト)` の3段階。

この skill を modify する際は `skills/genshijin-without-docs/evals/evals.json` の3ケース (会話返答 / README作成 / JSDocコメント) で回帰を確認してください。

### Phase 3 ワークフロー skill (2026-04 時点、11/11 完了)

ワークフロー (`docs/workflow.md`) に沿って実装中の skill 群です。Brainstorming → DAG 構築 → Spec → Spec Review → Isolate → Plan → Implement → Verify → Code Review → ship → Learn の 9 ステージをカバーします。

**実装済 (11 skill)**:

| # | skill | 役割 | eval 状態 |
|---|---|---|---|
| 1 | `brainstorming` | Spec 前の必須ヒアリング起点。Spec 分割提案 + コードベース精査 | iteration-2 完了 (with 100% / without 65% / Delta +35pt) |
| 2 | `spec-dag-builder` | 複数 Spec の依存関係解析、DAG 構築 (段階的アップデート、循環検出) | iteration-1 完了 (5/5 通過) |
| 3 | `writing-spec` | Brainstorming ノートから 7 章 Spec 生成、archive 移動、DAG 順処理、§13 レビュー指摘対応モード | iteration-1 完了 (with 100% / without 62.5% / Delta +37.5pt) |
| 4 | `spec-review` | Spec 自動レビュー (完全性 / 実現可能性 / 整合性の 3 観点、main agent 順次実行 → Phase 5 で agent 3 並列化)、writing-spec 自動再起動 | iteration-1 + iteration-2 完了、全 5 ケース pass (100%)。3 verdict (pass/needs-fix/reject) 各 2 回、整合性コードベース走査 (意図的問題 7/7 検出)、再レビューサイクル (前回 Major 3 件解消確認) すべて動作確認済 |
| 5 | `spec-leader` | Isolate → ship の 6 ステージ遷移制御。Phase 5 orchestrator 連携インタフェース確定済 | iteration-1 (3 ケース) + iteration-2 (2 ケース) 完了、全 5/5 pass (100%)。git worktree 実動作 / 再開モード / 前提条件違反 の全系統確認済 |
| 6 | `writing-plan` | Plan ステージ: spec.md → plans/<spec-name>.md、技術設計 + タスク分解 (チェックボックス形式) | iteration-1 主要 3 ケース完了 (basic / existing / not-worktree すべて 100%、9/9 pass) |
| 7 | `tdd-driver` | Implement ステージ: TDD 強制 (Red → Green → Refactor)、Phase 4 で PreToolUse hook 化予定 | iteration-1 完了 (basic / antipattern 2/2 pass) |
| 8 | `verification-before-completion` | Verify ステージ: 完了宣言前の全検証 (test / lint / type / 手動 AC) 強制、Phase 4 で Stop hook 化予定 | iteration-1 完了 (basic / antipattern 2/2 pass) |
| 9 | `receiving-code-review` | Code Review 差戻し対応: reviewer 指摘の集約 + Plan タスク追加 + 修正 loop (最大 3 回) | iteration-1 完了 (basic / antipattern 2/2 pass) |
| 10 | `cross-model-review` | Codex / GPT / Gemini 等の独立モデルレビュー、Phase 3 は手動依頼テンプレート | iteration-1 完了 (basic / antipattern 2/2 pass) |
| 11 | `learn` | ship 後の振り返り: 時間配分 / 手戻り / Keep / Problem / Try パッチ案生成 | iteration-1 完了 (basic / antipattern 2/2 pass) |

**設計方針の一貫性**:

- skill 間連携は自動起動 (writing-spec → spec-review → spec-leader → writing-plan → tdd-driver → verification → (Code Review reviewer 群 + cross-model-review) → receiving-code-review → ship → learn)
- specLeader は Phase 5 orchestrator 連携インタフェース (入力 spec_path / 出力 progress.json + result.json) を確定済、Phase 5 で skill 改修不要
- Phase 4 hook 化対応: tdd-driver / verification-before-completion の強制部分は hook 化予定だが skill インタフェースは変更なし
- 下位 skill 未実装時の扱い: spec-leader §16 で blocked 状態を記録、全停止 + ユーザー相談 (Q3 確定)

### Phase 3 agent (2026-04-21 時点、5/8 完了)

**実装済 (5 agent、spec-leader 配下)**:

| # | agent | 役割 | 連携 skill |
|---|---|---|---|
| 1 | `developer` | Plan タスク 1 件を TDD (Red→Green→Refactor) で実装 | tdd-driver |
| 2 | `verifier` | 4 カテゴリ検証 (test / lint / type / 手動 AC) を実行 + verify-report 生成 | verification-before-completion |
| 3 | `code-reviewer` | コード品質レビュー (可読性 / 設計 / 単純性 / 保守性) | receiving-code-review |
| 4 | `security-reviewer` | セキュリティレビュー (OWASP Top 10 + 認証認可 + 入力検証) | receiving-code-review |
| 5 | `cross-model-reviewer` | 外部モデル (Codex / GPT / Gemini) 経由の独立レビュー、Phase 3 は手動依頼運用 | cross-model-review |

**未実装 (3 agent)**:

- `investigator` — コードベース / 依存 / 類似実装調査 (Plan ステージ用、Phase 5 で Brainstorming にも拡張)
- `spec-reviewer` — Spec の 3 観点レビュー agent 並列化 (spec-review skill の Phase 5 版)
- `orchestrator` — 複数 Spec の DAG 管理、specLeader 起動、merge 順序制御 (Phase 5 で実装)

**設計方針**: specLeader は Phase 5 の orchestrator から呼ばれる前提のインタフェース (入力: spec ファイルパス、出力: 進捗ファイル + 結果ファイルパス) を Phase 3 時点で確定し、Phase 5 で改修不要にします。

新しい skill を設計する際は `docs/workflow.md` でステージ位置を確認し、`docs/glossary.md` の用語定義に従ってください。

## ドキュメント記述のルール

`.md` ファイルは genshijin-without-docs skill の対象外です。**常に通常の丁寧な日本語で記述** してください (「です/ます」体、完結した文章)。コードコメント・コミットメッセージ・PR本文も同様です。圧縮モードは会話返答のみに適用します。

## Git 運用

- main ブランチで直接作業しています (Phase 6 で公開を検討するまでブランチ戦略は未確立)
- コミットメッセージは日本語で記述
