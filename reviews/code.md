---
reviewer: code-reviewer
spec: tmux-dashboard-mvp
reviewed: 2026-04-20
executed_at: 2026-04-20T00:20:00Z
verdict: needs-fix
---

# Code Review: tmux-dashboard-mvp

## 概評

bash のみで完結する MVP として、構造は清潔で読みやすく、`set -u` / 関数分離 / docstring / 環境変数による test 注入 (`DASHBOARD_DRY_RUN` / `DASHBOARD_FAKE_NO_TMUX` / `DASHBOARD_PANE_ONESHOT`) が一貫して設計されています。Plan §5.1 の T-1〜T-4 は概ね忠実に実装され、AC-3 / AC-4 / AC-5 / AC-7 / AC-8 は自動テスト経路で検証可能な状態に仕上がっています。`mapfile -t targets < <(...)` による配列受け取り、`shopt -s nullglob` / `shopt -u nullglob` のスコープ限定、`readonly SCRIPT_DIR` の `$(cd ... && pwd)` パターンも堅実です。

一方で、Spec §3.2 の出力要件 (`## ログ` セクションの末尾 10 行) とコードの挙動 (progress.md 全体の末尾 10 行) が食い違っており、AC-6 の「progress.md のログ末尾 10 行」を厳密には満たしていません。加えて tmux バージョン判定 (`dashboard.sh:68`) に短絡評価の綻びがあり、非数値バージョン文字列が誤って "許容" されてしまう設計上の穴があります。これらは ship 前に直すべき Major 相当です。Critical は検出されませんでした。

## Critical

(なし)

## Major

### [code-Major-1] progress.md の「`## ログ` セクション末尾 10 行」ではなく全文末尾 10 行を表示している

- 該当: `tools/dashboard-pane.sh:81-84`

  ```bash
  if [[ -f "$progress_md" ]]; then
    printf "\n-- ログ末尾 10 行 (%s) --\n" "progress.md"
    tail -n 10 "$progress_md"
  fi
  ```

- 問題: Spec §3.2 で「progress.md の `## ログ` セクションの末尾 10 行を追加表示」と明記されていますが、実装は `tail -n 10 "$progress_md"` で**ファイル全体**の末尾 10 行を表示しています。progress.md の末尾に別セクション (例: `## 次のアクション`) が追記された場合、ログではない内容が混入します。AC-6 の「progress.md のログ末尾 10 行が 1 秒間隔で更新される」を厳密には満たしていません。
- 修正提案: `## ログ` セクションを抽出してから tail する。例えば:

  ```bash
  if [[ -f "$progress_md" ]]; then
    printf "\n-- ログ末尾 10 行 (%s) --\n" "progress.md"
    awk '/^## ログ/{flag=1; next} /^## /{flag=0} flag' "$progress_md" | tail -n 10
  fi
  ```

  もしくは Spec 側を「progress.md 全体の末尾 10 行」に修正するのであれば、Spec §3.2 と AC-6 の文言を合わせて更新し、本レビュー指摘を dismiss する判断でも構いません。いずれにせよ Spec と実装のどちらかを動かす必要があります。

### [code-Major-2] `ensure_tmux` のバージョン判定が非数値 version 文字列を誤って許容する

- 該当: `tools/dashboard.sh:64-72`

  ```bash
  version="$(tmux -V 2>/dev/null | awk '{print $2}')"
  local major
  major="${version%%.*}"
  if [[ -z "$major" || "$major" =~ ^[0-9]+$ && "$major" -lt 2 ]]; then
    log_err "tmux バージョン ${version} は未対応です。..."
    exit 1
  fi
  ```

- 問題: 条件は「`-z $major` OR (数値正規表現にマッチ AND 2 未満)」という構造です (bash の `[[ ]]` では `&&` が `||` より優先)。この結果、`major` が**非数値** (例: `next-3`、`unknown`、あるいは `tmux -V` が想定外の書式で出力された場合の任意文字列) の場合、正規表現にマッチせず `&&` 側の条件は偽となり、`||` 全体も偽になるため **エラーとして弾かれずに処理が継続** してしまいます。Spec §7.1 / Plan §7.4 の「tmux 1.x なら error + exit 1」という意図 (= 未対応バージョンは必ず検出) に反します。
- 修正提案: 非数値ケースを明示的に弾く:

  ```bash
  if [[ -z "$major" || ! "$major" =~ ^[0-9]+$ || "$major" -lt 2 ]]; then
    log_err "tmux バージョン '${version}' は未対応です。tmux 2.6+ / 3+ をインストールしてください。"
    exit 1
  fi
  ```

  `||` の連鎖で「空 OR 非数値 OR 2 未満」と直列に並べると意図が明確になります。

### [code-Major-3] progress.md のパスが `SPEC_DIR` 相対で組み立てられており、環境変数の想定と整合しない

- 該当: `tools/dashboard-pane.sh:49`

  ```bash
  local progress_md="${SPEC_DIR}/../worktrees/${spec}/progress.md"
  ```

- 問題: `SPEC_DIR` は `DASHBOARD_SPEC_DIR` で上書き可能ですが、このコードは `SPEC_DIR` の親ディレクトリを repo ルートと仮定しており、`DASHBOARD_SPEC_DIR=/tmp/fixtures` のようなテスト用パスを渡すと `progress.md` のパスが意味をなさなくなります。`SPEC_DIR` と worktree の位置関係を暗黙に結合しているため、将来 specs/ を別ディレクトリに移した場合や、テストで一時ディレクトリを渡した場合に debug しづらい挙動になります。
- 修正提案: progress.md の探索基準を `REPO_ROOT` (既に定義済み) に変更し、必要なら `DASHBOARD_WORKTREES_DIR` 環境変数を別に切る:

  ```bash
  local worktrees_dir="${DASHBOARD_WORKTREES_DIR:-${REPO_ROOT}/worktrees}"
  local progress_md="${worktrees_dir}/${spec}/progress.md"
  ```

  MVP としてはまず `REPO_ROOT` ベースに切り替えるだけで十分で、環境変数追加は拡張時で構いません。

## Minor

### [code-Minor-1] `ensure_tmux` の「tmux 不在」判定が 2 経路に分裂している

- 該当: `tools/dashboard.sh:56-63`
- 内容: `DASHBOARD_FAKE_NO_TMUX=1` ブランチと `command -v tmux` 失敗ブランチで、ほぼ同一のエラーメッセージが 2 回書かれています。テスト用の fake パスを先に評価する設計は合理的ですが、メッセージの DRY 性が低いです。
- 修正提案: fake フラグで `command` 経路を擬似的に fail させるフラグに統合する、またはエラーメッセージを変数に切り出す:

  ```bash
  local missing_msg="tmux がインストールされていません。tmux 2.6+ / 3+ をインストールしてください。"
  if [[ "${DASHBOARD_FAKE_NO_TMUX:-0}" == "1" ]] || ! command -v tmux >/dev/null 2>&1; then
    log_err "$missing_msg"; exit 1
  fi
  ```

### [code-Minor-2] `launch_tmux` の 9 Spec 超 warning が pane 作成「後」に出る

- 該当: `tools/dashboard.sh:128-137`
- 内容: Plan §7.3 の「9 Spec 超で stderr に警告」は実装されていますが、`tmux split-window` を全部実行した後に警告が出るため、ユーザーが気付いたときには既に session 起動済みです。
- 修正提案: `launch_tmux` 冒頭 (has-session チェック直前または直後) で `${#specs[@]} -gt 9` を判定して warning を出すと、事前に絞り込みを促せます。

### [code-Minor-3] `launch_tmux` 内で `select-layout tiled` が毎 split ごとに呼ばれ、最後にも呼ばれている

- 該当: `tools/dashboard.sh:129-133`
- 内容: for ループ内の `tmux select-layout -t "$SESSION:dashboard" tiled >/dev/null` と、ループ後の同呼び出しが重複しています。ループ内で呼ぶ理由は「split ごとに layout を整える」ためですが、最後にもう一度呼ぶのは冗長です。
- 修正提案: ループ内呼び出しを削除してループ後の 1 回だけ呼ぶ、もしくはループ内呼び出しだけに統一する:

  ```bash
  for spec in "${rest[@]}"; do
    tmux split-window -t "$SESSION:dashboard" "bash '$PANE_SCRIPT' '$spec'"
  done
  tmux select-layout -t "$SESSION:dashboard" tiled >/dev/null
  ```

  split 直後に layout 調整しなくても tmux は自動で合理的な分割をしてくれるため、1 回のみで十分です。

### [code-Minor-4] `tmux new-session` / `tmux split-window` のコマンド引数で Spec 名のシングルクォート不許容

- 該当: `tools/dashboard.sh:125,129`

  ```bash
  tmux new-session -d -s "$SESSION" -n dashboard "bash '$PANE_SCRIPT' '$first'"
  tmux split-window -t "$SESSION:dashboard" "bash '$PANE_SCRIPT' '$spec'"
  ```

- 内容: tmux はコマンドを `/bin/sh` で解釈するため、Spec 名に `'` (シングルクォート) が含まれると shell パースで破綻します。現状の Spec 命名規則 (kebab-case、英数字 + `-`) では発生しませんが、将来的に任意ファイル名を許容する場合に脆弱です。
- 修正提案: tmux には `-c` や配列渡しが無いため printf の `%q` で明示的にクオートする:

  ```bash
  tmux new-session -d -s "$SESSION" -n dashboard \
    "$(printf 'bash %q %q' "$PANE_SCRIPT" "$first")"
  ```

  ただし MVP 段階では Spec 名制約を README に明記する運用対応でも可です。

### [code-Minor-5] 既存 session への attach 時のメッセージが stderr で消失する

- 該当: `tools/dashboard.sh:120-123`

  ```bash
  if tmux has-session -t "$SESSION" 2>/dev/null; then
    log_err "既存セッション '$SESSION' に attach します"
    exec tmux attach-session -t "$SESSION"
  fi
  ```

- 内容: `log_err` は stderr に書きますが、その直後の `exec tmux attach-session` は端末を tmux に奪うため、ユーザーが `log_err` の出力を視認する暇がありません (特に一瞬)。
- 修正提案: attach 前に 1 秒 sleep するか、メッセージを stdout に出して cursor flush を挟む:

  ```bash
  echo "既存セッション '$SESSION' に attach します"
  sleep 0.5
  exec tmux attach-session -t "$SESSION"
  ```

  もしくはメッセージ自体を削除し、tmux attach 後に window 名で状況が伝わる運用でも MVP としては許容です。

### [code-Minor-6] `test_dashboard.sh` の `assert_case` docstring が関数名と一致しない

- 該当: `tests/test_dashboard.sh:21-22`

  ```bash
  # assert: 条件が真なら PASS、偽なら FAIL を記録する
  # 引数: $1=テスト名, $2=実行コマンド (文字列), $3=期待 exit code, $4=stdout/stderr の含有条件 (任意正規表現)
  assert_case() {
  ```

- 内容: 関数名 `assert_case` に対して docstring 先頭が `# assert:` となっており、grep 等で関数名検索した際に docstring が当たりません。
- 修正提案: `# assert_case: 条件が真なら PASS、...` に揃える。

### [code-Minor-7] `render_spec` の stderr 出力と poll ループの `clear` が競合する

- 該当: `tools/dashboard-pane.sh:54,108-111`
- 内容: `render_spec` は progress.json 不在時に `echo "progress 未生成..." >&2` とし、main ループは毎秒 `clear` を呼びます。stderr は `clear` でクリアされないため、warning が積み上がっていき画面下部に残ります (tmux pane で stderr がどう描画されるかは端末依存)。
- 修正提案: 1 秒 poll ループでは stderr ではなく stdout に出して一貫表示する、もしくは「progress 未生成」は return 0 する前に現在状態として stdout 描画する:

  ```bash
  if [[ ! -f "$progress_json" ]]; then
    echo "progress 未生成、spec-leader が起動されていない可能性 (expected: $progress_json)"
    return 0
  fi
  ```

  test T-test-6 は `2>&1` でマージしているので、stdout に変えても test は引き続き pass します。

### [code-Minor-8] `collect_specs_auto` で `jq` 不在時は全 Spec が対象に含まれる

- 該当: `tools/dashboard.sh:89-97`

  ```bash
  local verdict="unknown"
  if command -v jq >/dev/null 2>&1; then
    verdict="$(jq -r '.verdict // "unknown"' "$result" 2>/dev/null)"
  fi
  case "$verdict" in
    shipped|shipped-manual|...|aborted-on-resume) ;;
    *) echo "$spec" ;;
  esac
  ```

- 内容: `jq` 不在の環境では `verdict` が `unknown` に固定されるため、shipped 済み Spec も「in-progress」扱いで一覧に上がります。`dashboard-pane.sh` 側は `jq` 不在で exit 1 するため、dashboard.sh 側で先に `jq` チェックするのが一貫しています。
- 修正提案: `ensure_tmux` と同列に `ensure_jq` を設け、dashboard.sh 起動時にも `jq` 必須を宣言する:

  ```bash
  ensure_jq() {
    if ! command -v jq >/dev/null 2>&1; then
      log_err "jq が必要です (apt install jq / brew install jq)"
      exit 1
    fi
  }
  ```

  これで `collect_specs_auto` の `jq` 不在パスは発生し得なくなります。

## 良かった点

- `set -u` による未定義変数検出、`shopt -s/-u nullglob` のスコープ限定、`mapfile -t` による配列化など、bash 堅牢性の定石が適切に適用されています。
- 環境変数による test 注入 (`DASHBOARD_DRY_RUN` / `DASHBOARD_FAKE_NO_TMUX` / `DASHBOARD_PANE_ONESHOT` / `DASHBOARD_POLL_SEC`) が直交的に設計されており、`tests/test_dashboard.sh` からドライラン検証が簡潔に書けています。
- 関数ごとの docstring (bash コメント) が全関数に揃っており、AC-8 を満たしています。可読性も高いです。
- `render_spec` が `jq` 失敗時に「更新中...」へフォールバックする構造は Spec §7.3 / Plan §7.2 の atomic write 非前提リスクに正しく対応しています。
- `tests/test_dashboard.sh` の `trap 'rm -rf "$TMP_EMPTY"' EXIT` による一時ディレクトリ後片付けが衛生的で、CI 実行にも向いています。

## 総合 verdict

- Critical: 0 件
- Major: 3 件
- Minor: 8 件

判定ルール (Critical 0 件 かつ Major 3 件以上 → needs-fix) に従い、**verdict: needs-fix** とします。

Major 3 件はいずれも局所的修正で対応可能で、Spec §3.2 / §7.1 との整合性回復と `SPEC_DIR` 前提の疎結合化を行えば pass 水準に到達します。Minor 群は時間が許せば併せて取り込むことを推奨しますが、ship ブロック要因ではありません。
