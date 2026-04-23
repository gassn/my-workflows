#!/usr/bin/env bash
# WorktreeRemove hook: Claude Code が worktree を削除しようとした時 (ExitWorktree
# action: "remove" or Agent isolation cleanup) に発火。削除前の安全チェック +
# progress.md の main 側バックアップを実施する。
#
# Phase 5 バッチ 2 (2026-04-23) 実装。
#
# 判定ロジック:
# 1. SKIP_WORKTREE_REMOVE_HOOK=1 なら通過
# 2. worktree path を stdin JSON から取得
# 3. 未コミットの変更があれば stderr に警告 (exit 0、実際のブロックは ExitWorktree
#    側の discard_changes: false で処理される)
# 4. progress.md が存在すれば main 側の specs/archive/<spec>.progress.md.final に
#    コピー (learn skill が ship 後に読めるように)
# 5. main 側の specs/archive/<spec>.md が存在しない場合、archive 移動未完了と判定
#    して警告 (skill 手順から逸脱している可能性)
#
# bypass: SKIP_WORKTREE_REMOVE_HOOK=1

set -euo pipefail

if [[ "${SKIP_WORKTREE_REMOVE_HOOK:-0}" == "1" ]]; then
  exit 0
fi

input="$(cat)"

wt_path=""
for field in ".path" ".worktree_path" ".dir" ".worktree"; do
  candidate="$(printf '%s' "$input" | jq -r "${field} // empty")"
  if [[ -n "$candidate" ]]; then
    wt_path="$candidate"
    break
  fi
done

if [[ -z "$wt_path" || ! -d "$wt_path" ]]; then
  exit 0
fi

spec_name="$(basename "$wt_path")"
main_repo="$(cd "$wt_path" && git rev-parse --git-common-dir 2>/dev/null | xargs -I{} dirname {} 2>/dev/null || true)"

warnings=""

# 未コミット変更確認
if [[ -d "$wt_path/.git" || -f "$wt_path/.git" ]]; then
  uncommitted="$(cd "$wt_path" && git status --porcelain 2>/dev/null | wc -l)"
  if [[ "$uncommitted" -gt 0 ]]; then
    warnings+="  - 未コミットの変更が ${uncommitted} 件あります (git status --porcelain で確認)"$'\n'
  fi
fi

# archive 移動完了確認 (main 側)
if [[ -n "$main_repo" && -d "$main_repo/specs/archive" ]]; then
  if [[ ! -f "$main_repo/specs/archive/${spec_name}.md" ]]; then
    warnings+="  - main 側の specs/archive/${spec_name}.md が存在しません (ship ステージの archive 移動が未完の可能性)"$'\n'
  fi
fi

# progress.md を main 側にバックアップ (learn skill 用)
if [[ -f "$wt_path/progress.md" && -n "$main_repo" ]]; then
  mkdir -p "$main_repo/specs/archive"
  backup="$main_repo/specs/archive/${spec_name}.progress.md"
  if [[ ! -f "$backup" ]]; then
    cp "$wt_path/progress.md" "$backup"
    {
      echo "[WorktreeRemove hook] progress.md を archive に backup しました"
      echo "  source: ${wt_path}/progress.md"
      echo "  backup: ${backup}"
      echo ""
      echo "  learn skill が ship 後の振り返りで利用可能になります。"
    } >&2
  fi
fi

# 警告があれば stderr に表示 (Claude Code に通知、ExitWorktree 側で判断)
if [[ -n "$warnings" ]]; then
  {
    echo "[WorktreeRemove hook] worktree '${spec_name}' 削除前の確認で以下の注意点が検出されました:"
    echo ""
    echo -n "$warnings"
    echo ""
    echo "  削除を強行する場合は ExitWorktree の discard_changes: true (または git worktree remove --force) を使用、"
    echo "  worktree を保持する場合は action: \"keep\" を選択してください。"
  } >&2
fi

exit 0
