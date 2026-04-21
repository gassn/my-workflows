---
name: spec-leader
description: >
  承認済み Spec ファイルを起点に、Isolate → Plan → Implement → Verify → Code Review → ship
  の 6 ステージ遷移を制御する skill。本ワークフロー (docs/workflow.md) の
  Spec Review 以降を担当します。
  spec-review skill が verdict: pass を返した直後に自動起動します。
  加えて「Isolate 開始して」「spec-leader 起動」「<spec-name> の実装を始めて」
  等の明示フレーズでも起動します。
  Phase 3 では main agent 内で単独動作可能に実装し、Phase 5 で追加する
  orchestrator から呼ばれる前提のインタフェース (入力: spec.md パス、
  出力: progress / result ファイルパス) を確定済みのため、Phase 5 で本 skill の
  改修は不要です。
  ship ステージの実行はユーザー最終承認後に限定します。失敗時は全停止して
  ユーザーに相談します。
---

# Spec Leader Skill

承認済み Spec ファイルを入力として、Isolate → Plan → Implement → Verify → Code Review → ship の 6 ステージ遷移を制御する skill です。本プロジェクトのワークフロー (`docs/workflow.md`) における Spec Review 後〜ship までの一連のステージを担当します。

**用語**: 「Project Phase」「Workflow Stage (ステージ)」「Release Phase」「Spec」の定義は `docs/glossary.md` を参照してください。

## 1. 役割と位置づけ

ワークフロー上の位置:

```
... → writing-spec → spec-review → (pass) → [spec-leader (本 skill)] → Learn
                                                 │
                                                 ├─ Isolate (worktree 作成)
                                                 ├─ Plan (writing-plan)
                                                 ├─ Implement (developer + tdd-driver)
                                                 ├─ Verify (verifier + verification-before-completion)
                                                 ├─ Code Review (code-reviewer + security-reviewer + cross-model-reviewer)
                                                 └─ ship (ユーザー承認後、main merge + worktree 削除)
```

本 skill は **ステージ遷移制御** に専念します。各ステージ内部の具体的処理は下位 skill / agent に委譲します。本 skill の価値は下記 3 点です。

1. **単独動作可能**: orchestrator 不在の Phase 3 でも、ユーザーが手動起動すれば spec.md からの一連の流れを完走できる
2. **Phase 5 改修不要インタフェース**: 入力 = spec.md パス / 出力 = progress + result ファイルパス、の契約を固定。Phase 5 で orchestrator が本 skill を呼ぶ際、改修は不要
3. **進捗の可視化と再現性**: 各ステージの開始・完了・失敗を progress ファイルに機械可読形式で記録、中断・再開時の状態を一意に特定可能

## 2. 起動トリガー

### 2.1 自動起動 (第一トリガー)

`spec-review` skill が verdict `pass` を返した直後、**本 skill を自動起動** します。

- 入力: `specs/<spec-name>.md` (status: `spec-complete`)
- 前提: `specs/<spec-name>.review.md` の verdict が `pass`

spec-review §9.2 で「spec-leader 実装後に自動起動」とされていた TODO は、本 skill 実装によって解消されます。spec-review 側の改修は必要ありません (本 skill が存在すれば自動呼び出し)。

### 2.2 明示フレーズ起動 (第二トリガー)

以下の発話で起動してください。

- 「Isolate 開始して」「worktree 作って <spec-name> の実装始めて」
- 「spec-leader 起動」「<spec-name> のステージ遷移開始」
- 「<spec-name> 実装フェーズへ」

### 2.3 Phase 5 での起動経路

Phase 5 では orchestrator agent が本 skill を呼び出します。orchestrator は複数 Spec を並列処理する際、各 Spec について本 skill を起動します。本 skill 側は「誰に呼ばれたか」を意識する必要はありません (入力 spec.md パスが与えられれば同一の動作)。

## 3. 前提条件の確認

skill 起動直後、以下を必ず確認してください。

- 入力 Spec ファイル (`specs/<spec-name>.md`) の存在
- frontmatter `status: spec-complete`
- `specs/<spec-name>.review.md` の存在と verdict が `pass`
- プロジェクトルートが git リポジトリであること (`git rev-parse --is-inside-work-tree`)
- 対応する worktree (`worktrees/<spec-name>/`) が未作成であること (再開時は §14 参照)

前提条件を満たさない場合の対応:

| 状況 | 対応 |
|---|---|
| Spec ファイル未存在 | 「対象 Spec が見つかりません」と返して終了 |
| status が spec-complete でない | 現在の status を表示、writing-spec または spec-review への差戻しを提案 |
| review.md が存在しない | 「Spec Review が未実施です。spec-review を先に起動してください」と返して終了 |
| review.md の verdict が pass でない | 「verdict が `<verdict>` です。writing-spec レビュー指摘対応モードで修正してください」と返して終了 |
| git リポジトリでない | 「worktree は git リポジトリ内でのみ動作します」と返して終了 |
| worktree が既に存在 | 「再開モード」として §14 の手順を実行 |

## 4. インタフェース定義 (Phase 5 改修不要の契約)

Phase 3 時点で orchestrator 連携用インタフェースを固定します。Phase 5 で orchestrator を実装する際、本 skill の改修を不要とするための契約です。

### 4.1 入力

| 項目 | 型 | 説明 |
|---|---|---|
| `spec_path` | string (相対パス) | `specs/<spec-name>.md` |
| `options` (任意) | object | 実行オプション (`{"skip_ship": true}` 等) |

### 4.2 出力

| 項目 | 型 | 説明 |
|---|---|---|
| `progress_path` | string | `specs/<spec-name>.progress.json` |
| `progress_md_path` | string | `worktrees/<spec-name>/progress.md` (Isolate 完了後に生成) |
| `result_path` | string | `specs/<spec-name>.result.json` (終了時に生成、shipped / aborted / paused) |

### 4.3 状態遷移の原則

- 各ステージは `pending → in_progress → (completed | failed | blocked)` の 4 状態
- ステージ完了時に progress ファイルを更新 (原子的に書き込み、中断時は前回状態が残る)
- 失敗時は `failed` / 下位 skill 未実装時は `blocked` / 中断時は状態維持 (`in_progress`)

### 4.4 Phase 5 での呼び出し方法

orchestrator 側は本 skill を以下のように呼び出す想定です (本 skill は変更不要)。

```
spec-leader skill を起動 (入力: spec_path, options)
  → progress_path を監視 (poll or watch)
  → result_path の生成を待つ
  → 結果を集約して次 Spec へ進む
```

## 5. ステージ遷移の全体フロー

6 ステージを順次実行します。各ステージの成功で次ステージに進み、失敗時は全停止してユーザーに相談します。

```
[開始] → Isolate → Plan → Implement → Verify → Code Review → (ユーザー承認) → ship → [終了]
            │         │         │           │            │                          │
            └─────────┴─────────┴───────────┴────────────┴──────── 失敗時 ────────→ [停止 + ユーザー相談]
```

### 5.1 Phase 3 時点の自動遷移範囲

- Isolate → Plan → Implement → Verify → Code Review まで自動遷移
- **Code Review 完了 → ship はユーザー承認を必須** (Q5 確定)
- ship 完了後、Learn ステージは main agent + ユーザーの領域のため本 skill は起動せず、結果ファイルの生成と「Learn を実施してください」の提案に留める

### 5.2 進捗ファイルの更新タイミング

| タイミング | 更新内容 |
|---|---|
| skill 起動時 | progress.json / progress.md を初期化 (すべてのステージを `pending`) |
| ステージ開始時 | `current_stage` を当該ステージ、`stages.<stage>.status` を `in_progress` に |
| ステージ完了時 | `stages.<stage>.status` を `completed`、`outputs` を記録 |
| ステージ失敗時 | `stages.<stage>.status` を `failed`、`error` を記録、全停止 |
| 下位 skill 未実装時 | `stages.<stage>.status` を `blocked`、`missing_skill` を記録、全停止 |
| skill 終了時 | `result.json` を生成 |

## 6. 進捗ファイル仕様

### 6.1 progress.json (機械可読、main 側)

パス: `specs/<spec-name>.progress.json`

```json
{
  "spec": "<spec-name>",
  "spec_path": "specs/<spec-name>.md",
  "review_path": "specs/<spec-name>.review.md",
  "started_at": "2026-04-20T22:30:00Z",
  "updated_at": "2026-04-20T22:45:00Z",
  "current_stage": "plan",
  "stages": {
    "isolate": {
      "status": "completed",
      "started_at": "2026-04-20T22:30:00Z",
      "completed_at": "2026-04-20T22:30:15Z",
      "outputs": {"worktree": "worktrees/<spec-name>/", "branch": "spec/<spec-name>"}
    },
    "plan": {
      "status": "in_progress",
      "started_at": "2026-04-20T22:30:20Z",
      "completed_at": null,
      "outputs": null
    },
    "implement": {"status": "pending", "started_at": null, "completed_at": null, "outputs": null},
    "verify": {"status": "pending", "started_at": null, "completed_at": null, "outputs": null},
    "code_review": {"status": "pending", "started_at": null, "completed_at": null, "outputs": null},
    "ship": {"status": "pending", "started_at": null, "completed_at": null, "outputs": null}
  }
}
```

### 6.2 progress.md (人間可読、worktree 内)

パス: `worktrees/<spec-name>/progress.md` (Isolate 完了後に生成)

````markdown
---
spec: <spec-name>
started: 2026-04-20T22:30:00Z
updated: 2026-04-20T22:45:00Z
current_stage: plan
---

# Progress: <spec-name>

## Stages

- [x] **Isolate** (2026-04-20T22:30:00Z → 22:30:15Z)
  - worktree: `worktrees/<spec-name>/`
  - branch: `spec/<spec-name>`
- [ ] **Plan** (2026-04-20T22:30:20Z → 進行中)
  - writing-plan skill 呼び出し中
- [ ] **Implement**
- [ ] **Verify**
- [ ] **Code Review**
- [ ] **ship** (ユーザー承認後)

## ログ

2026-04-20T22:30:00Z [isolate] worktree 作成開始
2026-04-20T22:30:15Z [isolate] 完了 (branch: spec/<spec-name>)
2026-04-20T22:30:20Z [plan] writing-plan 起動
...
````

## 7. 結果ファイル仕様

パス: `specs/<spec-name>.result.json` (終了時に生成)

```json
{
  "spec": "<spec-name>",
  "verdict": "shipped | aborted | paused",
  "started_at": "2026-04-20T22:30:00Z",
  "ended_at": "2026-04-20T23:45:00Z",
  "final_commit": "abc123def...",
  "stages_completed": ["isolate", "plan", "implement", "verify", "code_review", "ship"],
  "stages_failed": [],
  "stages_blocked": [],
  "user_action_required": null,
  "notes": "全ステージ正常完了、main にマージ済"
}
```

- `verdict: shipped` = 正常完了
- `verdict: aborted` = 失敗で終了 (`stages_failed` に失敗ステージを記録)
- `verdict: paused` = 下位 skill 未実装で停止 (`stages_blocked` / `user_action_required` に指示)

## 8. Isolate ステージ

**目的**: Spec 単位で git worktree を作成し、main を汚さず実装を進める。

### 8.1 処理手順

1. `worktrees/` ディレクトリが存在しなければ作成
2. `git worktree add worktrees/<spec-name> -b spec/<spec-name>` 実行 (新規ブランチで worktree 作成)
3. `specs/<spec-name>.md` を worktree 内の `specs/<spec-name>.md` にコピー (Spec ファイルが worktree から参照可能)
4. `worktrees/<spec-name>/progress.md` を生成
5. progress.json の `stages.isolate` を `completed` に更新 (outputs に worktree / branch を記録)

### 8.2 品質ゲート

- worktree ディレクトリが存在すること
- `worktrees/<spec-name>/specs/<spec-name>.md` が読めること
- `git worktree list` に当該 worktree が表示されること

### 8.3 失敗時

- worktree 作成コマンドが失敗した場合、エラーメッセージを progress に記録して全停止
- 主な失敗原因: ブランチ名重複、ディスク容量不足、git config 問題

## 9. Plan ステージ

**目的**: Spec を技術設計に展開し、タスクに分解する (Plan ファイル生成)。

### 9.1 処理手順

1. `writing-plan` skill を起動 (入力: `worktrees/<spec-name>/specs/<spec-name>.md`)
2. writing-plan が `worktrees/<spec-name>/plans/<spec-name>.md` を生成
3. progress.json の `stages.plan` を `completed` に更新 (outputs に plan ファイルパスを記録)

### 9.2 品質ゲート

- Plan ファイルにタスク分解 (チェックボックス形式) が含まれること (writing-plan の責務)

### 9.3 下位 skill 未実装時の対応

`writing-plan` skill が未実装の場合 (Phase 3 初期段階):

- `stages.plan.status` を `blocked` に更新
- `stages.plan.missing_skill` に `"writing-plan"` を記録
- 全停止してユーザーに報告: 「writing-plan skill が未実装です。Phase 3 で実装予定。手動で `worktrees/<spec-name>/plans/<spec-name>.md` を作成し、完成したら spec-leader を再起動 (再開モード) してください」
- `result.json` の `verdict` を `paused` にして終了

## 10. Implement ステージ

**目的**: Plan ファイルのタスクを TDD で実装する。

### 10.1 処理手順

1. `tdd-driver` skill を起動 (テスト先行強制モード)
2. Plan ファイルのタスクリストを読み込み、各タスクについて `developer` agent を呼び出す
   - Phase 3 では順次実行 (並列化は Phase 5 で検討)
   - Agent Teams が安定したら developer agent を並列起動
3. 各タスク完了時に progress.md にログ追記
4. 全タスク完了で `stages.implement` を `completed` に更新

### 10.2 品質ゲート

- Plan ファイルの全タスク (チェックボックス) が完了済 ([x]) であること
- 新規コミットが worktree 内に作成されていること

### 10.3 下位 skill / agent 未実装時

- `tdd-driver` skill 未実装 → blocked
- `developer` agent 未実装 → blocked
- いずれの場合も progress に missing を記録して全停止

## 11. Verify ステージ

**目的**: 全テスト / lint / 型チェックを実行し、全項目 pass を確認する。

### 11.1 処理手順

1. `verification-before-completion` skill を起動
2. `verifier` agent を呼び出し、以下を並列実行:
   - 全テスト (`npm test` / `pytest` / `go test` 等)
   - lint (`eslint` / `ruff` / `golangci-lint` 等)
   - 型チェック (`tsc --noEmit` / `mypy` / `go vet` 等)
3. 検証レポートを progress.md に追記
4. 全項目 pass で `stages.verify` を `completed` に更新

### 11.2 品質ゲート

- 全検証項目が pass
- 失敗項目があれば Implement ステージに戻って修正 (Phase 3 では手動介入、Phase 5 で自動 rollback 検討)

### 11.3 下位 skill / agent 未実装時

- `verification-before-completion` / `verifier` いずれか未実装 → blocked

## 12. Code Review ステージ

**目的**: code / security / cross-model の独立レビューを並列実行する。

### 12.1 処理手順

1. 以下の 3 agent を並列起動:
   - `code-reviewer`: コード品質観点 (可読性 / 設計 / 単純性)
   - `security-reviewer`: セキュリティ観点 (OWASP Top 10 / 認証認可 / 入力検証)
   - `cross-model-reviewer`: 他モデル (Codex 等) による独立審査
2. 各 reviewer の結果を `worktrees/<spec-name>/reviews/code.md` / `security.md` / `cross-model.md` に保存
3. 全 reviewer の verdict を統合し、1 つでも reject があれば `stages.code_review` を `failed` に

### 12.2 差戻し時の対応

- `receiving-code-review` skill を起動し、レビュー指摘を spec-leader 配下の Implement ステージに戻して対応
- Implement → Verify → Code Review の再実行ループ (最大 3 回、超えたらユーザー相談)

### 12.3 下位 skill / agent 未実装時

- `code-reviewer` / `security-reviewer` / `cross-model-reviewer` / `receiving-code-review` / `cross-model-review` のいずれか未実装 → blocked

## 13. ship ステージ (ユーザー承認後)

**目的**: worktree を main にマージし、worktree を削除する。

### 13.1 ユーザー承認の取得

Code Review 完了後、以下をユーザーに提示して承認を求めます。

- Code Review 結果サマリ (全 reviewer pass)
- 変更差分のサマリ (`git diff spec/<spec-name> main` の概要)
- merge コマンド (通常は `git merge --no-ff spec/<spec-name>`)

承認を得てから ship を実行します。承認前に自動 merge してはいけません。

### 13.2 処理手順

1. main ブランチに切り替え (`git checkout main`)
2. spec/<spec-name> を merge (`git merge --no-ff spec/<spec-name>`)
3. merge 後 main で再度テスト実行 (品質ゲート)
4. worktree 削除 (`git worktree remove worktrees/<spec-name>`)
5. spec/<spec-name> ブランチ削除 (任意、ユーザー確認)
6. `specs/<spec-name>.md` を `specs/archive/<spec-name>.md` に移動 (frontmatter `status: archived` に更新)
7. progress.json の `stages.ship` を `completed`、最終的に `result.json` を生成

### 13.3 品質ゲート

- main での再テストが pass
- worktree が正常に削除されている
- spec.md が archive に移動されている

### 13.4 失敗時

- merge コンフリクト → 「コンフリクト解消後に spec-leader 再開モードで起動してください」と停止
- main 再テスト fail → 直前の merge を revert (`git revert HEAD`) して停止

## 14. 再開モード (中断からの復旧)

worktree が既に存在する状態で本 skill が起動された場合、**再開モード** として処理します。

### 14.1 判定

- `worktrees/<spec-name>/` が存在
- `specs/<spec-name>.progress.json` が存在

### 14.2 処理

1. progress.json を読み込み、最終状態を特定
2. `current_stage` の `status` を確認:
   - `in_progress` → 中断した可能性。ユーザーに確認後、当該ステージを再実行 or 完了扱いに
   - `failed` / `blocked` → 原因解消後にユーザー承認で当該ステージを再実行
   - `completed` → 次ステージから再開
3. 再開ステージから通常フローに合流

### 14.3 ユーザー確認の必須化

再開モードでは、どのステージから再開するかを**必ずユーザーに確認** してから処理を進めます。自動判断による意図しない再実行を防止します。

## 15. 失敗時の全停止 + ユーザー相談

どのステージでも失敗が発生した場合、**全停止 + ユーザー相談** に移行します (Q6 確定)。

### 15.1 全停止の手順

1. 失敗したステージの progress を `failed` に更新、`error` に原因を記録
2. 後続ステージは `pending` のまま (飛ばさない)
3. `result.json` を `verdict: aborted` で生成
4. ユーザーに以下を報告:
   - 失敗ステージ
   - 失敗原因
   - 再開手順 (「原因解消後、spec-leader を再起動すると再開モードで復旧します」)

### 15.2 自動リトライの方針

Phase 3 では自動リトライを行いません (Q6 = (a) 全停止)。下位 skill / agent が独自にリトライする場合は本 skill は関与しません。

## 16. 未実装下位 skill / agent の扱い (Phase 3 初期)

Phase 3 時点では下位 skill / agent の多くが未実装です。本 skill は以下のように扱います。

### 16.1 検出方法

各ステージ開始時、必要な skill が `~/.claude/skills/<skill-name>/SKILL.md` として存在するかを確認します。agent についても同様に `agents/` ディレクトリ or 設定を参照します。

### 16.2 未実装時の挙動 (Q3 確定: 呼び出し定義のみ)

- `stages.<stage>.status` を `blocked` に
- `stages.<stage>.missing_skill` / `missing_agent` に不足を列挙
- 全停止 + ユーザー報告
- `result.json` の `verdict` を `paused` に

### 16.3 実装状況の表 (2026-04-21 時点)

| ステージ | 必要 skill | 必要 agent | 実装状況 |
|---|---|---|---|
| Isolate | (本 skill で直接 git worktree 実行) | — | ○ |
| Plan | `writing-plan` ○ | `investigator` × 未実装 | skill 通過可、agent 未実装だが Plan は skill 単独で完了可能 |
| Implement | `tdd-driver` ○ | `developer` × 未実装 | **Implement で blocked** (developer agent 不在) |
| Verify | `verification-before-completion` ○ | `verifier` × 未実装 | (Implement で blocked のため未到達) |
| Code Review | `receiving-code-review` ○ / `cross-model-review` ○ | 3 reviewer agent × 未実装 | (未到達) |
| ship | (本 skill で直接 git merge 実行) | — | ○ |

Phase 3 の 11 skill が全て実装完了した現時点では、**Isolate → Plan 完了 → Implement で developer agent 未実装を検出して blocked** が標準的な流れとなります。Phase 3 の agent 実装 (developer / verifier / 3 reviewer) が進むと、順次下位ステージが通るようになり Code Review → ship まで完走可能になります。

## 17. Phase 5 改修不要性の保証

本 skill は Phase 5 で orchestrator が追加された際に改修不要であるよう、以下を担保しています。

| 観点 | 担保 |
|---|---|
| 呼び出し元の抽象化 | 本 skill は「誰に呼ばれたか」を意識しない (入力 spec_path のみに依存) |
| 状態の外部化 | 内部状態を持たず、すべての進捗を progress.json に記録 (orchestrator からも参照可能) |
| 結果の機械可読化 | result.json で終了状態を表現 (orchestrator が次 Spec へ進む判断に使用可能) |
| 並列呼び出し安全性 | worktree 単位で動作、他 Spec との状態共有なし (orchestrator が本 skill を並列起動しても衝突しない) |
| 下位 skill の入出力契約 | writing-plan は plan.md、verifier は検証レポート、等、下位との契約はファイルベース (変更不要) |

## 18. 失敗・アンチパターン

以下を行ってはいけません。

- ❌ Spec ファイルを読まずにステージ遷移を開始する
- ❌ spec-review の verdict が pass でない Spec を処理する
- ❌ worktree 作成を省略して main で直接実装する
- ❌ Code Review 完了後、ユーザー承認なしに ship を実行する
- ❌ 失敗時に progress を更新せず終了する (後の再開モードが破綻する)
- ❌ 下位 skill 未実装時に「代わりに本 skill で処理する」と判断する (責務逸脱、呼び出し定義に留める)
- ❌ progress.json / progress.md のどちらか一方だけ更新する (両方を一貫性をもって更新)
- ❌ main ブランチで本 skill を起動する (main 汚染防止、必ず worktree で作業)
- ❌ 再開モードでステージ状態をユーザー確認なしに変更する
- ❌ result.json 生成を飛ばしてして終了する (Phase 5 orchestrator が結果取得できなくなる)
