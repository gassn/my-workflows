# ベストプラクティス集

本プロジェクトの skill / agent / hook を実際のプロジェクトで活用するためのガイドです。12 種類の skill をシナリオ別に整理し、ドッグフーディングで判明した落とし穴と対処法、Phase 4 hook / Phase 5 orchestrator の活用方法、他プロジェクトへの持ち込み手順までを網羅します。

**対象読者**: 本リポジトリを自分の開発環境に取り込み、Spec 駆動開発を Claude Code で回したいと考えているエンジニア

**前提**: Claude Code v2.1.32 以上がインストール済、本リポジトリを clone 済、`ln -sfn` で skill / agent が `~/.claude/` 配下に有効化済 (README.md の「配置方法」参照)

**読み方**: §2 で全体像を掴み、§3 で着手したい skill を選び、§4 のハマりどころを先読みしてから実作業に入るのがお勧めです。

## 1. 基本フロー: 1 サイクルの全体像

1 つの Spec を Brainstorming から ship + Learn まで通す基本フローは以下の通りです。各ステージは skill が自動 / 半自動で進行します。

```
あなたの発話
  ↓ 「〜したい」「要件整理したい」
brainstorming skill (起点)
  ↓ 要件深掘りノート
spec-dag-builder skill (単一/複数不問、常時 1 ノード DAG 以上を生成)
  ↓ specs/dag.md
writing-spec skill
  ↓ specs/<spec>.md (7 章構成)
spec-review skill (自動、verdict: pass まで反復)
  ↓ specs/<spec>.review.md
writing-plan skill (main 側)
  ↓ specs/<spec>.plan.md + plan.meta.json
spec-leader skill (Isolate → Implement → Verify → Code Review → ship)
  ├─ tdd-driver skill (Implement 段階で Red→Green 強制)
  ├─ verification-before-completion skill (Verify 段階)
  ├─ receiving-code-review skill (差戻し時、最大 3 ループ)
  └─ cross-model-review skill (Phase 3 は placeholder)
  ↓ main merge + specs/archive/ 移動
learn skill
  ↓ specs/archive/<spec>.learn.md (Keep / Problem / Try)
```

複数 Spec を並列で扱う場合は、全体を `orchestrator skill` が統括します (§6 参照)。全サイクルを通して会話圧縮が欲しい場面では `genshijin-without-docs` skill を `/genshijin-without-docs` で起動します。

### 1.1 典型的な所要時間の目安

Phase 6 バッチ 2 (a) の `tmux-dashboard-mvp` ドッグフーディング実績では、Brainstorming → Learn まで **約 65 分** で完走しました。内訳は Isolate 5 分 / Implement 25 分 / Verify 10 分 / Code Review 20 分 / ship 10 分 / iteration 1 ループ +15 分 です。Spec の複雑度やレビュー loop 回数で前後しますが、**単一 Spec なら 1-2 時間が目安** として覚えておくと良いです。

### 1.2 中断と再開

各 skill は `specs/<spec>.progress.json` / `result.json` に機械可読な進捗を残します。Claude Code セッションを中断しても、次セッションで spec-leader を明示起動すれば再開モードに入り、`current_stage` から続行可能です (`skills/spec-leader/SKILL.md §14` 参照)。

## 2. skill 別利用例

各 skill の起動条件、典型的な発話、落とし穴を実例ベースで整理します。

### 2.1 brainstorming: 要件整理を始める

**起動発話**:

- 「要件整理したい」「機能追加したい」「Spec 書きたい」「やりたいことがあるんだけど」

**使い方の実例**:

「Phase 5 の orchestrator が動いている様子を見たい」のような漠然とした要望から、`brainstorming` は以下を順に深掘りします。

1. 動機と使用シナリオ (誰が / いつ / 何を知りたいか)
2. スコープ (含むもの / 含まないもの)
3. 制約 (技術的 / 運用的 / 期限)
4. 未解決事項 (TBD)
5. 複数 Spec に分けるべきか 1 Spec で十分か

**落とし穴**: brainstorming は全文を毎セッション常駐させると context が大きいため、**Phase 4 で SessionStart hook に skill インデックス方式** (using-superpowers パターン) を採用しています。skill 自体は必要時に `Read skills/brainstorming/SKILL.md` で読み込みます。初回起動は少し遅く感じても気にしないでください。

### 2.2 spec-dag-builder: 依存関係を整理する

**起動発話**:

- 「DAG 作って」「依存関係整理」「分割した Spec の順序決めて」
- brainstorming / spec-review 後に**自動起動**

**重要な設計**: 2026-04-22 改修で「**単一 Spec も 1 ノード DAG を生成**」するよう変更されました。これにより下流 skill (writing-plan / spec-leader) は常に `specs/dag.md` を参照して動作でき、単一 / 複数の分岐が削除されました。

**複数 Spec の場合**の実例:

```
ecsite-mvp-auth     (depends_on: [])                      → parallel_group: 1
ecsite-mvp-catalog  (depends_on: [])                      → parallel_group: 1
ecsite-mvp-order    (depends_on: [auth, catalog])         → parallel_group: 2
ecsite-mvp-payment  (depends_on: [order])                 → parallel_group: 3
```

**落とし穴**: 依存関係の推測根拠は必ずユーザーに表で提示して承認を取ります。自動で `depends_on` を書き込まないでください (skill 側で禁止)。

### 2.3 writing-spec: Spec を書く

**起動**: brainstorming 完了後に**自動起動**、または「Spec 書いて」

**出力**: `specs/<spec>.md` の 7 章構成 (1. 目的 / 2. スコープ / 3. 機能要件 / 4. 非機能要件 / 5. 受け入れ基準 / 6. 非対象 / 7. リスク)

**実例のポイント**:

- 機能要件は **「コマンド + 入力 + 出力 + エラーハンドリング」** の 4 点セットで記述 (`tmux-dashboard-mvp` の §3.1 が参考)
- 受け入れ基準は **チェックボックス形式の AC-1, AC-2, ...** で、Verify ステージの verify-report.md と 1:1 対応させる
- 非対象 (スコープ外) を明示すると spec-review §4.1 完全性チェックで「将来拡張」指摘を防げる

### 2.4 spec-review: 3 観点で Spec を自動レビュー

**起動**: writing-spec 完了後に**自動起動**

**観点**: 完全性 / 実現可能性 / 整合性の 3 観点から Critical / Major / Minor / Nits を列挙し、`verdict: pass | needs-fix | reject` を確定します。

**ループ運用**: `needs-fix` / `reject` の場合は writing-spec のレビュー指摘対応モードに戻り、Spec を修正後に再度 spec-review を走らせます。実運用では 1-2 loop で pass に至るのが標準です。

### 2.5 writing-plan: 技術設計 + タスク分解

**起動**: spec-review verdict: pass 後に**自動起動**、または「Plan 書いて」

**重要な設計**: **main ブランチ側で動作** します (2026-04-22 改修)。Isolate より前に配置することで、並列 spec-leader が他 Spec の `specs/*.plan.md` を参照可能にしています。

**タスク分解のルール**:

- 1 タスク = **30-60 分で完了する単位** を目安
- `files_touched` 配列を**必須**、並列判定に利用 (空配列禁止)
- 共通ファイル編集はすべて **T-integrate 集約タスクで最終工程に分離**

**plan.meta.json**: 時刻は `date -u +%Y-%m-%dT%H:%M:%SZ` で skill 起動直後と Plan 保存直前の 2 回取得します。両値を同値で書くのは未計測扱いと等価なため禁止 (2026-04-24 改修で Try 5.1 として明文化)。

### 2.6 spec-leader: 5 ステージ遷移制御の中核

**起動**: writing-plan 完了後に**自動起動**、または「spec-leader 起動」

**ステージ**: Isolate → Implement → Verify → Code Review → ship

**Phase 5 改修不要の契約**:

- 入力: `spec_path` (spec.md の相対パス)
- 出力: `progress.json` / `progress_md_path` / `result.json`

この契約により、Phase 5 の orchestrator が複数 Spec を並列起動する際も spec-leader 側の改修は不要です。

**iteration ループ**: receiving-code-review が差戻しを反映して Implement → Verify → Code Review を再実行するループは最大 3 回です。ループ中も main 側 progress.json を更新し続ける運用が 2026-04-24 で明文化されました (Try 5.3)。

**ship 時の main 掃除**: worktree 側の作業ファイル (`plans/<spec>.md` / `progress.md` / `reviews/*.md` / `verify-report.md`) は merge で main に流入するため、ship commit で明示的に `git rm` します (2026-04-24 Try 5.4)。

### 2.7 tdd-driver: TDD の Red → Green 強制

**起動**: spec-leader Implement ステージ内で developer agent と連携

**使い方**: 実装前にテストが存在しない場合、PreToolUse hook (`pre-tool-use-tdd.sh`) が Edit/Write をブロックします。`SKIP_TDD_HOOK=1` で bypass 可能ですが、原則として先にテストを書く流れを崩さないことを推奨します。

### 2.8 verification-before-completion: 4 カテゴリ検証

**起動**: spec-leader Verify ステージで**自動起動**

**検証対象**: test / lint / type / 手動 AC の 4 カテゴリ。実行結果を `verify-report.md` に記録し、全 pass なら verdict: pass を返します。

**bash スクリプトのみの Spec** (tmux-dashboard-mvp 等) では lint / type カテゴリは `bash -n` 構文チェックに集約します。型システムを持たない言語では「該当なし」と明示すれば OK です。

### 2.9 receiving-code-review: レビュー差戻しを実装に反映

**起動**: Code Review verdict 不一致時に**自動起動**、または「review 指摘を反映して」

**手順**:

1. code.md / security.md / cross-model.md の指摘を集約 → `consolidated.md`
2. Plan に `T-fix-<iter>-<番号>` タスクを追加 (frontmatter を `status: plan-revised` + `review_iteration: N` に更新)
3. Critical は必ず / Major は原則 / Minor は個別判断で対応
4. Implement → Verify → Code Review を再実行

**循環防止**: 同一 Spec で 3 ループ超過時は自動実行を停止し、Spec / Plan の再設計をユーザーに相談します。

### 2.10 cross-model-review: 他モデルによる独立審査

**起動**: spec-leader Code Review ステージ内で 3 reviewer のうち 1 つとして

**Phase 3 の運用**: 外部モデル API 呼び出しは未実装のため **PENDING placeholder** として動作します。code.md / security.md と同じ構造のファイルを `verdict: PENDING, mode: placeholder` で生成し、最終 verdict 算定から除外します。これにより spec-leader は `shipped-cross-model-pending` を返します。

**Phase 5/6 で外部モデル連携が実装された際、本 skill のインタフェース (入出力ファイル) は変更不要で、内部の呼び出しロジックだけ差し替える設計です。

### 2.11 orchestrator: 複数 Spec 統括 (Phase 5)

**起動発話**: 「複数 Spec 並列実行」「orchestrator 起動」

**動作**: `specs/dag.md` を読み、`parallel_group` 順に spec-leader を順次起動します (Phase 5 バッチ 3 で agent → skill に転換済、main agent が spec-leader と orchestrator を兼任)。詳細は §6 を参照してください。

### 2.12 genshijin-without-docs: 会話圧縮モード

**起動**: `/genshijin-without-docs` で起動

**用途**: トークン使用量を約 75% 削減。会話返答のみ圧縮し、`.md` ファイル / コメント / コミットメッセージ / PR 本文は丁寧な日本語を維持します。強度は丁寧 / 通常 / 極限の 3 段階で、デフォルトは極限です。

**切替**: `/genshijin-without-docs 丁寧`、`/genshijin-without-docs 通常`、`/genshijin-without-docs 極限`

**解除**: 「原始人やめて」「通常モード」

## 3. ハマりどころ集

ドッグフーディングと設計レビューで判明した落とし穴を優先度順にまとめます。新規ユーザーは **§3.1 〜 §3.5 を先に読んでから** 実作業に入ってください。

### 3.1 [最重要] Agent Teams 環境変数の有効化

`~/.claude/settings.json` の env セクションに以下が必要です:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

前提 Claude Code バージョンは **v2.1.32 以上**。subagents (Agent tool) 自体は有効化なしでも動作しますが、Agent Teams の並列 orchestration や `/agents` コマンドは環境変数がないと使えません。

設定変更は**セッション再起動で反映**されます。現セッションで環境変数を追加しても、次セッションから効く点に注意してください。

### 3.2 [重要] worktree 内で skill を起動しない (一部 skill のみ)

**main 側で動かすべき skill**:

- writing-plan (Plan は main 側に配置、他 Spec からの参照用)

**worktree 側で動かすべき skill**:

- spec-leader 内部 (Isolate 完了後、Implement / Verify / Code Review / ship)

**どちらでも動く skill**:

- brainstorming / writing-spec / spec-review / orchestrator / learn

worktree を切り替えたつもりで main 側で spec-leader Implement をやってしまうと、テストや実装が main に直接書かれて混乱の原因になります。`git worktree list` と `pwd` で現在地を常に確認する習慣を付けてください。

### 3.3 [重要] ship 時の worktree 作業ファイル掃除

spec-leader §13.2 の手順 6 で `archive 移動 + main 掃除` を同一 commit 内で実施します。掃除対象:

- `plans/<spec>.md` → `git rm` (main 側は archive に残る)
- `progress.md` → `git rm` (archive には JSON のみで十分)
- `reviews/code.md` / `security.md` / `cross-model.md` → `git rm` (consolidated.md を archive に残す)
- `verify-report.md` → `git rm` (Verify 結果は progress.json の outputs に構造化済)

`tmux-dashboard-mvp` サイクルでは、この掃除で **1309 行 → 752 行削減** の実績があります。掃除漏れがあると main history が作業ログで膨らみ、リポジトリ転用時の第一印象を悪化させます。

### 3.4 [重要] iteration 中の main 側 progress.json 更新

receiving-code-review による再 Implement → 再 Verify → 再 Code Review ループ中も、main 側 `specs/<spec>.progress.json` を更新し続けてください。更新を怠ると ship 直前にユーザーや orchestrator が古い状態を見て「ステージが止まっている」と誤認します (tmux-dashboard-mvp サイクルで実際に発生)。

iteration 番号は frontmatter の `review_iteration` に記録、各 iteration の実施記録は `stages.<stage>.outputs.iteration_N` に追記します。

### 3.5 [重要] Plan の時間計測を忘れない

writing-plan skill が生成する `plan.meta.json` の `plan_started_at` / `plan_completed_at` は、**skill 起動直後と Plan 保存直前** の 2 回 `date -u +%Y-%m-%dT%H:%M:%SZ` で取得します。両値を同値で書くと未計測扱いになり、learn skill の §2 時間配分テーブルで N/A になります。

複数 Spec で時間計測を蓄積すると「Plan が長引く Spec の傾向」を統計的に検出できるため、初手から正しく計測してください。

### 3.6 worktree ファイルコピー時の `cp` 厳守

spec-leader Isolate ステージで main 側 Spec / Plan / Review を worktree にコピーする際、**必ず `cp` を使い、`mv` や `git mv` は使いません**。worktree は main と同一 git 空間のため、rename 操作が commit に乗ると merge で main 側ファイルが消失する事故が起きます (iter-5 で実測)。

### 3.7 sub-worktree 方式の並列実行は任意

spec-leader Implement ステージで並列実行する場合、タスクごとに `git worktree add worktrees/<spec>/sub-<task-id>` で sub-worktree を作成し、独立 index で commit させてから親 worktree で `git cherry-pick` 統合します。

Phase 3 初期は Agent Teams の多階層 subagent 制約から並列実行が動作しなかったため、**sub-worktree 方式は任意** です。順次実行 (全タスクを直列、親 worktree で 1 つずつ) でも spec-leader は動作します。`options.parallel_implement: true` で有効化できます。

### 3.8 Spec 名の命名規則

Spec 名は **kebab-case (`^[A-Za-z0-9][A-Za-z0-9._-]*$`)** に統一してください。先頭は英数字必須、2 文字目以降はハイフン / ドット / アンダースコアが使えます。`tmux-dashboard-mvp` / `ecsite-mvp-auth` / `api-refactor-phase2` のような形です。スペース / 日本語 / 特殊文字を含むと、tmux-dashboard の allowlist や git ブランチ名制約に引っかかります。

命名規則として `<project>-<release-phase>-<feature>` を推奨します。Release Phase 順序 (`mvp` → `phase2` → `phase3`) から自動依存推測が効きます。

### 3.9 cross-model-reviewer は Phase 3 では PENDING

Phase 3 の cross-model-reviewer は外部モデル連携未実装のため、最終 verdict は必ず `shipped-cross-model-pending` になります。これは「未完成」ではなく「Phase 3 の設計上の placeholder」です。Phase 5/6 で外部モデル連携が実装されると、同じ Spec について retroactive に再レビューが可能になります。

### 3.10 skill / agent の配置はシンボリックリンク

リポジトリ内で開発 (`~/my-workflows/skills/*`) し、`~/.claude/skills/` へ `ln -sfn` で公開する方針です。実体を `~/.claude/skills/` に置くと、リポジトリと実環境の同期が崩れます。

## 4. Phase 4 hook 連携のベストプラクティス

Phase 4 で 8 種類の hook を実装済です。典型的な組み合わせ:

| hook | 発火タイミング | 効果 |
|---|---|---|
| SessionStart | セッション起動 | skill インデックス + 起点 skill 常駐 (using-superpowers 方式) |
| PreToolUse (Edit/Write) | ファイル編集前 | TDD 強制 (テスト不在で block、worktree 内のみ) |
| PostToolUse (Edit/Write) | ファイル編集後 | テストファイル変更時に自動実行 (warning) |
| Stop | 完了宣言前 | verify-report.md + verdict: pass 確認 (warning) |
| InstructionsLoaded | CLAUDE.md / spec ロード時 | 関連ファイルを additionalContext に追加 |
| WorktreeCreate | Claude Code 管理 worktree 作成時 | Spec/Plan/Review コピー + progress.md 初期化 |
| WorktreeRemove | worktree 削除前 | 未コミット警告 + progress.md archive バックアップ |
| TaskCompleted | TaskUpdate status=completed 時 | worktree 内 progress.md にタスク完了ログ追記 |

### 4.1 bypass 環境変数

hook が意図せぬタイミングで発火した場合の緊急回避:

- `SKIP_TDD_HOOK=1`: PreToolUse TDD 強制を bypass
- `SKIP_AUTO_TEST_HOOK=1`: PostToolUse 自動テストを bypass

原則として設計通りの挙動を優先し、bypass は本当に必要なときだけ使ってください。

### 4.2 hook 段階化の原則

Phase 4 以前に急いで hook 化しないでください。skill が成熟してから (実運用 5-10 サイクル、learn.md に同じ問題が複数回出現) 初めて hook 化を検討する段階論が設計思想です (`docs/hookify-setup.md` 参照)。

早すぎる hook 化は挙動の制御を失わせ、原因特定が困難になります。

## 5. Phase 5 orchestrator 活用 (複数 Spec 並列)

### 5.1 前提

- 複数 Spec (2 件以上) が `specs/` 配下にある
- 各 Spec の frontmatter に `status` / `depends_on` / `parallel_group` が設定されている
- `specs/dag.md` が最新 (spec-dag-builder を直近で起動済)

### 5.2 起動と動作

```
main agent が orchestrator skill を起動
  ↓ specs/dag.md 読み込み、parallel_group 順ソート
parallel_group 1 の Spec A, B を順に:
  main agent が spec-leader skill を A で起動 → ship
  main agent が spec-leader skill を B で起動 → ship
parallel_group 2 の Spec C:
  main agent が spec-leader skill を C で起動 → ship
...
```

**重要な制約**: 「Subagents cannot spawn their own subagents」により、main agent が orchestrator と spec-leader を**兼任**します。orchestrator から spec-leader を subagent で呼ぶことはできません。

### 5.3 Phase 6 以降の並列化

現状の `max_parallel=1` (逐次実行) から並列実行に進化させるには、マルチセッションが必要です。Claude Code を複数ターミナルで同時起動し、各セッションで異なる Spec の spec-leader を動かす運用が Phase 6 以降の検討事項です (ROADMAP.md 参照)。

## 6. 他プロジェクトへの持ち込みガイド

本リポジトリを自分の別プロジェクトで使うための手順です。

### 6.1 最小セットアップ

```bash
# 1. clone
git clone https://github.com/<your-github>/my-workflows ~/my-workflows
cd ~/my-workflows

# 2. 各 skill / agent を有効化
for dir in skills/*/; do
  name=$(basename "$dir")
  ln -sfn "$PWD/$dir" "$HOME/.claude/skills/$name"
done
for file in agents/*.md; do
  name=$(basename "$file")
  ln -sfn "$PWD/$file" "$HOME/.claude/agents/$name"
done

# 3. Agent Teams 有効化
# ~/.claude/settings.json の env に "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" を追加

# 4. 対象プロジェクトで specs/ ディレクトリを作成
cd ~/your-project
mkdir -p specs/archive worktrees
```

### 6.2 プロジェクト固有の設定

対象プロジェクトに `CLAUDE.md` を配置し、以下を明記すると skill が精度良く動きます:

- 使用言語 / テストフレームワーク (Verify ステージで該当コマンドを実行させるため)
- コミットメッセージ規約 (日本語 / 英語、Conventional Commits など)
- Spec 命名規則の前提 (kebab-case / project prefix など)

### 6.3 最初の 1 Spec を回す

```
あなた: 「<何か機能> を作りたい」
  → brainstorming skill が起動
  → 要件深掘り対話
  → spec-dag-builder が 1 ノード DAG 生成
  → writing-spec で Spec 作成
  → spec-review で verdict: pass
  → writing-plan で Plan + タスク分解
  → spec-leader で Isolate → Implement → ... → ship
  → learn で振り返り
```

初回は 1-2 時間を見込んでください。慣れると次第に短縮されます。

### 6.4 skill の選択的有効化

全 12 skill を一括で有効化する必要はありません。以下の段階導入を推奨します:

1. **入門段階**: brainstorming / writing-spec / writing-plan の 3 skill のみ (Spec を書く習慣を作る)
2. **中級段階**: spec-review / spec-leader / tdd-driver / verification-before-completion を追加 (自動化フローに乗せる)
3. **上級段階**: receiving-code-review / cross-model-review / orchestrator / learn を追加 (品質サイクル + 複数 Spec 管理)
4. **必要に応じて**: genshijin-without-docs / spec-dag-builder

Phase 4 hook も段階導入を推奨します。まず SessionStart + InstructionsLoaded だけ有効化し、skill が成熟してから PreToolUse / PostToolUse を加える流れが安全です。

### 6.5 Fork ではなく参照

本プロジェクトの設計思想として「Fork しない」を掲げています。他プロジェクトで使うときも、**独自の skill は自プロジェクトの skills/ 配下に作成**し、本リポジトリの skill は参照用としてシンボリックリンクで取り込む運用を推奨します。本リポジトリをアップデートした際に、自プロジェクトの独自 skill と競合しません。

### 6.6 カスタマイズしたいとき

- **skill の振る舞いを変えたい**: 元 skill を `~/.claude/skills/` へ直接コピーしてから編集 (シンボリックリンクを外す)
- **新 skill を追加したい**: 自プロジェクトの `skills/<new-skill>/SKILL.md` を作成、本リポジトリの `skill-creator` を参考に frontmatter 構造を踏襲
- **hook を追加したい**: `docs/hookify-setup.md` の手順でカスタム hook を登録

## 7. 関連ドキュメント

| ドキュメント | 用途 |
|---|---|
| `README.md` | プロジェクト概要、配置方法、利用開始ガイド |
| `ROADMAP.md` | Phase 1-6 の段階的構築計画 |
| `CLAUDE.md` | Claude Code へのプロジェクト固有ガイダンス |
| `docs/workflow.md` | 9 ステージ + 3 層階層のワークフロー定義 |
| `docs/components-map.md` | skill / agent / hook の Mermaid 図 + 使用ツール / コマンドマトリクス |
| `docs/glossary.md` | Project Phase / Workflow Stage / Release Phase / Spec の用語定義 |
| `docs/frameworks.md` | 参考フレームワーク一覧と取捨選択方針 |
| `docs/memory-operation.md` | Claude Code auto memory の本プロジェクト運用方針 |
| `docs/phase3-completion.md` / `phase4-completion.md` / `phase5-completion.md` | 各 Phase の完了レポート |
| `docs/hookify-setup.md` | hookify プラグイン導入ガイド |
| `docs/tmux-dashboard-operation.md` | tmux ダッシュボード運用ガイド (本プロジェクト最初のドッグフーディング成果) |

個別 skill の詳細は `skills/<skill-name>/SKILL.md` を、agent の詳細は `agents/<agent-name>.md` を、hook の実装は `hooks/<hook-name>.sh` を直接参照してください。

## 8. よくある質問

### Q. Phase 3 の placeholder とは何ですか?

外部モデル連携など「インタフェースは確定しているが、実装は後 Phase に先送り」の状態を指します。Phase 3 の cross-model-reviewer は placeholder で、`verdict: PENDING` を返します。

### Q. skill は自動で起動しますか、それとも明示発話が必要ですか?

両方あります。各 skill の `description` 内「起動条件」に記載された**トリガーフレーズ**で自動起動するほか、明示発話 (「spec-leader 起動」等) でも起動可能です。ワークフロー連鎖 (writing-spec → spec-review → writing-plan → spec-leader) は自動起動で繋がります。

### Q. Claude Code の Desktop app や VS Code 拡張でも使えますか?

skill / agent / hook の仕組み自体は Claude Code の共通機能のため、CLI / Desktop / VS Code 拡張で同等に動作します。ただし本リポジトリの bash hook は CLI 実行を前提とした部分があるため、Desktop / VS Code では一部調整が必要かもしれません (未検証、Phase 6 以降で確認予定)。

### Q. 会話が長くなると context が逼迫しませんか?

Phase 4 で導入した using-superpowers パターン (SessionStart hook で skill インデックスのみ常駐、必要時に `Read skills/<name>/SKILL.md`) により、当初の 30KB → 10.8KB に圧縮済です。それでも長いサイクルで逼迫する場合は `/genshijin-without-docs 極限` を併用してください。

### Q. 本プロジェクトの最新状態はどう把握すればいいですか?

以下の順で参照してください:

1. `ROADMAP.md`: 全 Phase の目標と完了項目
2. `docs/phase<N>-completion.md`: 各 Phase の完了レポート
3. `docs/components-map.md`: skill / agent / hook の現在地
4. `specs/archive/*.learn.md`: ドッグフーディングで得られた知見

### Q. 貢献したいのですが、PR は受け付けていますか?

本プロジェクトは「個人用の Claude Code 環境最適化」を目的としているため、PR より Issue による提案や Fork しての独自進化を歓迎します。詳細は `README.md §貢献 / フォーク` を参照してください。
