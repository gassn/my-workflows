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

# ANSI カラー定数 (default fallback、load_theme で上書き可能)
# dashboard-color-themes Spec により、tools/dashboard-themes/<name>.env で変更可能
COLOR_COMPLETED=$'\e[32m'
COLOR_IN_PROGRESS=$'\e[33m'
COLOR_PENDING=''
COLOR_FAILED=$'\e[31m'
COLOR_BLOCKED=$'\e[35m'
COLOR_SHIPPED=$'\e[36m'
COLOR_ABORTED=$'\e[31m'
COLOR_RESET=$'\e[0m'

# load_theme: tools/dashboard-themes/<name>.env をロードして COLOR_* を上書き
# source / eval / コマンド置換を一切使わない 4 段検証 (dashboard-color-themes Spec §7.1):
#   1. theme 名 allowlist (^[A-Za-z0-9][A-Za-z0-9._-]*$、path traversal 防止)
#   2. 行単位 allowlist (^COLOR_[A-Z_]+=...$)
#   3. quote 剥離 + 値 regex ^(\e\[[0-9;]+m)*$
#   4. 1 件でも違反で全体 default フォールバック (行単位部分読み込み禁止)
load_theme() {
  local theme_name="$1"
  local theme_file

  if [[ ! "$theme_name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "load_theme: invalid theme name '$theme_name', fallback to default" >&2
    [[ "$theme_name" != "default" ]] && load_theme "default"
    return
  fi
  theme_file="${SCRIPT_DIR}/dashboard-themes/${theme_name}.env"
  if [[ ! -f "$theme_file" ]]; then
    echo "load_theme: theme file not found '$theme_file', fallback to default" >&2
    [[ "$theme_name" != "default" ]] && load_theme "default"
    return
  fi

  local had_invalid=0
  declare -A _pending
  local line var val
  while IFS= read -r line; do
    # 空行 / コメント行はスキップ (invalid 扱いしない)
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ ! "$line" =~ ^(COLOR_[A-Z_]+)=(.*)$ ]]; then
      had_invalid=1
      continue
    fi
    var="${BASH_REMATCH[1]}"
    val="${BASH_REMATCH[2]}"
    # quote 剥離 (シングル / ダブル両対応)
    if [[ "$val" =~ ^\'(.*)\'$ ]] || [[ "$val" =~ ^\"(.*)\"$ ]]; then
      val="${BASH_REMATCH[1]}"
    fi
    # 値 regex: \e[数;数m の連なり、または空
    if [[ "$val" =~ ^(\\e\[[0-9\;]+m)*$ ]]; then
      _pending["$var"]="$val"
    else
      had_invalid=1
    fi
  done < "$theme_file"

  if [[ "$had_invalid" -eq 1 ]]; then
    echo "load_theme: invalid entry in ${theme_name}.env, fallback to default" >&2
    if [[ "$theme_name" != "default" ]]; then
      load_theme "default"
    fi
    return
  fi

  # 検証済のみ直接代入 (source / eval / コマンド置換なし)
  # env ファイル上の '\e[32m' (literal) を実際の ESC 文字に変換
  local key raw converted
  for key in "${!_pending[@]}"; do
    raw="${_pending[$key]}"
    converted="$(printf '%b' "$raw")"
    printf -v "$key" '%s' "$converted"
    export "$key"
  done
}

# skill 起動時にテーマを 1 回ロード (DASHBOARD_THEME 未指定時は default)
# 警告は stderr に出す (test / ユーザーが検知できるよう抑制しない)
load_theme "${DASHBOARD_THEME:-default}"

# _is_color_enabled: カラー出力の有効性を判定
# 優先度: DASHBOARD_FORCE_COLOR=1 (強制 ON、test 用) > NO_COLOR / DASHBOARD_NO_COLOR (強制 OFF) > [[ -t 1 ]] (TTY 判定)
# exit 0=有効、1=無効
_is_color_enabled() {
  [[ "${DASHBOARD_FORCE_COLOR:-0}" == "1" ]] && return 0
  [[ -n "${NO_COLOR:-}" ]] && return 1
  [[ "${DASHBOARD_NO_COLOR:-0}" == "1" ]] && return 1
  [[ -t 1 ]] && return 0
  return 1
}

# _color_for_status: status 名 → 対応する $COLOR_* 変数の値を stdout に出力
# shipped-* / aborted-* は prefix 一致で shipped / aborted の色を返す
_color_for_status() {
  case "$1" in
    completed) printf '%s' "$COLOR_COMPLETED" ;;
    in_progress) printf '%s' "$COLOR_IN_PROGRESS" ;;
    pending) printf '%s' "$COLOR_PENDING" ;;
    failed) printf '%s' "$COLOR_FAILED" ;;
    blocked) printf '%s' "$COLOR_BLOCKED" ;;
    shipped|shipped-*) printf '%s' "$COLOR_SHIPPED" ;;
    aborted|aborted-*) printf '%s' "$COLOR_ABORTED" ;;
    *) printf '%s' "" ;;
  esac
}

# print_color: status を ANSI カラー付き + 事前パディングで stdout に出力 (末尾改行なし)
# 引数: $1=status、$2=visible-width (optional、省略時はパディングなし)
# カラー無効時はパディング済 status のみ出力
print_color() {
  local status="$1"
  local width="${2:-0}"

  local padded="$status"
  if [[ "$width" =~ ^[0-9]+$ ]] && [[ "$width" -gt 0 ]]; then
    printf -v padded "%-${width}s" "$status"
  fi

  if _is_color_enabled; then
    local color_on
    color_on="$(_color_for_status "$status")"
    if [[ -n "$color_on" ]]; then
      printf '%s%s%s' "$color_on" "$padded" "$COLOR_RESET"
    else
      printf '%s' "$padded"
    fi
  else
    printf '%s' "$padded"
  fi
}

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
    # status は print_color で事前パディング + ANSI (visible-width 12)、wide の他カラムは通常 printf
    printf "%-12s %s %-24s %-24s\n" "$stage" "$(print_color "$status" 12)" "$started" "$completed"
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
    # narrow でも status に色を付ける (visible-width 指定なし、1 行末尾なので列崩れしない)
    printf "%-12s %s\n" "$stage" "$(print_color "$status")"
  done
}

# render_stages_compact: stages を 1 列 key=value で表示 (幅 40 未満)
# 時刻省略、折返しはターミナルに委ねる (Spec §3.5)。
# 引数: $1=progress_json (path)
render_stages_compact() {
  local progress_json="$1"
  jq -r '.stages | to_entries[] | [.key, (.value.status // "-")] | @tsv' "$progress_json" 2>/dev/null \
    | while IFS=$'\t' read -r stage status; do
        printf "%s=%s\n" "$stage" "$(print_color "$status")"
      done
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
