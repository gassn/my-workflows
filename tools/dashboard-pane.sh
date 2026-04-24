#!/usr/bin/env bash
# tmux-dashboard-mvp: 各 tmux pane の表示ロジック
#
# 1 秒間隔で progress.json / result.json / progress.md を読み取り、
# ターミナルに整形表示する。spec-leader が書き込む進捗ファイルを
# 読み取り専用で利用する。
#
# 使い方: bash tools/dashboard-pane.sh <spec-name>
# 環境変数:
#   DASHBOARD_SPEC_DIR     progress/result ファイルを探すディレクトリ (default: repo/specs)
#   DASHBOARD_PANE_ONESHOT 1 のとき 1 回描画して即 exit (test 用、default: unset)
#   DASHBOARD_POLL_SEC     poll 間隔秒 (default: 1)

set -u

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly SPEC_NAME_PATTERN='^[A-Za-z0-9][A-Za-z0-9._-]*$'
SPEC_DIR="${DASHBOARD_SPEC_DIR:-${REPO_ROOT}/specs}"
WORKTREES_DIR="${DASHBOARD_WORKTREES_DIR:-${REPO_ROOT}/worktrees}"
POLL_SEC="${DASHBOARD_POLL_SEC:-1}"

# validate_spec_name: Spec 名が allowlist に合致するか検証する (shell injection / path traversal 防止)
# 引数: $1=spec-name
# exit code: 0=OK, 1=invalid
validate_spec_name() {
  local name="$1"
  if [[ ! "$name" =~ $SPEC_NAME_PATTERN ]]; then
    echo "invalid spec name: '$name' (allowed: $SPEC_NAME_PATTERN)" >&2
    return 1
  fi
  return 0
}

# print_usage: 使い方を stderr に書く
print_usage() {
  cat >&2 <<'USAGE'
Usage: dashboard-pane.sh <spec-name>

1 秒間隔で progress.json / result.json / progress.md を表示する。

環境変数:
  DASHBOARD_SPEC_DIR       progress/result の置き場所
  DASHBOARD_PANE_ONESHOT=1 1 回描画して exit (test 用)
  DASHBOARD_POLL_SEC=N     poll 間隔 (秒、default 1)
USAGE
}

# ensure_jq: jq コマンドの存在を確認する。なければ警告して exit 1
ensure_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "jq が必要です (apt install jq / brew install jq)" >&2
    exit 1
  fi
}

# render_spec: 指定 Spec の現在状態を整形して stdout に書く
# 引数: $1=spec-name (呼び出し元で validate_spec_name 済みの前提)
render_spec() {
  local spec="$1"
  local progress_json="${SPEC_DIR}/${spec}.progress.json"
  local result_json="${SPEC_DIR}/${spec}.result.json"
  local progress_md="${WORKTREES_DIR}/${spec}/progress.md"

  printf "=== %s  (%s) ===\n" "$spec" "$(date '+%Y-%m-%d %H:%M:%S')"

  if [[ ! -f "$progress_json" ]]; then
    echo "progress 未生成、spec-leader が起動されていない可能性 (expected: $progress_json)"
    return 0
  fi

  local meta
  if ! meta=$(jq -r '"spec: \(.spec)\ncurrent_stage: \(.current_stage)\nupdated_at: \(.updated_at)"' "$progress_json" 2>/dev/null); then
    echo "更新中..."
    return 0
  fi
  printf "%s\n\n" "$meta"

  printf "%-12s %-12s %-24s %-24s\n" "stage" "status" "started_at" "completed_at"
  jq -r '
    .stages
    | to_entries[]
    | [.key, (.value.status // "-"), (.value.started_at // "-"), (.value.completed_at // "-")]
    | @tsv
  ' "$progress_json" 2>/dev/null | while IFS=$'\t' read -r stage status started completed; do
    printf "%-12s %-12s %-24s %-24s\n" "$stage" "$status" "$started" "$completed"
  done

  if [[ -f "$result_json" ]]; then
    printf "\n-- result --\n"
    jq -r '"verdict: \(.verdict)\nstages_completed: \(.stages_completed | join(", "))"' "$result_json" 2>/dev/null \
      || echo "result.json パース失敗、更新中..."
  fi

  if [[ -f "$progress_md" ]]; then
    printf "\n-- ログ末尾 10 行 (%s) --\n" "progress.md"
    # Spec §3.2 「progress.md の `## ログ` セクションの末尾 10 行」に従い、
    # awk で `## ログ` 見出しと次の `## ` 見出しの間を抽出してから tail
    awk '/^## ログ/{flag=1; next} /^## /{flag=0} flag' "$progress_md" | tail -n 10
  fi
}

# main: 引数検証 + poll ループ
main() {
  if [[ $# -lt 1 ]]; then
    print_usage
    exit 1
  fi

  case "$1" in
    -h|--help) print_usage; exit 0 ;;
  esac

  ensure_jq

  local spec="$1"
  validate_spec_name "$spec" || exit 1

  if [[ "${DASHBOARD_PANE_ONESHOT:-0}" == "1" ]]; then
    render_spec "$spec"
    exit 0
  fi

  while true; do
    clear 2>/dev/null || printf "\n\n"
    render_spec "$spec"
    sleep "$POLL_SEC"
  done
}

main "$@"
