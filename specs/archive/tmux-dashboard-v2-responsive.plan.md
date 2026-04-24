---
name: tmux-dashboard-v2-responsive
spec_path: specs/tmux-dashboard-v2-responsive.md
status: archived
created: 2026-04-24
---

# Plan: tmux-dashboard-v2-responsive

## 1. 技術設計概要

`tools/dashboard-pane.sh` の `render_spec()` 内で pane 幅を取得し、幅に応じて stages テーブルのレンダリング関数を 3 種 (wide / narrow / compact) に分岐させます。幅取得は 4 段フォールバック (`DASHBOARD_FAKE_COLS` → `$COLUMNS` → `tput cols` → 80)、分岐しきい値は 60 カラム / 40 カラム。既存の `render_spec()` 実装は wide モードと同一出力になるよう移植し、既存 14 テストが `DASHBOARD_FAKE_COLS` 未設定で `$COLUMNS ≥ 60` → wide 分岐で pass 維持する設計です。

## 2. アーキテクチャ

### 2.1 コンポーネント構成 (改修のみ、新規ファイルなし)

```
tools/
├── dashboard.sh         (変更なし)
└── dashboard-pane.sh    (改修対象、+ 30-40 行想定)
    ├── get_pane_cols()          新規: 4 段フォールバックで幅取得
    ├── render_stages_wide()     新規: 従来の 4 列テーブル (現行 render_spec 内の tsv → printf ブロックを切り出し)
    ├── render_stages_narrow()   新規: 2 列 (stage / status)
    ├── render_stages_compact()  新規: 1 列 (stage=status)
    └── render_spec()            改修: get_pane_cols → モード判定 → render_stages_* を呼ぶ

tests/
└── test_dashboard.sh    改修: T-test-9 (モード切替) + T-test-10 (fallback + 不正値) を追加
```

### 2.2 データフロー

```
render_spec()
  ↓ get_pane_cols() → $cols
  ↓ 判定: $cols >= 60 → wide
           $cols >= 40 → narrow
           otherwise  → compact
  ↓ 対応する render_stages_*() を呼ぶ
```

### 2.3 依存関係

- 既存依存: `jq` / `tput` / `awk` / `tail` / bash 4+
- 新規依存: なし (`tput` は既にログ末尾 10 行や ensure_jq で前提)

## 3. データモデル

変更なし。既存の `progress.json` / `progress.md` / `result.json` の構造をそのまま読み取ります。

## 4. API 設計

### 4.1 内部関数シグネチャ

| 関数 | 引数 | 返り値 / 副作用 |
|---|---|---|
| `get_pane_cols` | (なし) | stdout に幅 (整数) を出力 |
| `render_stages_wide` | $1=progress_json (path) | stdout に 4 列テーブルを出力 |
| `render_stages_narrow` | $1=progress_json (path) | stdout に 2 列テーブルを出力 |
| `render_stages_compact` | $1=progress_json (path) | stdout に 1 列 key=value を出力 |

### 4.2 環境変数

新規: `DASHBOARD_FAKE_COLS` (正の整数、test 用のみ)

## 5. 実装タスク分解

### 5.1 タスクリスト

- [ ] T-1: `tests/test_dashboard.sh` に 3 モード検証ケース (T-test-9a/b/c) + fallback ケース (T-test-10a/b) を Red 先行追加 (見積: 30 分)
  - 入力: Spec §5 AC-1〜AC-8
  - 出力: 5 ケースが実装前に fail することを確認
  - テスト: `bash tests/test_dashboard.sh` で新規 5 ケースが fail、既存 14 ケースは pass のまま
  - **files_touched**: `["tests/test_dashboard.sh"]`

- [ ] T-2: `get_pane_cols` 実装 + `render_stages_wide` リファクタ抽出 (見積: 30 分)
  - 入力: 本 Plan §4.1、Spec §3.1 F-1 の 4 段フォールバック仕様
  - 出力: `get_pane_cols` が `DASHBOARD_FAKE_COLS` > `$COLUMNS` > `tput cols` > 80 の順で幅を返す。`render_stages_wide` は現行 `render_spec()` の 4 列 printf ブロックを関数化 (出力は完全互換)
  - テスト: T-10a (`$COLUMNS` 経路) と T-10b (非数値 `DASHBOARD_FAKE_COLS=abc` で fallback) が pass
  - **files_touched**: `["tools/dashboard-pane.sh"]`

- [ ] T-3: `render_stages_narrow` / `render_stages_compact` 実装 + `render_spec` 分岐 (見積: 40 分)
  - 入力: Spec §3.2 の 3 モード出力例、Spec §3.5 compact 仕様
  - 出力: narrow (2 列) と compact (key=value) のレンダリング関数、`render_spec` が `get_pane_cols` 結果で 3 モード分岐
  - テスト: T-9a (wide) / T-9b (narrow) / T-9c (compact) が pass、既存 14 ケースも pass 維持
  - **files_touched**: `["tools/dashboard-pane.sh"]`

- [ ] T-4: `docs/tmux-dashboard-operation.md` 更新 + 最終 Verify (見積: 20 分)
  - 入力: T-1〜T-3 で書いたスクリプト、Spec §5 AC
  - 出力: docs に 3 モードの説明 + `DASHBOARD_FAKE_COLS` 記述を追記、全 19 テスト (14 + 5) pass 確認、AC-1〜AC-8 を手動で 1 周
  - テスト: `bash tests/test_dashboard.sh` で全 19 ケース pass、AC-8 の docs 記述確認
  - **files_touched**: `["docs/tmux-dashboard-operation.md", "tools/dashboard-pane.sh"]` (docstring 追記分含む)

### 5.2 タスク間の依存関係と並列判定

```
T-1 (Red) → T-2 (Green partial) → T-3 (Green full) → T-4 (docs + final verify)
```

全タスクが逐次依存の TDD サイクル + T-4 が複数ファイルを touch するため、**並列化可能なタスクは存在しません**。Phase 3 の逐次実行で十分。

### 5.3 plan.meta.json の生成

`specs/tmux-dashboard-v2-responsive.plan.meta.json` を Plan 保存直前に生成します (`plan_started_at` は writing-plan 起動直後に `date` で記録、`plan_completed_at` は Plan 保存直前に記録、2026-04-24 Try 5.1 改修準拠)。

## 6. テスト戦略

### 6.1 ユニットテスト (ドライラン、tests/test_dashboard.sh に統合)

| ID | 検証内容 | 対応 AC |
|---|---|---|
| T-test-9a | `DASHBOARD_FAKE_COLS=80` で wide 出力 (4 列) | AC-1 |
| T-test-9b | `DASHBOARD_FAKE_COLS=50` で narrow 出力 (2 列) | AC-2 |
| T-test-9c | `DASHBOARD_FAKE_COLS=30` で compact 出力 (1 列 key=value) | AC-3 |
| T-test-10a | `DASHBOARD_FAKE_COLS` 未設定時は `$COLUMNS` で動作 | AC-4 |
| T-test-10b | `DASHBOARD_FAKE_COLS=abc` / `=0` で fallback 経路に入る | AC-5 |

既存 14 ケース (T-test-1 〜 T-test-8d) は wide 互換を維持するため引き続き pass。

### 6.2 統合テスト (手動)

- AC-1〜AC-7 はユニットテストで検証
- AC-8 の docs 記述確認は Verify ステージで目視

### 6.3 E2E テスト

該当なし (CLI ツールのため)。

## 7. リスクと対応

### 7.1 既存 14 テストの回帰 (Spec §7.3 の技術的具体化)

**内容**: `render_spec()` の改修で既存 wide 出力が変化すると T-test-6 等が fail。

**対応**: T-2 で `render_stages_wide` を現行 `render_spec` の printf ブロックから**切り出す**だけの純粋リファクタにし、出力のバイト一致を `diff` で確認してから T-3 に進む。T-3 で `render_spec` の分岐を追加した後も T-test-6 が pass することを確認ポイントとする。

### 7.2 bash の `$COLUMNS` 未 export 問題

**内容**: 一部の bash 環境では `$COLUMNS` が対話 shell でしか設定されず、`bash script.sh` で呼ばれると空になる。

**対応**: `get_pane_cols` で `${COLUMNS:-}` が空なら次の `tput cols 2>/dev/null` にフォールバック。4 段目の 80 default で最終的に wide に落ちるため、未 export 環境でも既存挙動 (wide) と同じ出力を保証。

### 7.3 `tput cols` が 非対話 TTY で 0 を返す環境

**内容**: CI の `bash -c` 経由などで `tput cols` が `0` を返すと、compact モード (< 40) に誤って落ちる可能性。

**対応**: `get_pane_cols` で tput 結果が 0 以下の場合も fallback (80 default) に落とす。`[[ "$cols" -gt 0 ]]` のガードを入れる。
