#!/usr/bin/env bash
# InstructionsLoaded hook: CLAUDE.md / .claude/rules/*.md / specs/*.md のロード時に
# 関連コンテキスト (Phase 進捗サマリ / Spec 関連ファイル参照) を additionalContext
# として追加する。
#
# Claude Code 標準イベント InstructionsLoaded (load_reason: session_start /
# nested_traversal / path_glob_match 等) に応答する。hook はブロック機能を持たず、
# 観察 + コンテキスト追加のみ。
#
# 2026-04-23 Phase 4 バッチ 3 で導入。
#
# bypass: SKIP_INSTRUCTIONS_LOADED_HOOK=1

set -euo pipefail

if [[ "${SKIP_INSTRUCTIONS_LOADED_HOOK:-0}" == "1" ]]; then
  exit 0
fi

input="$(cat)"

file_path="$(printf '%s' "$input" | jq -r '.file_path // empty')"
load_reason="$(printf '%s' "$input" | jq -r '.load_reason // empty')"

if [[ -z "$file_path" ]]; then
  exit 0
fi

ctx=""

case "$file_path" in
  */CLAUDE.md)
    # プロジェクト現状サマリを追加 (Phase 3/4 の進捗)
    ctx="## プロジェクト現状 (InstructionsLoaded hook)

- **Phase 3**: ✅ 完了 (11 skill + 5 agent、iter-3/4/5 統合完走 shipped)
- **Phase 4**: 🚧 実装中 (SessionStart / PreToolUse / PostToolUse / Stop / InstructionsLoaded の 5 hook 実装済、残 3 は Phase 5 連携 + hookify)
- **Phase 5**: 未着手 (orchestrator + investigator + Agent isolation 活用)

詳細: \`docs/phase3-completion.md\` §10 総括、\`docs/components-map.md\` §1-§9、\`ROADMAP.md\`

load_reason: ${load_reason:-unknown}
"
    ;;
  */specs/*.md)
    # Spec ファイルロード時 → 関連ファイル参照を追加 (archive / plan / review / progress / result / learn)
    dir="$(dirname "$file_path")"
    base="$(basename "$file_path")"
    # <spec>.md / <spec>.plan.md / <spec>.review.md など、suffix 付きファイルは対象外 (spec 本体のみ対象)
    case "$base" in
      *.plan.md|*.review.md|*.progress.md|*.learn.md|*.consolidated.md) exit 0 ;;
      dag.md) exit 0 ;;
    esac
    # .brainstorm.md もスキップ (brainstorming ステージ中)
    case "$base" in
      *.brainstorm.md) exit 0 ;;
    esac
    spec_name="${base%.md}"
    related=""
    # main 側
    for suffix in ".review.md" ".plan.md" ".plan.meta.json" ".progress.json" ".result.json"; do
      [ -f "$dir/${spec_name}${suffix}" ] && related+="- \`$dir/${spec_name}${suffix}\`"$'\n'
    done
    # archive 側
    archive_dir="${dir}/archive"
    if [ -d "$archive_dir" ]; then
      for suffix in ".md" ".plan.md" ".review.md" ".learn.md" ".consolidated.md" ".brainstorm.md"; do
        [ -f "$archive_dir/${spec_name}${suffix}" ] && related+="- \`$archive_dir/${spec_name}${suffix}\` (archive)"$'\n'
      done
    fi
    # worktree 側
    worktree_candidate="$(dirname "$dir")/worktrees/${spec_name}"
    if [ -d "$worktree_candidate" ]; then
      related+="- \`$worktree_candidate/\` (worktree)"$'\n'
    fi
    # dag.md (complex Spec 時)
    [ -f "$dir/dag.md" ] && related+="- \`$dir/dag.md\` (全 Spec の DAG)"$'\n'

    if [ -n "$related" ]; then
      ctx="## Spec \`${spec_name}\` 関連ファイル (InstructionsLoaded hook)

${related}
必要時に \`Read\` で取得してください。
"
    fi
    ;;
esac

if [[ -z "$ctx" ]]; then
  exit 0
fi

jq -n --arg ctx "$ctx" '{
  hookSpecificOutput: {
    hookEventName: "InstructionsLoaded",
    additionalContext: $ctx
  }
}'
