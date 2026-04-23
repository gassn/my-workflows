#!/usr/bin/env bash
# PostToolUse hook: Edit/Write でテストファイルを変更した直後に、対応するテストを
# 自動実行して結果を stderr に通知する (warning レベル、ブロックしない)。
#
# Phase 4 バッチ 2 (2026-04-23) で導入。tdd-driver skill の TDD サイクル
# (Red → Green → Refactor) で、developer agent がテスト編集後に手動で pytest を
# 叩く手間を軽減し、失敗検知を即座にフィードバックする。
#
# 判定ロジック:
# 1. SKIP_AUTO_TEST_HOOK=1 なら通過
# 2. tool_name が Edit / Write でなければ通過
# 3. file_path がテストファイルパターンに一致しなければ通過
#    (*.test.* / *.spec.* / test_* / *_test.go / tests/ 配下 等)
# 4. worktree 内のみ対象 (worktree 外は通過)
# 5. 言語を file_path の拡張子で判定、対応テストコマンドを実行
# 6. 結果 (pass/fail、実行時間) を stderr に出力
# 7. 常に exit 0 (ブロックしない、情報提供のみ)
#
# timeout: 30 秒 (settings.json 側で設定)、超過時は Claude Code が SIGTERM
# bypass: SKIP_AUTO_TEST_HOOK=1

set -euo pipefail

if [[ "${SKIP_AUTO_TEST_HOOK:-0}" == "1" ]]; then
  exit 0
fi

input="$(cat)"

tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"

if [[ "$tool_name" != "Edit" && "$tool_name" != "Write" ]]; then
  exit 0
fi

if [[ -z "$file_path" ]]; then
  exit 0
fi

# テストファイルパターン判定
is_test=0
case "$file_path" in
  */tests/*|*/test/*|*/__tests__/*|*/spec/*) is_test=1 ;;
  *.test.*|*.spec.*) is_test=1 ;;
  */test_*.py|test_*.py|*_test.go|*_test.rs|*_test.rb|*Test.java|*_spec.rb) is_test=1 ;;
esac

if [[ "$is_test" == "0" ]]; then
  exit 0
fi

# worktree 内のみ対象
cwd="$(pwd)"
case "$cwd" in
  */worktrees/*) ;;
  *) exit 0 ;;
esac

# 言語別テストコマンド
ext="${file_path##*.}"
start_ts=$(date +%s)
result=""
exit_status=0

case "$ext" in
  py)
    if command -v pytest >/dev/null 2>&1; then
      result=$(pytest "$file_path" -q 2>&1) || exit_status=$?
    elif command -v python3 >/dev/null 2>&1; then
      result=$(python3 -m pytest "$file_path" -q 2>&1) || exit_status=$?
    else
      exit 0
    fi
    ;;
  ts|tsx|js|jsx)
    if [[ -f "package.json" ]] && command -v npx >/dev/null 2>&1; then
      # jest / vitest 想定、失敗時も情報だけ出す
      result=$(npx --no-install jest "$file_path" 2>&1 || npx --no-install vitest run "$file_path" 2>&1) || exit_status=$?
    else
      exit 0
    fi
    ;;
  go)
    if command -v go >/dev/null 2>&1; then
      dir=$(dirname "$file_path")
      result=$(go test "./$dir" 2>&1) || exit_status=$?
    else
      exit 0
    fi
    ;;
  rs)
    if command -v cargo >/dev/null 2>&1; then
      result=$(cargo test --quiet 2>&1) || exit_status=$?
    else
      exit 0
    fi
    ;;
  rb)
    if command -v rspec >/dev/null 2>&1; then
      result=$(rspec "$file_path" 2>&1) || exit_status=$?
    else
      exit 0
    fi
    ;;
  *)
    exit 0 ;;
esac

end_ts=$(date +%s)
duration=$((end_ts - start_ts))

# 結果を stderr に通知
if [[ "$exit_status" == "0" ]]; then
  {
    echo "[auto-test hook] テストファイル変更を検出、自動実行 → pass (${duration}s)"
    echo "  対象: $file_path"
    echo "  結果: $(echo "$result" | tail -3 | head -2)"
  } >&2
else
  {
    echo "[auto-test hook] テストファイル変更を検出、自動実行 → FAIL (${duration}s)"
    echo "  対象: $file_path"
    echo "  ----- 出力抜粋 -----"
    echo "$result" | tail -20
    echo "  --------------------"
    echo "  (tdd-driver skill §3.1 Red フェーズの挙動、または実装とテストの不整合が疑われます)"
  } >&2
fi

exit 0  # 常に成功 (ブロックしない)
