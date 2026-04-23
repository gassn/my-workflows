---
name: tmux-dashboard-mvp
spec_path: specs/tmux-dashboard-mvp.md
status: archived
created: 2026-04-20
revised: 2026-04-20
review_iteration: 1
---

# Plan: tmux-dashboard-mvp

## 1. 技術設計概要

Phase 5 orchestrator skill が管理する `progress.json` / `progress.md` / `result.json` を、tmux の複数 pane で 1 秒間隔で同時表示する CLI ダッシュボードを実装します。本 Plan はドッグフーディングが目的のため、**bash のみで完結** し、外部ランタイム (Python / Node) に依存しません。JSON 解釈は `jq` に委ねます。

アーキテクチャの要点:

- `tools/dashboard.sh` が tmux session を起動し、対象 Spec 毎に pane を割り当てて `dashboard-pane.sh` を `tmux send-keys` で起動
- `tools/dashboard-pane.sh` が 1 秒間隔の while ループで `jq` / `tail` を用いて progress.json / result.json / progress.md を整形表示
- 両スクリプトとも環境変数 (`DASHBOARD_FAKE_NO_TMUX=1` 等) で test 時の挙動注入を可能にし、`tests/test_dashboard.sh` から bash 構文 / 引数パース / エラーパスをドライラン検証

## 2. アーキテクチャ

### 2.1 コンポーネント構成

```
tools/
├── dashboard.sh         # エントリポイント (tmux session + pane 配置 + send-keys)
└── dashboard-pane.sh    # 各 pane の表示ループ (1 秒 poll、jq/tail で整形)

tests/
└── test_dashboard.sh    # bash 構文 + 引数 + エラー / warning パス検証 (tmux 起動なし)
```

### 2.2 データフロー

```
spec-leader ──(progress.json/result.json/progress.md 書き込み)──┐
                                                                 ▼
        dashboard.sh ── tmux pane × N ── dashboard-pane.sh ── 1 秒 poll 表示
```

### 2.3 依存関係

- **新規ライブラリ**: なし (bash 組み込みのみ、`jq` を前提 / 不在時は警告)
- **既存要件**: tmux 2.6+ / 3+、bash 4+、`jq`
- **対象ファイル**: `specs/*.progress.json`、`specs/*.result.json`、`specs/*.progress.md` (spec-leader 生成物)

## 3. データモデル

新規テーブル / 型定義はありません。spec-leader が既に定義する `progress.json` / `result.json` のスキーマを**読み取り専用**で利用します。スキーマ変更は本 Spec のスコープ外です。

## 4. API 設計

CLI のみ (ネットワーク API なし)。

| コマンド | 引数 | 挙動 |
|---|---|---|
| `bash tools/dashboard.sh` | (なし) | `specs/*.progress.json` を走査し in-progress Spec を対象に tmux session 起動 |
| `bash tools/dashboard.sh <spec> [<spec>...]` | Spec 名 1 個以上 | 指定 Spec のみを対象に tmux session 起動 |
| `bash tools/dashboard.sh --help` | `--help` | 使い方を表示して exit 0 |
| `bash tools/dashboard-pane.sh <spec>` | Spec 名 1 個 | 1 秒 poll で progress / result / ログ末尾 10 行を表示 |
| `bash tests/test_dashboard.sh` | (なし) | 全検証項目 pass なら exit 0、fail なら exit 1 |

環境変数による挙動注入 (test 用):

- `DASHBOARD_FAKE_NO_TMUX=1`: `tmux -V` 呼び出しを fail 扱いにし、未インストール時のエラーパスを検証
- `DASHBOARD_DRY_RUN=1`: tmux session を起動せず、「対象 Spec 一覧」だけを stdout に書き出して exit 0

認証要件: なし (ローカル CLI)。

## 5. 実装タスク分解

### 5.1 タスクリスト

- [ ] T-1: `tests/test_dashboard.sh` のテスト骨格を先行作成 (TDD Red 段階、見積: 40 分)
  - 入力: 本 Plan §4 API 設計、Spec §5 AC-1〜AC-8
  - 出力: bash 構文チェック / `--help` 応答 / 無効引数 / 0 件 / tmux 未インストール / progress.json 不在 warning の 6 ケースを検証する `tests/test_dashboard.sh`。実装前のため当然 fail することを確認
  - テスト: 本タスクそのものがテスト作成タスク。`bash tests/test_dashboard.sh` を実行して fail 出力が得られれば成功
  - **files_touched**: `["tests/test_dashboard.sh"]`

- [ ] T-2: `tools/dashboard-pane.sh` 実装 (見積: 50 分)
  - 入力: 本 Plan §4 dashboard-pane.sh コマンド定義、Spec §3.2 出力要件
  - 出力: 1 秒 poll ループ + `jq` による progress.json / result.json 整形 + `tail -n 10` で progress.md 末尾 10 行表示 + jq 失敗時の「更新中...」フォールバック
  - テスト: T-1 の「progress.json 不在 warning」ケースが pass することを確認。単独 pane 動作確認 (`bash tools/dashboard-pane.sh dummy-spec` を 3 秒 timeout 付きで実行 → warning 出力確認)
  - **files_touched**: `["tools/dashboard-pane.sh"]`

- [ ] T-3: `tools/dashboard.sh` 実装 (見積: 50 分)
  - 入力: 本 Plan §4 dashboard.sh コマンド定義、Spec §3.1 起動仕様、§7.1 tmux バージョン要件
  - 出力: `--help` / 引数パース / `DASHBOARD_FAKE_NO_TMUX` 検知 / tmux session 作成 + tiled layout + `send-keys` での pane 起動 / `DASHBOARD_DRY_RUN` 対応
  - テスト: T-1 のうち `--help` / 無効引数 / 0 件 / tmux 未インストールの 4 ケースが pass することを確認
  - **files_touched**: `["tools/dashboard.sh"]`

- [ ] T-4: docstring 整備 + AC-8 確認 + 手動 AC 通し確認 (見積: 30 分)
  - 入力: T-2 / T-3 で書いたスクリプト、Spec §5 AC-1〜AC-8
  - 出力: 全関数に bash コメント形式 docstring 追加、`bash tests/test_dashboard.sh` が全通過、AC-1〜AC-8 のうち tmux 実起動が必要な AC-1 / AC-2 / AC-6 を手動実行して記録
  - テスト: `bash tests/test_dashboard.sh` を最終実行して exit 0 を確認。Verify ステージの verify-report.md で AC-1 / AC-2 / AC-6 の手動確認結果を記録
  - **files_touched**: `["tools/dashboard.sh", "tools/dashboard-pane.sh", "tests/test_dashboard.sh"]`

### 5.2 タスク間の依存関係と並列判定

```
T-1 (テスト先行) → T-2 (dashboard-pane 実装) → T-3 (dashboard 実装) → T-4 (docstring + AC 通し)
```

**並列判定**: 全タスクが逐次依存 (TDD Red → Green の段階的進行) かつ T-4 が全ファイルを触るため、**並列化可能なタスクは存在しません**。`files_touched` が重複しない T-2 / T-3 については理屈上は並列化可能ですが、T-1 の fail/pass 遷移を順に確認しながら進めるほうが TDD の意図に合うため Phase 3 では逐次実行します。

### 5.2.1 レビュー指摘対応タスク (iteration 1)

receiving-code-review skill が worktree 側 `reviews/consolidated.md` (verdict_integrated: reject) を受けて追加したタスクです。統合判定は security-reviewer の Critical 1 件による reject で、Implement → Verify → Code Review ループの 1 回目 (§4 循環防止: 上限 3 回) です。

- [ ] T-fix-1-1: Spec 名インジェクション対策 (見積: 40 分)
  - 対応指摘: CR-security-Critical-1, CR-security-Minor-1, CR-code-Minor-4
  - 修正内容: `tmux new-session` / `tmux split-window` に渡す引数を `printf %q` でエスケープ、加えて `collect_specs_auto` / `validate_explicit_specs` / `dashboard-pane.sh` 冒頭に Spec 名 allowlist `^[A-Za-z0-9._-]+$` を追加
  - 追加テスト: 細工された Spec 名 (`evil';id;#` 等) が allowlist で弾かれる回帰ケースを `tests/test_dashboard.sh` に追加
  - **files_touched**: `["tools/dashboard.sh", "tools/dashboard-pane.sh", "tests/test_dashboard.sh"]`

- [ ] T-fix-1-2: Major + Minor 群対応 (見積: 40 分)
  - 対応指摘: CR-code-Major-1〜3, CR-code-Minor-1/2/3/6/7/8, CR-security-Minor-3
  - 修正内容:
    - Major-1: `awk '/^## ログ/{flag=1; next} /^## /{flag=0} flag'` で `## ログ` 抽出後に tail
    - Major-2: バージョン判定を `[[ -z || ! =~ || < 2 ]]` 直列に変更
    - Major-3: progress.md パスを `REPO_ROOT` 基準に変更
    - Minor-1: tmux 不在判定を 1 経路に DRY 化
    - Minor-2: 9 Spec 超 warning を `launch_tmux` 冒頭に移動
    - Minor-3: ループ内 `select-layout tiled` 削除
    - Minor-6: `assert_case` docstring 修正
    - Minor-7: progress 未生成メッセージを stdout に
    - Minor-8: dashboard.sh に `ensure_jq` 追加
    - security-Minor-3: test_dashboard.sh に REPO_ROOT / TMP_EMPTY のシングルクォート assertion
  - 追加テスト: 既存テストケースで全通過を確認
  - **files_touched**: `["tools/dashboard.sh", "tools/dashboard-pane.sh", "tests/test_dashboard.sh"]`

対応見送り (consolidated.md §3 参照):

- CR-security-Minor-2 (ANSI エスケープ素通し): Spec §4 の「ユーザー責任」記述にもとづき MVP スコープ外
- CR-code-Minor-5 (attach 時メッセージ視認性): MVP 段階では window 名で状況把握可能

### 5.3 plan.meta.json

`specs/tmux-dashboard-mvp.plan.meta.json` を別途生成します (内容は本 Plan 保存時に合わせて作成)。

## 6. テスト戦略

### 6.1 ユニットテスト (ドライラン)

`tests/test_dashboard.sh` が以下を検証:

- **T-test-1**: `bash -n tools/dashboard.sh` と `bash -n tools/dashboard-pane.sh` の構文チェック
- **T-test-2**: `bash tools/dashboard.sh --help` が exit 0 かつ "Usage" を含む stdout を返す
- **T-test-3**: `bash tools/dashboard.sh --invalid` が exit 1 かつ stderr にエラーメッセージ
- **T-test-4**: `specs/*.progress.json` が 0 件の状態で `DASHBOARD_DRY_RUN=1 bash tools/dashboard.sh` が「対象 Spec がありません」と表示して exit 0
- **T-test-5**: `DASHBOARD_FAKE_NO_TMUX=1 bash tools/dashboard.sh dummy` が exit 1 + "tmux をインストール" メッセージ
- **T-test-6**: 存在しない Spec 名を渡した場合 (`bash tools/dashboard-pane.sh ghost-spec` を 2 秒 timeout) が stderr に warning を出力

### 6.2 統合テスト (手動 AC)

tmux 実起動が必要な AC-1 / AC-2 / AC-6 は `tests/test_dashboard.sh` から自動化せず、Verify ステージで手動実行し verify-report.md に結果を記録します。

### 6.3 E2E テスト

該当なし (CLI ツールのため)。

## 7. リスクと対応

### 7.1 tmux send-keys の競合 (Spec §7.1 の技術的具体化)

**内容**: `tmux send-keys` で各 pane に `bash tools/dashboard-pane.sh <spec>` を送る際、pane 生成直後に shell が ready になる前に送ると command が失われる可能性。

**対応**: `tmux send-keys` 後に `Enter` を別呼び出しで送信し、`tmux wait-for` は使わず 0.2 秒の `sleep` で pane 初期化を待つ単純実装とします (MVP のため堅牢性より簡潔性優先、iter-N で改善可)。

### 7.2 jq 失敗時の表示崩れ (Spec §7.3 の技術的具体化)

**内容**: spec-leader が atomic write していない環境 (rename でなく truncate + write) では dashboard-pane 側が不完全な JSON を読んで jq が fail。

**対応**: `dashboard-pane.sh` の jq 呼び出しを `jq ... || echo "更新中..."` でラップし、前回の有効表示を上書きせず次の 1 秒後に再試行する構造にします。

### 7.3 10 Spec 超時の可読性 (Spec §7.2 の技術的具体化)

**対応**: 本 MVP では警告のみ (9 Spec 超で stderr に「pane が細かくなりすぎる可能性、絞り込みを推奨」と出力)。複数 tmux session 起動は運用ドキュメント (Phase 6 バッチ 1 の README) に記述済み。

### 7.4 bash / jq / tmux 不在環境

**対応**: `dashboard.sh` 冒頭で `command -v tmux` / `command -v jq` / `bash --version` を順にチェックし、不足品目を stderr に明示して exit 1。
