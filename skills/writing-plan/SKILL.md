---
name: writing-plan
description: >
  承認済み Spec ファイル (worktrees/<spec-name>/specs/<spec-name>.md) を入力として、
  技術設計 + タスク分解を含む Plan ファイル (worktrees/<spec-name>/plans/<spec-name>.md) を
  生成する skill。本ワークフロー (docs/workflow.md) の Plan ステージを担います。
  spec-leader skill が Isolate ステージ完了後に自動起動します。
  加えて「Plan 書いて」「技術設計して」「タスク分解して」等の明示フレーズでも起動します。
  出力は必ず実装可能な粒度のチェックボックス形式タスクリストを含みます。
  Phase 5 で investigator agent がコードベース調査を並列実行する前提のインタフェースを
  Phase 3 時点で確定します (skill 改修不要)。
---

# Writing Plan Skill

承認済み Spec ファイルを入力として、技術設計 + タスク分解を含む Plan ファイルを生成する skill です。本プロジェクトのワークフロー (`docs/workflow.md`) における Plan ステージを担います (spec-kit の Plan + Tasks 相当)。

**用語**: 「Project Phase」「Workflow Stage (ステージ)」「Release Phase」「Spec」の定義は `docs/glossary.md` を参照してください。

## 1. 役割と位置づけ

```
... → spec-leader (Isolate 完了) → [writing-plan (本 skill)] → Implement (tdd-driver + developer)
```

Spec の「何を作るか」を、実装可能な「どう作るか + どの順で作るか」に展開します。worktree 内で完結し、main には影響を与えません。

## 2. 起動トリガー

### 2.1 自動起動 (第一トリガー)

spec-leader skill が Isolate ステージを完了した直後、**本 skill を自動起動** します。入力:

- `worktrees/<spec-name>/specs/<spec-name>.md` (Isolate でコピーされた Spec)
- `worktrees/<spec-name>/` (作業ディレクトリ)

### 2.2 明示フレーズ起動 (第二トリガー)

- 「Plan 書いて」「技術設計して」「タスク分解して」
- 「writing-plan 起動」「<spec-name> の Plan を作って」

## 3. 前提条件の確認

- worktree 内の Spec ファイルの存在
- Spec の frontmatter `status: spec-complete`
- 対応する Plan ファイル (`plans/<spec-name>.md`) が未作成であること (上書き防止)
- 作業ディレクトリが worktree であること (main では動作しない)

前提違反時は明確なエラー文言で停止し、spec-leader に `failed` を返します。

## 4. Plan ファイル章構成

生成する `plans/<spec-name>.md` の章構成:

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

- [ ] T-1: <タスク名> (見積: XX 分)
  - 入力: <前提ファイル / 依存タスク>
  - 出力: <成果物>
  - テスト: <先行して書くテストの概要>
- [ ] T-2: ...
- [ ] T-N: ...

### 5.2 タスク間の依存関係

T-1 → T-2, T-3 (並列可) → T-4 のように DAG を記述。developer agent の並列起動判断に使用。

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
3. 最終確認 (タスク分解の粒度 / 技術選定 / リスク対応)
4. 承認後に `plans/<spec-name>.md` 保存
5. spec-leader に `completed` を返して Implement ステージへ

承認なしに Plan を保存してはいけません。

## 8. 失敗時の対応

- Spec が曖昧でタスク分解できない → Spec への差戻しを提案 (writing-spec レビュー指摘対応モード)
- 既存コードベースとの整合性問題発見 → ユーザー相談、場合により Spec Review に戻す
- 技術的に実現困難 → リスクとして明示し、代替案をユーザーと議論

## 9. アンチパターン

- ❌ Spec を読まずに Plan を書く
- ❌ チェックボックス形式を省略する (Implement の前提崩壊)
- ❌ タスクを 3 時間以上の粒度で定義する (developer が詰まる)
- ❌ テスト先行の記述を省略する (tdd-driver がブロックする)
- ❌ main で本 skill を起動する (worktree 内のみ)
- ❌ ユーザー承認なしに Plan を保存する
