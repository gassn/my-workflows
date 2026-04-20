---
name: tdd-driver
description: >
  Implement ステージにおいてテスト先行 (Test-Driven Development) を強制する skill。
  本ワークフロー (docs/workflow.md) の Implement ステージを担います。
  spec-leader skill が Plan ステージ完了後に自動起動します。
  加えて「TDD で実装して」「テスト先行で」「tdd-driver 起動」等の明示フレーズでも起動します。
  Phase 3 では skill による指導レベル (developer agent の呼び出し前にテスト存在確認を促す)、
  Phase 4 で PreToolUse hook による物理的強制に移行します (skill 改修不要)。
  superpowers の TDD skill 思想を踏襲します。
---

# TDD Driver Skill

Implement ステージでテスト先行 (Red → Green → Refactor) を強制する skill です。本プロジェクトのワークフロー (`docs/workflow.md`) における Implement ステージを担います。

## 1. 役割と位置づけ

```
... → spec-leader (Plan 完了) → [tdd-driver (本 skill)] → developer agents → Verify
```

本 skill は Plan のタスクを developer agent に割り当てる前に「テストが先に書かれているか」を確認する門番として機能します。Phase 4 で PreToolUse hook が追加された際、本 skill の呼び出し前処理と hook の両方で強制が効く二重防御になります。

## 2. 起動トリガー

### 2.1 自動起動

spec-leader が Implement ステージに入った直後、本 skill を自動起動。入力: Plan ファイルパス。

### 2.2 明示フレーズ

- 「TDD で実装して」「テスト先行で書いて」
- 「tdd-driver 起動」「<タスク名> を TDD で」

## 3. TDD サイクルの強制ルール

### 3.1 Red → Green → Refactor

1. **Red**: 実装予定機能のテストを書き、**失敗する** ことを確認 (実装がまだないため)
2. **Green**: 最小の実装でテストを pass させる
3. **Refactor**: テストが緑のまま構造を整理する

### 3.2 禁止事項

- 実装コードを書いてからテストを後付けする (= テスト後付けのアンチパターン)
- テストなしで実装を完了宣言する
- テストが赤の状態で次のタスクに進む

## 4. Plan のタスクへの適用手順

Plan のチェックボックス T-1, T-2, ... を順番 (または Plan §5.2 の DAG に従って並列) に処理:

1. タスク T-N の「先行して書くテスト」を参照
2. 該当テストファイルが既に存在するかチェック
3. 存在しなければ **テストを先に作成** (Red 確認)
4. developer agent に実装を指示 (最小実装で Green)
5. Refactor フェーズで不要な複雑さ / 重複を削除
6. タスクを `[x]` にマーク、次タスクへ

## 5. テスト存在チェックのロジック (Phase 4 hook 予行演習)

Phase 4 で PreToolUse hook にする前に、Phase 3 では skill 内で同等のチェックを行います。

### 5.1 対象ファイル判定

Edit / Write の対象が「実装ファイル」(src/ / lib/ / internal/ 配下等) なら:

1. 対応するテストファイル (`<file>.test.ts`, `test_<file>.py`, `<file>_test.go` 等) の存在を確認
2. 存在しなければ警告: 「このファイルにはテストがありません。先にテストを作成してください」
3. テストが存在しても `pass` している状態で実装変更する場合、「テストを赤にしてから実装を始めてください」と促す

### 5.2 テスト実行

編集後は関連テストを実行 (`npm test <file>` 等)。Phase 4 では PostToolUse hook で自動実行。

## 6. developer agent との連携

developer agent に渡す指示テンプレート:

```
タスク: T-N (<タスク名>)
Spec: worktrees/<spec-name>/specs/<spec-name>.md §<章>
Plan: worktrees/<spec-name>/plans/<spec-name>.md §5.1 T-N

【前提: テスト先行の遵守】
1. 先にテストを書く (実装が無いため Red 確認)
2. 最小実装で Green
3. Refactor

【成果物】
- テストファイル (<パス>)
- 実装ファイル (<パス>)
- コミット (テストと実装は分けても良いが同一 PR)
```

## 7. 並列タスク実行時の注意

Plan §5.2 で並列可能とされたタスク群を developer agent に並列起動する場合:

- 各タスクの TDD サイクル独立性を確保
- 共通依存ファイル編集の競合回避 (編集 scope が異なることを事前確認)
- 並列起動数の上限は spec-leader の判断に従う

## 8. Phase 4 hook への移行性

Phase 4 で PreToolUse hook を追加する際、本 skill は以下の方針で共存します。

| 責務 | Phase 3 (本 skill) | Phase 4 (hook 追加後) |
|---|---|---|
| テスト存在の確認 | skill 内でチェック | PreToolUse hook で物理的にブロック |
| テスト先行の指導 | skill が developer agent に指示 | 本 skill 継続 (hook は機械的判定のみ、思想は skill) |
| Refactor の促進 | skill 内で促す | 本 skill 継続 |

hook 追加時、本 skill §5 のチェック部分は hook 側に移り、skill は指導 / 促進に集中します。skill のインタフェース (developer agent への指示形式) は変更不要です。

## 9. 失敗時の対応

- テストが書けない (= Plan が曖昧) → Plan に戻って詳細化
- テストが複雑すぎる (= 設計問題) → 該当タスクを分割し Plan 更新
- developer agent がテストを書かずに実装を始める → 中断して TDD サイクルから再開指示

## 10. アンチパターン

- ❌ 実装コードを書いてからテストを後付けする
- ❌ テストが赤のまま次タスクに進む
- ❌ テストなしでタスクを `[x]` にマークする
- ❌ 実装ファイル編集前にテスト存在を確認しない
- ❌ developer agent に「テストは後でいい」と指示する
- ❌ Plan にないタスクを実装する (Plan に追記してから実装)
