#!/usr/bin/env bash
# Stop hook: Claude の応答終了前に呼ばれる。worktree 内で作業中の場合、
# verification-before-completion の成果物 (verify-report.md) が整備されているかを検査。
#
# Phase 4 (2026-04-23) で verification-before-completion skill の強制を物理化するために
# 導入。初期は warning レベル (exit 0 + stderr) で運用、false positive の影響を
# 確認してから将来的に exit 2 でブロック化を検討。
#
# 判定ロジック:
# 1. SKIP_VERIFY_HOOK=1 環境変数なら通過
# 2. worktree 外 (cwd に worktrees/ セグメントを含まない) なら通過
# 3. worktree 内で verify-report.md が存在しなければ warning
# 4. verify-report.md の frontmatter verdict が pass 以外なら warning
# 5. 全条件 OK なら通過
#
# bypass: SKIP_VERIFY_HOOK=1

set -euo pipefail

if [[ "${SKIP_VERIFY_HOOK:-0}" == "1" ]]; then
  exit 0
fi

# stdin を消費 (Claude Code から渡される JSON、現在は未使用)
cat > /dev/null

# worktree 内判定
cwd="$(pwd)"
case "$cwd" in
  */worktrees/*) ;;
  *) exit 0 ;;
esac

report="verify-report.md"

if [[ ! -f "$report" ]]; then
  {
    echo "[verification-before-completion hook] 注意: worktree 内で verify-report.md が未生成です"
    echo ""
    echo "完了宣言 / ship 準備前に verification-before-completion skill を起動し、"
    echo "4 カテゴリ検証 (テスト / Lint / 型 / 手動 AC) を実施して verify-report.md を生成してください。"
    echo ""
    echo "参照: skills/verification-before-completion/SKILL.md §3 (必須 4 カテゴリ) / §4 (出力仕様)"
    echo "worktree: $cwd"
  } >&2
  exit 0  # warning のみ (Phase 4 初期運用、ブロックしない)
fi

verdict="$(sed -n 's/^verdict: *//p' "$report" | head -n 1 | tr -d '[:space:]' || true)"

if [[ "$verdict" != "pass" ]]; then
  {
    echo "[verification-before-completion hook] 注意: verify-report.md の verdict が pass ではありません"
    echo "  現在の verdict: ${verdict:-(未設定)}"
    echo ""
    echo "完了宣言 / ship 前に verify を再実行してください。"
    echo ""
    echo "参照: skills/verification-before-completion/SKILL.md §6 失敗時の対応"
    echo "report: $cwd/$report"
  } >&2
  exit 0  # warning のみ
fi

# pass
exit 0
