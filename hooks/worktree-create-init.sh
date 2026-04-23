#!/usr/bin/env bash
# WorktreeCreate hook: Claude Code が worktree を作成した直後 (EnterWorktree or
# Agent isolation:worktree) に発火。spec-leader §8 Isolate の標準初期化処理
# (Spec/Plan/Review を worktree 内にコピー + progress.md 生成) を自動化する。
#
# Phase 5 バッチ 2 (2026-04-23) 実装。本 hook は Claude Code 管理の worktree に
# 限定発火するため、Phase 3 spec-leader の Bash git worktree add 経由では発火
# しない (その場合は spec-leader SKILL.md §8.1 手順を手動実行)。
#
# 入力 (stdin、想定): {"path": "...", "branch": "...", "name": "..."} 等の JSON
#   - 正確なスキーマは Claude Code のバージョンに依存、本 hook は複数候補を defensive に試行
#
# 判定ロジック:
# 1. SKIP_WORKTREE_CREATE_HOOK=1 なら通過
# 2. worktree path を stdin JSON から取得 (path / worktree_path / dir のいずれか)
# 3. path が未取得なら exit 0 (無害)
# 4. path から spec 名を推測 (basename、または命名規約 worktrees/<spec>/ から)
# 5. main 側の specs/<spec>.md / .plan.md / .review.md が存在するか確認
# 6. 存在すれば worktree 内にコピー (cp のみ、mv 禁止、iter-5 改修準拠)
# 7. progress.md を worktree 内に初期化
#
# bypass: SKIP_WORKTREE_CREATE_HOOK=1

set -euo pipefail

if [[ "${SKIP_WORKTREE_CREATE_HOOK:-0}" == "1" ]]; then
  exit 0
fi

input="$(cat)"

# worktree path の候補フィールドを順次試行
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

# spec 名を推測 (path の basename が spec 名 の前提、命名規約: worktrees/<spec>/ or .claude/worktrees/<spec>/)
spec_name="$(basename "$wt_path")"

# main 側 (プロジェクトルート) を探索
# 一般的には worktree の親の親、または git worktree list の main worktree
main_repo="$(cd "$wt_path" && git rev-parse --git-common-dir 2>/dev/null | xargs -I{} dirname {} 2>/dev/null || true)"

if [[ -z "$main_repo" || ! -d "$main_repo/specs" ]]; then
  # main 側 specs/ が無ければ spec-leader 管理外、通過
  exit 0
fi

# Spec / Plan / Review を worktree 内にコピー
spec_src="$main_repo/specs/${spec_name}.md"
plan_src="$main_repo/specs/${spec_name}.plan.md"
review_src="$main_repo/specs/${spec_name}.review.md"

copied=""
if [[ -f "$spec_src" ]]; then
  mkdir -p "$wt_path/specs"
  cp "$spec_src" "$wt_path/specs/${spec_name}.md"
  copied+="  - specs/${spec_name}.md"$'\n'
fi

if [[ -f "$plan_src" ]]; then
  mkdir -p "$wt_path/plans"
  cp "$plan_src" "$wt_path/plans/${spec_name}.md"
  copied+="  - plans/${spec_name}.md (main 側 ${spec_name}.plan.md をコピー)"$'\n'
fi

if [[ -f "$review_src" ]]; then
  mkdir -p "$wt_path/specs"
  cp "$review_src" "$wt_path/specs/${spec_name}.review.md"
  copied+="  - specs/${spec_name}.review.md"$'\n'
fi

# progress.md 初期化
now="$(date -u +%FT%TZ)"
cat > "$wt_path/progress.md" <<EOF
---
spec: ${spec_name}
started: ${now}
updated: ${now}
current_stage: isolate (auto-initialized by WorktreeCreate hook)
---

# Progress: ${spec_name}

## Stages

- [x] **Isolate** (${now}) — worktree 作成 + Spec/Plan/Review コピー済 (hook 自動化)
- [ ] **Implement**
- [ ] **Verify**
- [ ] **Code Review**
- [ ] **ship** (ユーザー承認後)

## ログ

${now} [isolate] WorktreeCreate hook により worktree 初期化完了
EOF

# Claude に通知 (stderr)
if [[ -n "$copied" ]]; then
  {
    echo "[WorktreeCreate hook] worktree '${spec_name}' の初期化を自動実行しました"
    echo "  worktree: ${wt_path}"
    echo "  コピー済ファイル:"
    echo -n "$copied"
    echo "  progress.md: ${wt_path}/progress.md 初期化"
    echo ""
    echo "次ステージ (Implement) に進む場合は spec-leader を再起動してください。"
  } >&2
fi

exit 0
