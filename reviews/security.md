---
reviewer: security-reviewer
spec: dashboard-color-themes
reviewed: 2026-04-24
executed_at: 2026-04-24T08:10:00Z
verdict: pass
---

# Security Review: dashboard-color-themes

## 総合判定

verdict: **pass**

Critical: 0 件、Major: 0 件、Minor: 2 件。Spec §7.1 の最重要リスク「source によるテーマ読み込み時の任意コード実行」に対する防御 (4 段検証 + `source`/`eval`/コマンド置換不使用) が実装されており、実機で攻撃ペイロード 3 種 (コマンド置換 / コマンド連結 / 非 COLOR_ 変数混入) を作って別途 PWN_MARKER 作成を試行したが、いずれも default フォールバックで遮断され RCE は成立しない。path traversal (`../evil`) も allowlist で遮断。`printf -v "$key"` の key が regex 事前検証済の `COLOR_[A-Z_]+` に限定されることから format string / 変数名注入も防御済。

## Critical

なし

## Major

なし

## Minor

- [security-Minor-1] A03: Injection — 回帰テストが「値 regex 違反」経路の end-to-end RCE 不発を assertion していない
  - **該当**: `tests/test_dashboard.sh:219-221` (T-test-12e)
  - **内容**: T-test-12e は `DASHBOARD_THEME='../evil'` の allowlist 違反拒否を検証しているが、Spec §5 AC-6 の「env ファイル内に `EVIL_CMD='rm -rf /'` 等の不正 entry が混入した場合に無害化されること」を end-to-end で `/tmp/PWN_MARKER` 未作成で検証するケース (T-test-7c と同形式) が無い。現状は regex が機能していれば不正 entry は had_invalid=1 → default フォールバックで防がれるが、将来 regex を緩和した際の回帰検知点が弱い。
  - **攻撃シナリオ**: 悪意ある PR reviewer が `tools/dashboard-themes/pwn.env` に `COLOR_X=$(touch /tmp/PWN)` を追加し、ユーザーが `DASHBOARD_THEME=pwn` を指定する。現実装では regex で弾かれ RCE 不成立だが、将来 regex を `\$[(]` 等の一部許可に書き換えた際にテストが気付けない。
  - **修正提案**: tests/test_dashboard.sh に T-test-12f を追加:
    ```bash
    MARKER_DIR="$(mktemp -d)"
    PWN_THEME_MARKER="${MARKER_DIR}/pwn_theme"
    PWN_THEMES_DIR="${MARKER_DIR}/themes"
    mkdir -p "$PWN_THEMES_DIR"
    cat > "$PWN_THEMES_DIR/evil.env" <<EOF
    COLOR_X=\$(touch $PWN_THEME_MARKER)
    COLOR_Y='\e[32m'; touch $PWN_THEME_MARKER
    EVIL_CMD='rm -rf /'
    EOF
    # SCRIPT_DIR/dashboard-themes が参照されるため、pane.sh をコピー + themes 配置
    cp "$DASHBOARD_PANE" "$MARKER_DIR/pane.sh"
    DASHBOARD_THEME=evil DASHBOARD_FORCE_COLOR=1 DASHBOARD_FAKE_COLS=80 \
      DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR="$TMP_PROG" \
      bash "$MARKER_DIR/pane.sh" sample >/dev/null 2>&1 || true
    if [[ -e "$PWN_THEME_MARKER" ]]; then
      FAIL=$((FAIL + 1)); FAIL_MESSAGES+=("[T-test-12f] RCE via theme file content")
    else
      PASS=$((PASS + 1))
    fi
    ```

- [security-Minor-2] A05: Security Misconfiguration — `export "$key"` でテーマ変数がプロセス環境全体に漏洩
  - **該当**: `tools/dashboard-pane.sh:101` (`export "$key"`)
  - **内容**: `load_theme` 末尾で `COLOR_*` 変数を export しているが、dashboard-pane.sh 自体からはサブプロセス (jq / awk / tail / clear) 呼び出し時にこれらの ANSI 文字列が渡る。現状は機密性のない表示用定数なので実害はないが、「必要な変数だけ export」原則に照らすと、同スクリプト内で参照するだけなら export は不要 (`printf -v` の代入だけで十分)。将来 `COLOR_` 以外の変数 (例: `THEME_NAME`) を追加した際に export 範囲の議論を再度行う必要が出るため、今のうちに不要な export は外すか「なぜ export しているか」のコメントを添えるのが望ましい。
  - **攻撃シナリオ**: 直接の攻撃経路はなし。defense-in-depth の観点で、後続 Spec が別変数を load_theme 経由でロードするよう拡張した際、その変数が意図せず子プロセスに漏れるリスクを予防する提案。
  - **修正提案**: 現状のまま export を残すなら `tools/dashboard-pane.sh:101` に `# export で子 jq/awk プロセスへ伝播 (必要なら後続 Spec で hermetic 化検討)` のコメント追加。もしくは export を外して `printf -v` のみに留め、同スクリプト内参照に限定する (現在 `print_color` は同スクリプト内のため動作に差はない)。

## 確認済事項

- **source / eval / コマンド置換の完全不使用**: `tools/dashboard-pane.sh` の load_theme 実装において `source`, `.`, `eval`, `$(...)`, backtick が含まれないことを確認 (line 46-103)。`printf '%b'` はコマンド置換ではなく format 指示子で、入力がすでに regex で `\e[0-9;]+m` 形式に制限されているため safe。
- **theme 名 allowlist (path traversal 遮断)**: `^[A-Za-z0-9][A-Za-z0-9._-]*$` が `../evil` / `/abs/path` / `.hidden` / `-rf` / 空文字をすべて拒否 (line 50)。T-test-12e で動作検証済。
- **行単位 allowlist (非 COLOR_ 変数遮断)**: `^(COLOR_[A-Z_]+)=(.*)$` の 1 件でも違反があれば had_invalid=1、最終的にテーマ全体を default フォールバック (line 68-71、86-92)。実機で `EVIL_CMD='...'` / `COLOR_FOO=$(...)` / `COLOR_FOO='\e[32m'; rm -rf /` の 3 パターンを試行し、いずれも PWN_MARKER 未作成を別途確認。
- **値 regex (`^(\\e\[[0-9\;]+m)*$`) の厳密性**: bash POSIX ERE の bracket expression では backslash がリテラル扱いのため `[0-9\;]` はデジット / セミコロン / バックスラッシュを許容するが、検証実験で `\e[3\2m` (余分 backslash 混入) は regex 全体として rejected されることを確認。先頭の `\\e` 以外に backslash を追加できない構造。
- **printf -v "$key" の変数名注入不可**: `$key` は `BASH_REMATCH[1]` 経由で `^COLOR_[A-Z_]+$` の capture group から取得、`IFS` / `PATH` / `LD_*` 等の危険変数上書きは不可。format string 展開も `%s` 固定なのでフォーマット文字列攻撃不成立。
- **再帰 load_theme 無限ループ防止**: `[[ "$theme_name" != "default" ]]` ガードが 3 箇所 (line 52 / 58 / 88) に配置され、`default.env` 自体が不在 / 不正な場合でも 1 回の warning 後に fallback せず exit する (line 31-38 の fallback 定数が有効のまま)。実機で default.env を削除 / 不正化して 5 秒 timeout で無限ループしないことを確認。
- **テーマ file の読み取り範囲限定**: `theme_file="${SCRIPT_DIR}/dashboard-themes/${theme_name}.env"` で親ディレクトリ固定 (line 55)。SCRIPT_DIR は `realpath` 相当の `cd && pwd` で決定済 (line 22)、`${theme_name}` は allowlist で `..` を排除済。Spec §6 非対象の「`tools/dashboard-themes/` 外のパスからのテーマ読み込み」境界が維持されている。
- **declare -A _pending の暗黙 local 化**: function 内の `declare -A` は bash で暗黙に local スコープ。再帰 `load_theme "default"` 時も外側 `_pending` を汚染しない (実機で挙動確認済)。
- **テーマ file 非機密**: `tools/dashboard-themes/*.env` は git 管理下の公開情報、機密情報の格納場所ではない。`docs/tmux-dashboard-operation.md §3.3` でセキュリティ境界を明記。
