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
│   └── frameworks.md                  # 参考フレームワーク一覧と取捨選択方針
└── skills/
    ├── <skill-name>/
    │   ├── SKILL.md                   # skill 本体 (frontmatter + 本文)
    │   └── evals/evals.json           # skill の評価セット (skill-creator 互換)
    └── <skill-name>-workspace/        # skill-creator が生成する eval 実行結果 (iteration ごと)
        └── iteration-N/eval-X-.../
            ├── with_skill/outputs/    # skill 有効時の出力
            └── without_skill/outputs/ # skill 無効時の比較出力
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

## 既存 skill: genshijin-without-docs

会話返答を圧縮 (トークン約75%削減) しつつ、**ドキュメント・コードコメント・コミットメッセージ・PR・.md ファイル** は通常の丁寧な日本語を維持する skill です。強度は `丁寧 / 通常 / 極限 (デフォルト)` の3段階。

この skill を modify する際は `skills/genshijin-without-docs/evals/evals.json` の3ケース (会話返答 / README作成 / JSDocコメント) で回帰を確認してください。

## ドキュメント記述のルール

`.md` ファイルは genshijin-without-docs skill の対象外です。**常に通常の丁寧な日本語で記述** してください (「です/ます」体、完結した文章)。コードコメント・コミットメッセージ・PR本文も同様です。圧縮モードは会話返答のみに適用します。

## Git 運用

- main ブランチで直接作業しています (Phase 6 で公開を検討するまでブランチ戦略は未確立)
- コミットメッセージは日本語で記述
