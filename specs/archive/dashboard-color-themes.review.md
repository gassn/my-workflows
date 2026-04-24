---
reviewer: spec-reviewer
verdict: needs-fix
reviewed_at: 2026-04-24
spec: dashboard-color-themes
responsibilities: [completeness, feasibility, consistency]
scores:
  completeness: 87
  feasibility: 60
  consistency: 91
  overall: 80.1
---

# Review: dashboard-color-themes

本レビューは spec-reviewer agent が 3 観点 (completeness / feasibility / consistency) を統合レポート形式で実施したものです。観点ごとに独立に審査した所見を併記し、観点間のバイアス混入を避けるために指摘は発見した観点に限定して計上しています。

## 総合判定

- **verdict**: `needs-fix`
- **overall score**: 80.1 (= 0.4 * 87 + 0.3 * 60 + 0.3 * 91)
- **理由**: セキュリティ (§7.1) の緩和策が **実際には正しい値を受け付けない regex** となっており、このまま Plan に進むと Implement 段階で再度仕様修正が発生します。観点 feasibility で Critical 1 件を検出したため pass にできず、一方で構造 / DAG 整合性 / 章立ては概ね健全のため reject でもなく、needs-fix とします。§7.1 の regex とパーサを修正すれば pass 相当。

---

# Partial Review: completeness

**score**: 87 / 100 (減点: Major 1 件 -10、Minor 1 件 -3)

## 指摘事項

### Critical

(なし)

### Major

- **[completeness-M-1]** AC-6 「`EVIL_CMD='rm -rf /'` があれば警告 + default フォールバック (当該変数は無視)」の挙動定義が §3.1 / §3.2 と微妙に矛盾する。§3.1 では「allowlist 違反 / regex 違反は stderr に警告、**default テーマにフォールバック**」とあり、一方 AC-6 後半では「当該変数は無視」と "部分的に読み込み継続" を示唆する記述になっている。「allowlist 違反が 1 つでもあればテーマ全体を default にフォールバック」なのか「違反行だけスキップして残りは読み込む」なのか、Spec Review / Plan 前に確定させる必要がある。
  - **該当章**: §3.1 バリデーション, §3.2 load_theme ヘルパー, §5 AC-6
  - **修正提案**: §3.1 に「allowlist / regex 違反検出時の動作」として 2 択を明示 — (a) 行単位スキップ継続 / (b) テーマ全体 default フォールバック。後述 feasibility-C-1 の実装方針と合わせて決めるのが合理的。

### Minor

- **[completeness-m-1]** §4 非機能要件テーブルに **テスト容易性** の項目がない (先行 Spec `dashboard-color` の §4 には含まれていた)。テーマ読み込み結果を検証する手段 (例: `load_theme <name> && echo "$COLOR_COMPLETED" | grep -q '\e\[32m'`) を非機能要件として明示しておくと、Plan での検証ステップ設計が楽になる。
  - **該当章**: §4
  - **修正提案**: `| テスト容易性 | load_theme 成功時に $COLOR_* 変数が export されていることを外部から検証可能 |` を 1 行追加。

## 観点固有の所見

- 7 章構成は充足 (§1 目的 / §2 スコープ / §3 機能要件 / §4 非機能要件 / §5 AC / §6 非対象 / §7 リスク)。
- frontmatter 必須フィールドは揃っている (`name` / `status` / `created` / `brainstorming_archive`)。`brainstorming_archive: "none (source: ...)"` は Phase 6 の「brainstorming 省略経緯を明示する」慣行に沿っている。
- AC-1 〜 AC-9 の大半は検証可能粒度 (AC-1 「同一カラー出力」、AC-5 「allowlist 違反として拒否」等、pass/fail の境界が明確)。曖昧語 (「適切に」「きちんと」) の使用なし。
- §7 リスクは 3 件とも内容 / 緩和策の対応が取れている (ただし 7.1 の緩和策の技術的妥当性は feasibility 観点で別途指摘)。
- TBD は 0 件。

---

# Partial Review: feasibility

**score**: 60 / 100 (減点: Critical 1 件 -30、Major 1 件 -10)

## 指摘事項

### Critical

- **[feasibility-C-1]** §7.1 の緩和策として提示された regex `^([\'\"]|)(\\\\e\[[0-9;]+m)*([\'\"]|)$` と `tr -d '\"'\''` によるクォート剥離は、**実装したとしても §3.1 の正規例 (`COLOR_COMPLETED='\e[32m'`) を受け付けない**。Spec-reviewer が実機 bash で検証した結果を以下に示す (テストスクリプト `/tmp/regex_test.sh` で再現可能):

  | 入力 value (= 右辺) | 期待 | 実機結果 |
  |---|---|---|
  | `'\e[32m'` (§3.1 の default.env そのまま) | pass | **fail** |
  | `\e[32m` (unquoted) | pass | **fail** |
  | `"\e[32m"` (double-quoted) | pass | pass |
  | `''` (空値) | pass | pass |
  | `\e[1;32m` (2 属性、`;` 含む) | pass | **fail** |
  | `'\e[32m'; EVIL=$(rm -rf /)` (攻撃) | fail | fail (OK) |

  **根本原因**:
  1. `\\\\e` は bash の `[[ =~ ]]` でエスケープ解釈された後に「バックスラッシュ 2 個 + e」を表すが、theme ファイル側の実際の value には「バックスラッシュ 1 個 + e」しか入っていない (printf の `\e` 相当)。regex 側の `\\\\e` を `\\e` に修正する必要がある。
  2. シングルクォート版 (`'\e[32m'`) が全滅する理由は 1 と同じ (内側のエスケープが一致しない)。
  3. `\e[1;32m` が fail するのは `[0-9;]+` 自体は正しいが 1 の原因で到達しないため。

  結果として「あらゆる正規入力が reject されて毎回 default フォールバック」となり、**機能 F-1〜F-4 の大半 (solarized-dark / monokai テーマの実適用) が達成不可能** になります。

  **該当章**: §7.1 緩和策、§3.1 バリデーション

  **修正提案**: regex を次のように書き換え、かつ「quote 剥離 → 値 validate → export」の 3 段構造にする:

  ```bash
  # theme file を 1 行ずつ読む (source は使わない)
  while IFS= read -r line; do
    # コメント / 空行スキップ
    [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
    # 変数名 allowlist + = の形式
    [[ "$line" =~ ^(COLOR_[A-Z_]+)=(.*)$ ]] || continue
    var="${BASH_REMATCH[1]}"
    raw="${BASH_REMATCH[2]}"
    # クォート剥離 (シングル / ダブル両対応)
    if [[ "$raw" =~ ^\'(.*)\'$ ]] || [[ "$raw" =~ ^\"(.*)\"$ ]]; then
      val="${BASH_REMATCH[1]}"
    else
      val="$raw"
    fi
    # 値 validation: 空 OR (\e[<digits and ;>m)+ のみ
    if [[ -z "$val" ]] || [[ "$val" =~ ^(\\e\[[0-9\;]+m)+$ ]]; then
      export "$var=$val"
    else
      echo "[load_theme] skip invalid value for $var" >&2
    fi
  done < "$theme_file"
  ```

  この書き換えにより、§3.1 の default.env リテラルがそのまま accept され、コマンド置換 / バッククォート / 改行経由の injection は reject されます。Spec 本文に pseudocode まで書き切るか、実装詳細は Plan に委ねて Spec では「validate の責務 (クォート剥離 + 値 regex + 変数名 allowlist の 3 段)」だけ明記するかは writing-spec の判断範囲。

### Major

- **[feasibility-M-1]** §7.1 最終行の `export "$var=$(echo "$val" | tr -d '\"'\''')"` は **コマンド置換を使っている**。`$val` に攻撃者が制御する文字列が入る前提で echo を走らせる構造は、regex でブロックされているとはいえ defense-in-depth として脆弱です (regex をすり抜けたケースで echo が解釈を始める)。上記 feasibility-C-1 の修正提案のように、**shell コマンドを経由せず bash 変数展開のみで完結** させるべきです。
  - **該当章**: §7.1 緩和策
  - **修正提案**: `export "$var=$val"` の直接代入 (上記 C-1 の修正提案に含まれる)。クォート剥離は `[[ =~ ]]` の `BASH_REMATCH` でやる。

### Minor

(なし)

## 観点固有の所見

- パフォーマンス要件「skill 起動時 1 回のみ」は bash の `load_theme` 呼び出しコスト (数 ms) として十分現実的。
- 保守性「標準テーマ追加は .env ファイル追加のみ」も Spec の構造上達成可能 (テーマ名 allowlist regex `^[A-Za-z0-9][A-Za-z0-9._-]*$` が既存のファイル発見ロジックと整合するため新規テーマに自動で追随)。
- 上記 Critical / Major を除けば、依存 Spec `dashboard-color` の `print_color()` を「ハードコード color map → `$COLOR_*` 参照」に置換する改修は実装上素直で、技術リスクはほぼなし。
- **security は最重要観点**として重点確認した結果、方向性 (source 回避 + allowlist + regex) は妥当だが、**実装指針のレベルで regex が破綻**しているため Plan / Implement 前の修正が必須です。

---

# Partial Review: consistency

**score**: 91 / 100 (減点: Minor 3 件 -9)

## 指摘事項

### Critical

(なし)

### Major

(なし)

### Minor

- **[consistency-m-1]** `specs/dag.md` の `推奨実行順序` §2 に「writing-plan が `specs/archive/dashboard-color.plan.md` を `references_other_plans` で参照」と明記されているが、**Spec 本体 §1 / §7.2** で言及される参照パスは同じく `specs/archive/dashboard-color.plan.md` で一致している。ただし Spec 本文には「この参照は writing-plan skill の `references_other_plans` frontmatter に記載する」という **具体的な契約の記述がない** (§7.2 では「Plan 段階で参照」と動名詞で書かれているのみ)。レビュー観点に記載された「writing-plan 段階で `references_other_plans: [specs/archive/dashboard-color.plan.md]` が参照される前提が Spec 本文で明示されているか」という問いに対しては **半分 yes / 半分 no** 判定。
  - **該当章**: §1 目的 最終段落、§7.2 緩和策
  - **修正提案**: §7.2 末尾に 1 文追加: 「具体的には writing-plan skill 起動時に `references_other_plans: [specs/archive/dashboard-color.plan.md]` を frontmatter に設定し、Plan 生成プロンプトに先行 Spec の `print_color()` シグネチャと呼び出し規約を含めます。」
- **[consistency-m-2]** 先行 Spec `dashboard-color` §3.1 の `print_color <status>` は **「stdout に `<ESC>[色]` + status + `<ESC>[0m` を出力」** するセマンティクス (文字列を直接出すラッパー) です。一方、本 Spec §3.3 の After コードは `printf '%s%s%s' "${COLOR_COMPLETED:-}" "$status" "${COLOR_RESET:-}"` と **変数展開のみ** で、関数として `print_color` を呼ぶのか・ `print_color` 自体を変数参照に書き換えるのかが曖昧。`dashboard-color` Spec の AC-1〜3 は「行に `\e[32m` が含まれる」を要求するため、本 Spec 実装後も関数は維持され、内部実装だけ差し替わる、と読むのが自然ですが、Spec 本文にそう書かれていません。
  - **該当章**: §3.3
  - **修正提案**: §3.3 冒頭に「本 Spec は `print_color()` 関数の **シグネチャ (引数 `status` 受取り、stdout へカラー付き文字列出力) を完全維持** し、内部の case 分岐のみ `$COLOR_*` 変数参照に差し替えます」と明記。先行 Spec の AC との連続性保証になる。
- **[consistency-m-3]** 本 Spec AC-1 「`DASHBOARD_THEME=default` (または未指定) で `dashboard-color` shipped 時と同一カラー出力」の判定基準は、先行 Spec `dashboard-color` §3.1 のカラーマップと本 Spec §3.1 default.env の定義が完全一致していることが前提。実際に両者を突き合わせると:

  | status | dashboard-color §3.1 | default.env §3.1 | 一致 |
  |---|---|---|---|
  | completed | `\e[32m` (緑) | `COLOR_COMPLETED='\e[32m'` | yes |
  | in_progress | `\e[33m` (黄) | `COLOR_IN_PROGRESS='\e[33m'` | yes |
  | pending | カラーなし (reset のみ) | `COLOR_PENDING=''` | yes |
  | failed | `\e[31m` (赤) | `COLOR_FAILED='\e[31m'` | yes |
  | blocked | `\e[35m` (マゼンタ) | `COLOR_BLOCKED='\e[35m'` | yes |
  | shipped / shipped-* | `\e[36m` (シアン) | `COLOR_SHIPPED='\e[36m'` | yes (ただし `shipped-*` 派生の扱い不明) |
  | aborted / aborted-* | `\e[31m` (赤) | `COLOR_ABORTED='\e[31m'` | yes (派生不明) |

  本体マップは一致しますが、**`shipped-*` / `aborted-*` の派生 status (先行 Spec で「shipped / shipped-*」と表記) に対する theme ファイルでのハンドリング方法**が本 Spec に記述されていません。`COLOR_SHIPPED` 1 変数でカバーするのか別変数を用意するのかが不明。

  - **該当章**: §3.1 default.env 例、§3.3 print_color 差替
  - **修正提案**: §3.1 default.env 例のコメントに「`shipped-*` は `COLOR_SHIPPED` / `aborted-*` は `COLOR_ABORTED` を共有 (派生 suffix では色変えない)」を追記。

## 観点固有の所見

- `specs/dag.md` との整合: `depends_on: [dashboard-color]` / `parallel_group: 2` が Spec frontmatter と DAG テーブルの双方で一致。Mermaid グラフ `color --> themes` も整合。
- 既存コードベース `tools/dashboard-pane.sh` との整合: Spec §3.2 の theme 名 allowlist regex `^[A-Za-z0-9][A-Za-z0-9._-]*$` は、既存 `SPEC_NAME_PATTERN` と**完全に同一**。コードベースの命名 / validation 規約を踏襲しており良好。
- 既存 `validate_spec_name` 関数のパターンを流用できるため、`validate_theme_name` 実装は既存コードの rename / 一般化で済む可能性あり (ただし Plan の領域)。
- `tests/test_dashboard.sh` への追加の方向性 (AC-7, AC-8) も先行 Spec と整合的。
- 先行 Spec が未 ship の現時点 (`specs/archive/dashboard-color.plan.md` がまだ存在しない) で本 Spec が `spec-complete` なのは、DAG 上の実行順序 (Group 1 → Group 2) で解決される前提 (writing-plan は Group 1 ship 後に Group 2 を処理)。ここは現行ワークフローと矛盾しない。

---

# 統合サマリ

| 観点 | score | Critical | Major | Minor |
|---|---:|---:|---:|---:|
| completeness | 87 | 0 | 1 | 1 |
| feasibility | 60 | 1 | 1 | 0 |
| consistency | 91 | 0 | 0 | 3 |

**overall**: 80.1 (= 87 * 0.4 + 60 * 0.3 + 91 * 0.3)

**verdict**: `needs-fix`

## 修正必須項目 (pass ラインに到達するため)

1. **feasibility-C-1** (最優先): §7.1 の regex を修正。現状の指針では正規入力が受け付けられず F-1〜F-4 が動かない。上記「修正提案」の pseudocode を §7.1 に差し替える (または Plan で解決する旨を §7.1 に明記して詳細実装指針を Plan に委ねる)。
2. **feasibility-M-1**: §7.1 の `export "$var=$(echo ...)"` 構造を削除し、`export "$var=$val"` の直接代入 + `BASH_REMATCH` によるクォート剥離に変更。

## 対応推奨項目 (pass 後のブラッシュアップ)

3. **completeness-M-1**: §3.1 のバリデーション違反時の動作 (行単位 skip / テーマ全体 fallback) を明示。
4. **consistency-m-1〜3**: §1 / §3.1 / §3.3 / §7.2 の軽微な記述補強 (writing-plan の `references_other_plans` 契約の明文化、`print_color()` シグネチャ維持の明示、`shipped-*` / `aborted-*` 派生の扱い)。
5. **completeness-m-1**: §4 非機能要件にテスト容易性項目追加。

## spec-review skill 統合時の推奨フロー

- 本レポートを writing-spec の「レビュー指摘対応モード」に渡して §7.1 / §3.3 / §1 を修正 → `status: spec-complete` を維持したまま再レビュー (feasibility 観点のみ再走で pass 判定の可能性大)。
- Plan ステージに進む前に上記 1, 2 だけは必ず解決すること (Implement で再度 Spec 修正が発生するコストを回避)。
