---
reviewer: code-reviewer
spec: tmux-dashboard-v2-responsive
reviewed: 2026-04-24
verdict: pass
executed_at: 2026-04-24T07:05:00Z
---

# Code Review: tmux-dashboard-v2-responsive

## 概評

`tools/dashboard-pane.sh` に pane 幅に応じた 3 モードレイアウト (wide / narrow / compact) を追加する改修について、コード品質観点でレビューしました。

総評は良好です。特筆すべきは以下の 3 点です:

1. **wide モードが純粋リファクタで出力バイト一致**: `render_stages_wide` は現行 `render_spec()` の 4 列 printf ブロックをそのまま関数に移したもので、`git diff main -- tools/dashboard-pane.sh` の当該ブロックを確認した結果、printf のフォーマット文字列も jq クエリも完全に同一です。Plan §7.1 で宣言した「純粋リファクタ」が実装でも厳守されており、既存 14 テスト (T-test-1〜T-test-8d) の回帰リスクが構造的に抑えられています。
2. **4 段フォールバックの設計が明瞭**: `get_pane_cols()` の `DASHBOARD_FAKE_COLS → $COLUMNS → tput cols → 80` の 4 段は、各段で `[[ "$cols" =~ ^[0-9]+$ ]] && [[ "$cols" -gt 0 ]]` という同じガード条件を直線的に並べており、Spec §3.1 F-1 / Spec §7.3 (`tput` が 0 を返す環境) の両要件を 1 つのパターンで満たしています。早期 return で読みやすく、将来追加するモードの挿入箇所も明確です。
3. **set -u 下での未定義変数回避が徹底**: `${DASHBOARD_FAKE_COLS:-}` / `${COLUMNS:-}` で default 空文字に展開した上で regex match で数値判定する構造により、set -u と未設定環境変数の両立が実現されています。前 Spec (tmux-dashboard-mvp) で security-reviewer が指摘した CR-security-Critical-1 (shell injection) に類する同類指摘の再発もなく、新規の `DASHBOARD_FAKE_COLS` は数値 regex で検証された上で echo でしか使われていないため、path 構築やコマンド文字列への埋込は発生しません。

前回 Spec (tmux-dashboard-mvp) の consolidated.md で挙がった Major / Minor 指摘と同類の再発は code 観点では見当たりませんでした (CR-code-Major-1 / 2 / 3 / Minor-1〜8 は本 Spec の改変範囲外のままで、新規コードにも類似パターンなし)。

verdict は **pass** です。Critical / Major はなく、Minor を 3 件示しますが、いずれも ship ブロック要因ではなく、次サイクル以降でまとめて検討可能な品質改善事項です。

## 総合判定

verdict: pass

Critical 0 件 / Major 0 件 / Minor 3 件。agent 定義 §合否判定ルールに従い **pass** としました (Critical 0 件 かつ Major 2 件以下)。

## Critical

(なし)

## Major

(なし)

## Minor

- **[code-Minor-1] `DASHBOARD_FAKE_COLS=0` / 負数ケースのテスト欠落** (該当: `tests/test_dashboard.sh:160-162` / 修正提案: T-test-10b に `abc` と並んで `DASHBOARD_FAKE_COLS=0` ケースを追加し、`^[0-9]+$` regex は pass するが `-gt 0` で弾かれる経路を明示的に検証する。Spec AC-5 は「非数値 / 0 以下は無視、フォールバック経路に入る」と明記しており、現状 T-test-10b は非数値 `abc` のみをカバーしているため、AC-5 の後半「0 以下」条件が自動テスト上は `get_pane_cols` の regex 展開 `^[0-9]+$` に依存している状態。`0` は regex には合致するので `-gt 0` ガードが効いていることをテストで明示すると将来の regex 変更時に守られる。例: `assert_case "T-test-10c: DASHBOARD_FAKE_COLS=0 で fallback → wide" "DASHBOARD_FAKE_COLS=0 DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_PROG' bash '$DASHBOARD_PANE' sample 2>&1" 0 "stage +status +started_at"` を追加)

- **[code-Minor-2] `get_pane_cols` 内の 3 重 regex + gt 0 ガードの重複** (該当: `tools/dashboard-pane.sh:69-89` / 修正提案: 3 段すべてが `[[ "$x" =~ ^[0-9]+$ ]] && [[ "$x" -gt 0 ]]` の同じ判定を繰り返している。現状は「3 similar lines is better than a premature abstraction」の閾値内で読みやすさも確保されており、Minor 指摘にとどめる。将来 4 モード目を追加する / 受理レンジが複雑化する場合は `_is_positive_int()` helper を抽出して 1 行ずつに短縮可能。現コミットでの対応は不要で、指摘は記録のみ)

- **[code-Minor-3] narrow モードで長い status が pane 幅 40 境界を超える可能性** (該当: `tools/dashboard-pane.sh:109-120` / 修正提案: narrow モードの printf `"%-12s %s\n"` は stage=12 カラム固定 + 空白 1 + status 可変。`shipped-cross-model-pending` (27 文字) のような長い status 値では 12 + 1 + 27 = 40 で pane 幅 40 の境界ちょうどに達する。Spec §3.5 は compact モードのみ「端末の折返しに委ねる」と明記しており、narrow モードの長い status 時の挙動は Spec で未定義。実装は端末折返しに暗黙的に委ねる形になっているため、Spec §3.5 相当の一文を narrow モードにも適用する旨を `docs/tmux-dashboard-operation.md §3.1` の表注記か Spec 側の clarification で追記推奨。コード自体の変更は不要)

## 良かった点

- **wide モード出力のバイト列完全一致**: `render_stages_wide` の printf 文字列と jq クエリが現行 `render_spec()` の該当ブロックと完全一致しており、Plan §7.1 「純粋リファクタで既存テスト回帰ゼロ」が実装レベルで厳守されています。既存 T-test-6 (`progress.json 不在 warning`) 等が wide パスで引き続き pass できる構造的保証になっています
- **関数の責務分離が Plan §2.1 の設計通り**: `get_pane_cols` / `render_stages_wide` / `render_stages_narrow` / `render_stages_compact` / `render_spec` の 5 関数が Plan §4.1 の内部関数シグネチャ表と 1:1 対応しており、スコープクリープも過剰抽象もありません
- **コメントが WHAT ではなく WHY を記述**: `get_pane_cols` 冒頭の「1. DASHBOARD_FAKE_COLS (test 用、正整数のみ採用) / 3. tput cols (pty から ioctl で取得、非対話でも動作することが多い)」は、単に処理を説明するのではなく「なぜこの順序か」「tput を選ぶ理由」を記述しており、code-reviewer §2 の「コメントは WHY を書く」方針と合致しています
- **Spec §3.5 (compact の折返し委譲) が実装 + docs 両方に反映**: `tools/dashboard-pane.sh:123` のコメントに `(Spec §3.5)` と参照元が明示され、`docs/tmux-dashboard-operation.md §3.1` にも「compact モードで 1 行が pane 幅を超える場合 ... truncate は行いません」と運用者向けに記述されており、仕様と実装と docs の 3 点が整合しています
- **テスト fixture の再利用判断**: `specs/archive/tmux-dashboard-mvp.progress.json` を `$TMP_PROG/sample.progress.json` にコピーして 3 モードを検証する方式は、テスト固有のモック json を手書きするより保守コストが低く、実 progress.json の schema 変更時にテストもリアルに追従できる利点があります
- **前回 consolidated の指摘に対する regression なし**: CR-security-Critical-1 (shell injection) / CR-code-Major-1〜3 の領域に新規コードが踏み込んでおらず、新規追加の `DASHBOARD_FAKE_COLS` も regex ガード + echo のみの利用で同類の脆弱性を作っていません
