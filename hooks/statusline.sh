#!/usr/bin/env bash
# Claude Code statusLine: branch+dirty / ccusage(model + context only) / short cwd
set -u

CCUSAGE="${CCUSAGE_BIN:-$HOME/.bun/bin/ccusage}"

input="$(cat)"

cwd="$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // "?"')"

case "$cwd" in
    "$HOME") short_cwd="~" ;;
    "$HOME"/*) short_cwd="~${cwd#$HOME}" ;;
    *) short_cwd="$cwd" ;;
esac

branch_part=""
if git -C "$cwd" rev-parse --show-toplevel >/dev/null 2>&1; then
    branch="$(git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null \
        || git -C "$cwd" rev-parse --short HEAD 2>/dev/null \
        || echo "?")"
    if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
        dirty="*"
    else
        dirty=""
    fi
    branch_part="⎇ ${branch}${dirty}"
fi

# ccusage statusline 出力から 🤖 (model) と 🧠 (context) のみ抽出
ccusage_out=""
if [ -x "$CCUSAGE" ]; then
    raw="$(printf '%s' "$input" | "$CCUSAGE" statusline 2>/dev/null || echo "")"
    if [ -n "$raw" ]; then
        model_part="$(printf '%s' "$raw" | grep -oE '🤖 [^|]+' | sed 's/[[:space:]]*$//')"
        ctx_part="$(printf '%s' "$raw" | grep -oE '🧠 [^|]+' | sed 's/[[:space:]]*$//')"
        keep=()
        [ -n "$model_part" ] && keep+=("$model_part")
        [ -n "$ctx_part" ] && keep+=("$ctx_part")
        if [ "${#keep[@]}" -gt 0 ]; then
            ccusage_out="${keep[0]}"
            for ((i=1; i<${#keep[@]}; i++)); do
                ccusage_out="${ccusage_out} | ${keep[$i]}"
            done
        fi
    fi
fi

BLUE=$'\033[34m'
GREEN=$'\033[32m'
RESET=$'\033[0m'
DIM=$'\033[2m'

parts=()
[ -n "$branch_part" ] && parts+=("${GREEN}${branch_part}${RESET}")
[ -n "$ccusage_out" ] && parts+=("$ccusage_out")
parts+=("${BLUE}${short_cwd}${RESET}")

sep="${DIM} | ${RESET}"
out=""
for i in "${!parts[@]}"; do
    if [ "$i" -eq 0 ]; then
        out="${parts[$i]}"
    else
        out="${out}${sep}${parts[$i]}"
    fi
done

printf '%s' "$out"
