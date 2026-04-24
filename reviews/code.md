---
reviewer: code-reviewer
spec: dashboard-color
executed_at: 2026-04-24T07:50:00Z
verdict: pass
---

# Code Review: dashboard-color

## 総合判定

verdict: pass

- Critical: 0 件
- Major: 0 件
- Minor: 2 件

判定根拠: code-reviewer 合否ルール「Critical 0 件 かつ Major 2 件以下 → pass」を満たします。Plan §5 タスク分解 (T-1〜T-4) はすべて実装され、25/25 テスト pass も Verify で確認済です。後続 Spec `dashboard-color-themes` の Plan が前提とする `print_color` API 契約 (Plan §4.1) も、`COLOR_*` 変数の静的定義 + 関数内での参照という形で維持されています。

## Critical

なし。

## Major

なし。

## Minor

- [code-Minor-1] `render_stages_narrow` での `print_color` 呼び出しが Spec §3.2 と Plan §5.1 T-3 の記述 (`print_color "$status" 12`) から visible-width 引数を省略している (該当: `tools/dashboard-pane.sh:182`)。
  - 現状の挙動: `printf "%-12s %s\n" "$stage" "$(print_color "$status")"` のため status は行末に置かれ後続カラムがないので表示は崩れず、コード内コメントも「1 行末尾なので列崩れしない」と割り切りを明記しています。
  - 指摘理由: Spec §3.2 と Plan §5.1 T-3 は明示的に「narrow モードも visible-width=12」と書いており、後続 `dashboard-color-themes` Spec で `load_theme` による可変長テーマが入った場合や、将来 narrow モードに列追加が入った場合に、この省略が列崩れの潜在バグになります。
  - 修正提案 (いずれか): (a) 記述を揃えるなら実装を `print_color "$status" 12` に変更、(b) 割り切りを維持するなら Spec §3.2 / Plan §5.1 T-3 に「narrow は行末なので width 省略」と注記を追加。後者で十分と判断した根拠はコード内コメントのみで、Spec / Plan 側が未更新です。
  - 本修正は ship ブロック要因ではないため Minor 判定 (pass verdict を維持)。

- [code-Minor-2] `_color_for_status` の case 文に `pending` が明示されているが、対応する `COLOR_PENDING` は空文字列のため `print_color` 内の `if [[ -n "$color_on" ]]` 分岐で結局 ANSI なしパスに落ちる (該当: `tools/dashboard-pane.sh:57, 81`)。
  - 現状の挙動: `pending` は `*)` (default) と同じく「色なしで padded 出力」経路に合流するため、ロジックとしては冗長。
  - 指摘理由: 後続 `dashboard-color-themes` Spec の Plan §4.3 で `COLOR_PENDING` もテーマから上書き可能になる前提があり、冗長性は仕様拡張のための「フック」として正当化されます。よって Minor でも「削除推奨」ではなく「将来の拡張を見越して意図的に残している」とコメントで明記する方が保守者に親切です。
  - 修正提案: `_color_for_status` の `pending)` 分岐の前段または先頭のコメントブロックに、「pending はデフォルトでカラーなし (`COLOR_PENDING=''`)、`dashboard-color-themes` で色付きに上書き可能なためフォールバックではなく明示的に拾っている」と 1 行注釈を追加。本修正は可読性改善のみで ship ブロックせず。

## 良かった点

- **Plan §7.2 の実装順序厳守**: `printf -v padded "%-${width}s"` で先にパディング → `printf '%s%s%s' "$color_on" "$padded" "$COLOR_RESET"` で色を重ねる順序が、Plan §7.2 の「逆にすると ANSI エスケープがバイト長に含まれて列崩れ」を完全に守っており、T-test-11d で 12 文字幅の実測検証も付随しています (`tools/dashboard-pane.sh:73-88`)。
- **`_is_color_enabled` の優先度設計の明瞭さ**: 関数先頭のコメント (`優先度: DASHBOARD_FORCE_COLOR=1 > NO_COLOR / DASHBOARD_NO_COLOR > [[ -t 1 ]]`) と 5 行の return が順序と効果を 1 対 1 に対応させており、将来テーマ / force-color の他フラグ追加時にも読み手が挿入位置を迷わない構造です (`tools/dashboard-pane.sh:43-49`)。
- **`shipped-*` / `aborted-*` prefix 一致の保守性**: `shipped|shipped-*` の `|` OR で `shipped` そのものと `shipped-cross-model-pending` などのバリエーションを 1 箇所に集約しており、将来 `shipped-partial` 等が追加されてもこの case 節だけ見れば拡張可能 (`tools/dashboard-pane.sh:60-61`)。
- **後続 Spec への API 契約の明示性**: `COLOR_*` 変数をファイル先頭の static 定義で並べ、`_color_for_status` が関数単位で参照する構造は、後続 `dashboard-color-themes` Spec の Plan §4.1 `load_theme` による export 上書きに自然に接続します。`print_color` 関数の signature も Plan §4.1 と一致し、後続 Plan が `references_other_plans` に本 Plan を挙げる根拠が維持されています (`tools/dashboard-pane.sh:29-38`)。
- **テストの過不足なし**: 新規 5 ケース (T-test-11a〜11e) が Spec §5 AC-4 / AC-5 / AC-7 に対応する 5 観点 (DASHBOARD_NO_COLOR / NO_COLOR / 非 TTY 自動無効化 / 12 幅パディング保持 / FORCE_COLOR で ANSI 検出) を直行カバーし、既存 20 ケースは無改修で維持。AC-7 で要求されていた「主要 5 status パターン」の明示的な 1 ケース 1 status 分割までは行っていないが、T-test-11e の `grep -cE $'\\x1b\\[3[0-9]m'` で 1 件以上検出を確認しており、実質的な AC カバレッジとして機能しています (`tests/test_dashboard.sh:169-199`)。

## 補足: Plan との一致確認

| Plan タスク | 実装 | 一致度 |
|---|---|---|
| T-1: T-test-11a〜11d の Red 先行追加 | T-test-11a〜11e (5 ケース) | 一致 (1 ケース追加、fail 検出の補強) |
| T-2: print_color + _color_for_status + _is_color_enabled + COLOR_* 8 変数 | 同上 | 一致 |
| T-3: 3 レンダラから print_color を呼ぶよう改修 | wide: width=12 / narrow: width 省略 / compact: width 省略 | code-Minor-1 で指摘したとおり narrow のみ Plan §5.1 T-3 から逸脱 (実害なし) |
| T-4: docs/tmux-dashboard-operation.md 更新 | §3.2 ANSI カラーを新設 + §3 環境変数表に 3 変数追加 | 一致 |

## spec-leader への報告

- verdict: pass
- code.md: `reviews/code.md`
- Critical: 0 件 / Major: 0 件 / Minor: 2 件
- ship ブロック要因: なし
