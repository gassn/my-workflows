---
spec: tmux-dashboard-v2-responsive
learned: 2026-04-24
shipped_at: 2026-04-24T07:12:00Z
total_duration_minutes: 20
verdict: shipped-cross-model-pending
---

# Learn: tmux-dashboard-v2-responsive

## 1. サマリ

Phase 6 バッチ 2 (b) ドッグフーディング第 2 題材として、`tmux-dashboard-mvp` の learn Try 5.2 で挙げた pane 幅適応レイアウト (wide / narrow / compact の 3 モード) を実装し、約 **20 分で完走** (前回 65 分比で 3 分の 1 に短縮) しました。iteration 0 で Code Review が初回 pass、receiving-code-review を経由せず直接 ship に進めた初の事例です。本サイクルの最大の収穫は、**2026-04-24 に反映した 4 件の skill 改修 (Try 5.1 / 5.3 / 5.4 / 5.5) が実運用でそれぞれ意図通り機能したこと** を実測できたことです。

## 2. 時間配分

| ステージ | 所要時間 | 備考 |
|---|---|---|
| Brainstorming | スキップ | 選択肢 A 採用で learn §5.2 を要件の下敷きとして即 writing-spec へ |
| Spec | ~5 分 | 7 章 Spec を一気に記述 + Review Major 2 / Minor 4 反映 |
| Spec Review | ~3 分 (spec-reviewer agent) | verdict: pass、overall 93 |
| Plan | **55 秒 (実測)** | writing-plan Try 5.1 改修の効果で実時刻記録成功 (06:50:52Z → 06:51:47Z) |
| Isolate | ~1 分 | 06:52:00Z 開始〜完了 |
| Implement | ~8 分 | T-1 Red → T-2 refactor → T-3 narrow/compact → T-4 docs |
| Verify | ~5 分 | 19/19 pass + 3 モード実機確認 |
| Code Review | ~5 分 | code-reviewer / security-reviewer 並列、両 pass (iteration 0) + Minor 2 件対応 |
| ship | ~2 分 | main merge + archive 移動 + worktree 掃除 |

**合計**: 約 20 分 (前回 tmux-dashboard-mvp サイクル 65 分比で 3 分の 1 の短縮)。初回 pass (iteration 0) + brainstorming 省略 + plan.meta 計測成功の 3 つが短縮要因。

## 3. うまくいったこと (Keep)

- **initial Code Review pass (iteration 0)**: code-reviewer / security-reviewer の両方が初回で pass 判定。前回サイクルで security-reviewer が Critical 1 件 (shell injection) を検出して reject 返しの原因となった点が、今回は `printf %q` + allowlist が既に反映済の状態で着手できたため再発せず。skill の成熟度向上が実運用で可視化された
- **plan.meta の時刻実測成功 (Try 5.1 効果検証)**: `date -u +%Y-%m-%dT%H:%M:%SZ` を skill 起動直後と Plan 保存直前の 2 回実行する運用が初めて適用され、55 秒という実測値を記録。前回サイクルでは plan.meta が 0 分扱いで統計分析不可だったが、今回から時間配分テーブルに実数が入るようになった
- **worktree 掃除の自動化 (Try 5.4 効果検証)**: spec-leader §13.2 手順 6 の「archive 移動 + worktree 作業ファイル掃除」規約に従い、plans/ / reviews/*.md / verify-report.md を ship commit で `git rm` 掃除。前回は手動で気付いて対応したが、今回は skill の規約通りに機械的に実施できた
- **brainstorming 省略の合理性**: learn §5.2 で既に要件の方向性が固まっていたため、brainstorming skill を起動せず選択肢 A (要件サマリ提示 → writing-spec 直行) を採用。結果として 30-40 分の工数短縮。過去サイクルの成果物 (特に learn.md §5 Try) が次サイクルの brainstorming を代替できることを実証
- **3 モードレンダラの純粋リファクタ**: T-2 で `render_stages_wide` を既存 `render_spec` から切り出す際、出力のバイト列一致を設計段階から念頭に置いたため、既存 14 テストを一切触らずに wide 互換を維持できた。T-test-1a/1b (bash 構文) から T-test-8d (allowlist) まで全て無改修で通った
- **GitHub Actions CI の自動検証**: push 時に 4 ジョブ (tests / frontmatter / hook 構文 / secrets-scan) が走り、手動チェックの抜け漏れを防止。本サイクルで合計 4 回 push したが毎回 10 秒程度で全 pass、開発体験を阻害しなかった

## 4. 改善したいこと (Problem)

### 4.1 iteration 更新規約 (Try 5.3) の実運用検証が先送りになった

- **原因**: iteration 0 で収束したため、receiving-code-review → 再 Implement → 再 Verify → 再 Code Review のループが発生せず、Try 5.3 で追加した iteration 更新規約 (`stages.<stage>.outputs.iteration_N` への追記 / `review_iteration` 更新) を実際に動かす機会がなかった
- **影響**: 改修の効果が「記述ベース実証 (iteration-5 benchmark)」の範囲に留まり、実運用での挙動 (複数 iteration 時の progress.json の見え方、orchestrator が iteration 進行を検知する動線) が未検証のまま
- **根本**: iteration 0 で pass する Spec では Try 5.3 規約は発動しない。意図的に Critical / Major を残した Spec を通すか、複雑な Spec で自然な iteration を狙う必要がある

### 4.2 brainstorming 省略の記録が Spec frontmatter のみ

- **原因**: brainstorming スキップは選択肢 A のユーザー承認に基づくが、Spec frontmatter の `brainstorming_archive: "none (source: ...)"` 以外に記録箇所がない
- **影響**: spec-reviewer が frontmatter を見ないと「brainstorm 省略した Spec」と気付けない。本サイクルでは spec-reviewer が `completeness-M-1` で指摘してくれたため OK だったが、次サイクル以降も同パターンが発生する
- **根本**: brainstorming skill 自体が「省略時の運用」を明示していない。`source: specs/archive/<prev-spec>.learn.md §N` の形式で代替ルートを示す運用ガイドが skill / docs にない

### 4.3 Spec Review の Minor 4 件対応がその場修正で済んだ

- **原因**: spec-reviewer の指摘 (frontmatter / §2.1 矛盾 / 計測手段 / compact truncate / tput cols 補記 / F-4「iteration 2」出典) は writing-spec レビュー指摘対応モードを正式起動せず、私が直接 Edit で Spec を 5 箇所書き換えた
- **影響**: writing-spec skill の「レビュー指摘対応モード」動線が実運用されておらず、本来のモードと今回のやり方で挙動差があるか未検証
- **根本**: spec-review verdict: pass で Major ≤ 2 件のときは writing-spec レビュー指摘対応モードを起動する / しないの閾値が skill 側で明示されていない

### 4.4 9 pane 超の実機検証が未実施

- **原因**: Spec §4 非機能要件の「9 Spec 超で narrow / compact が実用的に読めること」を tmux 実起動で確認しなかった。前回サイクルの最後に 3 pane デモは実施したが、今回は CI の test_dashboard.sh + specs/archive fixture の ONESHOT 描画のみで verification-before-completion を通した
- **影響**: compact モードの実際の見た目 (pane 幅 30 カラム以下で complete な stage リストが読めるか) が机上確認のみ
- **根本**: tmux 実起動検証は Claude Code Bash tool からは interactive attach できないため、ユーザーが手元で検証する運用が必要。本サイクルではユーザーに試してもらう機会を持たなかった

## 5. 改善提案 (Try)

### 5.1 brainstorming 省略時の記録 skill を追加 / writing-spec に記述推奨

- **対象ファイル**: `skills/writing-spec/SKILL.md` (または新 skill `skills/spec-continuation/SKILL.md`)
- **変更内容**: 「過去 learn.md §N / archive からの継続 Spec を起こす場合、frontmatter に `brainstorming_archive: <source>` を必須化、加えて本文 §1 目的の末尾に「継続元: `specs/archive/<prev>.learn.md §N`」を書く」運用を明記
- **期待効果**: Problem 4.2 解消。spec-reviewer が completeness を判定する際に brainstorming 省略の正当性を即判断可能、spec-reviewer が毎回 M-1 指摘を繰り返さない

### 5.2 writing-spec レビュー指摘対応モードの閾値明記

- **対象ファイル**: `skills/spec-review/SKILL.md` + `skills/writing-spec/SKILL.md`
- **変更内容**: spec-review §出力に「verdict: pass でも Major ≥ 1 件あれば writing-spec レビュー指摘対応モードで軽量修正を推奨」の運用ルールを追加、writing-spec 側に「軽量修正」モードの定義を追加 (主 skill を再起動せず Edit のみで対応する場合の手順)
- **期待効果**: Problem 4.3 解消。今回のような「pass + Major 2 + Minor 4」ケースで、私が直接 Edit するか skill を起動するかの判断がプロセスとして揃う

### 5.3 tmux 実起動検証を AC に含めない運用の明文化

- **対象ファイル**: `docs/best-practices.md` + `skills/verification-before-completion/SKILL.md`
- **変更内容**: 「tmux 実起動 / interactive attach を要する AC はユーザー手動検証として Verify 範囲外に分離、verify-report.md の §3.1 保留項目セクションで管理」の運用を明記
- **期待効果**: Problem 4.4 解消。本サイクルで §4 の「9 pane 超」確認が verify-report.md の保留項目に記録されたが、skill 側でこれを「意図通り」と明示すれば、次サイクルから verification-before-completion の verdict: pass 判定の整合性が保たれる

### 5.4 iteration 更新規約の実運用検証用 eval を用意

- **対象ファイル**: `skills/spec-leader-workspace/iteration-6/` (新規)
- **変更内容**: 意図的に Critical / Major を残した fixture Spec を用意し、receiving-code-review を経由する iteration ループを発火させて Try 5.3 規約が正しく動くか検証する benchmark.md を作成
- **期待効果**: Problem 4.1 解消。記述ベース実証から実運用検証 (シミュレーション付き) に格上げできる

### 5.5 3 モード実機デモを docs に GIF / 動画として追加 (非 skill 系 Try)

- **対象ファイル**: `docs/tmux-dashboard-operation.md` (新規セクション / README バッジ)
- **変更内容**: wide / narrow / compact の実際の pane 表示を screenshot (静止画) or asciicast (asciinema) として docs に埋め込む。第三者が本リポジトリを検討する際、文字説明より視覚資料の方が訴求力が高い
- **期待効果**: GitHub 公開後の flipability (「開いた瞬間に価値が伝わる度」) が向上、ベストプラクティス集 §2.6 と組み合わせて導入障壁を下げる

## 6. 共有資産 / 再発見したパターン

### 6.1 brainstorming 省略パターン: learn.md §5 Try の次サイクル直接利用

learn.md §5 Try は「次サイクルで何を作るか」が具体的なパッチ案として書かれている場合、brainstorming を通さず writing-spec の直接インプットとして機能します。本サイクルで Try 5.2 を writing-spec が読み込み、要件 (動機 / スコープ / 機能) を 5 分で Spec 化できた実績があります。将来同様のケースで brainstorming 省略 → writing-spec 直行 → spec-reviewer (Major 許容) のショートカットパスが確立。

### 6.2 純粋リファクタ → 機能追加 の 2 段階アプローチ

本サイクルで T-2 (既存ロジックの関数抽出) と T-3 (新モード追加 + 分岐) を 2 段階に分けたことで、各段階で既存テストの pass を確認しながら進められました。「既存挙動を壊さないリファクタ」を独立したコミットとして切り出すパターンは、今後も大きな機能追加の際に再利用可能です。

### 6.3 iteration 0 pass パターンの認識

learn.md §3.5.1 の省略条件 (iteration 0 = initial pass) が実運用で初めて発動。次サイクル以降は「iteration 0 達成」自体が成熟度指標となり、複数サイクル後に統計を取ると skill / agent の品質向上が可視化されます。

## 7. 次サイクルへの引き継ぎ事項

- **次ドッグフーディング候補 1**: 複数 Spec 並列実行検証 (Agent Teams 実効検証、tmux-dashboard-mvp の Problem 4.5 未解消)
- **次ドッグフーディング候補 2**: Try 5.4 (iteration 更新規約の実運用検証用 eval)、意図的に Major を残した fixture で iteration ループを再現
- **skill 改修キュー**: Try 5.1 / 5.2 / 5.3 の 3 件 (writing-spec / spec-review 改訂)
- **docs 追加キュー**: Try 5.5 (3 モード実機デモの asciicast / GIF)
- **前サイクル引き継ぎ (tmux-dashboard-mvp) の進捗**: Try 5.2 (pane 幅適応) は本サイクルで解消。残 Try 1 件 (cross-model-reviewer の外部モデル連携実装) は Phase 5/6 以降
- **LLM 定量 Delta 測定**: 2 サイクル連続で実施するとデータ量的に有用。専用セッションで skill-creator を回す計画を次セッションで検討
