---
spec: tmux-dashboard-mvp
review_iteration: 1
executed_at: 2026-04-20T00:25:00Z
verdict_integrated: reject
source_reviews:
  - reviews/code.md (verdict: needs-fix)
  - reviews/security.md (verdict: reject)
  - reviews/cross-model.md (verdict: PENDING placeholder)
---

# Consolidated Review: tmux-dashboard-mvp (iteration 1)

## 1. 統合 verdict

- code-reviewer: **needs-fix** (Critical 0 / Major 3 / Minor 8)
- security-reviewer: **reject** (Critical 1 / Major 0 / Minor 3)
- cross-model-reviewer: **PENDING** (Phase 3 は placeholder 運用、最終 verdict に不算入)

統合判定ルール §5 表: 「1 人以上 reject」→ **reject**

cross-model が PENDING のため、統合判定は code / security の 2 観点のみで算定します。修正完了後の再レビューで cross-model を再び PENDING とすることで、ship 時 verdict は `shipped-cross-model-pending` になる前提です (spec-leader §7.1)。

## 2. 指摘の集約 (優先度順)

### 2.1 Critical (対応必須)

| ID | 元レビュー | 該当 | 概要 | files_touched |
|---|---|---|---|---|
| CR-security-Critical-1 | security.md | `tools/dashboard.sh:125, 129` | Spec 名がシングルクォート付きで tmux コマンド文字列に埋め込まれ、細工された progress.json ファイル名経由で RCE 成立 | `tools/dashboard.sh`, `tools/dashboard-pane.sh`, `tests/test_dashboard.sh` |

### 2.2 Major (原則対応)

| ID | 元レビュー | 該当 | 概要 | files_touched |
|---|---|---|---|---|
| CR-code-Major-1 | code.md | `tools/dashboard-pane.sh:81-84` | progress.md の **`## ログ` セクション末尾 10 行** 要件に対し、ファイル全体の末尾 10 行を表示している | `tools/dashboard-pane.sh` |
| CR-code-Major-2 | code.md | `tools/dashboard.sh:64-72` | `ensure_tmux` のバージョン判定で非数値バージョン文字列が誤って許容される (`&&` / `\|\|` 優先度バグ) | `tools/dashboard.sh` |
| CR-code-Major-3 | code.md | `tools/dashboard-pane.sh:49` | progress.md のパスが `SPEC_DIR` 相対で組まれており `DASHBOARD_SPEC_DIR` 上書き時に整合しない | `tools/dashboard-pane.sh` |

### 2.3 Minor (対応有無を個別判断)

| ID | 元レビュー | 該当 | 概要 | 方針 |
|---|---|---|---|---|
| CR-security-Minor-1 | security.md | `tools/dashboard-pane.sh:47-49` | Spec 名経由の path traversal 可能性 | **対応** (Critical-1 の allowlist で同時対処) |
| CR-security-Minor-2 | security.md | `tools/dashboard-pane.sh:83` | ANSI エスケープ素通し | **対応見送り** (Spec §4 でユーザー責任明記、MVP スコープ外。consolidated に理由記録) |
| CR-security-Minor-3 | security.md | `tests/test_dashboard.sh:31` | `bash -c` の quote 耐性 | **対応** (REPO_ROOT/TMP_EMPTY のシングルクォート assertion を追加) |
| CR-code-Minor-1 | code.md | `tools/dashboard.sh:56-63` | tmux 不在判定の DRY 化 | **対応** (Critical-1 修正の巻き添えで統合) |
| CR-code-Minor-2 | code.md | `tools/dashboard.sh:128-137` | 9 Spec 超 warning が split 後 | **対応** (launch_tmux 冒頭に移動) |
| CR-code-Minor-3 | code.md | `tools/dashboard.sh:129-133` | `select-layout tiled` 重複呼び出し | **対応** (ループ内削除、最後の 1 回のみ) |
| CR-code-Minor-4 | code.md | `tools/dashboard.sh:125, 129` | Spec 名のシングルクォート耐性 | **対応** (Critical-1 と同一修正で解消) |
| CR-code-Minor-5 | code.md | `tools/dashboard.sh:120-123` | attach 時メッセージの視認性 | **対応見送り** (MVP スコープ外、運用で tmux session 名が分かれば十分。理由を記録) |
| CR-code-Minor-6 | code.md | `tests/test_dashboard.sh:21-22` | `assert_case` docstring の関数名ズレ | **対応** (1 行修正) |
| CR-code-Minor-7 | code.md | `tools/dashboard-pane.sh:54, 108-111` | `clear` と stderr の競合 | **対応** (progress 未生成メッセージを stdout に変更) |
| CR-code-Minor-8 | code.md | `tools/dashboard.sh:89-97` | `jq` 不在時 verdict 判定が崩れる | **対応** (dashboard.sh 起動時にも `ensure_jq` を追加) |

## 3. 対応見送り Minor の理由 (§8 アンチパターン回避の明記)

- **CR-security-Minor-2 (ANSI エスケープ)**: Spec §4 非機能要件で「progress.json / progress.md の内容はそのまま表示、機密情報はユーザー責任」と明示済。外部入力取り込み経路が本 Spec にないため、MVP 段階での sanitize 追加は YAGNI。docs 側 (Phase 6 バッチ 1 README 相当) に「progress.md に外部入力を書かないこと」の注意を後日追記する方針で代替
- **CR-code-Minor-5 (attach 時メッセージ視認性)**: MVP として tmux attach 後に window 名 `dashboard` で状況把握可能。sleep 挿入は対話体験を僅かに悪化させるため見送り。再レビューで体験上の問題が再指摘されれば対応

## 4. Plan §5 への T-fix 追加内容 (iteration 1)

T-fix-1-1 (Critical 解消) と T-fix-1-2 (残 Major + Minor 群) の 2 タスクで構成します。Critical を独立タスクに分けることで、security 観点の修正を明確に分離 + 回帰テスト追加を確実化します。

- T-fix-1-1 (見積: 40 分): CR-security-Critical-1 + CR-security-Minor-1 + CR-code-Minor-4 対応
  - 修正: `printf %q` による tmux 引数エスケープ + Spec 名 allowlist `^[A-Za-z0-9._-]+$` を `collect_specs_auto` / `validate_explicit_specs` / `dashboard-pane.sh` 冒頭に追加
  - 回帰テスト: `tests/test_dashboard.sh` に「細工 Spec 名は allowlist で弾かれる」ケースを追加
  - **files_touched**: `tools/dashboard.sh`, `tools/dashboard-pane.sh`, `tests/test_dashboard.sh`

- T-fix-1-2 (見積: 40 分): 残 Major + Minor 群対応
  - CR-code-Major-1: `awk` で `## ログ` セクション抽出後 tail
  - CR-code-Major-2: バージョン判定を `||` 直列に変更
  - CR-code-Major-3: progress.md パスを `REPO_ROOT` 基準に変更
  - CR-code-Minor-1: tmux 不在判定 DRY 化
  - CR-code-Minor-2: 9 Spec 超 warning を `launch_tmux` 冒頭に移動
  - CR-code-Minor-3: `select-layout tiled` ループ内呼び出し削除
  - CR-code-Minor-6: `assert_case` docstring 修正
  - CR-code-Minor-7: progress 未生成メッセージを stdout に
  - CR-code-Minor-8: dashboard.sh 冒頭に `ensure_jq`
  - CR-security-Minor-3: test_dashboard.sh に REPO_ROOT / TMP_EMPTY のシングルクォート assertion
  - **files_touched**: `tools/dashboard.sh`, `tools/dashboard-pane.sh`, `tests/test_dashboard.sh`

## 5. Plan frontmatter 更新 (§3.2.1 準拠)

Plan (`specs/tmux-dashboard-mvp.plan.md` / `plans/tmux-dashboard-mvp.md`) の frontmatter を以下に更新します:

```yaml
status: plan-revised      # plan-complete から変更
revised: 2026-04-20
review_iteration: 1
```

## 6. Plan §2 アーキテクチャ追従 (§3.2.2 準拠)

本 iteration の T-fix は既存ファイルの内部修正のみで、新規ファイル / 削除 / モジュール分割再編を伴いません。Plan §2 の「`tools/dashboard.sh` + `tools/dashboard-pane.sh` + `tests/test_dashboard.sh`」という配置は変更不要のため、§2 更新はスキップします (判定表の「同一ファイル内の修正」に該当)。

## 7. 次ステップ

1. Plan に T-fix-1-1 / T-fix-1-2 を追加 + frontmatter 更新 (main 側と worktree 側の両 plan.md)
2. Implement: T-fix-1-1 (TDD: 悪意ある Spec 名が allowlist で弾かれる回帰テスト → 修正) → T-fix-1-2
3. Verify: `tests/test_dashboard.sh` 全通過 + verify-report.md 更新
4. Code Review 再実行 (code / security / cross-model) → pass 取得を目指す
5. 循環回数: 1 / 3 (§4 で 3 回を上限、3 回超過時はユーザー相談)
