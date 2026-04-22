#!/usr/bin/env bash
# spec-leader eval iteration-2 / iter-3 統合テスト向けの fixture 用 git repo を
# 指定ディレクトリに構築するスクリプトです。
#
# 背景 (phase3-completion.md §5.3 No.3):
#   spec-leader eval 1 (Isolate 実動作) や統合完走テストでは、Agent が毎回
#   `git init + 初期 commit + specs/ 初期配置` を手作業で実行していました。
#   再現性と CI 化の観点から本スクリプトで一括構築できるようにします。
#
# 使い方:
#   bash setup-git-fixture.sh <target-dir> [--with-spec <name>]
#
# 引数:
#   <target-dir>        ... fixture を構築するディレクトリ (既存ファイルは上書きしない、新規作成)
#   --with-spec <name>  ... skills/spec-leader/evals/inputs/specs/ から
#                           <name>.md / <name>.review.md を target/specs/ にコピー
#                           (省略時は README.md のみの空 repo)
#
# 例:
#   # iter-3 統合テスト用に calculator Spec 付き fixture を準備
#   bash setup-git-fixture.sh ~/tmp/my-test --with-spec login
#
# 構築される内容:
#   <target-dir>/
#     ├── .git/              (初期化済、ユーザー test@example.com / test)
#     ├── README.md          (fixture 識別用)
#     └── specs/             (空、または --with-spec で指定した Spec をコピー)

set -euo pipefail

# スクリプト自身の絶対パスを cd 前に確定 (SCRIPT_DIR は inputs/ 解決に使用)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-dir> [--with-spec <name>]" >&2
  exit 1
fi

TARGET="$1"
SPEC_NAME=""
shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-spec)
      SPEC_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -e "$TARGET" ]]; then
  echo "Error: target directory already exists: $TARGET" >&2
  echo "Please remove or choose a different path." >&2
  exit 1
fi

mkdir -p "$TARGET/specs"
cd "$TARGET"

git init -q
git config user.email "spec-leader-eval-fixture@example.com"
git config user.name "spec-leader-eval-fixture"
echo "# Test project for spec-leader evals (fixture generated at $(date -u +%FT%TZ))" > README.md

# 一時ファイル類の .gitignore (2026-04-22 iter-5 改修: merge 時 __pycache__ 競合予防)
cat > .gitignore <<'GITIGNORE'
# Python
__pycache__/
*.py[cod]
.pytest_cache/
.venv/
venv/

# Node
node_modules/
dist/
build/

# その他 generated
*.log
.DS_Store
GITIGNORE

# Spec コピー (任意、SCRIPT_DIR はスクリプト冒頭で確定済み)
if [[ -n "$SPEC_NAME" ]]; then
  INPUT_DIR="$SCRIPT_DIR/../inputs/specs"
  if [[ ! -f "$INPUT_DIR/$SPEC_NAME.md" ]]; then
    echo "Error: spec not found: $INPUT_DIR/$SPEC_NAME.md" >&2
    exit 1
  fi
  cp "$INPUT_DIR/$SPEC_NAME.md" "specs/$SPEC_NAME.md"
  if [[ -f "$INPUT_DIR/$SPEC_NAME.review.md" ]]; then
    cp "$INPUT_DIR/$SPEC_NAME.review.md" "specs/$SPEC_NAME.review.md"
  fi
fi

git add .
git commit -q -m "initial fixture commit"

echo "Fixture constructed at: $TARGET"
echo "Branch: $(git branch --show-current)"
echo "HEAD: $(git log -1 --oneline)"
if [[ -n "$SPEC_NAME" ]]; then
  echo "Spec files:"
  ls specs/
fi
