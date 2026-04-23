#!/usr/bin/env bash
# TaskCompleted hook: Claude Code の Task 系 (TaskUpdate で status=completed) で
# タスク完了イベントが発火した時に、spec-leader の progress.md にタスク完了ログを
# 追記する。spec-leader の progress.json とは別系統の「Claude Code Task 系」と
# 「spec-leader 独自 progress」の連携を取り、orchestrator / learn が参照できる
# ログを残すのが目的。
#
# Phase 5 バッチ 2 (2026-04-23) 実装。
#
# 判定ロジック:
# 1. SKIP_TASK_COMPLETED_HOOK=1 なら通過
# 2. stdin から Task 情報を取得 (subject, description, status)
# 3. worktree 外なら通過 (spec-leader 管理対象外)
# 4. status が completed でなければ通過
# 5. worktree 内の progress.md にタスク完了行を追加
#
# bypass: SKIP_TASK_COMPLETED_HOOK=1

set -euo pipefail

if [[ "${SKIP_TASK_COMPLETED_HOOK:-0}" == "1" ]]; then
  exit 0
fi

input="$(cat)"

# Task 情報取得 (複数フィールド候補を試行)
status=""
subject=""
description=""
for status_field in ".status" ".task.status" ".new_status"; do
  candidate="$(printf '%s' "$input" | jq -r "${status_field} // empty")"
  if [[ -n "$candidate" ]]; then
    status="$candidate"
    break
  fi
done

for field in ".subject" ".task.subject" ".title" ".task.title"; do
  candidate="$(printf '%s' "$input" | jq -r "${field} // empty")"
  if [[ -n "$candidate" ]]; then
    subject="$candidate"
    break
  fi
done

for field in ".description" ".task.description" ".detail"; do
  candidate="$(printf '%s' "$input" | jq -r "${field} // empty")"
  if [[ -n "$candidate" ]]; then
    description="$candidate"
    break
  fi
done

# status が completed でなければ通過 (TaskUpdate には in_progress / deleted 等も含まれる)
if [[ "$status" != "completed" ]]; then
  exit 0
fi

# worktree 内判定
cwd="$(pwd)"
case "$cwd" in
  */worktrees/*|*/.claude/worktrees/*) ;;
  *) exit 0 ;;
esac

# progress.md が存在しなければ通過
progress_md="${cwd}/progress.md"
if [[ ! -f "$progress_md" ]]; then
  exit 0
fi

now="$(date -u +%FT%TZ)"
log_entry="${now} [task-completed] ${subject:-(no subject)}"
if [[ -n "$description" ]]; then
  log_entry+=" — ${description}"
fi

# progress.md の ## ログ セクションに追記
if grep -q "^## ログ$" "$progress_md"; then
  # 末尾に追記
  echo "$log_entry" >> "$progress_md"
else
  # ## ログ セクションが無ければ新規追加
  {
    echo ""
    echo "## ログ"
    echo ""
    echo "$log_entry"
  } >> "$progress_md"
fi

# updated タイムスタンプを frontmatter で更新
if grep -q "^updated: " "$progress_md"; then
  sed -i "s|^updated: .*|updated: ${now}|" "$progress_md"
fi

# Claude 通知は抑制 (Task 完了ごとに発火するため、出力過多防止)
exit 0
