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
... → writing-spec → spec-review → (pass) → writing-plan (main 側) → [spec-leader (本 skill)] → Learn
                                                                        │
                                                                        ├─ Isolate (worktree 作成 + Spec/Plan コピー)
                                                                        ├─ Implement (developer + tdd-driver)
                                                                        ├─ Verify (verifier + verification-before-completion)
                                                                        ├─ Code Review (code-reviewer + security-reviewer + cross-model-reviewer)
                                                                        └─ ship (ユーザー承認後、main merge + worktree 削除 + Plan archive)
```

**Plan は spec-leader の前** (main 側で writing-plan が実行) です。Phase 5 並列化時に他 Spec の Plan (`specs/*.plan.md`) を参照可能にするための構造 (2026-04-22 改修)。

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

Phase 5 では orchestrator skill が本 skill を呼び出します。orchestrator は複数 Spec を並列処理する際、各 Spec について本 skill を起動します。本 skill 側は「誰に呼ばれたか」を意識する必要はありません (入力 spec.md パスが与えられれば同一の動作)。

## 3. 前提条件の確認

skill 起動直後、以下を必ず確認してください。

- 入力 Spec ファイル (`specs/<spec-name>.md`) の存在
- frontmatter `status: spec-complete`
- `specs/<spec-name>.review.md` の存在と verdict が `pass`
- **`specs/<spec-name>.plan.md` の存在と frontmatter `status: plan-complete` or `plan-revised`** (2026-04-22 改修: Plan が本 skill の前提条件に昇格)
- プロジェクトルートが git リポジトリであること (`git rev-parse --is-inside-work-tree`)
- 対応する worktree (`worktrees/<spec-name>/`) が未作成であること (再開時は §14 参照)

前提条件を満たさない場合の対応:

| 状況 | 対応 |
|---|---|
| Spec ファイル未存在 | 「対象 Spec が見つかりません」と返して終了 |
| status が spec-complete でない | 現在の status を表示、writing-spec または spec-review への差戻しを提案 |
| review.md が存在しない | 「Spec Review が未実施です。spec-review を先に起動してください」と返して終了 |
| review.md の verdict が pass でない | 「verdict が `<verdict>` です。writing-spec レビュー指摘対応モードで修正してください」と返して終了 |
| **Plan ファイル未存在** | 「Plan が未作成です。先に writing-plan skill で `specs/<spec-name>.plan.md` を生成してください」と返して終了 (`verdict: precondition-failed`、precondition_violation: `plan_missing`) |
| **Plan status が plan-complete / plan-revised でない** | 現在の status (plan-writing / plan-draft 等) を表示、writing-plan の継続を促す |
| git リポジトリでない | 「worktree は git リポジトリ内でのみ動作します」と返して終了 |
| worktree が既に存在 | 「再開モード」として §14 の手順を実行 |

### 3.1 前提条件違反時の result.json 生成 (2026-04-22 iter-1 改修)

上記のいずれかで早期停止する場合、**Phase 5 orchestrator が「なぜ処理されなかったか」を機械可読で取得できるよう**、停止時点で `specs/<spec-name>.result.json` を以下で生成してください。

```json
{
  "spec": "<spec-name>",
  "verdict": "precondition-failed",
  "started_at": "<skill 起動時刻>",
  "ended_at": "<停止時刻>",
  "final_commit": null,
  "stages_completed": [],
  "stages_failed": [],
  "stages_blocked": [],
  "user_action_required": "<解消手順、上の対応列と同等の文言>",
  "precondition_violation": "<違反した前提条件の識別子、例: 'review_verdict_not_pass'>",
  "notes": "前提条件違反で処理未開始"
}
```

- progress.json は**生成しない** (処理が始まっていない = 進捗がないため)
- worktree / progress.md も生成しない
- result.json は再開モード / 次回起動判定のシグナルとしても利用される

これにより、orchestrator は `result.json` のみで「この Spec は次サイクルで何をすれば開始可能になるか」を判定できます。

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

本 skill は 5 ステージ (Isolate / Implement / Verify / Code Review / ship) を制御します。**Plan ステージは本 skill の前に main agent + writing-plan skill で実行済** の前提 (2026-04-22 改修、Phase 5 並列化準備)。

```
[Plan 完了済] → [本 skill 起動] → Isolate → Implement → Verify → Code Review → (ユーザー承認) → ship → [終了]
                                     │         │           │            │                          │
                                     └─────────┴───────────┴────────────┴──────── 失敗時 ────────→ [停止 + ユーザー相談]
```

### 5.1 Phase 3 時点の自動遷移範囲

- Isolate → Implement → Verify → Code Review まで自動遷移
- **Code Review 完了 → ship はユーザー承認を必須** (Q5 確定)
- ship 完了後、Learn ステージは main agent + ユーザーの領域のため本 skill は起動せず、結果ファイルの生成と「Learn を実施してください」の提案に留める

### 5.1.1 複数 Spec の DAG 順起動 (2026-04-22 改修)

`specs/dag.md` は単一 / 複数 Spec にかかわらず常に存在 (spec-dag-builder が 1 ノード DAG も生成) します。本 skill は writing-plan skill から 1 Spec 単位で起動される想定で、**本 skill 自体は 1 Spec を処理** します。

複数 Spec を扱う場合の起動制御は以下:

- **Phase 3**: writing-plan が DAG の parallel_group 順に 1 Spec ずつ Plan 生成 → 各 Plan 完了後に spec-leader を順次起動 (writing-plan SKILL.md §8.2 準拠)。本 skill は単純に呼ばれた Spec を処理するだけで、DAG を意識する必要はない
- **Phase 5**: orchestrator skill が DAG の parallel_group 内で複数 spec-leader を並列起動。本 skill のインタフェース (入力: spec_path / 出力: progress.json + result.json) は変更不要で、orchestrator が他 Spec の result.json を監視して依存解決

本 skill の責務はあくまで 1 Spec の Isolate〜ship 遷移制御です。DAG 解析や複数 Spec 協調は writing-plan / orchestrator の責務となります。

### 5.2 進捗ファイルの更新タイミング

| タイミング | 更新内容 |
|---|---|
| skill 起動時 | progress.json / progress.md を初期化 (すべてのステージを `pending`)、`updated_at` を設定 |
| ステージ開始時 | **前ステージの status が `completed` / `failed` / `blocked` のいずれかで確定している** ことを検証した上で、`current_stage` を当該ステージ、`stages.<stage>.status` を `in_progress` に、`started_at` を記録、`updated_at` を更新 |
| ステージ完了時 | `stages.<stage>.status` を `completed`、`completed_at` と `outputs` を記録、`updated_at` を更新 |
| ステージ失敗時 | `stages.<stage>.status` を `failed`、`error` を記録、`updated_at` を更新、全停止 |
| 下位 skill 未実装時 | `stages.<stage>.status` を `blocked`、`missing_skill` を記録、`updated_at` を更新、全停止 |
| skill 終了時 | `result.json` を生成 (§7 整合性チェックを通過後のみ) |

#### 5.2.1 更新契約の強化 (2026-04-22 iter-3 改修)

iter-3 統合テストで progress.json の `plan.status: in_progress` が未更新のまま result.json が `verdict: shipped` となる不整合が発生しました。再発防止のため以下を必須化:

1. **atomic write**: progress.json の書き換えは `<path>.tmp` に全文書き込み → `rename` で置換。部分書き込み状態を中断で生じさせない
2. **ステージ遷移時の二段検証**: 次ステージ開始前に「前ステージの `status` が pending のままでないこと」「前ステージの `started_at` が記録済であれば `completed_at` または `failed_at` / エラー記録が揃っていること」を検証。検証失敗時は progress の破損として停止 + ユーザー相談
3. **updated_at の厳守**: いかなる更新でも `updated_at` の更新を忘れない。古い `updated_at` のまま次操作を行うと stalled とみなされる
4. **ステージ飛ばし禁止**: `pending` → `in_progress` を経由せず直接 `completed` にしない。また blocked / failed のステージがあるまま後続を開始しない

## 6. 進捗ファイル仕様

### 6.1 progress.json (機械可読、main 側)

パス: `specs/<spec-name>.progress.json`

```json
{
  "spec": "<spec-name>",
  "spec_path": "specs/<spec-name>.md",
  "review_path": "specs/<spec-name>.review.md",
  "plan_path": "specs/<spec-name>.plan.md",
  "started_at": "2026-04-20T22:30:00Z",
  "updated_at": "2026-04-20T22:45:00Z",
  "current_stage": "isolate",
  "stages": {
    "isolate": {
      "status": "in_progress",
      "started_at": "2026-04-20T22:30:00Z",
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

Plan は main 側で事前に完了している前提のため、`stages` には含めません。`plan_path` を frontmatter 相当のメタとして記録し、Isolate ステージで worktree にコピーします。

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
  - Spec / Plan / Review を worktree 内にコピー済
- [ ] **Implement** (進行中)
- [ ] **Verify**
- [ ] **Code Review**
- [ ] **ship** (ユーザー承認後)

(※ Plan ステージは本 skill の前に main 側で完了済、stages に含めない)

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
  "verdict": "shipped | shipped-manual | aborted | aborted-on-resume | paused | precondition-failed",
  "started_at": "2026-04-20T22:30:00Z",
  "ended_at": "2026-04-20T23:45:00Z",
  "final_commit": "abc123def...",
  "stages_completed": ["isolate", "plan", "implement", "verify", "code_review", "ship"],
  "stages_failed": [],
  "stages_blocked": [],
  "user_action_required": null,
  "integrity_warnings": [],
  "notes": "全ステージ正常完了、main にマージ済"
}
```

### 7.1 verdict 種別

| verdict | 意味 | 条件 |
|---|---|---|
| `shipped` | 正常完了 (全ステージ機械的に整合) | ship ステージ成功 + 整合性チェック pass + cross-model-reviewer 実施済 (verdict: pass) |
| `shipped-manual` | 正常完了だが手動介入あり (2026-04-22 新設、iter-3 知見) | ship ステージ成功 + 整合性チェックで警告あり、`integrity_warnings` に記録 |
| `shipped-cross-model-pending` | 正常完了だが cross-model-reviewer が PENDING のまま (2026-04-22 新設、iter-4 知見) | ship ステージ成功 + code / security reviewer は pass + cross-model は PENDING placeholder (Phase 3 手動依頼運用)。将来外部モデル呼び出し実装後は区別可能に |
| `aborted` | 失敗で終了 | どこかのステージで `failed`、`stages_failed` に記録 |
| `aborted-on-resume` | 再開モードで中止選択 (2026-04-22 新設、iter-2 知見) | §14 再開モードで「中止」ユーザー選択 |
| `paused` | 下位 skill 未実装で停止 | ステージが `blocked`、`stages_blocked` / `user_action_required` に指示 |
| `precondition-failed` | 前提条件違反で停止 (2026-04-22 新設、iter-1 知見) | §3 前提条件チェックで NG、`user_action_required` に修正手順 |

### 7.2 integrity_warnings (2026-04-22 iter-3 改修)

result.json 生成時に progress.json との整合性チェックを行い、不一致があれば `integrity_warnings` 配列に記録します。verdict は手動介入を含む派生値 (`shipped-manual`) に切り替え、隠蔽を防ぎます。

#### 整合性チェック項目

- `stages_completed` の各要素について、progress.json `stages.<name>.status == "completed"` であること
- `stages_failed` / `stages_blocked` の各要素について、progress.json と status が一致すること
- `started_at` / `ended_at` のタイムスタンプが progress.json の最古 `started_at` / 最新 `updated_at` と整合すること
- progress.json に `in_progress` のまま残っているステージがないこと (handoff 漏れの検出)

#### 警告の記録形式

```json
"integrity_warnings": [
  {
    "kind": "stage_status_mismatch",
    "stage": "plan",
    "progress_status": "in_progress",
    "result_declared": "completed",
    "note": "手動介入で completed 扱いに補完された可能性"
  }
]
```

#### 影響

- 警告がある場合、verdict が `shipped` → `shipped-manual` に自動切替
- learn skill が `integrity_warnings` を受けて Try 提案として具体化 (spec-leader の progress 更新漏れとして)
- orchestrator (Phase 5) は `shipped-manual` を手動介入の必要があった Spec として分類、類似ケースの再発時に早期警告

## 8. Isolate ステージ

**目的**: Plan が確定した Spec について git worktree を作成し、main 側の Spec / Plan / Review ファイルを worktree 内にコピーして実装の作業環境を整える (2026-04-22 改修)。

### 8.1 処理手順

1. `worktrees/` ディレクトリが存在しなければ作成
2. `git worktree add worktrees/<spec-name> -b spec/<spec-name>` 実行 (新規ブランチで worktree 作成)
3. main 側の 3 ファイルを worktree 内にコピー (**`cp` のみ使用、`mv` は厳禁**、2026-04-22 iter-5 改修):
   - `specs/<spec-name>.md` → `cp` で `worktrees/<spec-name>/specs/<spec-name>.md` へ
   - `specs/<spec-name>.plan.md` → `cp` で `worktrees/<spec-name>/plans/<spec-name>.md` へ (**worktree 側では従来通り `plans/` サブディレクトリ命名**)
   - `specs/<spec-name>.review.md` → `cp` で `worktrees/<spec-name>/specs/<spec-name>.review.md` へ (参考情報)
   - **`git mv` や shell の `mv` は使わない**: worktree は master と同一 git 空間のため、rename 操作が commit に乗ると master 側ファイルが merge で消失する (iter-5 で実測された事故)
4. `worktrees/<spec-name>/progress.md` を生成
5. progress.json の `stages.isolate` を `completed` に更新 (outputs に worktree / branch / 各コピー先パスを記録)

### 8.2 品質ゲート

- worktree ディレクトリが存在すること
- `worktrees/<spec-name>/specs/<spec-name>.md` が読めること
- **`worktrees/<spec-name>/plans/<spec-name>.md` が読めること** (Implement ステージで developer agent が参照する)
- `git worktree list` に当該 worktree が表示されること

### 8.3 失敗時

- worktree 作成コマンドが失敗した場合、エラーメッセージを progress に記録して全停止
- 主な失敗原因: ブランチ名重複、ディスク容量不足、git config 問題
- Plan ファイルコピー失敗時も同様に failed として停止 (Plan は Implement の前提のため skip 不可)

### 8.4 main 側 Plan の扱い

Isolate はコピーのみで main 側の `specs/<spec-name>.plan.md` は**削除しません**。Phase 5 の並列 spec-leader が他 Spec の Plan を参照できるよう、ship ステージまで main 側に保持します。

## 10. Implement ステージ

**目的**: Plan ファイルのタスクを TDD で実装する。並列実行時は git index 競合を**物理的に排除する sub-worktree 方式**を採用する (2026-04-22 iter-3 改修)。

### 10.1 処理手順

1. `tdd-driver` skill を起動 (テスト先行強制モード)
2. Plan §5.2 の並列判定ロジック (依存 DAG + `files_touched` 積集合空) から並列実行可能なタスクグループを抽出
3. **並列グループ内の各タスクについて sub-worktree を作成**: `git worktree add worktrees/<spec>/sub-<task-id> spec/<spec-name>` (親 worktree の HEAD から分岐、独立 index)
4. 各 developer agent を `allowed_files` = Plan の `files_touched` を渡して起動、sub-worktree 内で作業
5. 全 developer 完了後、親 worktree で `git cherry-pick <各 sub-worktree の commit>` で順次統合 (**逐次実行、index 競合を親で起こさせない**)
6. 全タスク完了で sub-worktree を削除 (`git worktree remove --force worktrees/<spec>/sub-<task-id>`)
7. progress.json の `stages.implement` を `completed` に更新 (outputs に各 T-N の commit SHA を記録)

### 10.2 並列実行の具体的フロー

```
並列グループ: [T-1, T-2] (files_touched 積集合空)
逐次: [T-integrate]

1. sub-worktree 作成:
   git worktree add worktrees/calculator/sub-T-1 spec/calculator
   git worktree add worktrees/calculator/sub-T-2 spec/calculator
2. developer agent 並列起動:
   developer (T-1, allowed_files=[calculator/add.py, tests/test_add.py], cwd=sub-T-1)
   developer (T-2, allowed_files=[calculator/subtract.py, tests/test_subtract.py], cwd=sub-T-2)
3. 各 developer が独立 index で commit 作成 (競合一切なし)
4. 親 worktree で cherry-pick 統合:
   cd worktrees/calculator
   git cherry-pick <T-1 の sub-worktree 最終 commit>
   git cherry-pick <T-2 の sub-worktree 最終 commit>
5. T-integrate は親 worktree で逐次実行 (__init__.py 等の共通ファイル編集)
6. sub-worktree クリーンアップ
```

### 10.3 品質ゲート

- Plan ファイルの全タスク (チェックボックス) が完了済 ([x]) であること
- 新規コミットが親 worktree 内 (spec/<spec-name> ブランチ) に作成されていること
- cherry-pick 時にコンフリクトが発生していないこと (発生時は stages.implement を failed に記録して停止、ユーザーに手動解消を依頼)
- sub-worktree がすべて削除されていること

### 10.4 下位 skill / agent 未実装時

- `tdd-driver` skill 未実装 → blocked
- `developer` agent 未実装 → blocked
- いずれの場合も progress に missing を記録して全停止

### 10.5 Phase 3 移行措置 (並列実行未使用)

Phase 3 初期は Agent Teams の多階層 subagent 動作が未検証のため、**sub-worktree 方式は任意** です。順次実行 (全タスクを直列、親 worktree で 1 つずつ実装) でも本 skill は動作します。ただし Plan の `files_touched` は必須 (Phase 5 並列化の準備として記録される)。

実運用で並列化を有効にする場合は、spec-leader 起動時に `options.parallel_implement: true` を渡して sub-worktree 方式を有効化します。

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

0. **worktree 内の一時ファイルをクリーン** (2026-04-22 iter-5 改修、merge コンフリクト予防):
   - `__pycache__/`、`.pytest_cache/`、`node_modules/`、`dist/`、`build/`、`.venv/` 等の生成物を削除
   - 実装言語に応じた clean ターゲット (`npm run clean` / `make clean` 等) を実行
   - これにより merge 時に未追跡ファイル / index 競合による Aborting を予防 (iter-5 で `__pycache__` 競合が発生した事例あり)
1. main ブランチに切り替え (`git checkout main`)
2. spec/<spec-name> を merge (`git merge --no-ff spec/<spec-name>`)
3. merge 後 main で再度テスト実行 (品質ゲート)
4. worktree 削除 (`git worktree remove worktrees/<spec-name>`)
5. spec/<spec-name> ブランチ削除 (任意、ユーザー確認)
6. **Spec / Plan / Review / Code Review 結果を archive 移動** (2026-04-22 iter-4 改修含む):
   - `specs/<spec-name>.md` → `specs/archive/<spec-name>.md` (frontmatter `status: archived` に更新)
   - `specs/<spec-name>.plan.md` → `specs/archive/<spec-name>.plan.md` (frontmatter `status: archived` に更新)
   - `specs/<spec-name>.review.md` → `specs/archive/<spec-name>.review.md`
   - **`worktrees/<spec-name>/reviews/consolidated.md` → `specs/archive/<spec-name>.consolidated.md`** (iter-4 改修、受信 review の長期保存。worktree 削除前に `cp` でコピーしておき、ship ステップ 6 で archive 確定)
   - archive 移動により、過去の設計判断 / レビュー結果 / Plan / 統合 review を将来の Spec 策定時に参照可能
7. progress.json の `stages.ship` を `completed`、最終的に `result.json` を生成

### 13.3 品質ゲート

- main での再テストが pass
- worktree が正常に削除されている
- spec.md / plan.md / review.md の 3 ファイルが archive に移動されている

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

### 14.4 ユーザーが「中止」選択時の挙動 (2026-04-22 iter-2 改修)

再開モードでユーザーが「中止」を選択した場合、現在の progress.json 状態を変更せずに、以下で `result.json` を生成して終了します。

```json
{
  "spec": "<spec-name>",
  "verdict": "aborted-on-resume",
  "started_at": "<progress.json の started_at を引き継ぎ>",
  "ended_at": "<中止時刻>",
  "final_commit": null,
  "stages_completed": ["<completed だったステージを列挙>"],
  "stages_failed": [],
  "stages_blocked": ["<blocked だったステージを列挙>"],
  "user_action_required": "ユーザー中止。worktree / progress.json は保持、後日 spec-leader 再起動で再開モードに再入場可能",
  "resume_point_at_abort": "<current_stage の値>",
  "notes": "再開モードで中止選択"
}
```

#### 14.4.1 保持されるもの / 破棄されるもの

| 対象 | 挙動 |
|---|---|
| `worktrees/<spec-name>/` | 保持 (再開用) |
| `specs/<spec-name>.progress.json` | 保持 |
| `worktrees/<spec-name>/progress.md` | 保持 |
| `specs/<spec-name>.result.json` | 上記 JSON で生成 |

#### 14.4.2 再再開の可能性

`aborted-on-resume` は回復可能な状態です。後日 spec-leader を再起動すると再び再開モードに入り、§14.2 手順に従って状態確認からやり直します。完全な破棄が必要な場合は、ユーザーが明示的に `worktrees/<spec-name>/` を削除 + `progress.json` / `result.json` を削除してから新規に spec-leader を起動します。

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

### 16.3 実装状況の表 (2026-04-22 時点、Plan と Isolate 順序反転後)

Plan は本 skill の前提条件 (main 側で writing-plan 事前実行済) として扱うため、本表の対象外 (前提チェックは §3 参照)。本 skill が制御する 5 ステージ:

| ステージ | 必要 skill | 必要 agent | 実装状況 |
|---|---|---|---|
| Isolate | (本 skill で直接 git worktree + ファイルコピー実行) | — | ○ |
| Implement | `tdd-driver` ○ | `developer` ○ (2026-04-21 実装) | ○ |
| Verify | `verification-before-completion` ○ | `verifier` ○ (2026-04-21 実装) | ○ |
| Code Review | `receiving-code-review` ○ / `cross-model-review` ○ | 3 reviewer agent ○ (2026-04-21 実装) | ○ |
| ship | (本 skill で直接 git merge + archive 移動実行) | — | ○ |

2026-04-22 時点で Phase 3 の全 skill (11 種) + agent (5 種) が実装完了し、**iter-3 統合完走テスト (verdict: shipped) で全 5 ステージ通過を確認済み**。Phase 5 対応の残 agent (investigator / spec-reviewer / orchestrator) は本 skill の動作に影響しない。

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
