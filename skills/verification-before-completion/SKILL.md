---
name: verification-before-completion
description: >
  完了宣言前にすべての検証 (test / lint / type check / 手動チェックリスト) を
  強制実行する skill。本ワークフロー (docs/workflow.md) の Verify ステージを担います。
  spec-leader skill が Implement ステージ完了後に自動起動します。
  加えて「検証して」「verify」「verification 実行」「完了前チェック」等の
  明示フレーズでも起動します。
  Phase 3 では skill による指導レベル、Phase 4 で Stop hook による完了ブロックに
  移行します (skill 改修不要)。superpowers の verification skill 思想を踏襲します。
---

# Verification Before Completion Skill

Implement ステージ完了後、次ステージ (Code Review) に進む前にすべての検証を強制実行する skill です。本プロジェクトのワークフロー (`docs/workflow.md`) における Verify ステージを担います。

## 1. 役割と位置づけ

```
... → Implement (developer agents 完了) → [verification-before-completion (本 skill)] → Code Review
```

「テスト通った」と主張する前に、客観的な検証 (test / lint / type / 手動チェック) を網羅的に実行し、pass を確認します。Phase 4 で Stop hook と連動し、検証コマンド未実行での完了宣言を物理的にブロックします。

## 2. 起動トリガー

### 2.1 自動起動

spec-leader が Verify ステージに入った直後。入力: worktree パス。

### 2.2 明示フレーズ

- 「検証して」「verify 実行」「verification 回して」
- 「完了前チェック」「Stop 前の検証」
- 「全テスト走らせて」「lint / type もかけて」

## 3. 検証項目 (必須 4 カテゴリ)

### 3.1 テスト

- 全ユニットテスト実行 (`npm test` / `pytest` / `go test ./...` 等)
- 全統合テスト実行 (該当プロジェクトのみ)
- E2E テスト (該当プロジェクトのみ)
- **すべてが pass** していること

### 3.2 Lint

- プロジェクトの lint ツール (`eslint` / `ruff` / `golangci-lint` 等)
- ルール違反なし (warning も 0 を目指すが、プロジェクト規約に従う)

### 3.3 型チェック

- TypeScript: `tsc --noEmit`
- Python: `mypy` / `pyright`
- Go: `go vet` / `staticcheck`
- 型エラーなし

### 3.4 手動チェックリスト

Plan の §6 テスト戦略に記載された E2E 手順を人間が実行する場合:

- UI の golden path が動くこと
- エッジケース (空入力 / 極大入力 / エラー時挙動) が正しく扱われること
- 他機能への回帰がないこと

Spec §5 受け入れ基準を 1 つずつチェックします。

## 4. 検証レポートの出力

パス: `worktrees/<spec-name>/verify-report.md`

````markdown
---
spec: <spec-name>
verified: YYYY-MM-DD
verdict: pass | fail
---

# Verify Report: <spec-name>

## 総合判定

**verdict**: `pass` / `fail`

## 1. テスト
- 実行コマンド: `<command>`
- 結果: pass (XX tests / 失敗: 0)
- ログ (抜粋): ...

## 2. Lint
- 実行コマンド: `<command>`
- 結果: pass
- 警告: N 件 (詳細)

## 3. 型チェック
- 実行コマンド: `<command>`
- 結果: pass

## 4. 手動チェックリスト (Spec §5 受け入れ基準)
- [x] AC-1: ...
- [x] AC-2: ...
- [ ] AC-N: (未実施、理由)

## 失敗時の詳細 (該当時のみ)

...
````

## 5. Stop hook 連携 (Phase 4)

Phase 4 で Stop hook を追加する際、本 skill は以下の方針で共存します。

- **Phase 3**: skill が検証実行 + レポート生成を指導。spec-leader が verdict を確認
- **Phase 4**: Stop hook が「verify-report.md が存在 + verdict: pass」を物理的に確認。違反時は完了宣言 (Stop) をブロック

本 skill のインタフェースは変更不要です。hook は skill の成果物 (verify-report.md) を参照するだけ。

## 6. 失敗時の対応

### 6.1 テスト失敗

- 失敗テストの詳細を verify-report.md に記録
- spec-leader に `failed` を返し、Implement ステージに戻す
- receiving-code-review skill と同様、指摘を Plan のタスクに追加して再実装

### 6.2 Lint / 型エラー

- 修正コミットを作成 (Implement の延長と見なす)
- 修正後に本 skill を再実行

### 6.3 手動チェックリスト fail

- 原因を特定し、Implement に戻す
- Spec 自体の要件ミスマッチなら Spec Review への差戻しを提案

## 7. 検証コマンドの特定方法

worktree 内のファイルを走査して検証コマンドを推定:

- `package.json` の `scripts.test` / `scripts.lint` / `scripts.typecheck`
- `Makefile` の `test` / `lint` ターゲット
- `pyproject.toml` / `ruff.toml` / `mypy.ini`
- `go.mod` (Go プロジェクトなら `go test ./...` / `go vet ./...`)

コマンドが不明な場合はユーザーに確認。推測実行は避ける。

## 8. アンチパターン

- ❌ 一部のテストだけ実行して pass と報告する (必ず全テスト)
- ❌ lint / 型チェックを省略する
- ❌ 手動チェックリストを「確認済」とだけ記載し実体を示さない
- ❌ 検証未実施のまま Code Review ステージに進める
- ❌ 失敗を `pass` と偽って報告する (根拠の verify-report.md が実態と乖離)
- ❌ verify-report.md を生成せずに spec-leader に `completed` を返す
- ❌ 警告を勝手に抑止する (設定変更の判断はユーザーに委ねる)
