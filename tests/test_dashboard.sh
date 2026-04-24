#!/usr/bin/env bash
# tmux-dashboard-mvp ドライラン検証スクリプト
#
# tmux を実起動せずに dashboard.sh / dashboard-pane.sh の
# bash 構文・引数パース・エラー / warning 経路を確認する。
#
# 使い方: bash tests/test_dashboard.sh
# exit 0: 全ケース pass
# exit 1: いずれかのケースで fail

set -u

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DASHBOARD="${REPO_ROOT}/tools/dashboard.sh"
readonly DASHBOARD_PANE="${REPO_ROOT}/tools/dashboard-pane.sh"

# assert_path_safe: テストハーネス自身が bash -c の文字列評価に依存するため、
# ホームパス / mktemp パスにシングルクォートが含まれるとテストが壊れる。
# 実行前にクリティカルなパスにシングルクォートが含まれないことを確認する。
if [[ "$REPO_ROOT" == *\'* ]]; then
  echo "REPO_ROOT にシングルクォートを含むパスはテスト非対応: $REPO_ROOT" >&2
  exit 1
fi

PASS=0
FAIL=0
FAIL_MESSAGES=()

# assert_case: 条件が真なら PASS、偽なら FAIL を記録する
# 引数: $1=テスト名, $2=実行コマンド (文字列), $3=期待 exit code, $4=stdout/stderr の含有条件 (任意正規表現)
# 注意: $2 は bash -c に渡されるため呼び出し側で quoting 責任を負う。REPO_ROOT 側は冒頭で assert 済み。
assert_case() {
  local name="$1"
  local cmd="$2"
  local expected_exit="$3"
  local expected_match="${4:-}"

  local output
  local actual_exit
  output="$(bash -c "$cmd" 2>&1)"
  actual_exit=$?

  if [[ "$actual_exit" != "$expected_exit" ]]; then
    FAIL=$((FAIL + 1))
    FAIL_MESSAGES+=("[$name] exit code mismatch: expected=$expected_exit actual=$actual_exit output='$output'")
    return
  fi

  if [[ -n "$expected_match" ]] && ! grep -Eq "$expected_match" <<<"$output"; then
    FAIL=$((FAIL + 1))
    FAIL_MESSAGES+=("[$name] output does not match '$expected_match': output='$output'")
    return
  fi

  PASS=$((PASS + 1))
}

# --- T-test-1: bash 構文チェック ---
assert_case "T-test-1a: dashboard.sh 構文" "bash -n '$DASHBOARD'" 0 ""
assert_case "T-test-1b: dashboard-pane.sh 構文" "bash -n '$DASHBOARD_PANE'" 0 ""

# --- T-test-2: --help 応答 ---
assert_case "T-test-2: --help" "bash '$DASHBOARD' --help" 0 "Usage"

# --- T-test-3: 無効引数 ---
assert_case "T-test-3: 無効フラグ" "bash '$DASHBOARD' --invalid-flag" 1 "(unknown|invalid|不明)"

# --- T-test-4: 対象 0 件 ---
# DASHBOARD_DRY_RUN + DASHBOARD_SPEC_DIR を一時ディレクトリに差し替えて 0 件を再現
TMP_EMPTY="$(mktemp -d)"
trap 'rm -rf "$TMP_EMPTY"' EXIT
assert_case "T-test-4: 対象 0 件" \
  "DASHBOARD_DRY_RUN=1 DASHBOARD_SPEC_DIR='$TMP_EMPTY' bash '$DASHBOARD'" \
  0 "(対象 Spec がありません|No target spec)"

# --- T-test-5: tmux 未インストール ---
assert_case "T-test-5: tmux 未インストール" \
  "DASHBOARD_FAKE_NO_TMUX=1 bash '$DASHBOARD' dummy-spec" \
  1 "tmux.*(インストール|install)"

# --- T-test-6: progress.json 不在 warning ---
# 注意: ghost-spec は allowlist を通過する正常な Spec 名 (T-test-7 の allowlist 弾きと区別するため)
assert_case "T-test-6: progress.json 不在 warning" \
  "DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_EMPTY' bash '$DASHBOARD_PANE' ghost-spec 2>&1" \
  0 "(progress 未生成|not generated)"

# --- T-test-7: Spec 名 allowlist (Critical-1 回帰) ---
# 攻撃ペイロード: 細工 Spec 名を dashboard-pane.sh / dashboard.sh に渡すと allowlist で弾かれ exit 1
# 実際にコマンド実行が成立すると /tmp/PWN_MARKER が作成されるが、allowlist で弾けば作成されない
MARKER_DIR="$(mktemp -d)"
PWN_MARKER="${MARKER_DIR}/pwn"
EVIL_SPEC='evil$(touch '"'"${PWN_MARKER}"'"')#'
# pane 側 allowlist
assert_case "T-test-7a: 細工 Spec 名は dashboard-pane で拒否" \
  "DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_EMPTY' bash '$DASHBOARD_PANE' 'evil;id;#' 2>&1" \
  1 "(invalid spec name|不正な spec 名)"
# dashboard.sh 側 allowlist
assert_case "T-test-7b: 細工 Spec 名は dashboard で拒否" \
  "DASHBOARD_DRY_RUN=1 DASHBOARD_SPEC_DIR='$TMP_EMPTY' bash '$DASHBOARD' 'evil;id;#' 2>&1" \
  0 "(invalid spec name|不正な spec 名)"
# attack payload を実行しても /tmp の PWN_MARKER が作成されない
rm -f "$PWN_MARKER"
DASHBOARD_DRY_RUN=1 DASHBOARD_SPEC_DIR="$TMP_EMPTY" bash "$DASHBOARD" "$EVIL_SPEC" >/dev/null 2>&1 || true
if [[ -e "$PWN_MARKER" ]]; then
  FAIL=$((FAIL + 1))
  FAIL_MESSAGES+=("[T-test-7c: インジェクション実行不可] PWN_MARKER が作成されました = RCE 成立")
else
  PASS=$((PASS + 1))
fi
rm -rf "$MARKER_DIR"

# --- T-test-8: allowlist の dot-only / dot-starting 拒否 (security iter-2 Minor 対応) ---
# `.` / `..` / `.hidden` のような先頭ドット Spec 名は WORKTREES_DIR/../progress.md 等の path
# traversal の余地があるため、^[A-Za-z0-9][A-Za-z0-9._-]*$ で弾く
assert_case "T-test-8a: dot-only Spec 名 (..) は dashboard-pane で拒否" \
  "DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_EMPTY' bash '$DASHBOARD_PANE' '..' 2>&1" \
  1 "(invalid spec name|不正な spec 名)"
assert_case "T-test-8b: dot-starting Spec 名 (.hidden) は dashboard-pane で拒否" \
  "DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_EMPTY' bash '$DASHBOARD_PANE' '.hidden' 2>&1" \
  1 "(invalid spec name|不正な spec 名)"
assert_case "T-test-8c: dot-only Spec 名 (..) は dashboard でも拒否" \
  "DASHBOARD_DRY_RUN=1 DASHBOARD_SPEC_DIR='$TMP_EMPTY' bash '$DASHBOARD' '..' 2>&1" \
  0 "(invalid spec name|不正な spec 名)"
# hyphen-starting は従来通り拒否
assert_case "T-test-8d: hyphen-starting Spec 名 (-rf) は dashboard-pane で拒否" \
  "DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_EMPTY' bash '$DASHBOARD_PANE' '-rf' 2>&1" \
  1 "(invalid spec name|不正な spec 名)"

# --- T-test-9 / T-test-10: pane 幅適応 (v2-responsive) ---
# 実在する Spec (progress.json あり) を対象にして 3 モード切替 + fallback を検証する
# archive 済の tmux-dashboard-mvp.progress.json を test fixture として使う
TMP_PROG="$(mktemp -d)"
trap 'rm -rf "$TMP_EMPTY" "$TMP_PROG"' EXIT
cp "$REPO_ROOT/specs/archive/tmux-dashboard-mvp.progress.json" "$TMP_PROG/sample.progress.json"

# T-test-9a: wide モード (FAKE_COLS=80)
# 4 列テーブル ヘッダ (stage / status / started_at / completed_at) が出力される
assert_case "T-test-9a: DASHBOARD_FAKE_COLS=80 で wide モード (4 列)" \
  "DASHBOARD_FAKE_COLS=80 DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_PROG' bash '$DASHBOARD_PANE' sample 2>&1" \
  0 "stage +status +started_at +completed_at"

# T-test-9b: narrow モード (FAKE_COLS=50)
# 2 列 (stage / status のみ)、started_at 見出しは出力されない
assert_case "T-test-9b: DASHBOARD_FAKE_COLS=50 で narrow モード (started_at 見出しなし)" \
  "DASHBOARD_FAKE_COLS=50 DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_PROG' bash '$DASHBOARD_PANE' sample 2>&1 | grep -E '^stage'" \
  0 "^stage +status$"

# T-test-9c: compact モード (FAKE_COLS=30)
# 1 列 (stage=status 形式)
assert_case "T-test-9c: DASHBOARD_FAKE_COLS=30 で compact モード (key=value)" \
  "DASHBOARD_FAKE_COLS=30 DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_PROG' bash '$DASHBOARD_PANE' sample 2>&1" \
  0 "isolate=completed"

# T-test-10a: FAKE_COLS 未設定時は $COLUMNS または tput fallback で動作
assert_case "T-test-10a: DASHBOARD_FAKE_COLS 未設定で fallback 動作" \
  "unset DASHBOARD_FAKE_COLS; DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_PROG' bash '$DASHBOARD_PANE' sample 2>&1" \
  0 "(isolate|implement|verify)"

# T-test-10b: 不正値 (abc) の場合も fallback で wide になり、コマンド自体は成功する
assert_case "T-test-10b: DASHBOARD_FAKE_COLS=abc (非数値) で fallback → wide" \
  "DASHBOARD_FAKE_COLS=abc DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_PROG' bash '$DASHBOARD_PANE' sample 2>&1" \
  0 "stage +status +started_at"

# T-test-10c: 0 以下 (0) の場合も fallback で wide に落ちる (AC-5 後半)
assert_case "T-test-10c: DASHBOARD_FAKE_COLS=0 (0 以下) で fallback → wide" \
  "DASHBOARD_FAKE_COLS=0 DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_PROG' bash '$DASHBOARD_PANE' sample 2>&1" \
  0 "stage +status +started_at"

# --- T-test-11: ANSI カラー対応 (dashboard-color Spec) ---
# テストハーネス自体が bash -c パイプ経由で TTY false のため、
# 明示的に script コマンドや DASHBOARD_FORCE_TTY で擬似しない限り
# print_color は NO_COLOR 経路を通る。ここではその経路で ANSI 不在を確認する。

# T-test-11a: DASHBOARD_NO_COLOR=1 で ANSI エスケープなし
assert_case "T-test-11a: DASHBOARD_NO_COLOR=1 で ANSI 不在" \
  "DASHBOARD_NO_COLOR=1 DASHBOARD_FAKE_COLS=80 DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_PROG' bash '$DASHBOARD_PANE' sample 2>&1 | grep -cE $'\\x1b\\[' ; [[ \$? -eq 1 ]]" \
  0 ""

# T-test-11b: NO_COLOR=1 (業界標準) でも ANSI 不在
assert_case "T-test-11b: NO_COLOR=1 (業界標準) で ANSI 不在" \
  "NO_COLOR=1 DASHBOARD_FAKE_COLS=80 DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_PROG' bash '$DASHBOARD_PANE' sample 2>&1 | grep -cE $'\\x1b\\[' ; [[ \$? -eq 1 ]]" \
  0 ""

# T-test-11c: パイプ経由 (非 TTY) で自動無効化される (既存 T-test-9a と同一条件)
assert_case "T-test-11c: 非 TTY で自動 NO_COLOR" \
  "DASHBOARD_FAKE_COLS=80 DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_PROG' bash '$DASHBOARD_PANE' sample 2>&1 | grep -cE $'\\x1b\\[3[0-9]m' ; [[ \$? -eq 1 ]]" \
  0 ""

# T-test-11d: wide モード status カラムの visible-width 12 維持 (NO_COLOR 時でパディング確認)
# "completed" (9 文字) + 空白 3 = 12 文字で next column の started_at が開始
assert_case "T-test-11d: wide モード 12 文字幅パディング保持" \
  "DASHBOARD_NO_COLOR=1 DASHBOARD_FAKE_COLS=80 DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_PROG' bash '$DASHBOARD_PANE' sample 2>&1 | grep -E 'completed +2026' | head -1" \
  0 "completed    2026"

# T-test-11e: DASHBOARD_FORCE_COLOR=1 で TTY 判定 bypass → ANSI 有り (実装検証用)
# 実装前は print_color 関数が存在しないため ANSI が出ず fail、実装後は pass
assert_case "T-test-11e: DASHBOARD_FORCE_COLOR=1 で ANSI 出力" \
  "DASHBOARD_FORCE_COLOR=1 DASHBOARD_FAKE_COLS=80 DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_PROG' bash '$DASHBOARD_PANE' sample 2>&1 | grep -cE $'\\x1b\\[3[0-9]m'" \
  0 "^[1-9]"

# --- 結果出力 ---
echo ""
echo "=== test_dashboard.sh 結果 ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "失敗ケース:"
  for m in "${FAIL_MESSAGES[@]}"; do
    echo "  - $m"
  done
  exit 1
fi

exit 0
