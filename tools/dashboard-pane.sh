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
#   DASHBOARD_FAKE_COLS    pane 幅を強制する正整数 (test 用、default: unset)
#
# レイアウトモード (v2-responsive、pane 幅に応じた 3 モード):
#   wide (>= 60 カラム):   4 列 (stage / status / started_at / completed_at)
#   narrow (40-59 カラム): 2 列 (stage / status)
#   compact (< 40 カラム): 1 列 (stage=status)

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

# get_pane_cols: pane 幅 (カラム数) を 4 段フォールバックで取得する
# 1. DASHBOARD_FAKE_COLS (test 用、正整数のみ採用)
# 2. $COLUMNS (bash の対話 shell で設定される)
# 3. tput cols (pty から ioctl で取得、非対話でも動作することが多い)
# 4. 80 default (いずれも失敗時、wide 扱いに落とす)
# stdout に整数を 1 つ出力する。
get_pane_cols() {
  local fake="${DASHBOARD_FAKE_COLS:-}"
  if [[ "$fake" =~ ^[0-9]+$ ]] && [[ "$fake" -gt 0 ]]; then
    echo "$fake"
    return 0
  fi

  local cols="${COLUMNS:-}"
  if [[ "$cols" =~ ^[0-9]+$ ]] && [[ "$cols" -gt 0 ]]; then
    echo "$cols"
    return 0
  fi

  cols="$(tput cols 2>/dev/null || true)"
  if [[ "$cols" =~ ^[0-9]+$ ]] && [[ "$cols" -gt 0 ]]; then
    echo "$cols"
    return 0
  fi

  echo 80
}

# render_stages_wide: stages を 4 列テーブルで表示 (幅 60 以上)
# 引数: $1=progress_json (path)
render_stages_wide() {
  local progress_json="$1"
  printf "%-12s %-12s %-24s %-24s\n" "stage" "status" "started_at" "completed_at"
  jq -r '
    .stages
    | to_entries[]
    | [.key, (.value.status // "-"), (.value.started_at // "-"), (.value.completed_at // "-")]
    | @tsv
  ' "$progress_json" 2>/dev/null | while IFS=$'\t' read -r stage status started completed; do
    printf "%-12s %-12s %-24s %-24s\n" "$stage" "$status" "$started" "$completed"
  done
}

# render_stages_narrow: stages を 2 列テーブルで表示 (幅 40-59)
# 時刻カラムは省略。
# 引数: $1=progress_json (path)
render_stages_narrow() {
  local progress_json="$1"
  printf "%-12s %s\n" "stage" "status"
  jq -r '
    .stages
    | to_entries[]
    | [.key, (.value.status // "-")]
    | @tsv
  ' "$progress_json" 2>/dev/null | while IFS=$'\t' read -r stage status; do
    printf "%-12s %s\n" "$stage" "$status"
  done
}

# render_stages_compact: stages を 1 列 key=value で表示 (幅 40 未満)
# 時刻省略、折返しはターミナルに委ねる (Spec §3.5)。
# 引数: $1=progress_json (path)
render_stages_compact() {
  local progress_json="$1"
  jq -r '.stages | to_entries[] | "\(.key)=\(.value.status // "-")"' "$progress_json" 2>/dev/null
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

  # pane 幅に応じて 3 モードから stages レンダラを選択 (v2-responsive)
  local cols
  cols="$(get_pane_cols)"
  if [[ "$cols" -ge 60 ]]; then
    render_stages_wide "$progress_json"
  elif [[ "$cols" -ge 40 ]]; then
    render_stages_narrow "$progress_json"
  else
    render_stages_compact "$progress_json"
  fi

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
