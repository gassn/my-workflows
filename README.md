# my-workflows

オリジナルの Claude Code 環境構築プロジェクトです。既存の優れたフレームワーク群を参考にしつつ、自分の開発スタイルに最適化された skills / agents / hooks / commands を段階的に構築していきます。

## 設計思想

- **Fork しない**: 既存プラグインを直接改変せず、参考にしながら独自のワークフローを定義します。
- **段階的構築**: いきなり大規模な仕組みを目指さず、小さな skill から始めて検証と改善のサイクルを回します。
- **自分専用の最適化**: 一般向けフレームワークが含む冗長な指示を削ぎ、個人の開発習慣と合致する挙動を作ります。
- **資産化**: ドキュメントやコードコメントは将来の自分が読む資産として丁寧に維持します。

## ディレクトリ構成

```
~/my-workflows/
├── README.md             # 本ファイル
├── ROADMAP.md            # 開発ロードマップ
├── docs/
│   ├── genshijin.md      # genshijin 使い方メモ
│   └── frameworks.md     # 参考フレームワーク一覧
└── skills/
    └── genshijin-without-docs/  # 第1号 skill (会話圧縮、ドキュメントは丁寧維持)
        ├── SKILL.md
        └── evals/
```

## 配置方法

開発はこのリポジトリ内で行い、`~/.claude/skills/` にシンボリックリンクで公開します。

```bash
ln -sfn ~/my-workflows/skills/<skill-name> ~/.claude/skills/<skill-name>
```

## ライセンス

個人利用プロジェクトのため、現時点ではライセンス未定です。
