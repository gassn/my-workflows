---
name: writing-spec
description: >
  Brainstorming ノート (specs/<spec-name>.brainstorm.md) を入力として、
  軽量 Markdown 形式の Spec ファイル (specs/<spec-name>.md) を生成する skill。
  本ワークフロー (docs/workflow.md) の Spec ステージを担う。
  「Spec 書いて」「仕様書作って」「Spec 化して」「Brainstorming を Spec に起こして」等で起動。
  生成後の brainstorm.md は specs/archive/ に移動し、status を archived に更新する。
  複数 Spec の場合は specs/dag.md を参照して DAG 順に処理する。
  Brainstorming が完了している (status: brainstorming-complete) ことが必須前提。
---

# Writing Spec Skill

Brainstorming ノートを入力として、軽量 Markdown 形式の Spec ファイルを生成する skill です。本プロジェクトのワークフロー (`docs/workflow.md`) における Spec ステージを担います。

**用語**: 「Project Phase」「Workflow Stage (ステージ)」「Release Phase」「Spec」の定義は `docs/glossary.md` を参照してください。

## 1. 役割と位置づけ

ワークフロー上の位置:

```
Brainstorming → [DAG 構築 (複数 Spec 時)] → [writing-spec (本 skill)] → Spec Review → [DAG 構築 (確定)] → Isolate → ...
```

Brainstorming ノートで解像度の上がった要件を、後続の Plan / Implement ステージが参照可能な構造化された Spec ファイルに落とし込むことが役割です。単なる転記ではなく、**実装可能な粒度への具体化** を目指します。

## 2. 起動トリガー

以下のフレーズで自動的に起動してください。

- 「Spec 書いて」「Spec 作って」
- 「仕様書作って」「仕様書起こして」
- 「Spec 化して」「Brainstorming を Spec に起こして」
- 「ブレストの内容を仕様にして」

また、以下の状況で **自動起動を提案** してください。

- `specs/<spec-name>.brainstorm.md` に `status: brainstorming-complete` が付与され、対応する `specs/<spec-name>.md` が未作成
- ユーザーから Spec ステージへの移行承認を得た直後 (brainstorming skill の完了判定基準 3 を満たした後)

## 3. 前提条件の確認

skill 起動直後、以下を必ず確認してください。

- 入力 Brainstorming ノートの存在 (`specs/<spec-name>.brainstorm.md`)
- frontmatter `status` が `brainstorming-complete` であること
- 対応する `specs/<spec-name>.md` がまだ存在しないこと (上書き防止)
- 複数 Spec 処理時は `specs/dag.md` の存在確認

前提条件を満たさない場合、以下のエラー対応を行ってください。

- **Brainstorming ノート未存在**: 「Brainstorming ステージが完了していません。先に brainstorming skill を起動してください」と返して終了
- **status が brainstorming-complete でない**: 現在の status を表示し、Brainstorming ステージが完了するまで待つよう指示
- **spec.md が既に存在**: 「既存 Spec の編集」か「新規作成 (上書き)」のどちらかを明示的に確認、ユーザー承認なしに上書きしない

## 4. Spec ファイルの章構成

生成する `specs/<spec-name>.md` の章構成 (7 章):

````markdown
---
name: <spec-name>
status: spec-complete
created: YYYY-MM-DD
brainstorming_archive: specs/archive/<spec-name>.brainstorm.md
depends_on: [...]          # Brainstorming ノートから引き継ぎ (ない場合は省略)
parallel_group: N          # Brainstorming ノートから引き継ぎ (ない場合は省略)
---

# Spec: <spec-name>

## 1. 目的

<なぜこの機能 / 変更が必要なのか。ビジネス価値や解決する課題を簡潔に記述>

## 2. スコープ

### 2.1 含むもの
- <今回の Spec で実装・変更する対象 1>
- <対象 2>

### 2.2 含まないもの
- <明示的に除外する項目 1>
- <項目 2>

## 3. 機能要件

### 3.1 <機能名 1>

<機能の詳細な挙動>

**入力**:
- <入力項目と型 / 制約>

**出力**:
- <出力項目と型 / 制約>

**エラーハンドリング**:
- <エラーケースと挙動>

### 3.2 <機能名 2>
<同上>

## 4. 非機能要件

| 項目 | 要件 |
|---|---|
| パフォーマンス | <応答時間・スループット等> |
| セキュリティ | <認証・認可・データ保護等> |
| 可用性 | <稼働率・障害時の挙動等> |
| 拡張性 | <将来の拡張余地> |
| 保守性 | <ログ / モニタリング / ドキュメント要件> |

## 5. 受け入れ基準 (Acceptance Criteria)

- [ ] <具体的で検証可能な基準 1>
- [ ] <基準 2>
- [ ] <基準 3>

## 6. 非対象 (スコープ外)

- <明示的に含めないもの 1 (理由付き)>
- <2>

## 7. リスクと緩和策

### 7.1 <リスク 1>
- **内容**: <リスクの具体的内容>
- **緩和策**: <対応方針>

### 7.2 <リスク 2>
<同上>
````

## 5. Brainstorming ノートからの統合

Brainstorming ノートの各セクションを Spec ファイルの対応セクションに統合します。単なる転記ではなく、**実装判断に必要な粒度まで具体化** してください。

### 5.1 セクション対応表

| Brainstorming ノート | Spec ファイル | 統合時の対応 |
|---|---|---|
| 目的 | 1. 目的 | そのまま、または整理 |
| 利用者 | 1. 目的 | 目的セクションに含めるか、3. 機能要件の文脈で記述 |
| 成功条件 (受け入れ基準) | 5. 受け入れ基準 | そのまま、より検証可能な粒度に具体化 |
| 制約 | 4. 非機能要件 / 3. 機能要件 | 技術制約は非機能、仕様制約は機能要件へ |
| スコープ (含むもの / 含まないもの) | 2. スコープ / 6. 非対象 | そのまま |
| 代替案の検討 | (統合時は省略、必要なら 7. リスクで触れる) | Spec では採用案のみ記述 |
| リスク | 7. リスクと緩和策 | 緩和策を追加して具体化 |
| 未解決事項 | 3. 機能要件 / 4. 非機能要件 | Spec 段階で解決 (未解決なら Spec Review で相談) |
| Spec 間で共有する資産 | 3. 機能要件 / 4. 非機能要件 | 共有資産の参照箇所を明記 |
| 切り出した理由 (分割時) | (統合時は省略) | depends_on の frontmatter で依存関係を表現 |

### 5.2 具体化のガイドライン

Brainstorming ノートは要件レベル、Spec ファイルは実装判断可能レベルで記述します。具体化の例:

- **Brainstorming**: 「在庫が 10 個を切ったら通知」
- **Spec**: 「在庫数が 10 未満 (`< 10`) になった**瞬間** (在庫更新イベント直後、100ms 以内) に通知をトリガーする。既に 10 未満状態が継続している場合は重複通知しない (`last_notified_at` フィールドで制御、冷却期間 1 時間)。」

未解決事項はこの段階で **具体化**してください。具体化できない場合は Spec Review で相談する前提で「TBD (要議論)」とマークし、`status: spec-writing` のまま残します。

## 6. frontmatter の引き継ぎ

Brainstorming ノートの frontmatter から以下を引き継ぎます。

- `name`: そのまま
- `depends_on`: そのまま引き継ぎ (未設定なら省略)
- `parallel_group`: そのまま引き継ぎ (未設定なら省略)

新規に設定する項目:

- `status`: `spec-complete` (Spec 書き終わり、Spec Review 待ち)
- `created`: 当日の日付 (YYYY-MM-DD 形式)
- `brainstorming_archive`: `specs/archive/<spec-name>.brainstorm.md` (移動後のパス)

## 7. Brainstorming ノートの archive への移動

Spec ファイル生成と承認完了後、以下の手順で Brainstorming ノートを archive に移動します。

1. `specs/archive/` ディレクトリが存在しなければ作成
2. `specs/<spec-name>.brainstorm.md` の frontmatter `status` を `archived` に更新
3. `specs/<spec-name>.brainstorm.md` を `specs/archive/<spec-name>.brainstorm.md` に移動 (`git mv` 相当)
4. 移動したことをユーザーに報告

### 7.1 移動しない場合

以下の場合は archive 移動を **行わない** でください。

- ユーザーが明示的に「brainstorm.md を残したい」と指示した場合
- Spec 書き出しが途中で中断された場合 (`status: spec-writing`)
- Spec Review で差戻された場合 (Brainstorming ノートを参照して再編集が必要な可能性)

### 7.2 archive 移動の意義

- `spec-dag-builder` skill が再実行された際、`specs/archive/` 配下は対象外として扱える (重複解析防止)
- 過去の要件経緯を参照可能な形で保管
- `specs/` 配下の見通しを維持 (進行中の Spec のみ表示)

## 8. 複数 Spec 処理時の DAG 順走査

Brainstorming で複数 Spec に分割され、`specs/dag.md` が存在する場合、本 skill は **DAG 順に処理** します。

### 8.1 処理順序の決定

1. `specs/dag.md` を読み込み、`parallel_group` の小さい順にソート
2. 同一 `parallel_group` 内は、ユーザーと相談して処理順を決定 (通常は名前順または重要度順)
3. `status: brainstorming-complete` の Brainstorming ノートのみを対象とする (`archived` / `spec-complete` 以上はスキップ)

### 8.2 並列 vs 順次

本 skill は対話型のため、並列起動はせず **順次処理** します。1 つの Spec を書き終えてユーザー承認を得てから次の Spec に進みます。並列化は Phase 5 の orchestrator agent が担当する責務です。

### 8.3 中断時の状態

複数 Spec 処理の途中で中断した場合、それまでに書き出した Spec は `status: spec-complete` で保存済み、未処理の Brainstorming ノートは `brainstorming-complete` のまま残ります。再開時は未処理分のみを対象に本 skill を再起動してください。

## 9. ユーザー承認フロー

Spec ファイル生成は対話的に進めます。

1. **ドラフト提示**: Brainstorming ノートから推測・具体化した Spec ドラフトを提示
2. **修正要望の受付**: ユーザーから修正指示があれば反映
3. **最終確認**: 全 7 章が適切に埋まっているか、受け入れ基準が検証可能か、ユーザーと確認
4. **承認後に保存**: `specs/<spec-name>.md` に保存 + Brainstorming ノートを archive に移動
5. **次ステージへの引き継ぎ**: Spec Review ステージに進む旨を伝える

**承認なしに spec.md を保存してはいけません**。Brainstorming ノートの archive 移動も同様です。

## 10. 失敗時の対応

以下の状況では、無理に Spec を完成させずユーザーに相談してください。

- **要件が Spec に起こすには曖昧すぎる**: Brainstorming ステージへの差戻しを提案
- **受け入れ基準が検証不可能**: ユーザーと相談して検証方法を確定してから継続
- **リスクの緩和策が思い浮かばない**: リスクを明示して Spec Review で対応方針を議論する前提で進行
- **他 Spec との整合性問題を発見**: 該当 Spec の書き出しを保留し、全体見直しを提案

## 11. 次ステージへの引き継ぎ (Spec Review)

Spec ファイル生成 + archive 移動が完了したら、以下を行ってください。

1. ユーザーに Spec Review ステージへの移行を提案
2. 生成した Spec ファイルのパスを明示
3. Spec Review で確認してほしいポイント (未解決事項の TBD、リスクの緩和策、受け入れ基準の検証可能性等) をリスト化

`spec-review` skill (Phase 3 で実装予定) が起動されたら、本 skill の責務は完了です。

## 12. 失敗・障害事例 (アンチパターン)

以下を行ってはいけません。

- ❌ Brainstorming ノートを読まずに Spec を書き始める
- ❌ ユーザー承認なしに spec.md を保存する
- ❌ ユーザー承認なしに brainstorm.md を archive に移動する
- ❌ Brainstorming ノートに記述のない内容を勝手に追加する (推測による補完は明示して確認を求める)
- ❌ 受け入れ基準を検証不可能な曖昧な文言にする (例: 「適切に動作する」「高速である」)
- ❌ 未解決事項を放置したまま `spec-complete` にする (必ず具体化するか TBD マークで Spec Review に持ち込む)
- ❌ 複数 Spec 処理時に DAG 順を無視してランダム処理する
- ❌ `specs/dag.md` を書き換える (本 skill は読み取り専用、更新は `spec-dag-builder` の責務)
