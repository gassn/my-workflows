---
name: orchestrator
description: >
  複数 Spec の DAG を読み込み、parallel_group 順に spec-leader skill を逐次実行する
  Phase 5 skill。Claude Code 仕様 (多階層 subagent 禁止) に準拠し、main agent が
  本 skill を実行する形で orchestrator の役割を果たす。
  元々 Phase 5 で orchestrator を agent として設計したが、「Subagents cannot spawn
  their own subagents」制約のため agent 3 階層 (orchestrator → spec-leader → workers)
  が不可と判明。main agent が本 skill を通じて orchestrator の役割を担い、
  spec-leader は同じ main agent 内で逐次実行、workers (developer / verifier / reviewer)
  のみを Agent tool 経由で並列起動する設計に変更した。
  「複数 Spec 実装を統括して」「orchestration 起動」「全 Spec を順番に実装して」等の
  フレーズで起動する。単一 Spec のみの場合は本 skill を経由せず直接 spec-leader を起動可。
---

# Orchestrator Skill

複数 Spec 実行を統括する skill です。Phase 5 で導入。main agent が本 skill を実行することで複数 Spec の順次実装を管理します (Claude Code の多階層 subagent 禁止制約により、main agent 自身が orchestrator + spec-leader を実行し、下位の developer / verifier / reviewer のみを Agent tool 経由で起動する設計)。

## 1. 役割と位置づけ

```
ユーザー発話: "auth / order / payment を実装して"
  │
  ▼
main agent が本 orchestrator skill を起動
  │
  ├─ specs/dag.md を読む (spec-dag-builder が生成済)
  ├─ parallel_group 順に spec-leader skill を逐次実行
  │   │
  │   └─ (各 spec-leader 内で)
  │        ├─ Agent(developer, isolation: worktree) 並列起動
  │        ├─ Agent(verifier) 起動
  │        └─ Agent(code-reviewer / security-reviewer / cross-model-reviewer) 並列起動
  │
  └─ 各 spec-leader 完了後、result.json を読み次 Spec へ
```

## 2. 起動トリガー

### 2.1 自動起動

- `writing-plan` skill が複数 Spec の Plan 生成を完了した直後 (dag.md に記載された複数 Spec が plan-complete になった時)
- spec-dag-builder が複数 Spec の確定 DAG を生成した直後

### 2.2 明示フレーズ

- 「複数 Spec 実装を統括して」
- 「orchestration 起動」「orchestrator 起動」
- 「全 Spec を順番に実装して」「DAG 順に ship して」
- 「<spec A> と <spec B> をまとめて実装して」

### 2.3 単一 Spec 時のスキップ

単一 Spec (dag.md の specs 配列が 1 要素) の場合は本 skill を経由せず、main agent が直接 spec-leader を実行してください。本 skill の付加価値は複数 Spec 時に発揮されます。

## 3. 前提条件の確認

- `specs/dag.md` の存在 (spec-dag-builder が生成、単一 Spec も 1 ノード DAG で生成されているはず)
- dag.md の各 Spec について、以下が揃っていること:
  - `specs/<spec>.md` (status: spec-complete)
  - `specs/<spec>.review.md` (verdict: pass)
  - `specs/<spec>.plan.md` (status: plan-complete or plan-revised)
- 前提不備の Spec があれば、それを実行対象から除外 + ユーザーに相談

## 4. 処理手順

### 4.1 DAG 読み込みと並列計画

1. `specs/dag.md` を読み、`parallel_group` 順にグループ化
2. 各グループ内で依存関係が満たされている Spec を抽出
3. `files_touched` の和集合を計算、衝突があれば warning (writing-plan の DAG 並列判定と異なる場合)

### 4.2 グループ単位の実行

parallel_group 1 → 2 → 3 の順で、各グループ内の Spec を処理:

**Phase 5 時点の実装 (Phase 3 Agent Teams 制約)**:

- **同一 main agent 内で逐次実行** (並列度 1): 各 Spec について spec-leader skill を順次起動 → Isolate → Implement → Verify → Code Review → ship → 次 Spec へ
- **各 Spec 内の workers 並列化は有効**: spec-leader 実行中の developer / verifier / reviewer は Agent tool で並列起動される (1 階層 subagent なので動作可)

**疑似並列化の代替案 (Phase 5 後期 or Phase 6 で検討)**:

- ユーザーが複数 Claude Code セッションを起動、各セッションで 1 Spec を担当
- state ファイル (`specs/<spec>.progress.json`) 経由で進捗共有
- tmux + TUI で複数セッションを可視化 (claude-scrum-team 参考)

### 4.3 監視と次 Spec の解放

1 Spec の spec-leader skill が完了したら、`specs/<spec>.result.json` を読み:

- `verdict: shipped` / `shipped-manual` / `shipped-cross-model-pending` → 完了、依存が解決された後続 Spec を起動
- `verdict: aborted` / `aborted-on-resume` → 失敗、依存 Spec の処理を中止してユーザーに相談
- `verdict: paused` / `precondition-failed` → blocked、影響範囲を確認してユーザーに相談

### 4.4 merge 順序制御

各 spec-leader の ship ステージで個別に main に merge されますが、**main agent 内逐次実行** なので実質 `dependency-order` が自動で守られます (先行 Spec が ship 完了してから後続 Spec の Isolate が始まるため)。

`merge_strategy` オプション:

- **`dependency-order`** (推奨、default): DAG 依存順、Phase 5 時点では本質的にこれのみ動作
- **`completion-order`**: 完了順 (並列実行時に意味を持つ、Phase 6 以降でマルチセッション並列化時に有効化)
- **`manual`**: 全 Spec ship 完了後、ユーザーが手動判断 (Phase 5 実装は skip)

### 4.5 出力ファイル

`specs/orchestration.md` (人間可読、実行タイムライン):

```markdown
---
generated: YYYY-MM-DDTHH:MM:SSZ
dag_source: specs/dag.md
merge_strategy: dependency-order
total_specs: 3
---

# Orchestration Log

## 実行計画

| parallel_group | Spec | depends_on | 状態 |
|---|---|---|---|
| 1 | auth | [] | shipped |
| 2 | order | [auth] | in-progress |
| 3 | payment | [order] | pending |

## タイムライン

- YYYY-MM-DDTHH:MM:SSZ: auth の spec-leader 起動 (group 1)
- YYYY-MM-DDTHH:MM:SSZ: auth の result.json 検出 (verdict: shipped)
- YYYY-MM-DDTHH:MM:SSZ: order の spec-leader 起動 (group 2、auth 完了確認済)
- ...

## merge 順序 (最終)

1. auth (SHA: xxx)
2. order (SHA: yyy)
3. payment (SHA: zzz)
```

## 5. リソース上限 (max_parallel の扱い)

Claude Code の Agent tool には同時起動数の明示的上限はないが、公式ドキュメントで「Agent Teams は 3-5 teammates が最適」とあり、コスト観点でも過度な並列化は非推奨。

**本 skill の運用方針**:

- **Phase 5 時点では max_parallel=1** (main agent 内逐次実行、実質並列なし、安全優先)
- **各 Spec 内の workers 並列化は spec-leader に委ねる** (developer 3-5 並列、reviewer 3 並列)
- **Phase 6 以降のマルチセッション並列化**では、tmux + TUI ダッシュボードでユーザーが並列度を制御する設計を検討

## 6. Agent Teams 多階層制約への準拠

Claude Code 公式仕様 (2026-04 時点):

> **Subagents cannot spawn their own subagents**

これにより、以下は動作しません:

- ❌ `Agent(orchestrator) → Agent(spec-leader) → Agent(developer)` (3 階層)

代わりに、本 skill を採用することで:

- ✅ `main agent が orchestrator skill 実行 → main agent が spec-leader skill 実行 → Agent(developer)` (1 階層)

本 skill の全処理は main agent 内で実行され、Agent tool 経由の subagent 起動は下位 workers (developer / verifier / reviewer) のみに限定されます。

## 7. 失敗時の対応

### 7.1 1 Spec の spec-leader が aborted

- 依存関係によっては後続 Spec も進められない
- dag.md を見て影響範囲を確定、ユーザーに相談
- orchestration.md に失敗理由 + 影響範囲を記録

### 7.2 並列内で 1 Spec が paused (Phase 5 時点では逐次実行なので影響限定)

- 他の Spec は実行済 or 未着手
- paused Spec の原因解消 (writing-plan 再起動 / Spec 修正等) → orchestrator を再起動 (再開モード)

### 7.3 Agent Teams 多階層動作の環境差

Phase 5 調査で「subagent が更に subagent を起動できない」ことが公式仕様で明言されたため、本 skill の設計では多階層を前提としません。将来 Claude Code 側で解禁された場合は、本 skill を orchestrator agent に移植し直す可能性があります (インタフェースは互換に設計)。

## 8. 再開モード

orchestration.md + 各 Spec の result.json が既存の状態で本 skill が起動された場合:

1. orchestration.md を読み、どの Spec までが shipped か確認
2. 未完了 Spec (まだ result.json が無い、または paused/aborted) を抽出
3. ユーザーに「前回の続きから再開しますか?」と確認
4. 承認後、未完了 Spec のみを対象に 4.1 からやり直し

## 9. アンチパターン

- ❌ dag.md が存在しない状態で起動する (spec-dag-builder を先に起動)
- ❌ 前提条件不備の Spec (spec-complete / verdict: pass / plan-complete が揃っていない) を含めて実行
- ❌ 複数 agent を深い階層で起動しようとする (Claude Code 仕様で禁止)
- ❌ merge 順序をユーザー承認なしに manual や completion-order に変更 (依存関係の保証を失う)
- ❌ 1 Spec の失敗で他 Spec を巻き込む (影響範囲を最小化する責務)
- ❌ orchestration.md を生成せずに複数 Spec 実行を完了する (トレーサビリティ喪失)

## 10. 単一 Spec 時の挙動

dag.md の `specs` 配列が 1 要素のみの場合:

- 本 skill は起動されず、main agent が直接 spec-leader を起動
- またはユーザー明示時は本 skill が起動されても「単一 Spec のため orchestration 不要、spec-leader を直接実行します」と返して spec-leader を起動

単一 Spec に対して orchestration.md を生成する必要はありません。

## 11. Phase 3 で確定済のインタフェースへの完全依存

本 skill は spec-leader の Phase 3 入出力契約に**完全に依存**するだけで、spec-leader 本体は改修しません:

- 入力: `spec_path` (相対パス)
- 出力: `progress.json` + `result.json` (specs/<spec-name>.*)
- verdict 6 種で完了状態を表現

Phase 5 の新規実装は本 skill + 他 agent (investigator / spec-reviewer) + hook (WorktreeCreate/Remove/TaskCompleted) に限定されます。

## 12. 将来の発展 (Phase 6 以降)

- **マルチセッション並列化**: 各 Spec を独立 Claude Code セッションで並列実行、本 skill は main session が統括
- **tmux + TUI ダッシュボード**: 各セッションの進捗を可視化 (claude-scrum-team 参考)
- **Agent Teams 多階層解禁時**: 本 skill を orchestrator agent に移植 (現設計の互換性あり)
- **state ファイル watch 方式**: progress.json の変更を inotify / fswatch で検知して次 Spec 起動 (Phase 6 実装候補)
