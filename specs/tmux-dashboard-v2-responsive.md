---
name: tmux-dashboard-v2-responsive
status: spec-complete
created: 2026-04-24
depends_on: []
parallel_group: 1
brainstorming_archive: "none (source: specs/archive/tmux-dashboard-mvp.learn.md §5.2 で挙げられた Try 5.2 の派生 Spec、独立した brainstorm.md は経由せず)"
---

# Spec: tmux-dashboard-v2-responsive

## 1. 目的

`tmux-dashboard-mvp` で shipped した `tools/dashboard-pane.sh` は 4 列固定の stages テーブルを表示するため、9 Spec 超の tiled layout や端末幅が狭い環境では改行されて可読性が著しく低下します。実際 `tmux-dashboard-mvp` のドッグフーディングで、ユーザーが狭い pane 表示を見て「verify で止まっている?」と状態を誤認する事故が発生しました (specs/archive/tmux-dashboard-mvp.learn.md §4.2)。

本 Spec は `dashboard-pane.sh` に **pane 幅適応の 3 モードレイアウト** を追加し、狭い pane でも stages の現在状態を 1 行以内で把握できるようにすることを目的とします。

## 2. スコープ

### 2.1 含むもの

- `tools/dashboard-pane.sh` の `render_spec()` 内 stages テーブル表示部分の改修
- pane 幅取得ロジック (F-1 参照、`DASHBOARD_FAKE_COLS` → `$COLUMNS` → `tput cols` → 80 default の 4 段フォールバック)
- 3 モードレイアウト切替 (wide / narrow / compact)
- テスト注入用環境変数 `DASHBOARD_FAKE_COLS` の追加
- `tests/test_dashboard.sh` への 3 モード検証ケース追加
- 関連ドキュメント (`docs/tmux-dashboard-operation.md`) の更新

### 2.2 含まないもの

- `dashboard.sh` 側の tmux layout 制御ロジックの変更
- ヘッダ表示 (`=== <spec-name>  (時刻) ===`) の改修
- result セクションの改修
- progress.md ログ末尾 10 行の改修
- 3 モードを動的切替する UI / プリファレンス管理
- 幅以外の条件 (端末カラーサポート / フォント幅差) への対応

## 3. 機能要件

### 3.1 pane 幅の取得 (F-1)

**コマンド**: `dashboard-pane.sh` の `render_spec()` 冒頭で pane 幅を取得

**取得優先度**:

1. 環境変数 `DASHBOARD_FAKE_COLS` (test 用の注入値、設定されていれば最優先)
2. 環境変数 `$COLUMNS` (bash が通常セットする)
3. `tput cols 2>/dev/null` (tput が使える環境)
4. 取得失敗時は `80` をデフォルトとして wide モード扱い

**エラーハンドリング**:

- いずれの取得も失敗した場合は wide モード (80 相当) で動作、stderr に警告は出さない (1 秒 poll で毎回 warning が出ると邪魔なため)

### 3.2 3 モードレイアウト切替 (F-2)

**しきい値**:

| モード | pane 幅 | 表示内容 |
|---|---|---|
| wide | 60 カラム以上 | 4 列テーブル (stage / status / started_at / completed_at)、現行と同一 |
| narrow | 40-59 カラム | 2 列テーブル (stage / status)、時刻は省略 |
| compact | 40 カラム未満 | 1 列 (`stage=status` 形式の key-value 列挙)、時刻省略 |

**wide 出力例**:

```
stage        status       started_at               completed_at
isolate      completed    2026-04-20T00:00:00Z     2026-04-20T00:05:00Z
implement    completed    2026-04-20T00:05:00Z     2026-04-20T00:30:00Z
verify       in_progress  2026-04-20T00:30:00Z     -
code_review  pending      -                        -
ship         pending      -                        -
```

**narrow 出力例**:

```
stage        status
isolate      completed
implement    completed
verify       in_progress
code_review  pending
ship         pending
```

**compact 出力例**:

```
isolate=completed
implement=completed
verify=in_progress
code_review=pending
ship=pending
```

**エラーハンドリング**:

- jq パース失敗時の「更新中...」フォールバックは 3 モード共通で維持

### 3.3 DASHBOARD_FAKE_COLS 環境変数 (F-3)

**用途**: テストから 3 モード切替を検証するための幅注入

**仕様**:

- 値は正の整数 (1 以上)。非数値 / 0 以下は無視して $COLUMNS / tput 経路にフォールバック
- 設定されていれば `$COLUMNS` と `tput cols` より優先される
- 本番実行時には設定しないこと (docs/tmux-dashboard-operation.md に明記)

### 3.4 既存機能の互換性 (F-4)

- wide モード時の出力は `tmux-dashboard-mvp` の shipped 版 (learn.md `shipped_at: 2026-04-20T00:55:00Z` = receiving-code-review ループを経て ship された最終版) の出力と **完全一致** すること (既存テスト T-test-1 〜 T-test-8d が全 pass)
- wide モード時のヘッダ / result セクション / ログ末尾 10 行の表示位置は変更しない

### 3.5 compact モードでの長い status の扱い

compact モード (`stage=status` 形式) で 1 行が pane 幅を超える場合は**ターミナルの折返しに委ね、トランケートは行わない**。例えば `code_review=shipped-cross-model-pending` のような長い status が将来追加されても、compact モード側でサニタイズ / 切り詰めは実施しません。読者は tmux pane のリサイズで narrow / wide モードに切り替えれば詳細確認可能です。

## 4. 非機能要件

| 項目 | 要件 |
|---|---|
| パフォーマンス | 3 モード切替ロジック追加で `time bash tools/dashboard-pane.sh <spec>` (ONESHOT) の実時間が現行比 +10ms 以内 (努力目標、AC には含めない) |
| 互換性 | 既存 tmux-dashboard-mvp の全 AC (AC-1〜AC-8) が保たれること |
| 保守性 | 3 モード切替ロジックは 1 関数に集約、モード追加が容易 |
| テスト容易性 | `DASHBOARD_FAKE_COLS` で test から幅を強制でき、tmux 起動不要で検証可能 |

## 5. 受け入れ基準 (AC)

- [ ] AC-1: `DASHBOARD_FAKE_COLS=80` で wide モード出力 (4 列)、既存 tmux-dashboard-mvp iteration 2 の出力と一致
- [ ] AC-2: `DASHBOARD_FAKE_COLS=50` で narrow モード出力 (2 列、時刻省略)
- [ ] AC-3: `DASHBOARD_FAKE_COLS=30` で compact モード出力 (1 列 key=value)
- [ ] AC-4: `DASHBOARD_FAKE_COLS` 未設定時は `$COLUMNS` → `tput cols` → 80 のフォールバック順で幅取得
- [ ] AC-5: `DASHBOARD_FAKE_COLS=abc` (非数値) / `DASHBOARD_FAKE_COLS=0` (0 以下) は無視、フォールバック経路に入る
- [ ] AC-6: 既存 14 テスト (T-test-1 〜 T-test-8d) が全 pass (wide 互換維持)
- [ ] AC-7: 新規 3 モード検証テスト (wide / narrow / compact + フォールバック + 不正値) が pass
- [ ] AC-8: `docs/tmux-dashboard-operation.md` に 3 モードの説明と `DASHBOARD_FAKE_COLS` 環境変数を追記

## 6. 非対象 (スコープ外)

- dashboard.sh の tmux layout 制御改修
- 3 モード以外 (2 モード / 4 モード以上) の実装
- 列の詳細カスタマイズ (ユーザーが列を選択 / 並び替え)
- 他の表示要素 (ヘッダ / result / ログ) の応答的変更
- width 以外の端末能力 (truecolor / 256 色 / unicode 幅) への対応

## 7. リスクと緩和策

### 7.1 `$COLUMNS` が tmux pane 分割時に正しく反映されない可能性

**内容**: tmux で pane を split した直後、子 pane で起動した bash の `$COLUMNS` が親 shell の幅のままになるケースが報告されている (tmux のバージョン / 設定次第)。

**緩和策**: `DASHBOARD_FAKE_COLS` > `$COLUMNS` > `tput cols` のフォールバック順を採用。`tput cols` は実行時に ioctl (TIOCGWINSZ) で pty の実サイズを取得するため、`$COLUMNS` が古い場合でも pane の実際のサイズを反映できる。

### 7.2 非対話的実行時 (test 環境) の `tput cols` 動作

**内容**: CI 環境やリダイレクト先では `tput cols` が `unknown` や 80 を返す / エラーで exit 1 になる場合がある。

**緩和策**: `tput cols 2>/dev/null` で stderr を抑制、失敗時は 80 をデフォルトとして wide モードに落とす。`DASHBOARD_FAKE_COLS` を test で明示的に設定することで CI でも決定論的に検証可能。既存テスト (`DASHBOARD_FAKE_COLS` 未設定) は $COLUMNS が 80 以上に設定される bash の default と tput の default の双方が wide しきい値 60 を上回るため、両経路のいずれでも wide 分岐に入り、現行出力と一致します。

### 7.3 既存 tmux-dashboard-mvp テストの回帰

**内容**: 3 モード切替ロジックの追加で、既存テスト (`$COLUMNS` が通常 80 以上の環境) の出力が変化する可能性。

**緩和策**: wide モードのしきい値を 60 カラムに設定し、現行の 4 列テーブルを wide モードでそのまま出力する設計にします。既存テストは wide モードでの出力を期待する前提で pass し続けるため、回帰は発生しない想定。`DASHBOARD_FAKE_COLS` を設定しない既存テストは従来通り動作します。
