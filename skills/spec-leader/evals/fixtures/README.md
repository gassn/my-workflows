# spec-leader eval fixtures

spec-leader の eval (特に iteration-2 以降の git 実動作テスト / iter-3 統合完走テスト) で、毎回手作業で構築していた git repo 初期化 + Spec 配置を 1 コマンドで再現可能にする fixture 構築スクリプトを提供します。

## 背景

`docs/phase3-completion.md §5.3 No.3` の改善提案に基づく整備です。Agent が git 実動作テストを実施する際、`git init + 初期 commit + specs/ 初期配置` を毎回再実行することによる:

- 再現性の低下 (手順の微妙な差が蓄積する)
- CI 化の困難さ (Agent プロンプトに手順が埋まる)
- 実行時間の増加 (Agent の試行錯誤分)

これらを解消するため、本ディレクトリの `setup-git-fixture.sh` で標準化します。

## 使い方

```bash
# 基本 (空の repo + README.md のみ)
bash skills/spec-leader/evals/fixtures/setup-git-fixture.sh <target-dir>

# Spec を同梱 (skills/spec-leader/evals/inputs/specs/ から <name>.md / <name>.review.md をコピー)
bash skills/spec-leader/evals/fixtures/setup-git-fixture.sh <target-dir> --with-spec login
```

### 実行例

```bash
# iter-3 統合完走テスト用に login Spec 付き fixture を /tmp に構築
bash skills/spec-leader/evals/fixtures/setup-git-fixture.sh /tmp/my-test --with-spec login

# 出力例:
# Fixture constructed at: /tmp/my-test
# Branch: master
# HEAD: 3999152 initial fixture commit
# Spec files:
# login.md
# login.review.md
```

## 構築される内容

```
<target-dir>/
├── .git/                    # 初期化済 (user.email / user.name 設定済)
├── README.md                # fixture 識別用
└── specs/                   # 空、または --with-spec で指定した Spec 配置
    ├── <name>.md            # (--with-spec 指定時)
    └── <name>.review.md     # (--with-spec かつ inputs/ に存在する場合)
```

## 想定利用シナリオ

### eval iteration-2 eval 1 (isolate-then-blocked)

Agent に以下のように指示:

```
skills/spec-leader/evals/fixtures/setup-git-fixture.sh $WORKDIR --with-spec login

実行後に spec-leader skill を起動、Isolate → Plan → Implement で blocked
を確認してください。
```

### iter-3 統合完走テスト

同様に fixture で初期 repo を構築した後、skill + agent の連携フローを実行。

## 前提

- Bash 4+ (`set -euo pipefail` を使用)
- git 2.x+
- `skills/spec-leader/evals/inputs/specs/` に対象 Spec ファイル (`<name>.md` / オプションで `<name>.review.md`) が配置済み

## 追加 Spec を使う場合

新しい Spec を fixture 対象に加えたい場合:

1. `skills/spec-leader/evals/inputs/specs/<new-name>.md` を追加
2. (任意) `<new-name>.review.md` も追加
3. `--with-spec <new-name>` で即利用可能

## 制約

- fixture 構築先が既存ディレクトリの場合は error で停止 (破壊的操作の予防)
- `--with-spec` 指定時、inputs/ に対象 Spec が無ければ error で停止
- Spec ファイルの frontmatter や内容検証は本スクリプトでは行わない (skill / agent 側の責務)
