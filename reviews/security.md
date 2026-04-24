---
reviewer: security-reviewer
spec: tmux-dashboard-v2-responsive
reviewed: 2026-04-24
executed_at: 2026-04-24T07:05:00Z
verdict: pass
---

# Security Review: tmux-dashboard-v2-responsive

## 概評

本 Spec は `tools/dashboard-pane.sh` に pane 幅適応レイアウトを追加する改修で、新規攻撃面は主に「新環境変数 `DASHBOARD_FAKE_COLS` の値処理」「`tput cols` / `$COLUMNS` 経由で取得した整数の使用経路」「新 jq クエリ (`render_stages_narrow` / `render_stages_compact`) の入力処理」の 3 点です。

前回 `tmux-dashboard-mvp` iter-1 で検出された Critical (Spec 名によるコマンドインジェクション、CR-security-Critical-1) の対策は `dashboard.sh` 側に残存しており、v2-responsive 改修では `dashboard-pane.sh` 内の allowlist `^[A-Za-z0-9][A-Za-z0-9._-]*$` / `validate_spec_name()` / `printf %q` エスケープは変更されていません。同類脆弱性の再発は確認されませんでした。

新規導入コードの入力検証は保守的な正整数 regex + 算術比較の 2 段で構成されており、バリデーション不十分で bash 算術評価や eval に流れる経路は見当たりません。compact モードの ANSI エスケープ素通しは前回 security-Minor-2 の見送り判断と整合し、本 Spec §3.5 および §4 非機能要件で明示されています (docs/tmux-dashboard-operation.md §8 に注記あり)。

OWASP 観点のヒート: A03 Injection 領域のみが実質的な対象 (path traversal / command injection / 端末エスケープ)、他領域 (認証 / 認可 / 暗号 / 機密情報) は本 Spec のスコープ外です。

## 総合判定

verdict: **pass**

Critical 0 件、Major 0 件、Minor 1 件 (再確認事項)。合否判定ルール「Critical 0 かつ Major 1 件以下 → pass」に該当します。

## Critical

なし。

## Major

なし。

## Minor

- [security-Minor-1] A03: Injection (端末エスケープ) — `tools/dashboard-pane.sh:127` の compact モードは `jq -r '.stages | to_entries[] | "\(.key)=\(.value.status // "-")"'` で progress.json の `status` フィールドを整形せずに直接 stdout へ出力します。悪意ある progress.json が `status` に `\x1b]0;hacked\x07` のような ANSI エスケープを含んでいれば、端末タイトルの改ざん / カーソル制御 / カラー変更が実行されます。wide / narrow モードも printf `%-12s` / `%s` に渡すだけで同様のリスクがあります。前回 security-Minor-2 (`tmux-dashboard-mvp.consolidated.md §2.3 / §3`) でも同一脆弱性を認識したうえで、Spec §4 非機能要件「progress.json の内容はユーザー責任」に基づき見送り済で、今回の Spec §3.5 (compact モードで truncate しない旨) および §4 非機能要件でも同方針が維持されています。docs/tmux-dashboard-operation.md §8 に「progress.md に外部入力を書かないこと」の注意が記載済のため、本 Spec では対応不要と判断しますが、**将来 progress.json / progress.md を外部入力 (Issue 本文 / PR コメント / webhook 等) から自動生成するステージを追加する場合は、`sed 's/\x1b/^[/g'` や `cat -v` 相当の ANSI 除去を compact / narrow / wide の全レンダリング経路に挟む必要があります**。攻撃シナリオ: progress.json を書き込む spec-leader / hook / 手動コミット経路に untrusted 入力が混入すれば、端末改ざん RCE に昇格する可能性があります。修正提案 (将来用): `jq -r '.value.status | gsub("[\\u0000-\\u001f\\u007f]"; "?")'` のような制御文字 sanitize を jq 内で実施。

## 確認済事項

- **DASHBOARD_FAKE_COLS の入力検証** (`tools/dashboard-pane.sh:70-74`): `[[ "$fake" =~ ^[0-9]+$ ]] && [[ "$fake" -gt 0 ]]` の 2 段ガードで、非数値・空文字・負数・0 は採用されず `$COLUMNS` / `tput cols` 経路にフォールバックします。正整数 regex が確定した後に bash 算術比較 (`-gt 0`) に渡るため、算術評価のコマンド置換 (例: `$(touch /tmp/pwn)`) は regex で弾かれます。`eval` や `$(...)` は使われておらず、採用後の値は `echo "$fake"` で stdout に返され呼び出し元変数 `cols` に入って再度 regex ガードと `-ge 60 / -ge 40` 比較にしか使われません。injection 余地なし。
- **tput cols / $COLUMNS 経路** (`tools/dashboard-pane.sh:76-86`): 両経路とも取得直後に `^[0-9]+$` + `-gt 0` で再検証、失敗時は 80 default に落とすため、pty ioctl 異常や env 改ざんでも非数値は採用されません。bash 算術比較 `-ge 60 / -ge 40` に渡る値はいずれも正整数確定後なので、算術評価由来の injection 経路なし。
- **Spec 名 allowlist の維持** (`tools/dashboard-pane.sh:24, 32-39, 191`): `SPEC_NAME_PATTERN='^[A-Za-z0-9][A-Za-z0-9._-]*$'` と `validate_spec_name()` が 2026-04-24 強化版 (先頭英数字必須、dot-only / dot-starting / hyphen-starting 拒否) のまま保持されています。v2-responsive 改修で追加された `render_stages_wide / narrow / compact` は `$1=progress_json` をファイルパスとしてのみ受け取り、`render_spec()` 内で `${SPEC_DIR}/${spec}.progress.json` という固定パターンで生成されたパスを渡します。`spec` は既に `validate_spec_name` を通過済のため、新規 path traversal 余地は生じません。
- **新 jq クエリの堅牢性** (`tools/dashboard-pane.sh:96-100, 112-116, 127`): `@tsv` / jq 文字列補間はいずれも不正 JSON / 巨大値で jq 自体が exit 非 0 で落ちるだけで、shell 側は `2>/dev/null | while read` でエラー抑止しており、fatal 化は起こりません。巨大な status 文字列 (数 MB 等) で printf が OOM になる可能性は理論上ありますが、progress.json の内容はユーザー管理下なので現実的リスクは低く、前回 Spec §4 の「ユーザー責任」条項でカバーされています。`while read` の IFS 指定 (`IFS=$'\t'`) も適切で、タブを含む status 値は @tsv の escape で処理されるため column 崩れは発生しません。
- **test_dashboard.sh の bash -c 経由評価** (`tests/test_dashboard.sh:138-162`): 新規 5 ケース (T-test-9a/b/c / T-test-10a/b) は `DASHBOARD_FAKE_COLS=80 / 50 / 30 / abc` と固定値のみを埋め込み、テスト外部入力はありません。冒頭 (lines 20-23) の `REPO_ROOT` シングルクォート assertion で quote-escape 耐性も確保されており、新 FAKE_COLS 経由で壊れる経路なし。T-test-7 の RCE 回帰テスト (PWN_MARKER による実行検知) も v2-responsive で変更なしで保たれています。
- **compact モード truncate 省略** (`tools/dashboard-pane.sh:122-128` / Spec §3.5): ANSI エスケープ素通しは Minor-1 に記載の通り許容ポリシー。前回 security-Minor-2 の見送り判断 (`tmux-dashboard-mvp.consolidated.md §3`) と整合、本 Spec でも既存方針を逸脱していません。
- **環境変数 DASHBOARD_SPEC_DIR / DASHBOARD_WORKTREES_DIR**: v2-responsive では新規参照経路を追加していません。既存の `render_spec()` 内で `${SPEC_DIR}/${spec}.progress.json` 等のパス構築が残りますが、spec は allowlist 通過済、SPEC_DIR はユーザー管理下のため、新たな traversal 経路は増えていません。

## OWASP カテゴリ別ヒート

- A01 Broken Access Control: N/A (CLI ローカル実行)
- A02 Cryptographic Failures: N/A (暗号機能なし)
- **A03 Injection**: Minor-1 のみ (端末エスケープ、ユーザー責任ポリシーで見送り継続)
- A04 Insecure Design: 該当なし (前回指摘は allowlist + printf %q 2 層で対処済、維持を確認)
- A05 Security Misconfiguration: 該当なし
- A06 Vulnerable and Outdated Components: N/A (依存は jq / tput / tmux / bash のみ、新規追加なし)
- A07 Identification and Authentication Failures: N/A
- A08 Software and Data Integrity Failures: 該当なし (テスト fixture は archive/ からの read-only コピー)
- A09 Security Logging and Monitoring Failures: N/A
- A10 SSRF: N/A

## 次ステップ

- 本 Spec 範囲では追加修正不要。spec-leader は Code Review ステージで本 review を pass として統合してください。
- Minor-1 (ANSI エスケープ) は将来 progress.md に外部入力を取り込むステージを設計する際に、改めてセキュリティ要件として再掲する必要があります。`docs/tmux-dashboard-operation.md §8` の既存注意書きを削除しないでください。
