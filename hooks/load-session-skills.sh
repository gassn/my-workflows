#!/usr/bin/env bash
# セッション開始時 (startup/resume/clear/compact) に SKILL.md の扱いを 2 段階で制御する
# SessionStart hook。
#
# FULL_LOAD_SKILLS: SKILL.md 全文を additionalContext として常駐させる (genshijin のような
#   会話モード系で常時有効にしたいもの)。
# INDEX_SKILLS: 1 行要約のインデックスのみを additionalContext として追加し、詳細は
#   Claude が必要時に Read で読み込む (using-superpowers 方式、context 膨張抑制)。
#
# 2026-04-23 Phase 4 バッチ 2 改訂: Phase 3 ワークフロー skill は全文ロードから
# インデックス方式に切り替え (ユーザー指摘による改善、context サイズ削減)。
set -euo pipefail

# SKILL.md 全文を常駐させる skill (会話モード等で常時有効)
FULL_LOAD_SKILLS=(
  "genshijin-without-docs"
)

# 1 行要約でインデックス化する skill (必要時 Read で詳細取得)
# フォーマット: "skill-name|1 行要約 (起動トリガー / 役割)"
INDEX_SKILLS=(
  "brainstorming|Spec 前の要件深掘り起点。『要件まとめたい』『機能追加したい』『Spec 書きたい』『やりたいことがある』で起動"
  "spec-dag-builder|Spec 間の依存関係解析 + DAG 構築 (単一 Spec も 1 ノード DAG 生成)。『DAG 作って』『依存関係整理』で起動、brainstorming / spec-review 後に自動"
  "writing-spec|Brainstorming ノート → 7 章 Spec (目的/スコープ/機能要件/非機能要件/受け入れ基準/非対象/リスク)。『Spec 書いて』で起動、brainstorming 完了後に自動"
  "spec-review|Spec の 3 観点自動レビュー (完全性 / 実現可能性 / 整合性)、verdict (pass/needs-fix/reject) 生成。writing-spec 完了後に自動起動"
  "writing-plan|Spec → 技術設計 + タスク分解 (files_touched 必須)。main 側で specs/<spec>.plan.md 生成。spec-review verdict: pass 後に自動起動"
  "spec-leader|Isolate → Implement → Verify → Code Review → ship の 5 ステージ遷移制御 (progress.json + result.json 管理)。writing-plan 完了後に自動起動"
  "tdd-driver|Implement ステージで TDD サイクル (Red → Green → Refactor) を強制。developer agent と連携"
  "verification-before-completion|Verify ステージで test / lint / type / 手動 AC の 4 カテゴリ検証を強制、verify-report.md 生成。Phase 4 Stop hook と連動"
  "receiving-code-review|3 reviewer (code/security/cross-model) 結果の集約、consolidated.md 生成、Plan への T-fix 追加。verdict 不一致時に自動起動"
  "cross-model-review|Codex / GPT / Gemini 等の外部モデル経由独立レビュー。バイアス防止の順序厳守、Phase 3 は手動依頼 placeholder"
  "learn|ship 後の振り返り (progress / result 分析 → Keep / Problem / Try パッチ案)。spec-leader ship 完了後に自動起動"
)

context=""

# FULL_LOAD_SKILLS: 全文注入
for skill in "${FULL_LOAD_SKILLS[@]}"; do
  f="$HOME/.claude/skills/$skill/SKILL.md"
  [ -f "$f" ] || continue
  context+="$(cat "$f")"$'\n\n---\n\n'
done

# INDEX_SKILLS: 1 行要約のインデックスのみ
index=""
for entry in "${INDEX_SKILLS[@]}"; do
  name="${entry%%|*}"
  summary="${entry#*|}"
  f="$HOME/.claude/skills/$name/SKILL.md"
  [ -f "$f" ] || continue
  index+="- **\`${name}\`** (\`skills/${name}/SKILL.md\`): ${summary}"$'\n'
done

if [ -n "$index" ]; then
  context+=$'## ワークフロー skill 一覧 (必要時 `Read` で詳細取得)\n\n'
  context+=$'以下は本プロジェクトの Phase 3 ワークフロー skill です。SKILL.md 全文は常駐させず、\n'
  context+=$'必要なステージに入った時点で `Read skills/<skill-name>/SKILL.md` で読み込んでください。\n\n'
  context+="$index"
  context+=$'\n### 自動起動チェーン\n\n'
  context+=$'Brainstorming → spec-dag-builder (単一/複数不問で常時起動) → writing-spec → spec-review → writing-plan (main 側) → spec-leader → [Implement: tdd-driver + developer agent] → [Verify: verification-before-completion + verifier agent] → [Code Review: code-reviewer + security-reviewer + cross-model-review] → receiving-code-review (差戻し時) → ship → learn\n'
  context+=$'\n全体像 (Mermaid 図 + 使用ツール / コマンド) は `docs/components-map.md` 参照。\n'
  context+=$'ワークフロー定義は `docs/workflow.md`、各 skill の詳細手順は該当 `SKILL.md` を Read で取得。\n\n'
fi

[ -n "$context" ] || exit 0

jq -n --arg ctx "$context" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
