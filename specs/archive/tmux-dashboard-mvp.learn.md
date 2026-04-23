---
spec: tmux-dashboard-mvp
learned: 2026-04-20
shipped_at: 2026-04-20T00:55:00Z
total_duration_minutes: 55
verdict: shipped-cross-model-pending
---

# Learn: tmux-dashboard-mvp

## 1. サマリ

Phase 6 バッチ 2 (a) ドッグフーディング第 1 題材として、spec-leader の全 9 ステージ (Brainstorming / DAG / Spec / Spec Review / Plan / Isolate / Implement / Verify / Code Review / ship) を実際に通し、bash のみで完結する tmux + TUI ダッシュボード MVP を shipped-cross-model-pending で ship しました。iteration 1 で security-reviewer が Critical 1 件 (シェルインジェクション) を検出し、receiving-code-review → Implement 再 → Verify 再 → Code Review 再の 1 ループで pass 取得。Phase 3-5 skill 群の実運用に耐える品質が単一 Spec での完走として確認できた一方、Plan の時間計測、pane 幅に起因する UX 課題、worktree 側作業ファイルの main 混入処理など、次サイクルで改善すべき事項も浮き彫りになりました。

## 2. 時間配分

| ステージ | 所要時間 | 備考 |
|---|---|---|
| Brainstorming | N/A (未計測) | 前セッションで題材選定込、本セッション開始前に完了済のため progress に未記録 |
| Spec | N/A (未計測) | 同上、前セッションで writing-spec 完了 |
| Spec Review | N/A (未計測) | 前セッションで verdict: pass、本セッションで参照のみ |
| Plan | **N/A (未計測)** | `plan_started_at` と `plan_completed_at` を同一値 (2026-04-20T00:00:00Z) で記録しており実測 0 分。本来は writing-plan 実行時にタイムスタンプを分ける必要あり (writing-plan §5.3 meta 生成機能の改善要望) |
| Isolate | 5 分 | 00:00:00Z → 00:05:00Z。worktree 作成 + Spec/Plan/Review cp + progress.md 生成。問題なし |
| Implement | 25 分 | 00:05:00Z → 00:30:00Z。T-1 Red → T-2 pane → T-3 dashboard → T-4 docstring → T-fix-1-1 (Critical) → T-fix-1-2 (Major+Minor)。loop 1 回 (Code Review 差戻しで +15 分) |
| Verify | 25 分 (iter 1+2 合算) | iter-1: 00:10:00Z-00:15:00Z (5 分)、iter-2: 00:30:00Z-00:35:00Z (5 分)。合算で実作業 10 分、残り 15 分は Code Review と receiving-code-review の間の時間 |
| Code Review | 30 分 | iter-1: 00:15:00Z-00:25:00Z (10 分)、iter-2: 00:35:00Z-00:45:00Z (10 分)、receiving-code-review + consolidated 作成: 10 分 |
| ship | 10 分 | 00:45:00Z-00:55:00Z。main merge + 再テスト + archive 移動 + worktree 削除 |

合計 (計測可能分): 65 分 (本 skill 記録の 55 分は verify/code_review の重複時間を差し引いた数値)

## 3. うまくいったこと (Keep)

- **TDD 厳守の Red → Green 流れ**: T-1 で先行作成した `tests/test_dashboard.sh` が実装前 7 ケース全 fail → T-2/T-3 実装で 6/7 pass → ensure_tmux 順序修正で 7/7 pass という明確な段階遷移を取れ、AC-1〜AC-8 のうち 5 件 (AC-3/4/5/7/8) を自動テストで担保できた
- **security-reviewer の Critical 発見力**: iteration 1 で tmux new-session の文字列連結経由の Spec 名インジェクションを検出。修正方針 (`printf %q` + 3 経路 allowlist + 回帰テスト) まで具体的に提示してくれたことで、receiving-code-review → Implement 再の 1 ループだけで解消できた
- **receiving-code-review の consolidated.md 設計**: code verdict=needs-fix + security verdict=reject の統合判定を §5 ルール通り reject に確定し、T-fix-1-1/1-2 分解 + 対応見送り Minor 2 件の理由明記まで 1 ファイルに集約できた。iteration トレーサビリティが高い
- **Plan §5.1 files_touched の事前明記**: 3 タスクすべてに files_touched が書かれていたため、T-fix 追加時にも `tools/dashboard.sh` / `tools/dashboard-pane.sh` / `tests/test_dashboard.sh` の 3 ファイルへ修正が集中することを事前判断できた。並列化は Phase 3 逐次のためスキップしたが、契約としては機能した
- **実機 tmux デモでの AC 検証**: tmux 3.6a + `-L demo` socket で 3 pane tiled layout + 1 秒 poll 更新を ship 前に確認。DRY_RUN/ONESHOT だけでは見切れない実動作を ship 判断前に通せた

## 4. 改善したいこと (Problem)

### 4.1 Plan の時間計測が機能しなかった

- **原因**: writing-plan 実行時に `plan_started_at` / `plan_completed_at` を真の実時刻で記録せず、同じ値を入れた
- **影響**: learn §2 時間配分テーブルの Plan 行が N/A となり、次サイクルで「Plan に時間がかかる Spec」を識別できない
- **根本**: writing-plan SKILL.md §5.3 は meta 生成の必要性を明記しているが、時刻をどう取得するかの手順が曖昧 (手動で書くため、Claude 実装時に 0 分扱いが起こりやすい)

### 4.2 pane 幅が狭いと stages テーブルが見切れる

- **原因**: tmux tiled layout で N 個 pane に分割すると、Spec 数が増えるほど pane が狭くなり、`dashboard-pane.sh` の `stage / status / started_at / completed_at` の 4 列テーブルが横スクロール or 改行される
- **影響**: ユーザーが「verify で止まっている」と誤認した原因の一部 (狭い pane でログ末尾 10 行だけが見え、stages テーブルが見切れて code_review: in_progress が分からなかった)
- **根本**: 可変幅を考慮したレイアウトアルゴリズム (pane 幅が 40 カラム未満なら 2 列の縦レイアウトに切り替え等) が未実装

### 4.3 main 側 progress.json の更新漏れ

- **原因**: worktree 側 progress.md を更新したが、main 側 `specs/tmux-dashboard-mvp.progress.json` を iteration 2 完了時に更新し忘れた (ユーザーが pane を見て気付いた)
- **影響**: ship 直前までステータス表示が iteration 1 時点のままになり、ユーザーの状況把握を阻害
- **根本**: spec-leader §5.2 の更新タイミング規約は「ステージ完了時に progress ファイルを更新」としているが、iteration (receiving-code-review による再 Implement → 再 Verify → 再 Code Review ループ) 中の更新タイミングが明示されていない

### 4.4 worktree 側作業ファイルが main に混入する

- **原因**: Implement / Verify / Code Review ステージで worktree 側に作った `plans/` / `progress.md` / `reviews/` / `verify-report.md` を spec branch に commit → main merge で main にも入った
- **影響**: ship ステージで明示的に `git rm` を追加する手間が発生 (spec-leader §13.2 6 項目には archive 移動の記載はあるが、worktree 専用ファイルの main 側掃除は未規約)
- **根本**: spec-leader が worktree 側に作らせる作業ファイルの「main 混入を許容するか否か」が skill 側で未定義。`.gitignore` / worktree 側でのみ commit しない / merge 時に skip する、のいずれかの規約が必要

### 4.5 Agent Teams 並列が活用できなかった

- **原因**: 本 Spec は単一 Spec、かつタスク間で `tests/test_dashboard.sh` が共通 files_touched になっていたため、Phase 3 逐次実行で十分だった
- **影響**: Agent Teams の実効検証ができず、Phase 6 の他ドッグフーディング題材に持ち越し
- **根本**: Spec 設計時点で「並列化可能なタスク分解」を意識していなかった (bash 3 ファイル / 1 テストスイートの構造では並列化しづらい)

## 5. 改善提案 (Try)

### 5.1 writing-plan skill に plan.meta.json の自動時刻記録手順を追加

- **対象ファイル**: `skills/writing-plan/SKILL.md`
- **変更内容**: §5.3 plan.meta.json の項に「`plan_started_at` は skill 起動直後に `date -u +%Y-%m-%dT%H:%M:%SZ` で取得、`plan_completed_at` は Plan ファイル保存直前に同コマンドで再取得してメタへ記録すること」を明記。また Claude 実装時の失敗回避のため「両タイムスタンプを同値で書かないこと」のアンチパターンを §10 に追加
- **期待効果**: Problem 4.1 の解消。learn skill §2 時間配分テーブルの Plan 行が実測値になり、複数サイクル後に Plan 長引き Spec を統計的に検出可能に

### 5.2 dashboard-pane.sh に pane 幅適応レイアウトを追加

- **対象ファイル**: `specs/archive/tmux-dashboard-mvp.md` (archive) + 次サイクルで新規 Spec `tmux-dashboard-v2-responsive`
- **変更内容**: pane 幅が `$COLUMNS < 50` 時に stages テーブルを 2 列縦 (`stage:status`) に切り替える分岐を追加。または `awk` で幅に応じて列を削る
- **期待効果**: Problem 4.2 の解消。pane 9 個でも stages が読める。Phase 6 の次ドッグフーディング題材候補として浮上

### 5.3 spec-leader に iteration 中の progress 更新規約を追加

- **対象ファイル**: `skills/spec-leader/SKILL.md`
- **変更内容**: §5.2 進捗ファイル更新タイミング表に「receiving-code-review → Implement 再 → Verify 再 → Code Review 再 の iteration ループ時、各再ステージ開始 / 完了時にも main 側 progress.json を更新する」を追加。合わせて §5.2.1 更新契約の強化 5 項目目として「iteration 番号を frontmatter に記録し、各 iteration の started_at / completed_at を stages.<name>.outputs.iteration_N に追記」を追加
- **期待効果**: Problem 4.3 の解消。ship 直前の状況把握が常に最新化される。Phase 5 orchestrator が iteration 進行を外部から判定可能に

### 5.4 spec-leader §13.2 に worktree 作業ファイルの main 掃除規約を追加

- **対象ファイル**: `skills/spec-leader/SKILL.md`
- **変更内容**: §13.2 ship 処理手順の「6. archive 移動」に以下を追加:
  - worktree 側固有ファイル (`plans/<spec>.md` / `progress.md` / `reviews/*` / `verify-report.md`) は **merge 時に main に入るため、ship commit で明示的に削除** する
  - consolidated.md は `specs/archive/<spec>.consolidated.md` に rename、他の worktree 固有ファイルは `git rm -r`
  - 併せて §18 アンチパターンに「worktree 側作業ファイルを main に残したまま ship する」を追加
- **期待効果**: Problem 4.4 の解消。ship 時の手作業削減 + main が常にプロダクトコード + archive のみで保たれる

### 5.5 learn skill に「iteration ループ統計」観点を追加

- **対象ファイル**: `skills/learn/SKILL.md`
- **変更内容**: §3 振り返り観点に §3.5 として「iteration ループ統計」を新設:
  - receiving-code-review 起動回数
  - 各 iteration の Critical / Major / Minor 件数推移
  - iteration 内で解消された指摘 vs 見送り指摘の比率
- **期待効果**: 複数 Spec で蓄積すると「security Critical が繰り返し出る箇所」「Major が収斂しない設計領域」を識別可能に。Phase 6 の skill 品質改善ループの基礎データ

### 5.6 tmux-dashboard-mvp の運用文書を Phase 6 バッチ 1 の docs/ に追加 (非 skill 系 Try)

- **対象ファイル**: `docs/tmux-dashboard-operation.md` (新規)
- **変更内容**: dashboard.sh の起動方法 / 環境変数 / Spec 名制約 (allowlist `^[A-Za-z0-9._-]+$`) / 9 pane 超時の対処 (複数 tmux session 分割 / 絞り込み) / progress.md に外部入力を書かない注意 (security Minor-2 見送り判断の補完)
- **期待効果**: 他プロジェクトで dashboard.sh を転用する際のガイドとなり、ドッグフーディング成果物を skill 以外の形で再利用可能に

## 6. 共有資産 / 再発見したパターン

### 6.1 printf %q + allowlist の 2 層防御

tmux コマンド文字列のような「shell 解釈を迂回できない経路」に対する injection 防御は、以下の 2 層が鉄則:

1. allowlist で入力段を絞り込み (今回は `^[A-Za-z0-9._-]+$`)
2. 残余リスクに対して `printf %q` で shell エスケープ

今後 shell を多用する skill / tool を作る際は両方入れる。allowlist 単独 / `printf %q` 単独はいずれも単層で bypass 余地あり。

### 6.2 `DASHBOARD_FAKE_NO_TMUX` / `DASHBOARD_DRY_RUN` / `DASHBOARD_PANE_ONESHOT` の 3 フラグ直交設計

外部依存 (tmux) を **環境変数で差し替え可能な形** に分離することで、tests/test_dashboard.sh から tmux 実起動なしでエラーパスを検証できた。他 CLI skill / tool でも同様に「fake / dry_run / oneshot」3 種類の test フラグを用意すると TDD が回しやすい。

### 6.3 1 秒 poll ループ + atomic write 前提のフォールバック

`jq 失敗時に「更新中...」を出して次 poll で再試行` の設計は、spec-leader の atomic write が不完全な環境でも UI が崩れない。他のリアルタイム表示 tool (Phase 6 以降の web UI 等) でも流用可能。

## 7. 次サイクルへの引き継ぎ事項

- **次ドッグフーディング候補 1**: `tmux-dashboard-v2-responsive` (Problem 4.2 解消、pane 幅適応)
- **次ドッグフーディング候補 2**: 複数 Spec 並列実行検証 (Agent Teams 実効検証、Problem 4.5)
- **skill 改修キュー**: §5.1 / §5.3 / §5.4 / §5.5 の 4 件 (writing-plan / spec-leader / learn SKILL.md 改訂)
- **docs 追加キュー**: §5.6 (`docs/tmux-dashboard-operation.md` 新規作成)
- **cross-model-reviewer の実装**: Phase 3 placeholder のままで `verdict: shipped-cross-model-pending` が確定するため、Phase 6 以降で外部モデル連携実装時に本 Spec も再レビューを検討 (retroactive verdict 更新可能性)
- **未適用の security Minor**: allowlist が `..` / `.` のみのドット Spec 名を許容する点を `^[A-Za-z0-9][A-Za-z0-9._-]*$` に強化する変更を次サイクルで取り込む候補
