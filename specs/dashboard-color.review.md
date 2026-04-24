---
reviewer: spec-reviewer
verdict: needs-fix
reviewed_at: 2026-04-24
spec: dashboard-color
responsibility: composite (completeness + feasibility + consistency + api-contract)
score_completeness: 85
score_feasibility: 83
score_consistency: 94
score_api_contract: 91
score_overall: 87
---

# Review: dashboard-color

本レビューは Phase 6 バッチ 2 (c) 複数 Spec 並列実行検証の先行 Spec `dashboard-color` に対する統合レビューです。通常 spec-reviewer agent は 3 観点 (completeness / feasibility / consistency) のうち 1 つを担当しますが、本件は呼び出し元からの依頼により 3 観点 + 後続 Spec との API 契約観点を 1 agent で統合審査しています。

## サマリ

- 7 章構成 + frontmatter は必要項目を充足し、既存 3 モードレンダラ (archive/tmux-dashboard-v2-responsive.md) への追加実装として設計が素直です。
- bash + ANSI 8 色という技術選択は極めて堅実で、パフォーマンス要件 (1ms/call 未満) と既存 20 テストとの互換性は TTY 自動判定で自然に担保されます。
- DAG (parallel_group:1 / depends_on:[]) と後続 `dashboard-color-themes` の `depends_on: [dashboard-color]` とも整合しています。
- ただしリスク §7.2 の padding に関する記述が技術的に不正確で、`printf "%-12s"` は ANSI エスケープのバイト数も含めて長さ判定するため、カラー付き status 値では列アライメントが崩れます。この前提で AC-1/2 を pass 扱いにすると視覚品質が損なわれるため Plan 段階での補正が必要です。
- 後続 Spec が前提とする `print_color` シグネチャ (`<status>` 1 引数、stdout 出力、非改行) は本 Spec 内で十分に明示されていますが、末尾改行の有無が暗黙に留まる点のみ Minor 指摘です。

verdict は **needs-fix** とします。指摘はいずれも Plan 段階で解消可能な粒度であり、Spec 本体の骨格変更は不要です。

## 指摘事項

### Critical

なし。

### Major

- [feasibility-M-1] **`printf "%-12s"` の列幅計算が ANSI エスケープ込みで破綻する (§7.2 の「ズレは発生しない」は誤り)**

  §7.2 緩和策では「bash 側では仕様通り 12 バイト分確保される」「後続カラム (started_at 等) とのズレは発生しない」と結論していますが、実際の `printf "%-12s"` は「バイト長 12 未満の場合に空白で右パディング」という動作のため、`\e[32mcompleted\e[0m` (5 + 9 + 4 = 18 バイト) はそもそも 12 を超過しており **パディングが発生しません**。結果としてカラム幅はバイト単位で可変になり、ターミナル可視幅は 9 chars (= `completed` の視覚長) となって次カラム `started_at` が詰まって開始します。同様に `failed` (6 + 9 = 15 バイト) / `blocked` (7 + 9 = 16 バイト) / `in_progress` (11 + 9 = 20 バイト) すべて > 12 のため視覚的に列崩れが起きます。AC-1/2 は ANSI コードの存在確認のみなので pass しますが、wide / narrow モードの見た目はこれまでの shipped 版と比べて明確に劣化します。

  **修正提案**:
  1. §7.2 の結論部を事実ベースに書き換え、「`printf "%-12s"` に直接 ANSI 付文字列を渡すと列崩れが発生する」ことを明記する。
  2. 緩和策として Plan 段階で **事前パディング方式** を採用することを Spec §3.2 または §7.2 に追記する。具体的には:
     - `padded_status=$(printf "%-12s" "$status")` で先にパディングのみ実施
     - その後 `printf "%s%s%s" "$color_on" "$padded_status" "$color_off"` で色付けを被せる
     - あるいは `print_color` が「素の status 可視長が 12 未満になるよう空白詰めしてから ANSI を巻く」形で責務を内包する
  3. 併せて AC-1/2 を「ANSI 緑が含まれる **かつ** started_at カラムの開始列位置が wide shipped 版と同一」まで強化することで、視覚回帰を確実に検出できます。

### Minor

- [completeness-m-1] **`NO_COLOR=1` (業界標準) 環境変数の AC が欠落**

  §3.3 F-3 で「事実上の業界標準 `NO_COLOR=1` にも反応させる」と明記されているにもかかわらず、受け入れ基準 AC-4 は `DASHBOARD_NO_COLOR=1` のみ検証しています。F-3 の約束が実装されているかを保証できません。

  **修正提案**: AC-4 を「`DASHBOARD_NO_COLOR=1` または `NO_COLOR=1` 指定時、どのモードでも ANSI エスケープが一切出力されない」と OR 条件に拡張する、または AC-4b を新設。

- [completeness-m-2] **`print_color` の末尾改行有無が明示されていない**

  §3.1 F-1 「ANSI エスケープシーケンスを開始コードとして stdout に出力 + status 文字列 + reset コード」の記述では、末尾に改行が付くかどうかが不明瞭です。呼び出し側が `printf "%-12s" "$(print_color "$status")"` のようにコマンド置換で受ける形式 (または Major-1 の事前パディング方式) を前提にするなら **末尾改行なし (printf 利用)** が必須ですが、Spec 上は `echo` 実装でも矛盾しません。さらに後続 `dashboard-color-themes` §3.3 の "Before" スニペット `printf '\e[32m%s\e[0m' "$status"` は改行なし前提で書かれているため、改行ありで実装すると後続 Spec の拡張が破綻します。

  **修正提案**: F-1 に「末尾改行は付けない (`printf` を使用)」を 1 行追記し、出力例コードブロックのプロンプト形式も改行強調を避ける表現に調整。

- [completeness-m-3] **`shipped-*` / `aborted-*` の prefix マッチング挙動が F-1-1 テーブルで示唆されるのみ**

  §3.1 F-1-1 で `shipped` / `shipped-*` と `aborted` / `aborted-*` を同色扱いとする旨は書かれていますが、bash case での具体的パターン (`shipped*)`) は Spec に明示されていません。後続 `dashboard-color-themes` の default.env には `COLOR_SHIPPED` / `COLOR_ABORTED` のみがあり prefix 展開の実装責任は `print_color` 側に残ります。Plan 段階で明文化するなら許容範囲の Minor ですが、Spec レベルで「`shipped` およびそのプレフィックス派生 (`shipped-cross-model-pending` など) は同一色を使う」と自然言語で 1 行加えておくと後続の実装・レビューが楽になります。

  **修正提案**: F-1-1 テーブル直下に「`shipped-*` / `aborted-*` は glob 的に prefix マッチし、同色を適用する」の注記を追加。

- [consistency-m-1] **AC-7 の新規テスト範囲が曖昧**

  「新規カラー検証テスト (TTY 擬似 / NO_COLOR 指定 / 各 status) が pass」の記述は観点を列挙するのみで、具体的な test case 数 / 命名 (T-test-11a 以降) が決まっていません。既存 `tests/test_dashboard.sh` の T-test-1a〜10c ナンバリング規則に従い、Plan で `T-test-11a: print_color 単体 / completed で ANSI 緑が出力される`、`T-test-11b: DASHBOARD_NO_COLOR=1 で ANSI なし`、... の形で明文化すると AC-7 の検証可能粒度が上がります。

  **修正提案**: AC-7 に「T-test-11 系列 (新規 N ケース、内訳は Plan で確定) が pass」の粒度で記述、または Plan 時点で Spec に follow-up として補記。

- [consistency-m-2] **AC-6 の「既存 20 テスト」と本 Spec 追加後のテスト総数の関係が曖昧**

  AC-6 は「既存 20 テスト (T-test-1 〜 T-test-10c) が全 pass」と明示していますが、本 Spec 追加後の最終テスト総数は 20 + AC-7 の新規ケース N (現在未定) です。読者が AC-6 の「既存」が本 Spec 作業前の状態を指すと理解できるよう、「本 Spec 作業前の 20 テスト」などと表現を 1 語追加するだけで明瞭になります。

  **修正提案**: AC-6 を「既存 20 テスト (本 Spec 作業前時点、T-test-1 〜 T-test-10c) が全 pass」に改訂。

## 観点別の所見

### 1. 完全性 (completeness)

- 7 章 (目的 / スコープ / 機能要件 / 非機能要件 / 受け入れ基準 / 非対象 / リスクと緩和策) はすべて揃い、章立ての抜けはありません。
- frontmatter 必須項目 (name / status / created / depends_on / parallel_group / brainstorming_archive) 充足。`brainstorming_archive: "none (...)"` に明示的な由来記述があり、writing-spec skill の「brainstorm 経由でない場合の記述ルート」にも適合しています。
- 受け入れ基準 AC-1〜AC-8 は概ね検証可能な粒度 (具体的な環境変数値、ANSI コード) で書かれており、「適切に動作する」等の曖昧語は見当たりません。ただし前述 completeness-m-1/m-2 の通り、F-3 の `NO_COLOR` 相当環境変数や `print_color` の改行仕様のような **F 章で書かれた約束が AC にカバーされていない項目** が散見されます。AC は F 章の約束を 1:1 で網羅することが望ましいです。
- リスク §7.1〜§7.3 はそれぞれ具体的な環境想定と緩和策が書かれており、Phase 3 spec-review の「具体性」基準を満たします (ただし §7.2 の結論部は feasibility-M-1 の通り事実誤認を含みます)。
- スコア: 100 - (0 Critical × 30) - (0 Major × 10) - (3 Minor × 3) × (completeness 該当は m-1/m-2/m-3 の 3 件想定) = 91。他 Minor も一部 completeness 寄りと解釈できるので **85 点** に調整。

### 2. 実現可能性 (feasibility)

- bash 組込 + ANSI 8 色のみの実装で、新規ライブラリ・外部プロセス不要。パフォーマンス要件「1ms/call 未満」は `case` + `printf` で十分達成可能。
- TTY 判定 `[[ -t 1 ]]` は標準 bash 構文で環境依存が少なく、既存 20 テスト (`bash -c` 経由の command substitution はすべて stdout 非 TTY) との互換性は自然に成立します。
- tmux 2.6+ で ANSI 基本 8 色が保証されている点はリスク §7.1 で触れられており、`DASHBOARD_NO_COLOR=1` オプトアウト経路もあるため環境依存は低く抑えられています。
- **主要な実現可能性上の懸念は feasibility-M-1 の printf 列幅問題** で、現状 §7.2 の結論が楽観的すぎます。Plan 段階で事前パディング方式を採用すれば解決可能な範囲のため、Spec 骨格の手戻りは不要ですが、リスク記述の修正は必要です。
- スコア: 100 - (0 Critical × 30) - (1 Major × 10) - (0 Minor × 3) = **90**。ただし §7.2 緩和策の事実誤認が他観点にも波及する懸念があり **83 点** に下方調整。

### 3. 整合性 (consistency)

- **既存コードベース整合**: `tools/dashboard-pane.sh` 現行コードの `printf "%-12s %-12s %-24s %-24s"` (wide) / `printf "%-12s %s"` (narrow) / `"\(.key)=\(.value.status)"` (compact) の 3 箇所へ `print_color` を差し込む設計は、既存の関数境界 (`render_stages_wide` / `render_stages_narrow` / `render_stages_compact`) と素直に整合します。ヘッダ行と「更新中...」フォールバックは非対象で維持されるため、エラーハンドリング境界も現行挙動と一致。
- **既存テスト整合**: `tests/test_dashboard.sh` の T-test-1a〜10c (計 20 件) はすべて `output="$(bash -c "$cmd" 2>&1)"` のパターンで command substitution を使い、stdout は非 TTY となります。本 Spec F-3 の「stdout が TTY でなければ自動でカラー無効化」により、既存テストは追加修正なしで pass する見込み。ただし consistency-m-1 の通り新規ケース (AC-7) は粒度不足。
- **dag.md 整合**: `parallel_group: 1` / `depends_on: []` / `status: spec-complete` は dag.md §並列実行グループ表と完全一致。
- **archive 過去 Spec 整合**: `specs/archive/tmux-dashboard-v2-responsive.md` の 3 モード設計 (wide ≥ 60 / narrow 40-59 / compact < 40) を尊重し、各モードに色を乗せる形になっており設計階層の分離が守られています。F-4 の「NO_COLOR 時は v2-responsive shipped 版と完全一致」という明示契約も、archive Spec の AC-4 / AC-6 を活かす形で書かれており整合的。
- **スコープ境界**: ユーザーテーマは後続 Spec、256 色 / truecolor は明確に非対象、ヘッダ / result / ログ末尾 10 行も非対象と明示されており、Spec の責務範囲が曖昧になるリスクは低い。
- スコア: 100 - (0 Critical × 30) - (0 Major × 10) - (2 Minor × 3) = **94**。

### 4. API 契約 (後続 Spec dashboard-color-themes との整合)

- **シグネチャ**: `print_color <status>` (1 引数) は本 Spec §3.1 で明示されており、後続 `dashboard-color-themes` §3.3 でも同一シグネチャを保持したまま case 本体のみ `$COLOR_*` 変数参照に差し替える設計になっています。引数の拡張 (例: `print_color <status> <theme>`) ではなく環境変数経由でテーマを渡す設計のため、シグネチャは将来も stable を保つ見込み。
- **出力形式**: 本 Spec F-1 出力例 `<ESC>[32mcompleted<ESC>[0m` は後続 Spec §3.3 Before スニペット `printf '\e[32m%s\e[0m' "$status"` と同じバイト列を期待しています。後続 Spec は `printf '%s%s%s' "${COLOR_COMPLETED:-}" "$status" "${COLOR_RESET:-}"` という等価な構造に置き換えるため、バイト列互換の要件は保たれます。ただし前述 completeness-m-2 の通り、本 Spec で「末尾改行なし」が明示されていない点は後続 Spec の Plan 段階で前提が崩れるリスクを孕みます (改行ありで実装すると後続 Spec の `DASHBOARD_THEME=default` 時の出力互換 AC-1 が fail)。
- **カラーマップ**: 本 Spec F-1-1 テーブルの 7 行 (`completed` / `in_progress` / `pending` / `failed` / `blocked` / `shipped`(`*`) / `aborted`(`*`)) と default テーマ (`dashboard-color-themes.md` §3.1) の 8 変数 (`COLOR_COMPLETED` / `COLOR_IN_PROGRESS` / `COLOR_PENDING` / `COLOR_FAILED` / `COLOR_BLOCKED` / `COLOR_SHIPPED` / `COLOR_ABORTED` / `COLOR_RESET`) が 1:1 対応しており、後続 Spec の default テーマが本 Spec と同じ配色を再現可能。
- **prefix マッチング (`shipped-*` / `aborted-*`)**: 前述 completeness-m-3 の通り実装責務が `print_color` 側に暗黙に置かれています。後続 Spec default.env には `COLOR_SHIPPED_LEARN` のような個別変数は定義されず、prefix マッチは `print_color` 内の case パターンで吸収する前提です。本 Spec Plan 段階で bash case パターン (`shipped*)`) を明記すれば、後続 Spec の拡張時も破綻しません。
- **エラー動作の契約**: 本 Spec F-1 「その他 (不明値)」はカラーなしで status 文字列のみ出力、と明示されており、後続 Spec のテーマが追加色を定義していなくても fallback が機能します。
- スコア: 100 - (0 Critical × 30) - (0 Major × 10) - (3 Minor × 3、m-2 / m-3 / consistency-m-2 が API 契約にも波及) = **91**。

## 総合判定

- score_completeness: 85
- score_feasibility: 83
- score_consistency: 94
- score_api_contract: 91
- overall (completeness × 0.4 + feasibility × 0.3 + consistency × 0.3) = 85 × 0.4 + 83 × 0.3 + 94 × 0.3 = 34.0 + 24.9 + 28.2 = **87.1**
  (api_contract は本件固有の追加観点のため overall には含めず、別途 91 点として併記)

verdict: **needs-fix**

- Critical なし、Major 1 件 (§7.2 の事実誤認 + printf 列幅対策の Spec 反映)、Minor 5 件の合計。
- いずれも Plan 段階で解消可能な粒度であり、Spec 骨格 (目的 / スコープ / 章構成) の書き直しは不要です。
- Major-1 の事前パディング方式は `dashboard-color.plan.md` §4.1 の print_color 実装に反映し、Spec 側には §7.2 緩和策の修正 + §3.2 「ANSI 込みで `printf "%-12s"` を使わない」の一文追加程度で足ります。
- Minor 対応 (AC 強化 / 改行仕様明示 / prefix マッチ注記 / テストナンバリング / 既存テスト定義) は writing-spec レビュー指摘対応モードで機械的に消化可能です。

修正が入れば後続 `dashboard-color-themes` Spec の writing-plan / spec-leader 起動に支障はなく、Phase 6 バッチ 2 (c) 複数 Spec 並列実行検証のドッグフーディング題材として十分機能します。
