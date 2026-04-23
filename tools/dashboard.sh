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
readonly SPEC_NAME_PATTERN='^[A-Za-z0-9._-]+$'
SPEC_DIR="${DASHBOARD_SPEC_DIR:-${REPO_ROOT}/specs}"
SESSION="${DASHBOARD_SESSION:-my-workflows-dashboard}"

# validate_spec_name: Spec 名が allowlist に合致するか検証する (shell injection / path traversal 防止)
# 引数: $1=spec-name
# exit code: 0=OK, 1=invalid
validate_spec_name() {
  local name="$1"
  if [[ ! "$name" =~ $SPEC_NAME_PATTERN ]]; then
    log_err "invalid spec name: '$name' (allowed: $SPEC_NAME_PATTERN)"
    return 1
  fi
  return 0
}

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

# ensure_jq: jq コマンドの存在を確認する。不在なら exit 1
ensure_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    log_err "jq が必要です (apt install jq / brew install jq)"
    exit 1
  fi
}

# ensure_tmux: tmux が利用可能か検証し、不在なら exit 1
# DASHBOARD_FAKE_NO_TMUX=1 が指定されている場合は tmux 本体があっても不在扱いで exit 1 (テスト用)。
ensure_tmux() {
  local missing_msg="tmux がインストールされていません。tmux 2.6+ / 3+ をインストールしてください。"
  if [[ "${DASHBOARD_FAKE_NO_TMUX:-0}" == "1" ]] || ! command -v tmux >/dev/null 2>&1; then
    log_err "$missing_msg"
    exit 1
  fi
  local version major
  version="$(tmux -V 2>/dev/null | awk '{print $2}')"
  major="${version%%.*}"
  # 非数値 / 空 / 2 未満を直列 OR で明示的に弾く (&& の優先度バグ回避)
  if [[ -z "$major" || ! "$major" =~ ^[0-9]+$ || "$major" -lt 2 ]]; then
    log_err "tmux バージョン '${version}' は未対応です。tmux 2.6+ / 3+ をインストールしてください。"
    exit 1
  fi
}

# collect_specs_auto: DASHBOARD_SPEC_DIR から in-progress 相当の Spec 一覧を stdout に書く
# allowlist を通過しないファイル名 (悪意ある commit 等) はスキップして warning を出す
collect_specs_auto() {
  local progress
  shopt -s nullglob
  local progress_files=("${SPEC_DIR}"/*.progress.json)
  shopt -u nullglob

  for progress in "${progress_files[@]}"; do
    local spec result
    spec="$(basename "$progress" .progress.json)"
    if ! validate_spec_name "$spec"; then
      continue
    fi
    result="${SPEC_DIR}/${spec}.result.json"
    if [[ ! -f "$result" ]]; then
      echo "$spec"
      continue
    fi
    local verdict
    verdict="$(jq -r '.verdict // "unknown"' "$result" 2>/dev/null)"
    case "$verdict" in
      shipped|shipped-manual|shipped-cross-model-pending|aborted|aborted-on-resume) ;;
      *) echo "$spec" ;;
    esac
  done
}

# validate_explicit_specs: 指定 Spec の progress.json 有無を確認、存在しないものは warning して stdout から除外
# allowlist を通過しない Spec 名は warning + スキップ
# 引数: $@=spec-name 配列
validate_explicit_specs() {
  local spec
  for spec in "$@"; do
    if ! validate_spec_name "$spec"; then
      continue
    fi
    if [[ -f "${SPEC_DIR}/${spec}.progress.json" ]]; then
      echo "$spec"
    else
      log_err "warning: ${spec}.progress.json が見つかりません (スキップ)"
    fi
  done
}

# launch_tmux: tmux session を作成し、Spec 数分の pane を tiled layout で配置する
# 各 Spec 名は printf %q でエスケープ済の形式で tmux コマンド文字列に埋め込み、
# tmux の sh -c 解釈経路でのシェルインジェクションを防ぐ。
# 引数: $@=spec-name 配列 (呼び出し元で allowlist を通過した前提)
launch_tmux() {
  local specs=("$@")
  local first="${specs[0]}"
  local rest=("${specs[@]:1}")

  # 9 Spec 超は pane 過密の警告を事前に出してからセッション構築する
  if [[ ${#specs[@]} -gt 9 ]]; then
    log_err "warning: ${#specs[@]} Spec を同時表示します。pane が細かくなりすぎる可能性、絞り込みを推奨"
  fi

  if tmux has-session -t "$SESSION" 2>/dev/null; then
    log_err "既存セッション '$SESSION' に attach します"
    exec tmux attach-session -t "$SESSION"
  fi

  local pane_script_q first_q
  pane_script_q=$(printf '%q' "$PANE_SCRIPT")
  first_q=$(printf '%q' "$first")
  tmux new-session -d -s "$SESSION" -n dashboard "bash $pane_script_q $first_q"

  local spec spec_q
  for spec in "${rest[@]}"; do
    spec_q=$(printf '%q' "$spec")
    tmux split-window -t "$SESSION:dashboard" "bash $pane_script_q $spec_q"
  done

  tmux select-layout -t "$SESSION:dashboard" tiled >/dev/null

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

  ensure_jq
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
