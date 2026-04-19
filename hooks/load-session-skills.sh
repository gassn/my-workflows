#!/usr/bin/env bash
# セッション開始時 (startup/resume/clear/compact) に常駐させたい skill の SKILL.md を
# additionalContext として出力する SessionStart hook。
#
# 追加したい skill は SKILLS 配列に skill 名 (~/.claude/skills/<name>/ の <name> 部分) を追記する。
set -euo pipefail

SKILLS=(
  "genshijin-without-docs"
)

context=""
for skill in "${SKILLS[@]}"; do
  f="$HOME/.claude/skills/$skill/SKILL.md"
  [ -f "$f" ] || continue
  context+="$(cat "$f")"$'\n\n---\n\n'
done

[ -n "$context" ] || exit 0

jq -n --arg ctx "$context" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
