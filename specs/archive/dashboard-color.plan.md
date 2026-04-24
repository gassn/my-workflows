---
name: dashboard-color
spec_path: specs/dashboard-color.md
status: archived
created: 2026-04-24
---

# Plan: dashboard-color

## 1. 技術設計概要

`tools/dashboard-pane.sh` に `print_color()` ヘルパー関数を追加し、既存の 3 レンダラ (`render_stages_wide` / `render_stages_narrow` / `render_stages_compact`) から呼び出します。ANSI カラーは bash 標準の 8 色 + reset のみを使用、visible-width 引数による事前パディング方式で列アライメントを維持します。`NO_COLOR` / `DASHBOARD_NO_COLOR` / TTY 判定の 3 段階で自動無効化を実装し、既存 20 テスト (`bash -c` 経由でパイプ扱い) は無改修で wide 互換を保つ設計です。

後続 Spec `dashboard-color-themes` が `print_color()` を拡張する前提のため、色コードはマジックナンバーではなく**名前付き変数** (`COLOR_COMPLETED` 等) で管理します。

## 2. アーキテクチャ

```
tools/
└── dashboard-pane.sh    改修 (+ 約 50 行)
    ├── print_color()              新規: status → ANSI 色 + visible-width パディング
    ├── _color_for_status()        新規: status 名 → $COLOR_* 変数の値を返す (内部ヘルパー)
    ├── _is_color_enabled()        新規: NO_COLOR / DASHBOARD_NO_COLOR / TTY 判定
    ├── render_stages_wide()       改修: status セルを print_color "$status" 12 に置換
    ├── render_stages_narrow()     改修: 同上
    └── render_stages_compact()    改修: stage=$(print_color "$status") に置換
```

## 3. データモデル

変更なし。既存の `progress.json` / `result.json` / `progress.md` を読み取る経路はそのまま。色情報は shell 変数 (`COLOR_COMPLETED` 等) として dashboard-pane プロセス内のみで保持。

## 4. API 設計

### 4.1 print_color (後続 Spec の前提契約)

```
print_color <status> [<visible-width>]
```

| 項目 | 仕様 |
|---|---|
| 引数 $1 | status 文字列 (例: `completed`, `in_progress`, `shipped-cross-model-pending`) |
| 引数 $2 | optional、visible-width 整数。省略 or 0 はパディングなし |
| stdout | ANSI on + padded_status + ANSI off (末尾改行なし)、または NO_COLOR 時は padded_status のみ |
| 終了コード | 常に 0 (無効値でも fallback で default 色、fail しない) |

**カラー変数 (dashboard-pane.sh の先頭で static 定義、後続 Spec で外部上書き可能)**:

```bash
COLOR_COMPLETED=$'\e[32m'
COLOR_IN_PROGRESS=$'\e[33m'
COLOR_PENDING=''
COLOR_FAILED=$'\e[31m'
COLOR_BLOCKED=$'\e[35m'
COLOR_SHIPPED=$'\e[36m'
COLOR_ABORTED=$'\e[31m'
COLOR_RESET=$'\e[0m'
```

後続 Spec `dashboard-color-themes` は `load_theme` で上記変数を上書き可能。

### 4.2 環境変数

| 変数 | 値 | 効果 |
|---|---|---|
| `NO_COLOR` | 任意の非空文字列 | カラー無効化 (業界標準) |
| `DASHBOARD_NO_COLOR` | `1` | カラー無効化 (本プロジェクト固有) |
| (暗黙) | `! [[ -t 1 ]]` | stdout が TTY でなければカラー無効化 |

## 5. 実装タスク分解

### 5.1 タスクリスト

- [ ] T-1: tests/test_dashboard.sh にカラー検証ケース (T-test-11a〜11d) を Red 先行追加 (見積: 25 分)
  - 入力: Spec §5 AC-4 / AC-5 / AC-7
  - 出力: 4 ケース (NO_COLOR + DASHBOARD_NO_COLOR + 主要 status 5 種 + パディング幅保持) が実装前に fail
  - テスト: 既存 20 ケースは pass、新規 4 ケースが fail
  - **files_touched**: `["tests/test_dashboard.sh"]`

- [ ] T-2: print_color + ヘルパー関数 + カラー変数定数を追加 (見積: 30 分)
  - 入力: Plan §4.1 / Spec §3.1 F-1 / §7.2 実装イメージ
  - 出力: `print_color` / `_color_for_status` / `_is_color_enabled` + 8 個の `COLOR_*` 変数
  - テスト: T-test-11a/b/c が pass
  - **files_touched**: `["tools/dashboard-pane.sh"]`

- [ ] T-3: 3 レンダラから print_color を呼ぶよう改修 (見積: 25 分)
  - 入力: Plan §4.1 / Spec §3.2
  - 出力: render_stages_wide / narrow / compact の status セル部分を print_color に置換、visible-width=12 で wide/narrow、指定なしで compact
  - テスト: T-test-11d (パディング保持) が pass、既存 20 ケースが pass 維持
  - **files_touched**: `["tools/dashboard-pane.sh"]`

- [ ] T-4: docs/tmux-dashboard-operation.md 更新 + 最終 Verify (見積: 20 分)
  - 入力: T-1〜T-3 で書いたスクリプト、Spec §5 AC
  - 出力: docs に カラーマップ + `NO_COLOR` / `DASHBOARD_NO_COLOR` 記述追加、全 24 テスト (20 + 4) pass 確認
  - テスト: `bash tests/test_dashboard.sh` で全 24 ケース pass、docs 記述確認
  - **files_touched**: `["docs/tmux-dashboard-operation.md", "tools/dashboard-pane.sh"]`

### 5.2 依存関係

T-1 → T-2 → T-3 → T-4 の逐次実行。全タスクが同一ファイルを触るため並列化不可。

### 5.3 plan.meta.json

`specs/dashboard-color.plan.meta.json` を生成します (writing-plan Try 5.1 準拠で実時刻 2 回計測)。

## 6. テスト戦略

| ID | 検証内容 | 対応 AC |
|---|---|---|
| T-test-11a | `DASHBOARD_FAKE_COLS=80` + `NO_COLOR=1` / `DASHBOARD_NO_COLOR=1` で ANSI 不在 | AC-4 |
| T-test-11b | パイプ出力 (非 TTY) で自動無効化 | AC-5 |
| T-test-11c | 主要 status (completed / in_progress / failed / blocked / shipped-cross-model-pending) のカラー対応 | AC-1/7a |
| T-test-11d | wide モード status カラムの visible-width 12 維持 (パディング幅保持) | AC-1/7d |

既存 20 ケースは `bash -c` パイプ出力で TTY false → 自動 NO_COLOR → wide 互換で pass 維持。

## 7. リスクと対応

### 7.1 TTY 判定の CI での false negative (Spec §7.3 具体化)

**対応**: `_is_color_enabled` で `DASHBOARD_FORCE_COLOR=1` で TTY 判定を bypass できるオプションを内部実装するかは不要と判断。既存の `DASHBOARD_NO_COLOR=1` でユーザーが明示指定できるため、force-color は YAGNI。

### 7.2 事前パディング方式で ANSI 幅計算が誤動作 (Spec §7.2 具体化)

**対応**: `printf -v padded "%-12s" "$status"` で先にパディング、その後 `printf '%s%s%s' "$color_on" "$padded" "$color_off"` で色を重ねる順序を厳守。コードコメントに「必ずこの順序、逆にすると ANSI エスケープがバイト長に含まれて列崩れ」と明記。
