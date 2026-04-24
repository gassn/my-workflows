---
name: dashboard-color
status: spec-complete
created: 2026-04-24
depends_on: []
parallel_group: 1
brainstorming_archive: "none (source: Phase 6 バッチ 2 (c) 複数 Spec 並列実行検証の先行 Spec、Agent Teams 実効検証ドッグフーディング題材として起こした独立 Spec。A → B の DAG 順実行を検証する設計)"
---

# Spec: dashboard-color

## 1. 目的

`tools/dashboard-pane.sh` の 3 モード (wide / narrow / compact) すべてで、status に応じた **ANSI カラー付与** を実装します。現状は status 値が単色で表示されるため、9 pane 超の narrow / compact モードで個々の Spec の完了状況を視認するのに時間がかかります。カラー付与により、一瞥で completed / in_progress / failed / pending の比率が分かるダッシュボードを目指します。

本 Spec は Phase 6 バッチ 2 (c) 複数 Spec 並列実行検証の**先行 Spec (依存なし)** です。後続の `dashboard-color-themes` Spec は本 Spec の `print_color()` ヘルパー関数を前提に実装されるため、Plan で API 契約を明確化する必要があります。

## 2. スコープ

### 2.1 含むもの

- `tools/dashboard-pane.sh` に `print_color()` ヘルパー関数追加 (status → ANSI color code)
- `render_stages_wide` / `render_stages_narrow` / `render_stages_compact` の 3 レンダラすべてで status セル をカラー出力
- 環境変数 `DASHBOARD_NO_COLOR=1` でカラー無効化 (CI / パイプ用)
- `tests/test_dashboard.sh` に カラー検証ケース追加
- `docs/tmux-dashboard-operation.md` の更新

### 2.2 含まないもの

- stage / started_at / completed_at カラムのカラー付与 (status のみ対象)
- ヘッダ / result セクション / progress.md ログ末尾 10 行のカラー付与
- ユーザーカスタムテーマ (後続 `dashboard-color-themes` Spec のスコープ)
- 256 色 / truecolor 対応 (8 色の ANSI コードで固定)

## 3. 機能要件

### 3.1 print_color ヘルパー関数 (F-1)

**シグネチャ**: `print_color <status> [<visible-width>]`

**動作**:

- 引数 `status` (例: `completed` / `in_progress` / `pending` / `failed` / `blocked`) に対応する **ANSI エスケープ開始コード + status 文字列 + reset コード** を `printf` で stdout に出力 (**末尾改行は付けない**)
- オプション引数 `visible-width` が指定された場合、ANSI エスケープを巻く前に status を `printf "%-${width}s"` で**可視長ベースで左詰めパディング** してから色を重ねる (wide / narrow モードの列整列用、Major 対応)
- `DASHBOARD_NO_COLOR=1` または `NO_COLOR=1` が設定されていれば、ANSI エスケープなしでパディング済 status 文字列のみ出力
- 標準出力が TTY でない場合 (パイプ / リダイレクト) も ANSI エスケープなし (`[[ -t 1 ]]` で判定)
- `shipped-*` / `aborted-*` の suffix バリエーション (例: `shipped-cross-model-pending` / `aborted-on-resume`) はそれぞれ `shipped` / `aborted` の色にマッピング (prefix 一致、F-1-1 表の「`shipped` / `shipped-*`」欄参照)

**カラーマップ (F-1-1)**:

| status | ANSI 前景色 | エスケープコード |
|---|---|---|
| `completed` | 緑 | `\e[32m` |
| `in_progress` | 黄 | `\e[33m` |
| `pending` | 白 (default) | カラーなし (reset のみ) |
| `failed` | 赤 | `\e[31m` |
| `blocked` | マゼンタ | `\e[35m` |
| `shipped` / `shipped-*` | シアン | `\e[36m` |
| `aborted` / `aborted-*` | 赤 | `\e[31m` |
| その他 (不明値) | default | カラーなし |

**出力例** (末尾改行なし、ここでは可視化のため `⏎` を明示):

```
$ print_color "completed"                      # visible-width 未指定
<ESC>[32mcompleted<ESC>[0m                     (= 9 可視文字、パディングなし)

$ print_color "completed" 12                   # visible-width=12
<ESC>[32mcompleted<ESC>[0m                     (= 9 文字 + 空白 3 = 可視 12、printf -c 後に色重ね)

$ DASHBOARD_NO_COLOR=1 print_color "completed" 12
completed                                      (= 9 文字 + 空白 3、ANSI なし)

$ print_color "shipped-cross-model-pending"    # suffix バリエーション
<ESC>[36mshipped-cross-model-pending<ESC>[0m  (shipped 色 = cyan に prefix 一致)
```

### 3.2 3 レンダラへの適用 (F-2)

**wide モード**: status カラム (12 文字幅) に `print_color "$status" 12` の結果を埋める。事前パディング方式により列アライメントが保たれる (F-1 visible-width 引数)

**narrow モード**: 同様に `print_color "$status" 12`。時刻カラムなしなのでパディング幅は wide と同じ 12

**compact モード**: `stage=print_color "$status"` (visible-width 未指定、1 行 1 ステージの key=value 形式なのでパディング不要)

**エラーハンドリング**:

- jq パース失敗時の「更新中...」フォールバックはカラーなしのまま維持

### 3.3 DASHBOARD_NO_COLOR 環境変数 (F-3)

- `DASHBOARD_NO_COLOR=1` でカラー無効化 (事実上の業界標準 `NO_COLOR=1` にも反応させる)
- 設定されていなくても、stdout が TTY でなければ自動でカラー無効化

### 3.4 既存機能の互換性 (F-4)

- `DASHBOARD_NO_COLOR=1` 指定時、または TTY でない場合の出力は **v2-responsive shipped 版の出力と完全一致**
- 既存 20 テスト (T-test-1 〜 T-test-10c) はパイプ経由 (`bash -c "..."`) のため TTY 判定で自動的に NO_COLOR 扱い、全 pass を維持

## 4. 非機能要件

| 項目 | 要件 |
|---|---|
| パフォーマンス | `print_color` は bash 組み込みのみで 1 呼び出し 1ms 未満 |
| 互換性 | v2-responsive の全 AC (AC-1〜AC-8) が保たれること |
| アクセシビリティ | `DASHBOARD_NO_COLOR=1` で完全にカラー無効化できる (色覚対応) |
| テスト容易性 | ANSI エスケープを含む出力を `grep -E '\x1b\[3[0-9]m'` で検証可能 |

## 5. 受け入れ基準 (AC)

- [ ] AC-1: wide モード (`DASHBOARD_FAKE_COLS=80`) + TTY 想定で、`completed` の行に ANSI 緑 (`\e[32m`) が含まれる **かつ** 後続 `started_at` カラムの開始列位置が wide shipped 版 (v2-responsive iteration 2) と同一バイト位置
- [ ] AC-2: narrow モード (`=50`) + TTY 想定で、status カラムが対応カラーで出力される **かつ** 後続改行までのレイアウトが shipped 版と同一
- [ ] AC-3: compact モード (`=30`) + TTY 想定で、`stage=status` の status 部分がカラー化される
- [ ] AC-4: `DASHBOARD_NO_COLOR=1` **または** `NO_COLOR=1` 指定時、どのモードでも ANSI エスケープが一切出力されない (業界標準 NO_COLOR 対応、F-3)
- [ ] AC-5: 標準出力が TTY でない (パイプ) 場合、ANSI エスケープなしで出力される (自動無効化)
- [ ] AC-6: 既存 20 テスト (T-test-1a 〜 T-test-10c、2026-04-24 時点) が全 pass (NO_COLOR 自動判定で wide 互換維持)
- [ ] AC-7: 新規カラー検証テスト (a: TTY 擬似 × 各主要 status (completed / in_progress / failed / blocked / shipped-cross-model-pending の 5 パターン)、b: NO_COLOR=1 で ANSI 不在、c: NO_COLOR=1 / DASHBOARD_NO_COLOR=1 両方が機能、d: 事前パディング幅保持 (wide 列崩れ防止)) が pass
- [ ] AC-8: `docs/tmux-dashboard-operation.md` に カラーマップ + `DASHBOARD_NO_COLOR` / `NO_COLOR` 記述追加

## 6. 非対象 (スコープ外)

- ユーザー定義カラーテーマ (後続 `dashboard-color-themes` Spec)
- 背景色 / 太字 / 下線などの装飾
- 256 色 / truecolor
- ヘッダ / result / ログ行のカラー付与

## 7. リスクと緩和策

### 7.1 tmux pane が ANSI エスケープを正しくレンダリングしない環境

**内容**: 古い tmux (2.6 未満) や一部のターミナルで ANSI 基本 8 色が正しくレンダリングされない。

**緩和策**: `DASHBOARD_NO_COLOR=1` でユーザーがオプトアウト可能にすることで、環境依存問題を運用でかわせる仕様とします。tmux 2.6+ (Spec §4 互換性要件) は基本 8 色を完全サポートすることが保証されているため、推奨環境では問題なし。

### 7.2 `printf "%-12s"` パディング幅計算が ANSI エスケープ込みで破綻する

**内容**: `printf "%-12s"` は「バイト長 12 未満の場合に空白で右パディング」という動作のため、ANSI エスケープを含む文字列 (例: `\e[32mcompleted\e[0m` = 18 バイト) はパディングされません。結果としてカラム幅はバイト単位で可変になり、後続カラム (started_at 等) の開始位置が wide モードの shipped 版と比べて詰まって見えます (spec-reviewer feasibility-M-1 指摘)。

**緩和策 (Plan 段階で採用する実装方式、§3.1 F-1 の visible-width 引数で表現)**: `print_color` に**事前パディング方式**を導入します。

```bash
# 実装イメージ (Plan 段階で詳細化)
print_color() {
  local status="$1"
  local width="${2:-0}"
  local color_on color_off=""
  # ... カラー選択 (F-1-1 表) ...

  # 事前にパディング済 status を作る (visible-width 基準)
  local padded="$status"
  if [[ "$width" -gt 0 ]]; then
    padded=$(printf "%-${width}s" "$status")
  fi

  # NO_COLOR / TTY 判定
  if [[ "${NO_COLOR:-}" || "${DASHBOARD_NO_COLOR:-}" == "1" || ! -t 1 ]]; then
    printf '%s' "$padded"
  else
    printf '%s%s%s' "$color_on" "$padded" "$color_off"
  fi
}
```

この方式により、`printf "%-12s" "$status"` 相当のパディングは ANSI を巻く前に実施され、ターミナル可視幅が確実に 12 文字になります。compact モードでは visible-width 未指定で単純に ANSI + status を出力。

### 7.3 TTY 判定が誤動作する環境

**内容**: tmux pane 内の bash は TTY として検出されるが、一部の Docker / CI 環境では TTY が false になる。

**緩和策**: `DASHBOARD_NO_COLOR=1` の明示指定を最優先とし、TTY 判定は第二チェックにフォールバック。既存 20 テストは `bash -c` 経由でパイプ出力のため TTY 判定で自動 NO_COLOR になり、wide 互換を維持。
