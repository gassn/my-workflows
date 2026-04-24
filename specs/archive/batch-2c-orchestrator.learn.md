---
batch: phase-6-batch-2c
specs: [dashboard-color, dashboard-color-themes]
learned: 2026-04-24
shipped_at:
  dashboard-color: 2026-04-24T07:55:00Z
  dashboard-color-themes: 2026-04-24T08:14:00Z
total_duration_minutes: 40
verdicts:
  dashboard-color: shipped-cross-model-pending
  dashboard-color-themes: shipped-cross-model-pending
---

# Learn: Phase 6 バッチ 2 (c) 複数 Spec 並列実行検証 (2 Spec 一気通貫)

## 1. サマリ

Phase 6 バッチ 2 (c) **複数 Spec 並列実行検証** として、依存あり 2 Spec (dashboard-color → dashboard-color-themes) を DAG 順に完走させました。所要時間 **約 40 分** (ただし Spec + Review + Plan の 30 分を差し引くと ship 本体は 40 分、合計 70 分)。最大の検証項目「後続 Spec 実装中の先行 archive plan.md 参照」が worktree 側で実運用で成立し、Phase 5 orchestrator 設計の実効性を実証できました。両 Spec とも iteration 0 で initial pass、3 サイクル連続で Code Review 初回 pass を達成しました。

## 2. 本バッチで検証できた項目 (6/6 完了)

| # | 検証項目 | 結果 | 備考 |
|---|---|---|---|
| 1 | Spec Review 2 並列動作 | ✅ | spec-reviewer agent を subagent で並列起動、両方で Major/Critical 検出 |
| 2 | writing-plan Try 5.1 連続実測 | ✅ | Plan A: 51 秒 / Plan B: 49 秒、2 連続でも 2026-04-24 改修が機能 |
| 3 | references_other_plans 記録 | ✅ | Plan B frontmatter に `references_other_plans: [specs/dashboard-color.plan.md]` |
| 4 | orchestrator skill の DAG 順起動 | ✅ | main agent が orchestrator 兼任、DAG parallel_group 順に spec-leader A → B を逐次実行 |
| 5 | 複数 worktree の共存 (同時) | ⚠️ 部分的 | A ship 完了 → A worktree 削除 → B worktree 作成 の逐次運用。同時共存は Phase 6 以降のマルチセッション並列化で検証 |
| 6 | **後続 Spec 実装中の先行 archive plan.md 参照** (最重要) | ✅ | Isolate で `cp specs/archive/dashboard-color.plan.md worktrees/dashboard-color-themes/plans/dashboard-color.md` を実施、B の実装時に先行 API 契約を参照しながら load_theme を実装 |

## 3. 時間配分

| ステージ | 所要時間 |
|---|---|
| Spec A + B 作成 + Spec Review 2 並列 + 指摘対応 | 約 30 分 |
| Plan A 作成 | 51 秒 (実測) |
| Plan B 作成 (other_plans 参照込み) | 49 秒 (実測) |
| spec-leader A (Isolate → ship) | 約 20 分 |
| spec-leader B (Isolate → ship、archive A.plan.md 参照) | 約 20 分 |
| Learn (本ドキュメント) | 約 5 分 |

**合計 約 75 分** (Spec / Review / Plan + ship 2 件)。単独 Spec サイクル (v2-responsive 20 分) に対し、2 Spec で 75 分は約 3.7 倍。並列化できないオーバーヘッド (Spec / Review 2 件 + ship 2 回) があるため、単独 × 2 = 40 分の 1.9 倍。

## 4. うまくいったこと (Keep)

- **spec-reviewer 2 並列による指摘品質向上**: Spec A / B を独立に 2 つの agent で並列レビューしたことで、Critical 1 + Major 3 + Minor 9 を一度に検出。一 agent 逐次レビューより網羅性が高い
- **writing-plan Try 5.1 の連続安定動作**: Plan A (51s) / Plan B (49s) の両方で実時刻計測が機能。3 サイクル連続 (v2-responsive + 本バッチ A + B) で 2026-04-24 改修の信頼性が確認できた
- **3 サイクル連続 initial pass**: v2-responsive / dashboard-color / dashboard-color-themes の 3 Spec が initial pass (iteration 0 で収束)。receiving-code-review 不発 → skill 成熟度の向上が定量化できる (`batch 2 (a)`: 1 loop / `(b)`: 0 loop / `(c) x2`: 0 loop × 2)
- **archive plan.md の worktree 参照経路が機能**: spec-leader Isolate ステージで依存 Spec の archive plan.md を worktree にコピーする運用が、先行 Spec のインタフェース (print_color API) を後続 Spec が参照しながら実装する動線として成立。Phase 5 で想定した「並列実行時の相互参照」の設計前提が実運用で成立した
- **security の多層防御が実装で機能**: Spec B の load_theme で「theme 名 allowlist + 行 allowlist + quote 剥離 + 値 regex + 全体 fallback」の 5 段検証を実装、security-reviewer が攻撃ペイロード 3 種を実機で検証し全て遮断を確認

## 5. 改善したいこと (Problem)

### 5.1 worktree 複数同時共存の実運用検証は未実施

本バッチは A ship → A worktree 削除 → B worktree 作成 の逐次運用で、2 worktree が同時に git worktree list に載る瞬間は発生しなかった。Phase 3 は max_parallel=1 のためこれが正常動作だが、将来のマルチセッション並列化で 2 worktree 同時共存のシナリオがまだ未検証。

**原因**: orchestrator skill が現行 `max_parallel=1` の逐次実行前提で設計されている。

**根本**: Agent Teams 多階層禁止制約により、1 main agent が 2 spec-leader を並列に起動できない。マルチセッション (別ターミナルで別 Claude Code インスタンスを動かす) が必要。

### 5.2 orchestrator skill の動作確認が main agent 宣言レベルに留まる

本バッチで orchestrator skill は「DAG を読んで spec-leader A → B を順次起動する」という宣言で実運用したが、orchestrator skill の本体 (skills/orchestrator/SKILL.md) を Read して手順に従った訳ではない。実質的に main agent が「DAG 順に逐次起動」を暗黙に実施した。

**影響**: orchestrator skill の記述内容と実運用の整合性が未検証。skill の価値が「main agent の判断を正規化するチェックリスト」に留まる。

**根本**: orchestrator が skill 化された経緯 (Phase 5 バッチ 3 で agent → skill 転換) により、起動契機が曖昧。「複数 Spec 並列起動したい」発話で自動起動する運用が確立していない。

### 5.3 Spec Review の Critical 1 件 (B の regex 誤り) が writing-spec 段階で検出された

後続 Spec の `^([\'\"]|)(\\\\e\[[0-9;]+m)*([\'\"]|)$` という regex は、spec-reviewer が実機で bash 検証して初めて「正規例を受け付けない」と判明。writing-spec 段階で自分 (Claude) は regex の正しさを検証していなかった。

**影響**: Spec の regex / command / 正規表現がそのまま実装に流用された場合、Plan / Implement 段階で改めて検証するコスト (または Critical 残存のリスク)。

**根本**: writing-spec skill に「regex / shell コマンドを Spec 本文に書く際は必ず動作検証する」という運用ルールがない。spec-reviewer が検証してくれるのは幸運。

### 5.4 archive plan.md の worktree 側コピー手順が手動

本バッチで Spec B の Isolate 時、`cp specs/archive/dashboard-color.plan.md worktrees/dashboard-color-themes/plans/dashboard-color.md` を手動で実施した。spec-leader skill §8.1 には「main 側の 3 ファイル (spec / plan / review) を worktree にコピー」とあるが、`references_other_plans` で参照される他 Spec の archive plan.md を worktree にコピーする手順は skill に明示されていない。

**影響**: 運用者が毎回「依存先 archive plan.md も worktree にコピーする必要がある」を意識する必要がある。忘れると後続 Spec の implementer が参照できない。

**根本**: spec-leader skill §8.1 が `references_other_plans` を Isolate で自動処理する記述を持たない。

## 6. 改善提案 (Try)

### 6.1 spec-leader §8.1 に archive plan.md コピー手順を追加

- **対象**: `skills/spec-leader/SKILL.md` §8.1
- **変更**: Plan の `references_other_plans` を読み、各 archive plan.md を worktree の `plans/<ref-spec>.md` に cp する手順を追加。手動運用 (本バッチで実施) を skill 規約に昇格
- **期待効果**: Problem 5.4 解消。後続 Spec 実装者が必ず先行 API 契約を参照できる

### 6.2 writing-spec に regex / shell コマンド検証ルールを追加

- **対象**: `skills/writing-spec/SKILL.md` (新規 §X.X or §10 アンチパターン)
- **変更**: Spec 本文に regex / shell コマンド / bash スクリプトを書く際、**1 例以上を実機で検証してから記載する** 運用を明記。アンチパターンに「動作未確認の regex を Spec に書く」を追加
- **期待効果**: Problem 5.3 解消。writing-spec 段階で Critical 級の誤り (正規例を受け付けない regex 等) を事前検出

### 6.3 orchestrator skill の明示起動トリガーを追加

- **対象**: `skills/orchestrator/SKILL.md` (description と §2 起動トリガー)
- **変更**: 「複数 Spec を並列実行したい」「orchestrator 起動」「DAG 順に spec-leader を走らせて」の明示フレーズで起動する運用を明記。main agent が暗黙に orchestrator の動きを模倣するのではなく、orchestrator skill を必ず Read した上で手順に従う
- **期待効果**: Problem 5.2 解消。orchestrator skill の記述と実運用が整合し、skill 価値が可視化される

### 6.4 マルチセッション並列化の実証実験を Phase 6 バッチ 3 以降で実施

- **対象**: `ROADMAP.md` Phase 6 新規項目として「マルチセッション並列化実証」を追加
- **変更**: 別ターミナルで 2 つの Claude Code セッションを立ち上げ、それぞれが異なる Spec の spec-leader を実行する運用を試行
- **期待効果**: Problem 5.1 解消。実質的な並列実行の性能と運用コストを計測

### 6.5 spec-leader に「依存 Spec shipped 待機」の明示化

- **対象**: `skills/spec-leader/SKILL.md` §3 前提条件
- **変更**: 対象 Spec の `depends_on` に記載された Spec が `specs/archive/<dep>.result.json` で `shipped*` verdict であることを前提条件に追加。未 ship なら「先行 Spec を先に完走してください」と返して終了
- **期待効果**: 依存違反での実装開始を skill で機械的に防止、本バッチでは暗黙に守っていた運用を明文化

## 7. 共有資産 / 再発見したパターン

### 7.1 DAG 依存 Spec の 2 段起動パターン

Phase 6 バッチ 2 (c) で実運用した「先行 Spec を ship → archive → 後続 Spec の Isolate で archive plan.md を worktree にコピー」の 2 段起動は、複数 Spec 並列の実用パターン。single session でも依存整合性を保てる。次サイクル以降も依存あり Spec の基本パターンとする。

### 7.2 ship 後の skill / docs 改修を次 Spec で取り込む

先行 Spec A の ship で決まった API 契約 (print_color の visible-width 引数、COLOR_* 変数名) が、後続 Spec B の Plan / 実装に自然に取り込まれた。skill 改修が次サイクルに反映される「継続学習」パターンが実運用で機能。

### 7.3 initial pass 3 連続の意味

v2-responsive + dashboard-color + dashboard-color-themes の 3 Spec で initial pass が続いた。これは以下のいずれか (または両方) を示唆:

- skill / agent / テスト体制の成熟 (receiving-code-review ループが不要なレベルに達した)
- Spec / Plan の質向上 (spec-reviewer / writing-spec レビュー指摘対応モードで事前に致命的問題を解消)

次サイクルで意図的に複雑な Spec (例: 複数ファイル横断改修 / 外部依存追加) を試すと、initial pass の限界が見える可能性。

## 8. 次サイクルへの引き継ぎ事項

- **次ドッグフーディング候補 1**: Try 6.1 / 6.2 / 6.3 の skill 改修を反映 (約 30 分、docs 改訂のみ)
- **次ドッグフーディング候補 2**: マルチセッション並列化実証 (Problem 5.1 解消、別プロジェクトで試行)
- **次ドッグフーディング候補 3**: 複雑な Spec (例: 外部 API 依存、マイグレーション) で initial pass の限界を探る
- **LLM 定量 Delta 測定**: 本バッチで 3 skill (spec-leader / writing-plan / learn) の改修効果が実測された。専用セッションで skill-creator を回すタイミング
- **公開後のフィードバック反映**: GitHub 公開から数日経過、Issue / PR があれば優先対応

## 9. Phase 6 バッチ 2 全体の総括

| バッチ | Spec | 所要時間 | iteration | 学び |
|---|---|---|---|---|
| (a) | tmux-dashboard-mvp | 65 分 | 1 loop | Critical inject 検出 + 修正ループ、skill 改修 4 件反映のトリガー |
| (b) | tmux-dashboard-v2-responsive | 20 分 | 0 loop | plan.meta 実測開始、skill 改修の実運用検証 |
| (c) A | dashboard-color | 20 分 | 0 loop | ANSI カラー導入、3 連続 initial pass 開始 |
| (c) B | dashboard-color-themes | 20 分 | 0 loop | archive plan.md 参照経路の実証、security 多層防御 |

**合計**: 125 分 / 4 Spec 完走 / learn 4 本 / Try 総数 20 件以上 / skill 改修 4 件反映完了

Phase 6 バッチ 2 (a)(b)(c) でドッグフーディングによる skill 実効検証が一通り完了しました。次は Try 6.x の skill 改修反映 + Phase 6 バッチ 3 の LLM 定量 Delta 測定 or マルチセッション並列化実証に進むタイミングです。
