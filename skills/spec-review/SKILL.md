---
name: spec-review
description: >
  Spec ファイル (specs/<spec-name>.md) に対する AI 自動レビューを行い、
  完全性 / 実現可能性 / 整合性 (コードベース含む) の 3 観点から指摘事項と合否判定を生成する skill。
  本ワークフロー (docs/workflow.md) の Spec Review ステージを担います。
  writing-spec skill の完了 (spec.md 保存 + brainstorm.md archive 移動) 直後に自動起動します。
  加えて「Spec レビューして」「spec-review 起動」「Spec を見直して」等の明示フレーズでも起動します。
  出力は specs/<spec-name>.review.md。verdict は pass / needs-fix / reject の 3 値。
  needs-fix / reject 時は writing-spec skill を自動再起動し、レビュー指摘対応モードで spec.md を修正します。
---

# Spec Review Skill

Spec ファイルに対する AI 自動レビューを実施し、完全性 / 実現可能性 / 整合性 (コードベース含む) の 3 観点から指摘事項と合否判定を生成する skill です。本プロジェクトのワークフロー (`docs/workflow.md`) における Spec Review ステージを担います。

**用語**: 「Project Phase」「Workflow Stage (ステージ)」「Release Phase」「Spec」の定義は `docs/glossary.md` を参照してください。

## 1. 役割と位置づけ

ワークフロー上の位置:

```
... → writing-spec → [spec-review (本 skill)] → (pass) → Isolate (Phase 3 時点では停止)
                                              → (needs-fix / reject) → writing-spec (レビュー指摘対応モード)
```

writing-spec で生成された Spec ファイルの品質を、実装 (Plan / Implement) に進む前に機械的にチェックすることが目的です。claude-scrum-team の PO レビュー役割を AI で代替します。

## 2. 起動トリガー

### 2.1 自動起動 (第一トリガー)

writing-spec skill が以下を完了した直後、**本 skill を自動起動** します。

- `specs/<spec-name>.md` が生成され frontmatter `status: spec-complete` になった
- `specs/<spec-name>.brainstorm.md` が `specs/archive/` に移動された
- ユーザーの承認 (writing-spec §9) が得られた

複数 Spec を DAG 順に処理している場合も、**1 Spec 生成完了ごとに本 skill を起動** し、review 完了後に次 Spec の writing-spec に進みます (バッチ処理せず、都度レビュー)。

### 2.2 明示フレーズ起動 (第二トリガー)

以下のユーザー発話でも起動してください。

- 「Spec レビューして」「Spec を見直して」
- 「spec-review 起動」「review 実行」
- 「<spec-name> のレビュー実施」

## 3. 前提条件の確認

skill 起動直後、以下を必ず確認してください。

- 入力 Spec ファイル (`specs/<spec-name>.md`) の存在
- frontmatter `status` が `spec-complete` であること
- 同名の `specs/<spec-name>.review.md` が存在する場合の扱い (上書き確認、または前回結果を参照する差分レビュー)
- 複数 Spec 処理時は `specs/dag.md` の存在確認 (整合性観点で利用)

前提条件を満たさない場合の対応:

- **Spec ファイル未存在**: 「対象 Spec が見つかりません。先に writing-spec を起動してください」と返して終了
- **status が spec-complete でない**: 現在の status を表示。`spec-writing` なら writing-spec の継続を促す。`archived` / `plan-*` 以降なら「既にレビュー済の Spec です」と返して終了
- **既存 review.md がある**: 前回の verdict を確認。`pass` なら再レビュー不要の可能性を提示、`needs-fix`/`reject` ならレビュー指摘対応後の再レビューと判断して続行

## 4. レビュー 3 観点の順次実行

Phase 3 時点では main agent 内で 3 観点を**順次実行** します。Phase 5 で spec-reviewer agent を 3 並列起動する方式に移行します (本 skill のインタフェースは Phase 5 移行時に改修不要)。

### 4.1 完全性 (Completeness)

Spec が後続の Plan / Implement に進むために十分な情報を含んでいるかを確認します。

- **7 章の充足**: 目的 / スコープ / 機能要件 / 非機能要件 / 受け入れ基準 / 非対象 / リスク の 7 章がすべて記述されているか (writing-spec §4 参照)
- **frontmatter 必須フィールド**: `name` / `status: spec-complete` / `created` / `brainstorming_archive` が存在するか。複数 Spec 時は `depends_on` / `parallel_group` も確認
- **受け入れ基準の検証可能粒度**: 「適切に動作する」「高速である」等の曖昧語を使っていないか。各基準が具体的な数値 / 時間 / 条件 / 検証方法を含むか
- **機能要件の粒度**: 入力 / 出力 / エラーハンドリングが各機能で明示されているか
- **TBD 未解消数**: Spec 内の `TBD` / `要議論` マーカー数をカウント。1 件以上は Spec Review で解消するか、解消できない場合は妥当な理由 (外部依存調査中 / ユーザー確認待ち等) が記述されているか
- **リスクと緩和策の対応**: リスクが列挙されているだけでなく、各リスクに緩和策が記述されているか

### 4.2 実現可能性 (Feasibility)

Spec の内容が技術的・時間的に実装可能かを確認します。

- **非機能要件の達成可能性**: パフォーマンス / 可用性 / セキュリティ要件が現在の技術スタックで達成可能か
- **技術制約との整合**: Spec 内の実装方針が制約 (既存構成維持 / 新規ライブラリ禁止等) に違反していないか
- **時間制約との整合**: スコープと時間制約 (リリース日など) が釣り合っているか。過大なスコープを過小な時間で達成しようとしていないか
- **リスク緩和策の妥当性**: 緩和策が現実的に実装可能で、効果が見込めるか
- **依存関係の妥当性**: `depends_on` で指定した他 Spec が実際に必要な API / データモデルを提供しているか
- **外部サービス・ライブラリ**: Spec で言及している外部サービス (Stripe, Redis, Auth0 等) や新規ライブラリが現時点で利用可能かつ制約に違反しないか

### 4.3 整合性 (Consistency)

他 Spec・既存コードベース・DAG 定義との整合性を確認します。本観点はプロジェクトのコードベースを読み取る必要があるため、Read / Glob / Grep ツールでコードベースを走査します。

- **他 Spec との整合 (specs/ 直下)**: 進行中の他 Spec と要件が矛盾していないか (例: 同じ API エンドポイントを異なる仕様で定義していないか)
- **archive 内の過去 Spec との整合**: 既に ship された機能と矛盾していないか (`specs/archive/*.md` を参照)
- **既存コードベースとの整合**:
  - 類似実装の有無 (Grep で機能名 / エンドポイント / モデル名を検索)
  - 既存の命名規約 (変数 / 関数 / ファイル名) との一貫性
  - 既存の依存ライブラリと競合がないか (package.json / go.mod / requirements.txt 等を参照)
  - 共有資産 (middleware / utility) の再利用可能性
- **DAG 定義との整合 (dag.md)**: `depends_on` と `parallel_group` が `specs/dag.md` の記述と一致しているか。Spec が DAG の前提を違反していないか (例: 後続 Spec がないはずの共有資産を先に定義してしまう等)

## 5. review.md の出力仕様

レビュー結果は `specs/<spec-name>.review.md` に書き出します。テンプレート:

````markdown
---
spec: <spec-name>
reviewed: YYYY-MM-DD
verdict: pass | needs-fix | reject
scores:
  completeness: NN
  feasibility: NN
  consistency: NN
  overall: NN
---

# Spec Review: <spec-name>

## 総合判定

**verdict**: `pass` / `needs-fix` / `reject`

**理由**: <1-2 文で判定理由を要約>

## 1. 完全性 (score: NN/100)

### Critical
- [C-1] <指摘内容> (該当章: §X.Y / 修正提案: ...)

### Major
- [M-1] <指摘内容> (該当章 / 修正提案)

### Minor
- [m-1] <指摘内容> (該当章 / 修正提案)

## 2. 実現可能性 (score: NN/100)

(同上: Critical / Major / Minor)

## 3. 整合性 (score: NN/100)

(同上: Critical / Major / Minor)

## 修正ガイド (verdict が pass 以外の場合のみ)

- 本 review.md を参照しながら writing-spec をレビュー指摘対応モードで再起動してください
- spec.md の `status` を `spec-writing` に戻し、指摘項目を順次反映してください
- 修正完了後、spec.md の `status` を `spec-complete` に戻すと spec-review が自動再起動します
````

- **指摘事項の ID 規則**: Critical は `C-N`、Major は `M-N`、Minor は `m-N`。観点ごとに通番
- **該当章の記載**: 「§3.2 機能要件 2」のように spec.md 内の章番号で参照
- **修正提案**: 単なる指摘ではなく「どう直せばよいか」を 1 文で添える

## 6. 合否判定ルール

以下のロジックで `verdict` を決定します。

| 条件 | verdict |
|---|---|
| Critical 1 件以上 | `reject` |
| Critical 0 件 かつ Major 3 件以上 | `needs-fix` |
| Critical 0 件 かつ Major 2 件以下 かつ Minor 任意 | `pass` |

**重大度の定義**:

- **Critical**: Spec のまま Plan / Implement に進むと**必ず手戻りが発生**する欠陥。受け入れ基準が検証不可能 / 必須章が欠落 / 他 Spec と完全に矛盾 / 非機能要件が実現不可能 等
- **Major**: 放置すると**実装中にブロッカー化する可能性が高い**問題。TBD 未解消が多数 / リスク緩和策が粗い / 既存コードとの命名規約不整合 等
- **Minor**: Spec の品質改善事項だが**実装進行を妨げない**。文言の曖昧さ / 章構成の整理余地 等

## 7. スコアリング

3 軸 × 0-100 点でスコア化し、総合スコアを加重平均で算出します。

### 7.1 各軸のスコア計算

各観点のベーススコアは 100 点から以下を減算:

- Critical 1 件ごとに -30 点
- Major 1 件ごとに -10 点
- Minor 1 件ごとに -3 点

0 未満は 0 にクランプ。

### 7.2 総合スコア

重み付け平均:

```
overall = completeness * 0.4 + feasibility * 0.3 + consistency * 0.3
```

完全性は後続ステージ全体への影響が大きいため、重みを高く設定しています。

## 8. 差戻し時の writing-spec 自動再起動

verdict が `needs-fix` または `reject` の場合、**writing-spec skill を自動再起動** します (ユーザー承認不要、Q7 確定)。

### 8.1 再起動時の引き渡し

writing-spec にレビュー指摘対応モードで起動するよう、以下を引き渡します。

- 対象 Spec ファイルパス (`specs/<spec-name>.md`)
- レビューファイルパス (`specs/<spec-name>.review.md`)
- 指示: 「レビュー指摘対応モードで起動。spec.md の status を spec-writing に戻し、review.md の指摘項目を反映してください」

### 8.2 writing-spec 側の責務

writing-spec は本 skill からの再起動を検出した場合、以下を実施します (writing-spec SKILL.md §13 参照)。

1. spec.md の frontmatter `status` を `spec-writing` に変更
2. review.md を読み込み、Critical → Major → Minor の順に対応
3. 対応完了後、spec.md の frontmatter `status` を `spec-complete` に戻す
4. spec-review が自動再起動されて再レビュー

### 8.3 再レビューの循環防止

同一 Spec で 3 回連続で verdict が pass にならない場合、**自動再起動を停止してユーザーに相談** します。設計自体に問題がある可能性が高いため、Brainstorming への差戻しを提案します。

## 9. pass 時の挙動

verdict が `pass` の場合:

### 9.1 Phase 3 時点 (spec-leader 未実装)

pass 報告のみで一旦停止します。以下をユーザーに伝えてください。

- レビュー結果 (scores, 指摘なし / Minor のみの内容)
- 次ステージ (Isolate → Plan → ...) は spec-leader 実装後に自動起動になる予定
- 現時点では手動で Isolate ステージに進んでください

### 9.2 spec-leader 実装後 (Phase 3 後半予定)

spec-leader skill を自動起動し、Isolate → Plan → ... の一連のステージ遷移に引き渡します。本節は spec-leader 実装完了時に詳細化してください。

## 10. 複数 Spec 処理時の挙動

writing-spec が DAG 順に複数 Spec を生成している場合、本 skill は**1 Spec ごと**に起動します (Q6 確定)。

- writing-spec が `auth.md` 生成完了 → spec-review 起動 (auth のレビュー)
- auth が pass → writing-spec が `order.md` 生成開始
- 途中で needs-fix / reject が出た場合、対象 Spec の writing-spec レビュー指摘対応モードに入り、他 Spec の生成は一時停止

バッチで全 Spec をまとめてレビューする方式はとりません。早期フィードバックで手戻りを最小化するためです。

## 11. 失敗時・アンチパターン

### 11.1 失敗時の対応

- **Critical を抽出できない (= レビュー観点が機能していない)**: ユーザーに「レビュー観点が曖昧で機能しません」と相談。Spec の性質を踏まえた追加観点を提案
- **整合性観点でコードベース走査が完了できない**: 「コードベース規模が大きいため、走査範囲を絞る必要があります」と報告し、対象ディレクトリや検索キーワードをユーザーと合意してから再実行
- **スコア計算結果が極端 (全 0 点 / 全 100 点)**: レビュー観点の運用に問題あり。各観点の指摘内容を見直す

### 11.2 アンチパターン

以下を行ってはいけません。

- ❌ spec.md を読まずにレビュー結果を書き出す
- ❌ review.md を spec.md と同じディレクトリ以外に書き出す (必ず `specs/<spec-name>.review.md`)
- ❌ verdict を独自基準で決定する (§6 のルールに従う)
- ❌ spec.md の frontmatter を本 skill が書き換える (status 変更は writing-spec の責務)
- ❌ pass 以外の verdict で Isolate ステージに進める (必ず writing-spec 再起動)
- ❌ 同一 Spec で無限に再レビューループする (§8.3 の循環防止を遵守)
- ❌ 指摘事項に修正提案を添えない (指摘だけでは writing-spec が対応できない)
- ❌ 「適切にレビュー済」等の曖昧な判定理由を書く (具体的な指摘内容を根拠として示す)
