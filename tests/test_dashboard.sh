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

PASS=0
FAIL=0
FAIL_MESSAGES=()

# assert: 条件が真なら PASS、偽なら FAIL を記録する
# 引数: $1=テスト名, $2=実行コマンド (文字列), $3=期待 exit code, $4=stdout/stderr の含有条件 (任意正規表現)
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
assert_case "T-test-6: progress.json 不在 warning" \
  "DASHBOARD_PANE_ONESHOT=1 DASHBOARD_SPEC_DIR='$TMP_EMPTY' bash '$DASHBOARD_PANE' ghost-spec 2>&1" \
  0 "(progress 未生成|not generated)"

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
