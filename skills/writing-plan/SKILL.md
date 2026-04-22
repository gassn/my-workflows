---
name: writing-plan
description: >
  承認済み Spec ファイル (specs/<spec-name>.md、main 側) を入力として、
  技術設計 + タスク分解を含む Plan ファイル (specs/<spec-name>.plan.md、main 側) を
  生成する skill。本ワークフロー (docs/workflow.md) の Plan ステージを担います。
  **main ブランチ側で動作** し、Plan ファイルを他 Spec の spec-leader / writing-plan から
  参照可能な状態に置くことで、Phase 5 の並列 Spec 実行時の相互参照を可能にします
  (2026-04-22 改修、Phase 5 並列化準備)。
  spec-review skill が verdict: pass を返した直後に自動起動し、完了後は spec-leader に
  バトンタッチします (spec-leader は Plan ファイルを worktree にコピーして Implement へ)。
  加えて「Plan 書いて」「技術設計して」「タスク分解して」等の明示フレーズでも起動します。
  出力は必ず実装可能な粒度のチェックボックス形式タスクリスト (files_touched 必須) を含みます。
  Phase 5 で investigator agent がコードベース調査 / 他 Spec Plan 走査を並列実行する前提の
  インタフェースを Phase 3 時点で確定します (skill 改修不要)。
---

# Writing Plan Skill

承認済み Spec ファイルを入力として、技術設計 + タスク分解を含む Plan ファイルを生成する skill です。本プロジェクトのワークフロー (`docs/workflow.md`) における Plan ステージを担います (spec-kit の Plan + Tasks 相当)。

**用語**: 「Project Phase」「Workflow Stage (ステージ)」「Release Phase」「Spec」の定義は `docs/glossary.md` を参照してください。

## 1. 役割と位置づけ

```
... → writing-spec → spec-review (pass) → [writing-plan (本 skill、main 側)] → spec-leader (Isolate〜ship)
                                                        │
                                                        └── 他 Spec の Plan を参照可能
                                                            (specs/*.plan.md、Phase 5 並列化時)
```

Spec の「何を作るか」を、実装可能な「どう作るか + どの順で作るか」に展開します。**main ブランチ側で完結** し、Plan ファイルを `specs/<spec-name>.plan.md` として配置することで:

- 他 Spec の spec-leader / writing-plan が並列実行中の Plan を `specs/*.plan.md` で参照可能
- Plan 策定が難航して Spec 差戻しになった際、worktree 作成の無駄が発生しない
- ship 時に `specs/archive/<spec-name>.plan.md` に archive 移動、過去の設計判断を将来 Spec で参照可能

## 2. 起動トリガー

### 2.1 自動起動 (第一トリガー)

`spec-review` skill が verdict: pass を返した直後、**本 skill を自動起動** します (2026-04-22 改修: 従来の spec-leader 起動順序から独立し、spec-leader の前に配置)。入力:

- `specs/<spec-name>.md` (main 側の Spec、status: spec-complete)
- `specs/<spec-name>.review.md` (参考、verdict: pass 確認用)
- `specs/dag.md` (複数 Spec 時、並列実行中の他 Spec の Plan 参照のため)

### 2.2 明示フレーズ起動 (第二トリガー)

- 「Plan 書いて」「技術設計して」「タスク分解して」
- 「writing-plan 起動」「<spec-name> の Plan を作って」

## 3. 前提条件の確認

- **main 側の Spec ファイル** (`specs/<spec-name>.md`) の存在
- Spec の frontmatter `status: spec-complete`
- `specs/<spec-name>.review.md` の存在と verdict: pass
- **対応する Plan ファイル (`specs/<spec-name>.plan.md`) が未作成であること** (上書き防止)
- **作業ディレクトリが main ブランチ (or 任意ブランチの main worktree)**: 本 skill は main 側で動作する前提 (2026-04-22 改修)。worktree 内からは起動しない

前提違反時は明確なエラー文言で停止し、spec-leader には進まずにユーザー相談で解決してから再実行します。

## 4. Plan ファイル章構成

生成する `specs/<spec-name>.plan.md` の章構成 (main 側に配置、2026-04-22 改修):

````markdown
---
name: <spec-name>
spec_path: specs/<spec-name>.md
status: plan-complete
created: YYYY-MM-DD
---

# Plan: <spec-name>

## 1. 技術設計概要

Spec の機能要件を実現するための技術選定と高レベル設計。

## 2. アーキテクチャ

- コンポーネント構成
- データフロー
- 依存関係 (新規 / 既存ライブラリ)

## 3. データモデル

- 新規テーブル / 型定義
- 既存スキーマへの変更 (migration を伴う場合は明示)

## 4. API 設計

- エンドポイント一覧 (メソッド / パス / 入出力)
- 認証要件

## 5. 実装タスク分解

### 5.1 タスクリスト (チェックボックス形式、必須)

各タスクは以下の項目を必須で持ちます (`files_touched` は並列競合防止のために必須、2026-04-22 の iter-3 統合テスト知見に基づく改修):

- [ ] T-1: <タスク名> (見積: XX 分)
  - 入力: <前提ファイル / 依存タスク>
  - 出力: <成果物>
  - テスト: <先行して書くテストの概要>
  - **files_touched**: `[<編集予定ファイルの絶対的相対パス>, ...]` (必須、空配列不可)
- [ ] T-2: ...
- [ ] T-N: ...

#### 5.1.1 files_touched 必須化の理由

過去 (iter-3 統合テスト) で、並列実行した T-1/T-2 の developer agent が共通ファイル (`__init__.py`) を同時編集して git index 競合が発生、T-2 の commit が消失する事故が起きました。`files_touched` を Plan 段階で明示することで:

- 並列実行可否を `files_touched` の積集合で機械判定できる (積集合が空 = 並列可)
- developer agent が allowed_files として受け取り、越境編集を自己検出できる
- 共通ファイル (バンドル / entrypoint 等) は専用の集約タスク (T-integrate) として最後に分離可能

### 5.2 タスク間の依存関係と並列判定

T-1 → T-2, T-3 (並列可) → T-4 のように DAG を記述。**並列可の判定は以下 2 条件の AND**:

1. タスク間の依存関係が DAG 上で先祖-子孫関係にない
2. タスクの `files_touched` が空積集合 (= 編集対象ファイルが一切重ならない)

共通ファイルを複数タスクが編集する場合は、**T-integrate タスクを最終工程として分離** することを推奨:

```markdown
- [ ] T-1: add(a,b) 実装
  - files_touched: [calculator/add.py, tests/test_add.py]
- [ ] T-2: subtract(a,b) 実装
  - files_touched: [calculator/subtract.py, tests/test_subtract.py]
- [ ] T-integrate: __init__.py に公開 API 追加 (T-1, T-2 完了後)
  - files_touched: [calculator/__init__.py]
```

この構造で T-1 と T-2 は files_touched 積集合が空のため安全に並列化可能。T-integrate は逐次実行。

### 5.3 plan.meta.json の生成 (2026-04-22 iter-4 改修、軽量メタ)

Plan 保存時に `specs/<spec-name>.plan.meta.json` も同時生成します (任意、learn skill の時間計測補助):

```json
{
  "spec": "<spec-name>",
  "plan_started_at": "2026-04-22T14:00:00Z",
  "plan_completed_at": "2026-04-22T14:15:00Z",
  "tasks_count": 4,
  "parallel_groups_count": 2,
  "files_touched_union": ["util/add.py", "util/core.py", ...],
  "depends_on": ["auth"],
  "references_other_plans": ["specs/auth.plan.md"]
}
```

- `plan_started_at` / `plan_completed_at`: Plan ステージの所要時間を learn skill が計測できる
- `tasks_count` / `parallel_groups_count`: タスク粒度統計
  - `parallel_groups_count` の定義 (iter-4 eval の曖昧性指摘を反映): **§5.2 で「並列可」と判定されたグループの数** を指す。単独タスク (先頭の migration 等 / 末尾の T-integrate 等) は並列グループに含めない。例: T-1 (単独) → [T-2, T-3] (並列 G1) → [T-4, T-5, T-6] (並列 G2) → T-integrate (単独) の構造なら `parallel_groups_count: 2`
- `files_touched_union`: 全タスクの files_touched 和集合 (orchestrator の衝突検出に使用)
- `references_other_plans`: 本 Plan が参照した他 Spec の Plan (§8.3 の継承追跡)

learn skill §4 時間配分テーブルで Plan 行が旧来 null だった問題 (iter-4 learn 指摘) が解消されます。

## 6. テスト戦略

- ユニットテスト対象
- 統合テスト対象
- E2E テスト対象 (該当する場合)

## 7. リスクと対応

Spec の §7 リスクの技術的具体化。実装上の注意点を記述。
````

## 5. タスク分解のガイドライン

### 5.1 粒度

- 1 タスク = **30-60 分で完了する単位** を目安
- 過大: 「認証機能を実装」(ブレイクダウン必須)
- 過小: 「import 文を追加」(統合して 1 タスクに)

### 5.2 チェックボックス形式の必須性

spec-leader の Implement ステージは Plan のチェックボックスを developer agent に割り当てます。チェックボックス以外の形式 (箇条書きのみ / 段落のみ) は NG です。

### 5.3 テスト先行タスク

各タスクには「先行して書くテスト」を明記します。tdd-driver skill が Implement 時にテスト存在を確認するため、Plan 段階で設計します。

## 6. investigator agent の活用 (Phase 5)

Phase 3 時点では main agent が直接コードベースを調査します。Phase 5 で investigator agent が追加された際、以下を並列起動する前提のインタフェースを確定します。

- コードベース調査 (類似実装 / 命名規約 / 既存共有資産)
- 依存ライブラリ調査 (利用可能な機能 / バージョン制約)
- 類似実装調査 (archive の過去 Spec / 同様機能の実装パターン)

本 skill は investigator の結果をマージして Plan に反映するだけで、呼び出し方法は Phase 5 で確定させます (本 skill 側の改修不要)。

## 7. ユーザー承認フロー

1. Plan ドラフトを提示
2. 修正要望を受け付け
3. 最終確認 (タスク分解の粒度 / 技術選定 / リスク対応 / files_touched の妥当性)
4. 承認後に `specs/<spec-name>.plan.md` 保存 (main 側、2026-04-22 改修)
5. **spec-leader を自動起動** (入力: spec_path)。spec-leader が Isolate ステージで Plan ファイルを worktree にコピーして Implement へ進む

承認なしに Plan を保存してはいけません。

### 7.1 spec-leader への自動起動

Plan ファイル保存 + ユーザー承認完了後、**spec-leader skill を自動起動** します (従来 spec-review → spec-leader 直結だったフローが、spec-review → writing-plan → spec-leader に変わったため本 skill が自動起動担当)。

引き渡すパラメータ:

- `spec_path`: `specs/<spec-name>.md`
- (spec-leader が内部で `plan_path` = `specs/<spec-name>.plan.md` を自動特定、前提条件 §3 でチェック)

## 8. 複数 Spec 処理時の DAG 順走査 (2026-04-22 改修)

`specs/dag.md` は単一 / 複数にかかわらず **常に存在** する前提 (spec-dag-builder が 1 ノード DAG も生成するため)。本 skill は dag.md を**唯一の実行順序源** として扱います。

### 8.1 処理順序の決定

1. `specs/dag.md` を読み込み、`parallel_group` の小さい順にソート
2. 同一 `parallel_group` 内はユーザーと相談して処理順を決定 (通常は名前順 or 重要度順)
3. 対象は `status: spec-complete` / `spec-revised` の Spec のみ (`archived` / `plan-complete` 以上は処理済のためスキップ)
4. 対応する `specs/<spec-name>.plan.md` が既存の Spec もスキップ (§3 前提条件、上書き防止)

### 8.2 並列 vs 順次 (Phase 3)

本 skill は対話型のため、Phase 3 では**順次処理** します。1 つの Plan を生成してユーザー承認 → spec-leader 自動起動 (§7.1) → 次 Spec の Plan 策定に戻る、の繰り返しです。

```
dag.md 読込 → Spec A (group 1) の Plan 生成 → ユーザー承認 → spec-leader 起動
            → Spec B (group 2) の Plan 生成 → ユーザー承認 → spec-leader 起動
            → Spec C (group 3) の Plan 生成 → ユーザー承認 → spec-leader 起動
```

Phase 5 の orchestrator agent 実装後は、同一 `parallel_group` 内の複数 Spec について writing-plan / spec-leader を並列起動できるよう拡張されますが、本 skill のインタフェース (1 Spec 単位で動作) は変更不要です。

### 8.3 他 Spec の Plan 参照 (2026-04-22 改修の核心)

本 skill が main 側で動作する最大の目的は **先行 Spec の Plan を後続 Spec の Plan 策定時に参照可能にする** ことです。具体的な活用例:

- **API 契約の整合**: auth Spec の Plan で定義した `POST /api/auth/login` の入出力スキーマを、order Spec の Plan 策定時に参照し重複 / 不整合を防ぐ
- **命名規約の継承**: auth Plan の `User` モデル定義を order Plan の `UserId` 参照で一貫させる
- **共有資産の再利用**: auth Plan の `requireAuth` ミドルウェアを order Plan が再利用する前提で設計
- **データモデル整合**: auth Plan の `users` テーブルスキーマと order Plan の外部キー整合

対象 Spec の `depends_on` に列挙された Spec の `specs/<dep>.plan.md` を入力として扱い、本 Plan の設計判断に反映してください。

### 8.4 Phase 5 investigator agent への拡張

Phase 5 で investigator agent が実装された際、8.3 の「他 Spec Plan 参照」は investigator agent の責務に委譲されます:

- investigator が `specs/*.plan.md` を走査し、対象 Spec の依存先 Plan を構造化して返す
- investigator がコードベース調査 + 依存ライブラリ調査 + 類似実装調査を並列実行
- 本 skill は investigator の結果をマージして Plan に反映

インタフェースは Phase 3 時点で確定 (本 skill が investigator の出力を Plan §2-4 に統合するだけ、呼び出しロジックは Phase 5 で追加)。

### 8.5 中断時の状態

複数 Spec 処理の途中で中断した場合、それまでに書き出した Plan は `status: plan-complete` で保存済。未処理の Spec (まだ `spec-complete` 状態) は残ります。再開時は未処理分のみを対象に本 skill を再起動してください。

## 9. 失敗時の対応

- Spec が曖昧でタスク分解できない → Spec への差戻しを提案 (writing-spec レビュー指摘対応モード)
- 既存コードベースとの整合性問題発見 → ユーザー相談、場合により Spec Review に戻す
- 技術的に実現困難 → リスクとして明示し、代替案をユーザーと議論

## 10. アンチパターン

- ❌ Spec を読まずに Plan を書く
- ❌ チェックボックス形式を省略する (Implement の前提崩壊)
- ❌ タスクを 3 時間以上の粒度で定義する (developer が詰まる)
- ❌ テスト先行の記述を省略する (tdd-driver がブロックする)
- ❌ **worktree 内で本 skill を起動する** (2026-04-22 改修: 本 skill は main 側で動作、worktree は Isolate 後の spec-leader 配下で使用)
- ❌ ユーザー承認なしに Plan を保存する
- ❌ `files_touched` を省略する (並列競合検出が効かなくなる、§5.1.1 で必須化)
- ❌ `files_touched` が重なる 2 タスクを並列可と判定する (§5.2 並列判定の 2 条件 AND を無視)
- ❌ 共通ファイルを複数タスクに散らす (T-integrate 集約タスクで最終工程に分離)
- ❌ Plan 保存後に spec-leader を自動起動しない (§7.1 自動起動が必須)
