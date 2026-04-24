# tmux ダッシュボード運用ガイド

本プロジェクトに ship された `tools/dashboard.sh` / `tools/dashboard-pane.sh` は、Phase 5 orchestrator が管理する複数 Spec の進捗 (`specs/*.progress.json` / `specs/*.result.json` / `worktrees/*/progress.md`) を tmux の複数 pane で同時表示する CLI ツールです。本ドキュメントは運用手順とハマりどころをまとめます。

仕様本体は `specs/archive/tmux-dashboard-mvp.md` を、設計判断と指摘対応は `specs/archive/tmux-dashboard-mvp.plan.md` / `specs/archive/tmux-dashboard-mvp.consolidated.md` / `specs/archive/tmux-dashboard-mvp.learn.md` を参照してください。

## 1. 前提要件

| 項目 | 要件 |
|---|---|
| OS | Linux / macOS (WSL2 も動作確認済) |
| bash | 4 以上 |
| tmux | 2.6 以上 / 3 系推奨 (`tmux -V` で 2+ を確認) |
| jq | 1.6 以上 (`jq --version` で確認) |

いずれかが不在の場合、`dashboard.sh` / `dashboard-pane.sh` は起動時に stderr へ不足品目を出力して exit 1 します。

## 2. 起動方法

### 2.1 自動探索モード (引数なし)

```bash
bash tools/dashboard.sh
```

`specs/*.progress.json` を glob し、対応する `result.json` が未生成または verdict が in-progress 相当 (`shipped` / `shipped-manual` / `shipped-cross-model-pending` / `aborted` / `aborted-on-resume` 以外) の Spec を対象に tmux セッション `my-workflows-dashboard` を起動します。

### 2.2 明示指定モード

```bash
bash tools/dashboard.sh auth order catalog
```

指定した Spec 名のみを対象にします。`specs/<name>.progress.json` が存在しない Spec は stderr に warning を出して skip します (他 Spec の起動は継続)。

### 2.3 ヘルプ

```bash
bash tools/dashboard.sh --help
```

### 2.4 手動で pane をもう 1 枚足す

tmux session 起動後に別 Spec を追加で見たい場合は、tmux 側のコマンドで pane を足してから `dashboard-pane.sh` を実行します:

```bash
tmux split-window -t my-workflows-dashboard:dashboard
# 開いた pane で:
bash tools/dashboard-pane.sh <spec-name>
tmux select-layout -t my-workflows-dashboard:dashboard tiled
```

## 3. 環境変数

| 変数 | 用途 | デフォルト |
|---|---|---|
| `DASHBOARD_SPEC_DIR` | progress/result の置き場所 | `$REPO_ROOT/specs` |
| `DASHBOARD_WORKTREES_DIR` | progress.md の置き場所 | `$REPO_ROOT/worktrees` |
| `DASHBOARD_SESSION` | tmux session 名 | `my-workflows-dashboard` |
| `DASHBOARD_POLL_SEC` | pane の poll 間隔 (秒) | `1` |
| `DASHBOARD_DRY_RUN` | `1` のとき対象一覧だけ表示して tmux 起動なし | 未設定 |
| `DASHBOARD_FAKE_NO_TMUX` | `1` のとき tmux 未インストールを擬似再現 (test 用) | 未設定 |
| `DASHBOARD_PANE_ONESHOT` | `1` のとき dashboard-pane が 1 回描画して exit (test 用) | 未設定 |
| `DASHBOARD_FAKE_COLS` | pane 幅を正整数で強制 (test 用、v2-responsive 追加) | 未設定 |
| `NO_COLOR` | 任意の非空値で ANSI カラー無効化 (業界標準、dashboard-color 追加) | 未設定 |
| `DASHBOARD_NO_COLOR` | `1` で ANSI カラー無効化 (本プロジェクト固有、dashboard-color 追加) | 未設定 |
| `DASHBOARD_FORCE_COLOR` | `1` で TTY 判定を bypass してカラー強制 ON (test 用、dashboard-color 追加) | 未設定 |
| `DASHBOARD_THEME` | テーマ名 (default / solarized-dark / monokai またはカスタム、dashboard-color-themes 追加) | `default` |

別ディレクトリから dashboard を動かしたいケースでは `DASHBOARD_SPEC_DIR` / `DASHBOARD_WORKTREES_DIR` を両方指定してください。tmux が既に別 server で起動している場合、環境変数が server に引き継がれないため、`tmux -L <socket名>` で別 socket を使うか、`-e KEY=VALUE` flag で明示的に環境を渡す必要があります (下記 §7.3 参照)。

### 3.1 pane 幅適応レイアウト (v2-responsive)

`dashboard-pane.sh` は pane の幅に応じて stages テーブルを 3 モードで切り替えます。幅は以下の 4 段フォールバックで取得します:

1. `DASHBOARD_FAKE_COLS` (test 用、正整数のみ採用)
2. `$COLUMNS` (bash の対話 shell で設定される)
3. `tput cols` (pty から ioctl で取得、非対話でも動作)
4. `80` default (いずれも失敗時、wide モードに落とす)

| モード | pane 幅 | 表示 |
|---|---|---|
| wide | 60 カラム以上 | 4 列テーブル (`stage / status / started_at / completed_at`) |
| narrow | 40-59 カラム | 2 列テーブル (`stage / status`)、時刻は省略 |
| compact | 40 カラム未満 | 1 列 (`stage=status` 形式の key-value 列挙)、時刻省略 |

compact モードおよび narrow モードで 1 行が pane 幅を超える場合 (長い status / 長いステージ名) は、ターミナルの折返しに委ねて truncate は行いません。詳細は `specs/archive/tmux-dashboard-v2-responsive.md` §3.5 を参照してください。

9 pane 超 (§5) で狭くなる懸念は、compact モードが自動で選ばれることで stages 状態の把握が可能になります。ただし時刻情報は失われるため、進行時間を確認したい場合は pane を手動で拡大 (tmux `Ctrl-b z` で zoom) して wide モードに切り替えてください。

### 3.2 ANSI カラー (dashboard-color)

3 モードすべてで status に応じた ANSI カラーが付きます。`print_color` ヘルパーが pane ごとに 1 秒 poll で呼ばれ、status セルを色付きで出力します。

| status | 色 | 代表例 |
|---|---|---|
| `completed` | 緑 (32) | isolate ステージ通過済 |
| `in_progress` | 黄 (33) | 現在作業中のステージ |
| `pending` | デフォルト | 未開始 |
| `failed` | 赤 (31) | エラーで停止 |
| `blocked` | マゼンタ (35) | 下位 skill 未実装で待機 |
| `shipped` / `shipped-*` | シアン (36) | result.json の最終状態 |
| `aborted` / `aborted-*` | 赤 (31) | result.json のアボート状態 |

**カラーの有効 / 無効**:

- 自動: 標準出力が TTY のとき ON、パイプ / リダイレクト時は OFF
- 強制 OFF: `NO_COLOR=1` または `DASHBOARD_NO_COLOR=1` を指定 (業界標準 `NO_COLOR` + 本プロジェクト固有変数の両方を受け付け)
- 強制 ON: `DASHBOARD_FORCE_COLOR=1` (test 環境や tmux server 経由で TTY が正しく引き継がれない場合の救済)

優先度は **FORCE_COLOR > NO_COLOR > DASHBOARD_NO_COLOR > TTY 判定** です。

**列アライメント**:

wide モードの status カラム (12 文字幅) は `print_color <status> 12` で**事前パディング後に ANSI を巻く**ため、後続の `started_at` / `completed_at` カラムの開始列位置は wide shipped 版と同一です (ANSI エスケープコードがバイト幅計算に影響せず、視覚幅 12 を保つ)。

### 3.3 カラーテーマ (dashboard-color-themes)

`DASHBOARD_THEME=<name>` で配色を切り替えられます。標準テーマ 3 種:

| テーマ | 背景想定 | 特徴 |
|---|---|---|
| `default` | ライト / ダーク両対応 | ANSI 基本 8 色 (32m 緑 / 33m 黄 / 31m 赤 など) |
| `solarized-dark` | ダーク端末 | 高輝度 ANSI (92m / 93m / 96m など)、青系背景に映える |
| `monokai` | ダーク端末 | bold 修飾 (1;32m 等) で鮮やか、IDE 風 |

**カスタムテーマ作成**:

1. `tools/dashboard-themes/<my-theme>.env` を作成 (例: `tools/dashboard-themes/ocean.env`)
2. 以下 8 変数を定義 (`\e[...m` の ANSI エスケープ文字列、または空文字列)

```bash
# tools/dashboard-themes/ocean.env
COLOR_COMPLETED='\e[36m'
COLOR_IN_PROGRESS='\e[34m'
COLOR_PENDING=''
COLOR_FAILED='\e[31m'
COLOR_BLOCKED='\e[35m'
COLOR_SHIPPED='\e[96m'
COLOR_ABORTED='\e[31m'
COLOR_RESET='\e[0m'
```

3. `DASHBOARD_THEME=ocean bash tools/dashboard.sh ...` で適用

**セキュリティ**:

- テーマ名 allowlist: `^[A-Za-z0-9][A-Za-z0-9._-]*$` (先頭英数字必須、path traversal 拒否)
- env ファイルは `source` / `eval` / コマンド置換を一切使わず、行単位 allowlist (`^COLOR_[A-Z_]+=`) + 値 regex (`^(\e\[[0-9;]+m)*$`) の 2 段検証
- 1 件でも違反があればテーマ全体を default にフォールバック (行単位の部分読み込みはしない)

**挙動マトリクス**:

| DASHBOARD_THEME | 結果 |
|---|---|
| (未指定) | default 自動ロード |
| `default` / `solarized-dark` / `monokai` | 標準テーマ適用 |
| `ocean` (自作) | `tools/dashboard-themes/ocean.env` を 2 段検証してロード |
| `nonexistent` | 警告 (`theme file not found`) + default フォールバック |
| `../evil` | allowlist 違反警告 + default フォールバック |
| (env ファイル内に `EVIL_CMD='...'` 等の不正エントリ) | 警告 (`invalid entry`) + default フォールバック (全体、部分読み込みなし) |

## 4. Spec 名の制約 (セキュリティ)

`dashboard.sh` / `dashboard-pane.sh` は Spec 名を以下の allowlist で検証します:

```
^[A-Za-z0-9][A-Za-z0-9._-]*$
```

**先頭**は英数字必須、**2 文字目以降**はドット / アンダースコア / ハイフンも許可します。先頭ドット (`.hidden`) / dot-only (`..`) / ハイフンスタート (`-rf`) は拒否されます (path traversal と `-` フラグ混入の予防)。これは `tmux new-session` / `tmux split-window` の shell コマンド文字列経由でのコマンドインジェクション防止のためで、`printf %q` によるエスケープと合わせた 2 層防御です。allowlist 違反は stderr に「invalid spec name」を出力して exit 1 します (dashboard-pane) / スキップ + warning (dashboard)。

Spec 命名規則として kebab-case (`ecsite-mvp-auth` 等) を推奨します。2026-04-24 に `^[A-Za-z0-9][A-Za-z0-9._-]*$` に強化され、security-reviewer iter-2 で指摘されていた dot-only 許容問題 (`specs/archive/tmux-dashboard-mvp.learn.md §7`) は解消済です。

## 5. 9 Spec 超の運用

10 pane 以上を tiled layout で配置すると、各 pane が狭くなり `stage / status / started_at / completed_at` の 4 列テーブルが改行されて可読性が下がります。`dashboard.sh` は 9 Spec 超で起動時に stderr へ警告を出します:

```
warning: 12 Spec を同時表示します。pane が細かくなりすぎる可能性、絞り込みを推奨
```

対処法:

- **引数で Spec を絞り込む**: 注目している 3-5 Spec だけ明示指定
- **複数 tmux session に分割**: `DASHBOARD_SESSION=my-workflows-auth bash tools/dashboard.sh auth-* && DASHBOARD_SESSION=my-workflows-order bash tools/dashboard.sh order-*` のように feature 単位で session を分ける
- **将来の改修を待つ**: pane 幅適応レイアウト (4 列 → 2 列折り返し) が specs/archive/tmux-dashboard-mvp.learn.md §5.2 の Try として挙がっています

## 6. 表示の読み方

各 pane は 1 秒間隔で以下を表示します:

```
=== <spec-name>  (<現在時刻>) ===
spec: <spec-name>
current_stage: <isolate / implement / verify / code_review / ship>
updated_at: <progress.json の updated_at>

stage        status       started_at               completed_at
isolate      completed    2026-04-20T00:00:00Z     2026-04-20T00:05:00Z
implement    completed    2026-04-20T00:05:00Z     2026-04-20T00:30:00Z
verify       completed    2026-04-20T00:10:00Z     2026-04-20T00:35:00Z
code_review  in_progress  2026-04-20T00:15:00Z     -
ship         pending      -                        -

-- result --
verdict: shipped-cross-model-pending
stages_completed: isolate, implement, verify, code_review, ship

-- ログ末尾 10 行 (progress.md) --
<worktree 側 progress.md の `## ログ` セクションの末尾 10 行>
```

`result.json` が未生成なら `-- result --` セクションは表示されません。`progress.md` が存在しない (worktree 削除後 / 未作成) 場合はログセクションが省略されます。

### 6.1 「更新中...」が表示される場合

spec-leader が progress.json / result.json を atomic write していない環境で、jq が不完全な JSON を読んで fail すると pane に `更新中...` と表示されます。次の 1 秒 poll で再試行されるため、数秒以上続く場合は spec-leader 側の書き込み方法を確認してください (tmp file + rename の atomic write 推奨、spec-leader SKILL.md §5.2.1 参照)。

## 7. トラブルシューティング

### 7.1 `open terminal failed: not a terminal`

Claude Code の Bash tool や CI など TTY が無い環境で `dashboard.sh` を直接実行すると、最後の `exec tmux attach-session` が失敗します。pane 自体は `tmux new-session -d` で detached 作成されるので session は残っています。capture したい場合は:

```bash
tmux list-sessions
tmux capture-pane -t my-workflows-dashboard:dashboard.1 -p
```

### 7.2 「対象 Spec がありません」

`specs/*.progress.json` が 0 件、または全 Spec が `shipped` / `aborted` 系の verdict を持っている状態です。spec-leader を起動して進捗ファイルを生成するか、明示指定で対象を絞ってください。

### 7.3 環境変数が pane に届かない

既存 tmux server に対して `new-session` した場合、呼び出し元 shell の環境変数は server に引き継がれません。以下のいずれかで回避します:

```bash
# 方法 1: 別 socket で新規 server 起動
tmux -L demo new-session -d -s dashboard -e "DASHBOARD_SPEC_DIR=/path/to/specs" "bash tools/dashboard-pane.sh <spec>"

# 方法 2: tmux set-environment で session 環境に注入
tmux set-environment -t my-workflows-dashboard DASHBOARD_SPEC_DIR /path/to/specs
```

### 7.4 Spec 名 allowlist で意図せず弾かれる

Spec 名にスペース / `@` / `:` 等を含むと弾かれます。命名規則を kebab-case に統一してください。Unicode (日本語等) も現行 allowlist では拒否されます (意図的なセキュリティ制約)。

### 7.5 `tmux -V` が出せないバージョン

`tmux` コマンドは存在するが `tmux -V` の出力が `tmux 2.6` のような標準形式でない (組み込みシステム等) 場合、`ensure_tmux` の `||` 直列判定 (`-z || ! =~ ^[0-9]+$ || < 2`) で「未対応」として exit 1 します。標準の tmux をインストールしてください。

## 8. progress.md に外部入力を書かない

`dashboard-pane.sh` は `worktrees/<spec>/progress.md` の `## ログ` セクション末尾 10 行を `tail` で表示します。Spec §4 非機能要件で「sanitize なし、機密情報はユーザー責任」と明記しているため、progress.md の内容は端末にそのまま流れます。つまり:

- **ANSI エスケープシーケンス** を含む内容が書き込まれると、端末のタイトル書き換え / カラー変更 / カーソル制御が実行されます
- spec-leader / hook / 手動コミットで progress.md にログ追記する際、**外部入力 (Issue 本文 / PR コメント / Slack メッセージ等) を検証なしで書き込まないでください**
- 将来 progress.md を外部入力から自動生成するステージを追加する場合は、ANSI 除去 (`sed 's/\x1b/^[/g'`) や `cat -v` でのサニタイズを検討してください (specs/archive/tmux-dashboard-mvp.consolidated.md §3 security-Minor-2 参照)

## 9. テスト

`tests/test_dashboard.sh` がドライラン範囲の 10 ケースを検証します:

```bash
bash tests/test_dashboard.sh
```

全 pass なら exit 0、失敗があれば exit 1 + fail 一覧を stdout に出します。テスト冒頭で `REPO_ROOT` にシングルクォートが含まれるパス (テストハーネスが bash -c 評価に依存するため) を assertion で弾きます。

tmux 実起動が必要な AC-1 / AC-2 / AC-6 は自動テスト範囲外です。実環境で以下を通してください:

```bash
bash tools/dashboard.sh              # AC-1: 自動探索
bash tools/dashboard.sh a b c        # AC-2: 3 pane tiled
echo "[demo] test" >> worktrees/a/progress.md
# 1 秒以内に対応 pane で末尾行が更新されることを目視確認 (AC-6)
```

## 10. 関連ドキュメント

- 仕様: `specs/archive/tmux-dashboard-mvp.md`
- 設計・タスク分解: `specs/archive/tmux-dashboard-mvp.plan.md`
- レビュー結果: `specs/archive/tmux-dashboard-mvp.consolidated.md`
- 振り返り: `specs/archive/tmux-dashboard-mvp.learn.md`
- spec-leader との連携: `skills/spec-leader/SKILL.md` §4 (progress.json / result.json のインタフェース)
