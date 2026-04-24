---
name: dashboard-color-themes
status: archived
created: 2026-04-24
depends_on: [dashboard-color]
parallel_group: 2
brainstorming_archive: "none (source: Phase 6 バッチ 2 (c) 複数 Spec 並列実行検証の後続 Spec、先行 dashboard-color の print_color ヘルパーに依存。writing-plan の other_plans 参照経路検証を兼ねる)"
---

# Spec: dashboard-color-themes

## 1. 目的

`dashboard-color` Spec で導入する固定 ANSI カラー配色 (status → 色のハードコード) を、**テーマファイル経由でカスタマイズ可能** にします。個人の好み / 色覚特性 / 端末の背景色 (ダーク / ライト) に応じてカラー配色を切り替え、dashboard の可読性を向上させます。

本 Spec は Phase 6 バッチ 2 (c) 複数 Spec 並列実行検証の**後続 Spec (先行 `dashboard-color` に依存)** です。先行 Spec の `print_color()` ヘルパー関数を拡張する形で実装するため、先行 Spec の Plan (`specs/dashboard-color.plan.md`) を `references_other_plans` で参照します。

## 2. スコープ

### 2.1 含むもの

- `tools/dashboard-themes/` ディレクトリの新設 + 標準テーマ 3 種 (`default.env` / `solarized-dark.env` / `monokai.env`)
- `tools/dashboard-pane.sh` の `print_color()` をテーマ対応に拡張 (`load_theme()` ヘルパー追加)
- 環境変数 `DASHBOARD_THEME=<theme-name>` でテーマ切替 (未指定時は default)
- `tests/test_dashboard.sh` にテーマ切替検証ケース追加
- `docs/tmux-dashboard-operation.md` にテーマ一覧 + カスタムテーマ作成手順を追記

### 2.2 含まないもの

- `dashboard-color` Spec のスコープ (ANSI カラー自体の導入) は本 Spec では変更しない
- 動的テーマ切替 (起動中の `Ctrl-b T` などのインタラクティブ変更)
- 3 種以外の標準テーマ (将来拡張用、本 Spec は 3 種で確定)
- 背景色 / 装飾 / 256 色 / truecolor (これらも `dashboard-color` 同様非対象)

## 3. 機能要件

### 3.1 テーマファイル形式 (F-1)

**パス**: `tools/dashboard-themes/<theme-name>.env`

**形式**: 以下の shell 変数を定義する単純な env ファイル (source で読み込み可能)

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

**バリデーション**:

- テーマファイル内の変数名は **allowlist** (`COLOR_[A-Z_]+` のみ) で制限
- 値はシングル / ダブルクォートを剥離した後、ANSI エスケープ相当の形式のみ許可 (regex `^(\\e\[[0-9;]+m)*$` で検証、`\\e` は bash `[[ =~ ]]` 解釈後にバックスラッシュ 1 + `e` を表す)
- allowlist 違反 / regex 違反を **1 件でも検出した場合、テーマ全体を default にフォールバック** (行単位の部分読み込みはしない)
- バリデーション失敗は stderr に警告 (`load_theme: invalid entry in <theme-name>.env, fallback to default`) を 1 回出力

### 3.2 load_theme ヘルパー (F-2)

**シグネチャ**: `load_theme <theme-name>`

**動作**:

1. `tools/dashboard-themes/<theme-name>.env` の存在チェック
2. 存在すれば allowlist + regex で検証してから `source` で読み込み、`COLOR_*` 変数を shell にエクスポート
3. 存在しなければ stderr に警告 + default テーマにフォールバック
4. 読み込みに成功したか失敗したかを stdout に (loaded 名) 出力 (log 用)

**エラーハンドリング**:

- `../` や `/` を含む theme 名は拒否 (path traversal 防止)
- allowlist `^[A-Za-z0-9][A-Za-z0-9._-]*$` に合致しない theme 名は拒否

### 3.3 print_color のテーマ対応 (F-3)

`dashboard-color` Spec の `print_color()` を、**ハードコードされた色マップの代わりに `$COLOR_*` 変数を参照** するよう改修します。

具体的には:

```bash
# dashboard-color.plan.md §4.1 の print_color 実装を拡張
# Before (dashboard-color):
case "$status" in
  completed) printf '\e[32m%s\e[0m' "$status" ;;
  ...
esac

# After (dashboard-color-themes):
case "$status" in
  completed) printf '%s%s%s' "${COLOR_COMPLETED:-}" "$status" "${COLOR_RESET:-}" ;;
  ...
esac
```

### 3.4 標準テーマ 3 種 (F-4)

| テーマ名 | 背景想定 | 特徴 |
|---|---|---|
| `default` | ライト / ダーク両対応 | 業界標準の ANSI 8 色 |
| `solarized-dark` | ダーク端末 | Solarized 配色 (青系背景に見やすい) |
| `monokai` | ダーク端末 | Monokai 配色 (鮮やか、IDE 風) |

### 3.5 既存機能の互換性 (F-5)

- `DASHBOARD_THEME` 未設定時は `default` テーマが自動適用、`dashboard-color` shipped 時の出力と完全一致
- `DASHBOARD_NO_COLOR=1` はテーマ設定を上書き (どのテーマが選ばれていてもカラー無効化)

## 4. 非機能要件

| 項目 | 要件 |
|---|---|
| パフォーマンス | テーマ読み込みは skill 起動時 1 回のみ (`render_spec` 内では参照のみ) |
| セキュリティ | テーマ名 allowlist + env ファイル allowlist + regex バリデーションで任意コード実行を防止、`source` / `eval` / コマンド置換は一切使わない |
| 保守性 | 標準テーマ追加は `tools/dashboard-themes/<name>.env` ファイル追加のみ、コード変更不要 |
| テスト容易性 | `load_theme <name>` 成功時に `$COLOR_*` 変数が shell にセットされていることを `declare -p COLOR_COMPLETED` や `printenv COLOR_*` で外部検証可能 |

## 5. 受け入れ基準 (AC)

- [ ] AC-1: `DASHBOARD_THEME=default` (または未指定) で `dashboard-color` shipped 時と同一カラー出力
- [ ] AC-2: `DASHBOARD_THEME=solarized-dark` で Solarized 配色が適用される (完了行が青緑系)
- [ ] AC-3: `DASHBOARD_THEME=monokai` で Monokai 配色が適用される
- [ ] AC-4: `DASHBOARD_THEME=nonexistent` で警告 + default フォールバック (exit 0)
- [ ] AC-5: `DASHBOARD_THEME=../evil` で allowlist 違反として拒否 + default フォールバック
- [ ] AC-6: テーマファイル内に `COLOR_*` 以外の変数 (例: `EVIL_CMD='rm -rf /'`) があれば警告 + default フォールバック (当該変数は無視)
- [ ] AC-7: 既存 20 テスト + `dashboard-color` の新テスト全 pass (default テーマで wide 互換維持)
- [ ] AC-8: 新規テーマ切替テスト (3 テーマ + 不在 / 不正) が pass
- [ ] AC-9: `docs/tmux-dashboard-operation.md` にテーマ一覧 + カスタムテーマ作成手順を追記

## 6. 非対象 (スコープ外)

- 動的テーマ切替 (起動中のリロード)
- `tools/dashboard-themes/` 外のパスからのテーマ読み込み (セキュリティ境界)
- 4 種以上の標準テーマ (本 Spec は 3 種で確定)
- 背景色 / 装飾 (前景色のみ)
- 256 色 / truecolor

## 7. リスクと緩和策

### 7.1 source によるテーマ読み込み時の任意コード実行

**内容**: テーマ env ファイルを `source` で読み込むと、ファイル内のシェルコードがすべて実行される。悪意ある PR が `tools/dashboard-themes/evil.env` に `rm -rf $HOME` を仕込んだ場合、ユーザーが `DASHBOARD_THEME=evil` を指定すると即実行される。

**緩和策 (3 段検証 + 直接代入)**: `source` / `eval` / コマンド置換を一切使わず、**env ファイルを行単位で読み、quote 剥離 → 値 validate → 直接代入** の 3 段で処理します。コマンド置換は defense-in-depth 違反のため禁止。

```bash
# 実装イメージ (Plan 段階で詳細化、spec-reviewer feasibility-C-1 / M-1 修正版)
load_theme() {
  local theme_name="$1"
  local theme_file="${SCRIPT_DIR}/dashboard-themes/${theme_name}.env"

  # Spec 名 allowlist (path traversal / hyphen-start 拒否、dashboard-mvp と同じ規則)
  if [[ ! "$theme_name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || [[ ! -f "$theme_file" ]]; then
    theme_file="${SCRIPT_DIR}/dashboard-themes/default.env"
  fi

  local had_invalid=0
  local -A pending   # 検証成功した key=value を一時バッファ

  # 1. 行単位読み込み + allowlist + regex 検証
  while IFS= read -r line; do
    # 空行 / コメント行はスキップ
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    # allowlist: COLOR_[A-Z_]+=... の形式のみ通す
    [[ "$line" =~ ^(COLOR_[A-Z_]+)=(.*)$ ]] || { had_invalid=1; continue; }
    local var="${BASH_REMATCH[1]}"
    local val="${BASH_REMATCH[2]}"

    # 2. quote 剥離 (シングル / ダブル両対応、BASH_REMATCH で安全に取り出す)
    if [[ "$val" =~ ^\'(.*)\'$ ]] || [[ "$val" =~ ^\"(.*)\"$ ]]; then
      val="${BASH_REMATCH[1]}"
    fi

    # 3. 値 regex 検証: ANSI エスケープ相当形式のみ許可 (\e[数;数m の連なり or 空)
    if [[ "$val" =~ ^(\\e\[[0-9\;]+m)*$ ]]; then
      pending["$var"]="$val"
    else
      had_invalid=1
    fi
  done < "$theme_file"

  # 4. 1 件でも違反があれば全体 default フォールバック
  if [[ "$had_invalid" -eq 1 ]] && [[ "$theme_name" != "default" ]]; then
    echo "load_theme: invalid entry in ${theme_name}.env, fallback to default" >&2
    load_theme "default"
    return
  fi

  # 5. 検証済みのみ直接代入 (コマンド置換なし)
  local key
  for key in "${!pending[@]}"; do
    printf -v "$key" '%s' "${pending[$key]}"
    export "$key"
  done
}
```

設計上の注意:

- `source` / `eval` / `$(...)` を使わないため、theme ファイル内の任意コードは実行不能
- `printf -v` + `export` の 2 段で変数を設定、`echo ... | tr` のようなコマンド置換経由の代入を排除
- regex `^(\\e\[[0-9\;]+m)*$` は bash `[[ =~ ]]` 解釈後に「バックスラッシュ 1 + e + `[` + 数値 + `m`」の連なりにマッチ (spec-reviewer 指摘 C-1 の修正版)
- 1 件でも違反があればテーマ全体を default へフォールバック (部分読み込みしない、spec-reviewer completeness-M-1 の a/b 二択から b を採用)

### 7.2 `dashboard-color` Spec との実装衝突

**内容**: 本 Spec が `dashboard-color` の `print_color()` を書き換えるため、両 Spec が並列実装されると最終的な関数シグネチャが曖昧になる。

**緩和策**: DAG 上で `depends_on: [dashboard-color]`、`parallel_group: 2` を明示。先行 Spec `dashboard-color` が ship 済 (archive 移動済) になってから本 Spec の writing-plan が起動する。Plan 段階で `specs/archive/dashboard-color.plan.md` の `print_color()` API 契約を `references_other_plans` で参照し、整合性を保ちます。

### 7.3 既存テストの NO_COLOR 経由 pass が「default テーマ + TTY 判定」で曖昧になる

**内容**: `dashboard-color` Spec では「TTY でないとき自動 NO_COLOR」で既存テスト pass だったが、本 Spec でテーマ機構が入ると default テーマ読み込みのタイミング / 成否がテスト結果に影響する可能性。

**緩和策**: `load_theme` は `print_color` より前に呼ばれ、default テーマが確実にロードされている前提とする。テスト側は引き続き `bash -c` パイプ経由のため TTY 判定で NO_COLOR となり、`$COLOR_*` 変数は読み込まれるが出力には使われない経路で pass。default テーマ以外のテーマ読み込み確認テストは明示的に TTY を擬似する必要があるが、検証は `grep -oE 'solarized|monokai'` 等のマーカー文字列で代替可能です。
