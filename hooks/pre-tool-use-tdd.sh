#!/usr/bin/env bash
# PreToolUse hook: Edit/Write で実装ファイルを編集する際、対応するテストファイルの
# 存在を確認する。なければ exit 2 でブロックし、TDD 指導メッセージを stderr に出す。
#
# Phase 4 (2026-04-23) で tdd-driver skill の強制を物理化するために導入。
#
# 判定ロジック:
# 1. tool_name が Edit / Write でなければ通過
# 2. file_path が以下のいずれかなら通過 (除外):
#    - テストファイル / docs / config / skill 定義 / hook / Makefile 等
# 3. file_path の拡張子が実装言語 (.py/.ts/.tsx/.js/.jsx/.go/.rs/.java/.rb/.c/.cpp/.h/.hpp) でなければ通過
# 4. 現在のディレクトリが worktree 外 (worktrees/ セグメントを含まない) なら通過
#    → worktree 内 (spec-leader Implement ステージ中) のみ強制対象とする
# 5. 対応テストファイル候補のいずれかが存在すれば通過
# 6. いずれも存在しなければ exit 2 + 指導メッセージ
#
# bypass: SKIP_TDD_HOOK=1 環境変数を設定すると本 hook をスキップ (非推奨、手動承認時のみ)

set -euo pipefail

input="$(cat)"

if [[ "${SKIP_TDD_HOOK:-0}" == "1" ]]; then
  exit 0
fi

tool_name="$(printf '%s' "$input" | jq -r '.tool_name // empty')"
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"

# Edit / Write 以外は対象外
if [[ "$tool_name" != "Edit" && "$tool_name" != "Write" ]]; then
  exit 0
fi

# file_path 未指定は対象外
if [[ -z "$file_path" ]]; then
  exit 0
fi

# 除外パターン (テストファイル / docs / config / skill / hook / 等)
case "$file_path" in
  */tests/*|*/test/*|*/__tests__/*|*/spec/*|*.test.*|*.spec.*|*_test.*|*/test_*) exit 0 ;;
  */docs/*|*.md|*.mdx|*.txt|*.rst) exit 0 ;;
  */.claude/*|*/.github/*|*/.git/*|*/node_modules/*|*/venv/*|*/.venv/*|*/dist/*|*/build/*|*/__pycache__/*) exit 0 ;;
  *.json|*.yaml|*.yml|*.toml|*.ini|*.cfg|*.env|*.lock) exit 0 ;;
  */skills/*/SKILL.md|*/agents/*.md|*/hooks/*) exit 0 ;;
  *Makefile*|*Dockerfile*|*.sh|*.bash|*.zsh|*.fish) exit 0 ;;
esac

# 実装ファイル拡張子のみ対象
case "$file_path" in
  *.py|*.ts|*.tsx|*.js|*.jsx|*.go|*.rs|*.java|*.rb|*.c|*.cpp|*.h|*.hpp) ;;
  *) exit 0 ;;
esac

# worktree 内のみ強制対象 (spec-leader の Implement ステージ中を想定)
cwd="$(pwd)"
case "$cwd" in
  */worktrees/*) ;;
  *) exit 0 ;;
esac

# 対応テストファイル候補の生成
dir="$(dirname "$file_path")"
base="$(basename "$file_path")"
name="${base%.*}"
ext="${base##*.}"

candidates=()

case "$ext" in
  py)
    candidates+=(
      "$dir/test_${name}.py"
      "$dir/tests/test_${name}.py"
      "$(dirname "$dir")/tests/test_${name}.py"
      "tests/test_${name}.py"
      "tests/$(basename "$dir")/test_${name}.py"
    )
    ;;
  ts|tsx|js|jsx)
    candidates+=(
      "$dir/${name}.test.${ext}"
      "$dir/${name}.spec.${ext}"
      "$dir/__tests__/${name}.test.${ext}"
      "tests/${name}.test.${ext}"
      "__tests__/${name}.test.${ext}"
    )
    ;;
  go)
    candidates+=(
      "$dir/${name}_test.go"
    )
    ;;
  rs)
    candidates+=(
      "$dir/tests/${name}.rs"
      "tests/${name}_test.rs"
      "$dir/${name}_tests.rs"
    )
    ;;
  java)
    candidates+=(
      "$dir/${name}Test.java"
      "src/test/java/${name}Test.java"
    )
    ;;
  rb)
    candidates+=(
      "$dir/${name}_spec.rb"
      "spec/${name}_spec.rb"
      "test/${name}_test.rb"
    )
    ;;
  c|cpp|h|hpp)
    candidates+=(
      "$dir/${name}_test.${ext}"
      "$dir/test_${name}.${ext}"
      "tests/${name}_test.${ext}"
    )
    ;;
  *)
    # 未サポート拡張子は通過
    exit 0 ;;
esac

# いずれかの候補が存在すれば通過
for candidate in "${candidates[@]}"; do
  if [[ -f "$candidate" ]]; then
    exit 0
  fi
done

# テストなし → ブロック
{
  echo "[tdd-driver hook] TDD 違反: 実装ファイル \"$file_path\" に対応するテストが存在しません"
  echo ""
  echo "TDD サイクル (Red → Green → Refactor) に従い、実装より先にテストを書いてください:"
  echo ""
  echo "  1. 以下いずれかのパスにテストファイルを作成"
  for c in "${candidates[@]}"; do
    echo "     - $c"
  done
  echo ""
  echo "  2. pytest / jest / go test 等でテスト実行 → 失敗 (Red) を確認"
  echo ""
  echo "  3. その後、実装ファイル \"$file_path\" を編集してテストを通す (Green)"
  echo ""
  echo "参照: skills/tdd-driver/SKILL.md §3 TDD サイクルの強制ルール"
  echo "bypass (非推奨): SKIP_TDD_HOOK=1 環境変数で本 hook をスキップ可能"
} >&2

exit 2
