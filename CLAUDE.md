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

### Phase 3 ワークフロー skill (2026-04 時点、5/11 完了)

ワークフロー (`docs/workflow.md`) に沿って実装中の skill 群です。Brainstorming → DAG 構築 → Spec → Spec Review → Isolate → Plan → Implement → Verify → Code Review → ship → Learn の 9 ステージをカバーします。

**実装済 (5 skill)**:

- `brainstorming` — Spec 前の必須ヒアリング起点。Spec 分割提案 + コードベース精査機能も含む。eval iteration-2 で with_skill 100% / without_skill 65% (Delta +35%) を確認済み
- `spec-dag-builder` — 複数 Spec の依存関係解析、DAG 構築 (段階的アップデート方式、循環検出)。eval iteration-1 で 5 ケース全通過 (100%)
- `writing-spec` — Brainstorming ノートから 7 章 Spec 生成、archive 移動、DAG 順処理。eval iteration-1 で with_skill 100% (18/18) / without_skill 62.5% (10/16) / Delta +37.5pt を確認済み。§11 で spec-review を自動起動、§13 でレビュー指摘対応モードに対応
- `spec-review` — AI による Spec 自動レビュー (完全性 / 実現可能性 / 整合性の 3 観点を main agent で順次実行、Phase 5 で agent 3 並列化)。verdict (pass / needs-fix / reject) を specs/<spec-name>.review.md に出力。needs-fix / reject 時は writing-spec をレビュー指摘対応モードで自動再起動。**eval iteration-1 未実施**
- `spec-leader` — Isolate → Plan → Implement → Verify → Code Review → ship の 6 ステージ遷移制御。単独動作可能、入力 spec_path / 出力 progress.json + result.json の Phase 5 orchestrator 連携インタフェースを確定済み。Phase 3 初期は Isolate で作動 → Plan で writing-plan 未実装のため blocked (verdict: paused) が標準動作。iteration-1 は限定テスト (前提条件 / Isolate / 未実装検出 / 再開モード) を実施

**未実装 (6 skill)**:

- `writing-plan` (技術計画 + タスク分解)
- `tdd-driver` (テスト先行強制)
- `verification-before-completion` (完了前検証強制)
- `receiving-code-review` (レビュー指摘対応)
- `cross-model-review` (Codex 等の独立モデルレビュー)
- `learn` (振り返り + 改善提案)

**設計方針**: specLeader は Phase 5 の orchestrator から呼ばれる前提のインタフェース (入力: spec ファイルパス、出力: 進捗ファイル + 結果ファイルパス) を Phase 3 時点で確定し、Phase 5 で改修不要にします。

新しい skill を設計する際は `docs/workflow.md` でステージ位置を確認し、`docs/glossary.md` の用語定義に従ってください。

## ドキュメント記述のルール

`.md` ファイルは genshijin-without-docs skill の対象外です。**常に通常の丁寧な日本語で記述** してください (「です/ます」体、完結した文章)。コードコメント・コミットメッセージ・PR本文も同様です。圧縮モードは会話返答のみに適用します。

## Git 運用

- main ブランチで直接作業しています (Phase 6 で公開を検討するまでブランチ戦略は未確立)
- コミットメッセージは日本語で記述
