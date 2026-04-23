#!/usr/bin/env bash
# セッション開始時 (startup/resume/clear/compact) に常駐させたい skill の SKILL.md を
# additionalContext として出力する SessionStart hook。
#
# 追加したい skill は SKILLS 配列に skill 名 (~/.claude/skills/<name>/ の <name> 部分) を追記する。
#
# 2026-04-23 (Phase 4 バッチ 2): ワークフロー起点 skill として brainstorming を追加。
# 他の Phase 3 skill (writing-spec / spec-review / spec-leader / writing-plan /
# tdd-driver / verification-before-completion / receiving-code-review /
# cross-model-review / learn / spec-dag-builder) は自動起動チェーンで連鎖読込
# されるため、常駐させず必要時にのみ読込む戦略。これにより context 膨張を抑制
# しつつ、起点 skill は即時利用可能にする。
set -euo pipefail

SKILLS=(
  "genshijin-without-docs"
  "brainstorming"
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
