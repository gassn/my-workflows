#!/usr/bin/env bash
# tmux-dashboard-mvp: エントリポイント
#
# spec-leader が管理する複数 Spec の進捗を tmux pane で同時表示する。
# 引数なしなら specs/*.progress.json から in-progress 状態の Spec を抽出、
# 引数ありなら指定 Spec のみを対象にする。
#
# 使い方:
#   bash tools/dashboard.sh                # 自動探索
#   bash tools/dashboard.sh auth order     # 明示指定
#   bash tools/dashboard.sh --help         # ヘルプ
#
# 環境変数:
#   DASHBOARD_SPEC_DIR         progress/result の置き場所 (default: repo/specs)
#   DASHBOARD_DRY_RUN=1        tmux を起動せず対象一覧だけ表示
#   DASHBOARD_FAKE_NO_TMUX=1   tmux 未インストールを擬似再現 (test 用)
#   DASHBOARD_SESSION          tmux session 名 (default: my-workflows-dashboard)

set -u

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly PANE_SCRIPT="${SCRIPT_DIR}/dashboard-pane.sh"
SPEC_DIR="${DASHBOARD_SPEC_DIR:-${REPO_ROOT}/specs}"
SESSION="${DASHBOARD_SESSION:-my-workflows-dashboard}"

# print_usage: 使い方を stdout に書く
print_usage() {
  cat <<'USAGE'
Usage: dashboard.sh [--help] [spec-name...]

複数 Spec の進捗を tmux の複数 pane に同時表示する。

引数:
  spec-name...  表示対象の Spec 名。省略時は specs/*.progress.json を走査し
                result.json 未生成または verdict が in-progress 相当のものを対象にする。

オプション:
  --help / -h   このヘルプを表示して exit 0

環境変数:
  DASHBOARD_SPEC_DIR         progress / result の置き場所
  DASHBOARD_DRY_RUN=1        tmux を起動せず対象一覧だけ表示
  DASHBOARD_FAKE_NO_TMUX=1   tmux 未インストールを擬似再現 (test 用)
  DASHBOARD_SESSION          tmux session 名 (default: my-workflows-dashboard)
USAGE
}

# log_err: stderr にエラーメッセージを書く
log_err() {
  echo "$*" >&2
}

# ensure_tmux: tmux が利用可能か検証し、不在なら exit 1
ensure_tmux() {
  if [[ "${DASHBOARD_FAKE_NO_TMUX:-0}" == "1" ]]; then
    log_err "tmux がインストールされていません。tmux 2.6+ / 3+ をインストールしてください。"
    exit 1
  fi
  if ! command -v tmux >/dev/null 2>&1; then
    log_err "tmux がインストールされていません。tmux 2.6+ / 3+ をインストールしてください。"
    exit 1
  fi
  local version
  version="$(tmux -V 2>/dev/null | awk '{print $2}')"
  local major
  major="${version%%.*}"
  if [[ -z "$major" || "$major" =~ ^[0-9]+$ && "$major" -lt 2 ]]; then
    log_err "tmux バージョン ${version} は未対応です。tmux 2.6+ / 3+ をインストールしてください。"
    exit 1
  fi
}

# collect_specs_auto: DASHBOARD_SPEC_DIR から in-progress 相当の Spec 一覧を stdout に書く
collect_specs_auto() {
  local progress
  shopt -s nullglob
  local progress_files=("${SPEC_DIR}"/*.progress.json)
  shopt -u nullglob

  for progress in "${progress_files[@]}"; do
    local spec result
    spec="$(basename "$progress" .progress.json)"
    result="${SPEC_DIR}/${spec}.result.json"
    if [[ ! -f "$result" ]]; then
      echo "$spec"
      continue
    fi
    local verdict="unknown"
    if command -v jq >/dev/null 2>&1; then
      verdict="$(jq -r '.verdict // "unknown"' "$result" 2>/dev/null)"
    fi
    case "$verdict" in
      shipped|shipped-manual|shipped-cross-model-pending|aborted|aborted-on-resume) ;;
      *) echo "$spec" ;;
    esac
  done
}

# validate_explicit_specs: 指定 Spec の progress.json 有無を確認、存在しないものは warning して stdout から除外
# 引数: $@=spec-name 配列
validate_explicit_specs() {
  local spec
  for spec in "$@"; do
    if [[ -f "${SPEC_DIR}/${spec}.progress.json" ]]; then
      echo "$spec"
    else
      log_err "warning: ${spec}.progress.json が見つかりません (スキップ)"
    fi
  done
}

# launch_tmux: tmux session を作成し、Spec 数分の pane を tiled layout で配置する
# 引数: $@=spec-name 配列
launch_tmux() {
  local specs=("$@")
  local first="${specs[0]}"
  local rest=("${specs[@]:1}")

  if tmux has-session -t "$SESSION" 2>/dev/null; then
    log_err "既存セッション '$SESSION' に attach します"
    exec tmux attach-session -t "$SESSION"
  fi

  tmux new-session -d -s "$SESSION" -n dashboard "bash '$PANE_SCRIPT' '$first'"

  local spec
  for spec in "${rest[@]}"; do
    tmux split-window -t "$SESSION:dashboard" "bash '$PANE_SCRIPT' '$spec'"
    tmux select-layout -t "$SESSION:dashboard" tiled >/dev/null
  done

  tmux select-layout -t "$SESSION:dashboard" tiled >/dev/null

  if [[ ${#specs[@]} -gt 9 ]]; then
    log_err "warning: ${#specs[@]} Spec を同時表示します。pane が細かくなりすぎる可能性、絞り込みを推奨"
  fi

  exec tmux attach-session -t "$SESSION"
}

# main: 引数をパースし、自動探索または明示指定で対象 Spec を決定して launch する
main() {
  local -a args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) print_usage; exit 0 ;;
      --*) log_err "unknown flag: $1"; print_usage >&2; exit 1 ;;
      *) args+=("$1"); shift ;;
    esac
  done

  if [[ "${DASHBOARD_DRY_RUN:-0}" != "1" ]]; then
    ensure_tmux
  fi

  local -a targets=()
  if [[ ${#args[@]} -eq 0 ]]; then
    mapfile -t targets < <(collect_specs_auto)
  else
    mapfile -t targets < <(validate_explicit_specs "${args[@]}")
  fi

  if [[ ${#targets[@]} -eq 0 ]]; then
    echo "対象 Spec がありません。specs/*.progress.json を確認してください。"
    exit 0
  fi

  if [[ "${DASHBOARD_DRY_RUN:-0}" == "1" ]]; then
    echo "対象 Spec (${#targets[@]} 件):"
    local s
    for s in "${targets[@]}"; do
      echo "  - $s"
    done
    exit 0
  fi

  launch_tmux "${targets[@]}"
}

main "$@"
