---
name: tmux-dashboard-mvp
status: archived
created: 2026-04-23
depends_on: []
parallel_group: 1
---

# Spec: tmux-dashboard-mvp

## 1. 目的

Phase 5 orchestrator skill が複数 Spec を逐次/並列実行する際、各 Spec の進捗 (progress.json / progress.md / result.json の内容) を **tmux の複数 pane で同時表示** する最小実装を提供します。Phase 5 ROADMAP で先送りされた「長時間タスクの可視化 (tmux + TUI ダッシュボード検討)」の MVP 版として、本プロジェクト自身のドッグフーディングで実装します。

## 2. スコープ

### 2.1 含むもの

- `tools/dashboard.sh`: メイン起動スクリプト (tmux session 作成 + 各 Spec の pane 配置 + 1 秒間隔 poll 表示)
- `tools/dashboard-pane.sh`: 各 pane 内部で実行される個別 Spec 表示ロジック (progress.json / result.json のフォーマット表示)
- `tests/test_dashboard.sh`: bash 構文 + 引数パース + tmux 起動なしのドライラン動作確認

### 2.2 含まないもの

- Web UI / ブラウザダッシュボード
- リアルタイム (ms 単位) 更新 (1 秒 poll で十分)
- Windows / macOS GUI (tmux 依存のため Linux / macOS iTerm2 想定)
- カスタマイズ設定 UI (引数のみで挙動切替)
- 進捗グラフ / ガントチャート描画 (テキスト整形のみ)

## 3. 機能要件

### 3.1 dashboard.sh の起動

**コマンド**: `bash tools/dashboard.sh [spec-name...]`

**入力**:

- **引数なし**: `specs/*.progress.json` を glob 走査し、result.json が未生成または verdict が in-progress 相当 (`shipped` / `aborted` 以外) の Spec を対象
- **引数あり (Spec 名を空白区切り)**: 指定 Spec のみを対象

**出力**:

- tmux セッション `my-workflows-dashboard` を新規作成 (既存時は attach)
- 各 Spec について 1 pane を割当、計 N pane の layout (tmux の `tiled` layout)
- 各 pane で `tools/dashboard-pane.sh <spec-name>` を実行

**エラーハンドリング**:

- tmux 未インストール: `command -v tmux` で検知し、「tmux をインストールしてください」と表示して exit 1
- 対象 Spec が 0 件: 「対象 Spec がありません。specs/*.progress.json を確認してください」と表示して exit 0
- 指定 Spec の progress.json が存在しない: warning (stderr) を出しつつその Spec はスキップ、他 Spec は継続

### 3.2 dashboard-pane.sh (各 pane の表示ロジック)

**コマンド**: `bash tools/dashboard-pane.sh <spec-name>`

**入力**: Spec 名

**出力 (1 秒間隔で更新)**:

- ヘッダ: Spec 名 + 現在時刻
- progress.json の frontmatter 相当情報 (spec / current_stage / updated_at)
- stages テーブル (isolate / implement / verify / code_review / ship の 5 行、各 status + started_at + completed_at)
- result.json が存在すれば末尾に verdict + stages_completed を表示
- progress.md の `## ログ` セクションの末尾 10 行を追加表示

**エラーハンドリング**:

- progress.json が存在しない: 「progress 未生成、spec-leader が起動されていない可能性」と表示
- jq 未インストール: 「jq が必要です」と表示

### 3.3 tests/test_dashboard.sh (ドライラン検証)

**コマンド**: `bash tests/test_dashboard.sh`

**検証項目**:

- bash 構文チェック (`bash -n tools/dashboard.sh`、`bash -n tools/dashboard-pane.sh`)
- 引数パース動作 (`--help` フラグ応答、無効引数のエラーメッセージ)
- tmux 未インストール想定のエラーハンドリング (環境変数 `DASHBOARD_FAKE_NO_TMUX=1` で tmux 呼び出しを fail させて error path 確認)
- progress.json 不在時の warning 出力 (fake spec 名で呼び出し、stderr 確認)

## 4. 非機能要件

| 項目 | 要件 |
|---|---|
| パフォーマンス | 1 秒 poll の CPU 使用率 < 1% (tmux pane ごと)、10 Spec 同時表示で 10% 未満 |
| 互換性 | Linux / macOS、bash 4+、tmux 2.6+ / 3+ |
| セキュリティ | progress.json / progress.md の内容をそのまま表示 (sanitize なし)、機密情報を埋めた spec.md 運用時はユーザー責任 |
| 保守性 | tools/ 配下に集約、全関数に docstring (bash コメント) 必須 |
| 拡張性 | 将来 Phase 6 以降で web UI / リアルタイム更新等に拡張余地あり (本 MVP はシンプルさ優先) |

## 5. 受け入れ基準 (AC-1 〜 AC-8)

- [ ] AC-1: `bash tools/dashboard.sh` (引数なし) で specs/*.progress.json を走査、in-progress 状態の Spec を対象に tmux セッションを起動できること
- [ ] AC-2: `bash tools/dashboard.sh login auth order` で 3 Spec を明示指定して起動できること
- [ ] AC-3: 対象 Spec が 0 件の場合に「対象 Spec がありません」と表示して exit 0
- [ ] AC-4: tmux 未インストールの場合に警告 + exit 1
- [ ] AC-5: 指定 Spec の progress.json がない場合に warning を stderr に出しつつ他 Spec は継続
- [ ] AC-6: 各 pane で progress.json の stages テーブル + result.json の verdict + progress.md のログ末尾 10 行が 1 秒間隔で更新される
- [ ] AC-7: `bash tests/test_dashboard.sh` が全検証項目 pass (bash 構文 / 引数パース / エラーパス / warning パス)
- [ ] AC-8: dashboard.sh / dashboard-pane.sh / test_dashboard.sh の全関数に docstring (bash コメント) がある

## 6. 非対象 (スコープ外)

- Web UI ダッシュボード (Phase 6 以降で検討、本 MVP はテキスト UI のみ)
- リアルタイム (sub-second) 更新 (1 秒 poll で十分な想定)
- カスタマイズ設定ファイル (`.dashboardrc` 等、本 MVP は引数のみ)
- セッション記録 / ログ永続化 (tmux 標準機能で代替可)
- Windows サポート (WSL 経由は間接対応)

## 7. リスクと緩和策

### 7.1 tmux バージョン差異による layout コマンドの挙動差

**内容**: `tmux select-layout tiled` が tmux 1.x で動作しない等のバージョン差。

**緩和策**: README で tmux 2.6+ / 3+ を必須要件として明示、バージョンチェックを dashboard.sh 冒頭で実施 (`tmux -V` で 1.x なら error + exit 1)。

### 7.2 10 Spec 同時表示時の可読性低下

**内容**: 画面分割が細かくなりすぎて各 pane の内容が読めない。

**緩和策**: 引数で Spec を絞り込める設計を維持、10 Spec 超の実運用では複数 tmux session を別ウィンドウで起動する運用を推奨 (docs 側でガイド)。

### 7.3 progress.json / result.json が atomic write されない場合の表示崩れ

**内容**: spec-leader が progress.json を書き換え中に dashboard-pane.sh が読み取ると、不完全な JSON で jq が fail。

**緩和策**: dashboard-pane.sh の jq パース失敗時は前回の有効な表示を維持 (再試行)、cat | jq の pipe で失敗時に "更新中..." を表示。spec-leader §5.2 の atomic write (tmp file + rename) 規約を前提とすれば発生頻度は低い。
