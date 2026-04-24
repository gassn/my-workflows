---
name: dashboard-color-themes
spec_path: specs/dashboard-color-themes.md
status: archived
created: 2026-04-24
references_other_plans:
  - specs/dashboard-color.plan.md
---

# Plan: dashboard-color-themes

## 1. 技術設計概要

`dashboard-color` Plan §4.1 で定義された 8 個の `COLOR_*` 変数を**テーマファイル経由で上書き可能** にします。`tools/dashboard-themes/<name>.env` を `source` / `eval` / コマンド置換を一切使わず、行単位 + allowlist + regex + 直接代入の 4 段階で読み込みます (Spec §7.1)。標準テーマ 3 種 (default / solarized-dark / monokai) を同梱し、`DASHBOARD_THEME=<name>` で切替。

本 Plan は先行 `specs/dashboard-color.plan.md` の `print_color()` API 契約 (§4.1) を前提とするため、`references_other_plans` に記載。

## 2. アーキテクチャ

```
tools/
├── dashboard-pane.sh            改修 (+ 約 50 行、load_theme 追加 + print_color の static 定数を $COLOR_* 参照に変更)
│   ├── load_theme()                      新規: テーマファイルを 4 段検証 + 直接代入で読み込み
│   ├── _validate_theme_name()            新規: theme 名 allowlist (path traversal 防止)
│   └── print_color()                     改修: Plan §4.1 の static 定数参照を維持しつつ load_theme 結果で上書き可能に
└── dashboard-themes/            新規ディレクトリ
    ├── default.env              新規
    ├── solarized-dark.env       新規
    └── monokai.env              新規
```

## 3. データモデル

テーマファイルは shell 変数定義形式 (env ファイル)、`COLOR_[A-Z_]+=<ANSI-escape-or-empty>` の行の繰り返し。各変数は dashboard-pane プロセス内でのみ export。

## 4. API 設計

### 4.1 load_theme

先行 Plan §4.1 の `print_color` 契約を壊さない形で、`$COLOR_*` 変数を外部ファイルから上書き可能にする責務です。

```
load_theme <theme-name>
```

| 項目 | 仕様 |
|---|---|
| 引数 $1 | テーマ名 (例: `default`, `solarized-dark`, `monokai`) |
| 副作用 | `$COLOR_COMPLETED` 〜 `$COLOR_RESET` の 8 変数を theme ファイル値で上書き、export |
| stdout | `loaded: <theme-name>` (log 用) |
| 終了コード | 常に 0 (失敗時も default フォールバックで 0) |

### 4.2 環境変数

| 変数 | 値 | 効果 |
|---|---|---|
| `DASHBOARD_THEME` | テーマ名 (default / solarized-dark / monokai / カスタム) | 未指定時は default |

### 4.3 テーマファイル仕様

```bash
# tools/dashboard-themes/default.env
COLOR_COMPLETED='\e[32m'
COLOR_IN_PROGRESS='\e[33m'
COLOR_PENDING=''
COLOR_FAILED='\e[31m'
COLOR_BLOCKED='\e[35m'
COLOR_SHIPPED='\e[36m'
COLOR_ABORTED='\e[31m'
COLOR_RESET='\e[0m'
```

- 変数名 allowlist: `^COLOR_[A-Z_]+$`
- 値 regex: `^(\\e\[[0-9\;]+m)*$` (クォート剥離後)
- 1 件でも違反があればテーマ全体を default にフォールバック

## 5. 実装タスク分解

### 5.1 タスクリスト

- [ ] T-1: tests/test_dashboard.sh にテーマ切替検証ケース (T-test-12a〜12e) を Red 先行追加 (見積: 30 分)
  - 入力: Spec §5 AC-1〜AC-6
  - 出力: 5 ケース (default / solarized-dark / monokai / 不存在 / 不正値) が実装前に fail
  - テスト: 既存 24 ケース (20 + dashboard-color 4) は pass、新規 5 ケースが fail
  - **files_touched**: `["tests/test_dashboard.sh"]`

- [ ] T-2: tools/dashboard-themes/ 3 ファイル + load_theme 実装 (見積: 40 分)
  - 入力: Plan §4.1 load_theme 契約、Spec §7.1 実装イメージ (4 段検証)
  - 出力:
    - `tools/dashboard-themes/default.env` / `solarized-dark.env` / `monokai.env` の 3 ファイル
    - `tools/dashboard-pane.sh` に `load_theme` + `_validate_theme_name` + 呼び出しポイント追加
  - テスト: T-test-12a (default) / 12b (solarized-dark) / 12c (monokai) / 12d (不存在 → default) が pass
  - **files_touched**: `["tools/dashboard-pane.sh", "tools/dashboard-themes/default.env", "tools/dashboard-themes/solarized-dark.env", "tools/dashboard-themes/monokai.env"]`

- [ ] T-3: 不正テーマファイル / path traversal 対応 + AC-5/6 検証 (見積: 30 分)
  - 入力: Spec §5 AC-5 (path traversal) / AC-6 (不正変数混入)
  - 出力: テーマ名 allowlist + 行単位 allowlist の両経路で拒否が動作、1 件でも違反で全体 default フォールバック
  - テスト: T-test-12e (path traversal / 不正変数混入) が pass、security 回帰テスト (悪意ファイルで /tmp マーカー未作成) も追加
  - **files_touched**: `["tools/dashboard-pane.sh", "tests/test_dashboard.sh"]`

- [ ] T-4: docs/tmux-dashboard-operation.md 更新 + 最終 Verify (見積: 25 分)
  - 入力: T-1〜T-3 で書いたスクリプト、Spec §5 AC-9
  - 出力: docs に テーマ一覧 + カスタムテーマ作成手順 + `DASHBOARD_THEME` 環境変数を追記、全 29 テスト (24 + 5) pass 確認
  - **files_touched**: `["docs/tmux-dashboard-operation.md", "tools/dashboard-pane.sh"]`

### 5.2 依存関係

T-1 → T-2 → T-3 → T-4 の逐次実行。全タスクが `tools/dashboard-pane.sh` を touch するため並列化不可。

### 5.3 plan.meta.json

`specs/dashboard-color-themes.plan.meta.json` を生成 (writing-plan Try 5.1 準拠、先行 Plan A を `references_other_plans` に記録)。

## 6. テスト戦略

| ID | 検証内容 | 対応 AC |
|---|---|---|
| T-test-12a | `DASHBOARD_THEME=default` (未指定) で dashboard-color shipped 時と同一出力 | AC-1 |
| T-test-12b | `DASHBOARD_THEME=solarized-dark` で Solarized 配色識別可能 | AC-2 |
| T-test-12c | `DASHBOARD_THEME=monokai` で Monokai 配色識別可能 | AC-3 |
| T-test-12d | `DASHBOARD_THEME=nonexistent` で警告 + default フォールバック + exit 0 | AC-4 |
| T-test-12e | `DASHBOARD_THEME=../evil` で allowlist 違反拒否 + PWN_MARKER 未作成 (回帰) | AC-5/6 |

## 7. リスクと対応

### 7.1 先行 Spec の `print_color` API 変更リスク

**内容**: `dashboard-color` ship 後に `print_color` の signature が変わると、本 Plan の前提が崩れる。

**対応**: `references_other_plans: [specs/dashboard-color.plan.md]` で依存を明示、spec-leader Isolate ステージで `specs/archive/dashboard-color.plan.md` を worktree にコピーして参照可能にする。ship 後は archive 済のため、本 Plan 実装中に先行 Spec の再改修が入った場合は再 Review 対象とする。

### 7.2 Solarized / Monokai の色値選定

**内容**: 各テーマの ANSI 色コード選定は主観 (背景色との相性次第)。

**対応**: 標準的な参照 (Solarized の「Precision colors for machines and people」配色、Monokai の 16 色 palette) に基づく変換表を `tools/dashboard-themes/<name>.env` のコメントに明記し、実装レビュー時に根拠を確認可能にする。実環境での見映えは第三者フィードバック次第で調整 (Phase 6 バッチ 2 以降の learn で扱う)。
