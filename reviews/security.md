---
reviewer: security-reviewer
spec: dashboard-color
executed_at: 2026-04-24T07:50:00Z
verdict: pass
---

# Security Review: dashboard-color

## 総合判定

verdict: pass

- Critical: 0 件
- Major: 0 件
- Minor: 1 件

判定根拠: security-reviewer 合否ルール「Critical 0 件 かつ Major 1 件以下 → pass」を満たします。本改修 (print_color + ヘルパー関数 + 環境変数 3 種) は**新規の外部入力経路を増やしていません**。既存の Spec 名 allowlist (`^[A-Za-z0-9][A-Za-z0-9._-]*$`) と T-test-7 のインジェクション回帰テストは無改修で pass しており、printf %q エスケープ経路 (dashboard.sh 側) も本 PR では触っていません。shell injection / ANSI injection / 変数上書きのいずれも実効的な攻撃経路にはなりません。

## Critical

なし。

## Major

なし。

## Minor

- [security-Minor-1] `status` カラム経路の ANSI エスケープはスルー可能で、攻撃者が `specs/*.progress.json` の書き込み権限を持つ場合に端末制御が可能になる (該当: `tools/dashboard-pane.sh:69-89, 163-194` / OWASP A03: Injection、A09: Security Logging and Monitoring Failures の周辺)。
  - **攻撃シナリオ**: 本プロジェクト外の悪意ある spec-leader 実装、もしくは progress.json が untrusted ソース (CI / webhook / 外部 PR の任意書込) で更新される場合、`.stages.foo.status` に `\e]0;PWN\a\e[31mfake-completed\e[0m` のような文字列を埋めると、jq は文字列として読み出し、`print_color` は `_color_for_status` の default 分岐 (`*)`) を通って、padded の中に埋め込まれた ANSI がそのまま端末に流れます。結果として端末タイトル書き換え / カラー偽装 / カーソル移動 / OSC 52 によるクリップボード書込 (一部端末) が成立。
  - **責任範囲の整理**: `docs/tmux-dashboard-operation.md §8` で「progress.md に外部入力を書かない、ANSI エスケープは端末にそのまま流れる」と明記済で、status 文字列も同じ信頼境界にあります。本 Spec のスコープでは `progress.json` は spec-leader が書くトラステッドデータ、という前提が維持されており、現状では Critical / Major ではありません。
  - **修正提案 (任意、現状は pass で ship 可)**: `docs/tmux-dashboard-operation.md §8` の「progress.md に外部入力を書かない」節を、`progress.json` の `.stages[].status` 値も含む形で記述を拡張し、「status 値に対する ANSI / OSC シーケンス混入は端末制御として実行されるため、status の値ソースはトラステッドであること」を明記。あるいは `_color_for_status` の default 分岐で `printf '%s' "$status"` 前に `status="${status//$'\e'/}"` で ESC を除去 (幅計算が変わらないよう先にフィルタ)。後者は `dashboard-color-themes` の feasibility にも波及するため、ドキュメント化で対処する方がバランス良。
  - 重大度判定: 攻撃前提条件が「progress.json への書き込み権限」であり、spec-leader の信頼前提と同じ境界上にあるため Minor。Critical / Major へ昇格するのは progress.json が untrusted ソースから書かれる運用に変更された場合のみ。

## 確認済事項

- **`printf -v padded "%-${width}s"` の format string 注入**: `width` は `[[ "$width" =~ ^[0-9]+$ ]] && [[ "$width" -gt 0 ]]` で数値検証済のため `${width}` に `%s` 等を仕込む経路はなし。`status` は format の引数 (第 3 引数に相当) として渡されており、format 文字列側には埋め込まれないので `$status` 中の `%` 文字による format string 攻撃も成立しない (`tools/dashboard-pane.sh:73-76`)。
- **`printf -v` の変数名展開による意図せぬ変数上書き**: `printf -v padded` の変数名 `padded` はスクリプト内で固定のリテラル。ユーザー入力由来の変数名で `-v` を呼ぶ箇所はなく、hazardous な `printf -v "$user_input"` パターンは不存在 (`tools/dashboard-pane.sh:75`)。
- **環境変数の値検証**: `DASHBOARD_FORCE_COLOR` / `DASHBOARD_NO_COLOR` は `== "1"` の strict 比較、`NO_COLOR` は `[[ -n ]]` で業界標準 (no-color.org spec に準拠、「非空ならすべて disable」)。いずれも不正値で fatal にならず、未設定時は `:-0` / `:-` で安全に未定義扱い。`[[ -t 1 ]]` は副作用なしの TTY 判定のみ (`tools/dashboard-pane.sh:43-49`)。
- **既存 Spec 名 allowlist の維持**: T-test-7 (Critical-1 インジェクション回帰) と T-test-8 (dot-only / hyphen-starting 拒否) が無改修で 25/25 pass を維持しており、`validate_spec_name` 関数は本 PR で触られていない。Spec 名経由の shell injection / path traversal 対策は後退していない (`tools/dashboard-pane.sh:91-101` / `tests/test_dashboard.sh:87-127`)。
- **tmux 側の `printf %q` エスケープ**: 本 PR では `dashboard.sh` を改修していないため、tmux `new-session` / `split-window` への Spec 名引き渡しの 2 層防御 (allowlist + `%q`) は現状維持。
- **`_color_for_status` の case 節に対するパターン注入**: 入力 `$1` はマッチ対象の値であり、右辺の glob パターン (`completed` / `shipped-*` 等) はスクリプト内の固定文字列。入力値に `*` / `?` / `[` が含まれても、これらは「値側の文字」として扱われパターンとしては解釈されないため、意図しない分岐入りは発生しない (`tools/dashboard-pane.sh:53-64`)。
- **新規環境変数 3 種 (`DASHBOARD_FORCE_COLOR` / `DASHBOARD_NO_COLOR` / `NO_COLOR`) 経由のコマンドインジェクション**: いずれも値は `==` / `-n` 比較にしか使われず、`eval` / `source` / unquoted expansion に流れる経路が一切ない。
- **依存ライブラリの変更**: 新規依存なし。jq / bash / tmux のバージョン要件は shipped 版と同一で、CVE 追加の露出なし。

## OWASP カテゴリ別ヒート

| カテゴリ | 指摘 |
|---|---|
| A01: Broken Access Control | - |
| A02: Cryptographic Failures | - |
| A03: Injection | Minor-1 (ANSI / OSC 経路、ただし trust boundary 上の既知範囲) |
| A04: Insecure Design | - |
| A05: Security Misconfiguration | - |
| A06: Vulnerable and Outdated Components | - |
| A07: Identification and Authentication Failures | 本 PR 非対象 (ツール単体で認証なし) |
| A08: Software and Data Integrity Failures | - |
| A09: Security Logging and Monitoring Failures | Minor-1 の周辺 (端末制御シーケンスによる「ログの視認性毀損」観点でも同質) |
| A10: SSRF | - |

## spec-leader への報告

- verdict: pass
- security.md: `reviews/security.md`
- Critical: 0 件 / Major: 0 件 / Minor: 1 件
- OWASP 集中領域: なし (A03 周辺に Minor 1 件のみ、progress.md 取り扱いと同じ trust boundary)
- ship ブロック要因: なし
