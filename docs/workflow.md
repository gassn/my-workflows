# 開発ワークフロー定義

本プロジェクトで Claude Code を運用する際の標準ワークフローを定義します。複数フレームワーク (superpowers / spec-kit / OpenSpec / claude-scrum-team / BMAD-METHOD 等) の良い部分を取捨選択した独自合成です。

**用語**: 本ドキュメント内の「Project Phase」「Workflow Stage (ステージ)」「Release Phase」「Spec」の定義は `docs/glossary.md` を参照してください。「フェーズ」という単独表記は使用せず、文脈に応じて適切な用語を使い分けます。

## 設計原則

1. **段階的構築**: 単一 Spec から開始し、複数 Spec 並列対応は後続 Phase で導入します
2. **極力自動化**: Agent Teams を活用し、並列化可能なステージはすべて並列実行します
3. **テスト品質担保**: TDD 強制と完了前検証強制を hook で固定化します
4. **階層分離**: orchestrator / specLeader / workers の 3 層に責務を明確に分けます
5. **拡張可能なインタフェース**: Phase 3 時点で「将来 orchestrator から呼ばれる前提」のインタフェースを確定し、Phase 5 で specLeader を改修不要にします
6. **Spec 前のヒアリング必須**: いきなり Spec を書き始めず、必ず Brainstorming ステージで要件を深掘りします。曖昧な要件のまま Spec を書くと後続ステージすべてが手戻りするため、起点ステージとして固定化します

## 階層構造 (3層)

```
orchestrator (Phase 5 で実装)
  ├── specLeader (Spec A 担当)
  │     ├── developer agents (タスク並列)
  │     ├── reviewer agents (code / security / cross-model)
  │     └── verifier agent
  ├── specLeader (Spec B 担当)
  │     └── ...
  └── specLeader (Spec C 担当)
        └── ...
```

### 各層の責務

| 層 | 役割 | 起動主体 | 実装 Phase |
|---|---|---|---|
| **orchestrator** | 複数 Spec の DAG 管理、specLeader 起動、merge 順序制御 | ユーザー / main agent | Phase 5 |
| **specLeader** | worktree 作成、ステージ遷移制御 (Plan → Implement → Verify → Code Review)、配下 agent 起動、進捗報告 | orchestrator (Phase 5 以降) または main agent (Phase 3) | Phase 3 |
| **workers** (developer / reviewer / verifier) | 単機能タスクの実行 | specLeader | Phase 3 |

### Phase 3 設計方針 (orchestrator 不在前提)

- specLeader は **単独動作可能** に作ります
- 将来 orchestrator から呼ばれる前提のインタフェースを Phase 3 時点で確定します
  - **入力**: spec ファイルパス
  - **出力**: 進捗ファイル + 結果ファイルのパス
- Phase 5 で orchestrator を追加する際、specLeader の改修は不要にします

## ワークフロー全体像

```mermaid
flowchart LR
    Z[Brainstorming] --> X[DAG 構築<br/>暫定]
    X --> A[Spec]
    A --> B[Spec Review]
    B -->|承認| X2[DAG 構築<br/>確定]
    B -->|差戻し| A
    X2 --> D[Plan]
    D --> C[Isolate]
    C --> E[Implement]
    E --> F[Verify]
    F -->|失敗| E
    F -->|成功| G[Code Review]
    G -->|失敗| E
    G -->|成功| H[ship]
    H --> I[Learn]
    I -.->|skill 改善| Z
```

**DAG 構築ステージは段階的アップデート方式**: 同一 skill を Brainstorming 直後 (暫定 DAG) と Spec Review 完了後 (確定 DAG) の 2 回起動します。**単一 Spec の場合も 1 ノード DAG を生成** する統一フロー (2026-04-22 改修、分岐削除)。下流 skill (writing-spec / writing-plan / spec-leader) は常に `specs/dag.md` を実行順序源として参照します。

## 各ステージ詳細

### 0. Brainstorming

**目的**: ユーザーの曖昧な要望を質問の往復で深掘りし、Spec を書ける状態まで要件を解像度上げます (superpowers の brainstorming 参考)。

| 項目 | 内容 |
|---|---|
| 担当層 | main agent (対話) |
| 入力 | ユーザーの自然言語要望 (曖昧なものを含む) |
| 出力 | 要件サマリ (Brainstorming ノート、Spec の素材) |
| Agent Teams 活用 | × (対話必須) |
| 品質ゲート | 「ユーザーが Spec ステージへの移行を明示的に承認したか」を hook で確認 |

**起点ステージとして固定化**: 設計原則 6 のとおり、いきなり Spec を書くことを禁じます。曖昧な要件のまま Spec に進むと後続ステージすべてが手戻りするためです。

**コードベース精査**: 本ステージでは AI が能動的に既存コードベースを精査します。起動直後の軽スキャン (ディレクトリ構造 / `CLAUDE.md` / `README` / マニフェストファイル / `specs/` 配下) と、ヒアリング中の深スキャン (関連キーワード `Grep` / 既存実装 / テストパターン / `git log`) の 2 段階で実施します。精査で判明した事項はユーザーへ質問せず、推測内容の確認を求める形にして質問数を絞ります。詳細手順は `skills/brainstorming/SKILL.md` のセクション 11 を参照してください。Phase 3 では brainstorming skill 内で精査を完結させますが、Phase 5 で `investigator` agent の役割を「Brainstorming + Plan 両ステージで使用」に拡張し、重い精査を agent に委譲する設計に移行します。

**スコープ過大時の分割**: ヒアリング結果が単一 Spec として大きすぎると判定した場合、本ステージで複数 Spec への分割を提案します。分割軸 (機能 / Release Phase / データ / 層) と分割案をユーザーに提示し、承認を得てから複数の Brainstorming ノートを生成します。分割判定基準と運用ルールは `skills/brainstorming/SKILL.md` のセクション 10 に記載されています。分割後のノートには Spec 間依存関係 (`depends_on`) を明記し、Phase 5 の orchestrator が DAG 解決に利用できるようにします。

**Brainstorming ノート配置**: `specs/<spec-name>.brainstorm.md` (Spec ファイルと並置、main ブランチ側)。分割時は共通接頭辞を使用 (例: `specs/ecsite-auth.brainstorm.md`, `specs/ecsite-payment.brainstorm.md`)。

### 0.5. DAG 構築 (Brainstorming で複数 Spec に分割した場合のみ)

**目的**: 複数 Spec の依存関係を解析し、orchestrator (Phase 5) が起動順序を判断できる DAG を構築します。

| 項目 | 内容 |
|---|---|
| 担当層 | main agent (対話、`spec-dag-builder` skill 起動) |
| 入力 | 複数の Brainstorming ノート (`specs/*.brainstorm.md`) |
| 出力 | 各ノートへの `depends_on` / `parallel_group` / `status` 追記 + `specs/dag.md` (Mermaid 図 + 並列実行グループ + 推奨実行順序) |
| Agent Teams 活用 | × (対話 + 推測ロジックは main agent で実行) |
| 品質ゲート | 循環依存 (cycle) 検出時はエラーを返し、Brainstorming ステージへ差し戻し |

**段階的アップデート方式**: 同一 skill (`spec-dag-builder`) を 2 回起動します。

- **1 回目 (Brainstorming 直後)**: 暫定 DAG。全 Spec が `brainstorming-complete` 段階のため依存関係は粗い推測。`specs/dag.md` の冒頭に警告メッセージを含める
- **2 回目 (Spec Review 完了後)**: 確定 DAG。詳細仕様を反映した正確な依存関係。orchestrator はこの確定 DAG を消費する

**スキップ条件**: 2026-04-22 改修により本ステージはスキップしなくなりました。単一 Spec の場合も 1 ノード DAG を生成します (`skills/spec-dag-builder/SKILL.md` §3 参照)。これにより下流 skill (writing-spec / writing-plan / spec-leader) が dag.md を唯一の実行順序源として扱う 1 モード動作となり、フロー分岐が削除されました。

**Phase 5 (orchestrator) との連携**: 本 skill の出力 (`specs/dag.md` + 各 Spec の frontmatter) は orchestrator skill の **唯一の入力データ** です。詳細は `skills/spec-dag-builder/SKILL.md` のセクション 12 を参照してください。

### 1. Spec

**目的**: Brainstorming で解像度の上がった要件を、7 章構成の Spec ファイルに具体化します (`writing-spec` skill 担当)。

| 項目 | 内容 |
|---|---|
| 担当層 | main agent (対話、`writing-spec` skill 起動) |
| 入力 | Brainstorming ノート (`specs/<spec-name>.brainstorm.md`) |
| 出力 | Spec ファイル (`specs/<spec-name>.md`、7 章構成: 目的 / スコープ / 機能要件 / 非機能要件 / 受け入れ基準 / 非対象 / リスク) + Brainstorming ノートの `specs/archive/` への移動 |
| Agent Teams 活用 | × (対話必須、並列化は Phase 5 の orchestrator が担当) |
| 品質ゲート | Spec frontmatter (name / status: spec-complete / brainstorming_archive) の存在を hook で検証 |

**Spec ファイル配置**: `specs/<spec-name>.md` (worktree 外、main 側で管理)。Brainstorming ノートは `specs/archive/<spec-name>.brainstorm.md` に移動。

**複数 Spec 処理**: Brainstorming で分割された複数 Spec を Spec 化する際は、`specs/dag.md` の `parallel_group` 順に順次処理します。並列化は本ステージでは行わず、Phase 5 の orchestrator の責務です。

**status 遷移**:
- Brainstorming ノート: `brainstorming-complete` → `archived` (archive 移動時)
- Spec ファイル (新規): `spec-complete` (Spec Review 待ち)

詳細手順は `skills/writing-spec/SKILL.md` を参照してください。

### 2. Spec Review

**目的**: AI による自動レビュー後、ユーザーが最終承認します (claude-scrum-team の PO 役割と同じ)。

| 項目 | 内容 |
|---|---|
| 担当層 | main agent + reviewer agents |
| 入力 | Spec ファイル |
| 出力 | レビューコメント + 承認ステータス |
| Agent Teams 活用 | ○ (AI reviewer 3 並列: 完全性 / 実現可能性 / 既存仕様との整合性) |
| 品質ゲート | ユーザー承認なしに Plan へ進めない |

### 3. Plan

**目的**: Spec を技術設計に展開し、タスクに分解します (spec-kit の Plan + Tasks 相当)。**main ブランチ側で実施** し、Plan ファイルを他 Spec の spec-leader から参照可能な状態に置くことで、Phase 5 の並列 Spec 実行時の相互参照 (API 契約 / 命名規約 / データモデル整合性) を可能にします (2026-04-22 改修、iter-3 知見 + Phase 5 並列化準備)。

| 項目 | 内容 |
|---|---|
| 担当層 | main agent (+ Phase 5 以降 investigator agent) |
| 入力 | 承認済み Spec ファイル (`specs/<spec-name>.md`) |
| 出力 | Plan ファイル (`specs/<spec-name>.plan.md`、main 側に配置) |
| Agent Teams 活用 | △ (Phase 3 は main agent 単独、Phase 5 で investigator agent 並列化: コードベース調査 / 依存ライブラリ調査 / 類似実装調査 + **他 Spec の Plan 参照**) |
| 品質ゲート | Plan ファイルにタスク分解 (チェックボックス形式 + `files_touched`) が含まれること |

**Plan ファイル配置 (改修)**: `specs/<spec-name>.plan.md` (main ブランチ、Spec ファイルと同階層)。従来 (worktree 内) から main 側に変更したため:

- 他 Spec の spec-leader / writing-plan が `specs/*.plan.md` パターンで並列実行中の Plan を参照可能
- Plan 失敗 / Spec 差戻し時に worktree 作成の無駄が発生しない
- ship 時に `specs/archive/<spec-name>.plan.md` に archive 移動、過去の設計判断を将来の Spec で参照可能

**Phase 3 初期の動作**: main agent が直接 writing-plan skill で Plan を生成。Phase 5 で investigator agent を並列起動してコードベース調査 / 他 Spec Plan 走査を分離します (writing-plan / investigator のインタフェースは Phase 3 時点で確定)。

### 4. Isolate

**目的**: Plan が確定した Spec について worktree を作成し、main を汚さず実装を進めます。**Plan の後に実施** することで、Plan 段階での差戻しによる worktree 作成の無駄を排除します。

| 項目 | 内容 |
|---|---|
| 担当層 | specLeader |
| 入力 | 承認済み Spec ファイル + Plan ファイル |
| 出力 | worktree path + ブランチ名 |
| Agent Teams 活用 | × |
| 品質ゲート | worktree 作成成功確認、Spec + Plan ファイルが worktree から参照可能であること |

**worktree 命名規則**: `worktrees/<spec-name>/`、ブランチ名 `spec/<spec-name>`

**worktree への持ち込み**: Isolate ステージで以下を worktree 内にコピー:
- `specs/<spec-name>.md` → `worktrees/<spec-name>/specs/<spec-name>.md`
- `specs/<spec-name>.plan.md` → `worktrees/<spec-name>/plans/<spec-name>.md` (**名前規則は worktree 側では従来通り `plans/` サブディレクトリ**)
- `specs/<spec-name>.review.md` → `worktrees/<spec-name>/specs/<spec-name>.review.md` (参考情報として)

### 5. Implement

**目的**: TDD でタスクを並列実装します。

| 項目 | 内容 |
|---|---|
| 担当層 | specLeader + developer agents |
| 入力 | Plan ファイル |
| 出力 | 実装コード + テストコード + コミット |
| Agent Teams 活用 | ◎ (タスク単位で developer agent を並列起動) |
| 品質ゲート | PreToolUse hook: 実装ファイル編集前に対応テストの存在を確認、なければブロック |

**TDD 強制**: superpowers の TDD skill 思想を踏襲し、テスト先行を hook で物理的に強制します。

### 6. Verify

**目的**: 全テスト / lint / 型チェック / 手動チェックリストを実行します。

| 項目 | 内容 |
|---|---|
| 担当層 | specLeader + verifier agent |
| 入力 | 実装完了状態の worktree |
| 出力 | 検証レポート (全項目 pass / fail) |
| Agent Teams 活用 | ○ (テスト / lint / 型を並列実行) |
| 品質ゲート | Stop hook: 完了宣言前に「全テスト緑 + lint 通過 + 型通過」を強制 |

**verification-before-completion skill** が Stop hook と連動し、検証コマンド未実行ならブロックします。

### 7. Code Review

**目的**: code / security / cross-model の独立レビューを並列実行します。

| 項目 | 内容 |
|---|---|
| 担当層 | specLeader + reviewer agents |
| 入力 | Verify 通過済み worktree |
| 出力 | レビューコメント + 承認ステータス |
| Agent Teams 活用 | ◎ (code-reviewer / security-reviewer / cross-model-reviewer の 3 並列) |
| 品質ゲート | 全 reviewer 承認 + ユーザー最終承認なしに ship 不可 |

**cross-model-review**: Codex 等の他モデルによる独立審査 (claude-scrum-team 参考)。

### 8. ship

**目的**: worktree を main にマージし、worktree を削除します。

| 項目 | 内容 |
|---|---|
| 担当層 | specLeader (Phase 3) → orchestrator (Phase 5、merge 順序制御込み) |
| 入力 | Code Review 通過済み worktree |
| 出力 | main へのマージコミット + worktree 削除 |
| Agent Teams 活用 | × |
| 品質ゲート | merge 後に main で再度テスト実行 |

### 9. Learn

**目的**: 振り返りを実施し、skill / hook / ワークフロー自体を改善します。

| 項目 | 内容 |
|---|---|
| 担当層 | main agent + ユーザー |
| 入力 | ship 完了状態 + 当該サイクルの記録 |
| 出力 | 改善提案 + skill / hook 修正コミット |
| Agent Teams 活用 | × |
| 品質ゲート | なし (改善提案は次サイクル以降に反映) |

## skill / agent / hook 配置一覧

### skill (Phase 3 で作成)

| skill 名 | 役割 | 担当ステージ | 参考 |
|---|---|---|---|
| `brainstorming` | Spec 前の要件深掘り (起点、必須) | Brainstorming | superpowers |
| `spec-dag-builder` | 複数 Spec の依存関係解析、DAG 構築 (段階的アップデート) | DAG 構築 (Brainstorming 後 / Spec Review 後) | 独自 |
| `writing-spec` | Brainstorming ノートから 7 章構成の Spec を生成、archive 移動、DAG 順処理 | Spec | OpenSpec + 独自 |
| `spec-review` | AI 自動 Spec レビュー | Spec Review | claude-scrum-team |
| `spec-leader` | ステージ遷移制御 (Isolate → Code Review) | Isolate〜Code Review | 独自 |
| `writing-plan` | 技術計画 + タスク分解 | Plan | superpowers + spec-kit |
| `tdd-driver` | テスト先行強制 | Implement | superpowers |
| `verification-before-completion` | 完了前検証強制 | Verify | superpowers |
| `receiving-code-review` | レビュー指摘対応 | Code Review (差戻し時) | superpowers |
| `cross-model-review` | 独立モデルレビュー | Code Review | claude-scrum-team |
| `learn` | 振り返り + 改善提案 | Learn | 独自 |

### agent (Phase 3 で作成)

| agent 名 | 役割 | 起動主体 |
|---|---|---|
| `developer` | タスク単位の TDD 実装 | specLeader |
| `code-reviewer` | コード品質レビュー | specLeader |
| `security-reviewer` | セキュリティ観点レビュー | specLeader |
| `cross-model-reviewer` | 他モデル (Codex 等) 経由のレビュー | specLeader |
| `verifier` | 全検証 (test / lint / type) 実行 | specLeader |
| `spec-reviewer` | Spec の完全性 / 実現可能性 / 整合性レビュー | main agent |
| `investigator` | コードベース / 依存 / 類似実装の調査 (Phase 3 では Plan ステージ専用、Phase 5 で Brainstorming ステージにも拡張) | specLeader (Plan ステージ) / main agent (Brainstorming ステージ、Phase 5 以降) |
| `orchestrator` | 複数 Spec の DAG 管理 (Phase 5) | main agent / ユーザー |

### hook (Phase 4 で実装)

| hook event | 用途 | 連動 skill |
|---|---|---|
| `SessionStart` | プロジェクト固有 skill / コンテキスト注入 | (全般) |
| `InstructionsLoaded` | CLAUDE.md / Spec ファイルロード時の追加コンテキスト | `writing-spec` |
| `PreToolUse` (Edit/Write) | TDD 強制 (実装前にテスト存在確認) | `tdd-driver` |
| `PostToolUse` (Edit/Write) | テストファイル変更時の自動テスト実行 | `tdd-driver` |
| `WorktreeCreate` | worktree 初期化 (Spec ファイルコピー、ブランチ確認) | `spec-leader` |
| `WorktreeRemove` | worktree 削除前の未コミット警告 | `spec-leader` |
| `Stop` | 完了宣言前の全検証強制 | `verification-before-completion` |
| `TaskCompleted` | タスク完了時に進捗ファイル更新 | `spec-leader` |

## 技術的不確実性と検証計画

### Agent Teams の多階層 subagent サポート

Phase 5 で orchestrator → specLeader → workers の 3 層構造を実装する際、Claude Code の Agent Teams が「subagent of subagent」をサポートするか未確認です。

**Phase 5 での検証項目**:
1. specLeader 自身が subagent として起動された状態で、配下に developer agent を起動できるか
2. 階層間の進捗通知 (specLeader → orchestrator) の実現方法
3. 並列起動時のリソース上限 (同時起動可能 agent 数)

**代替案**: 多階層 subagent が動作しない場合、orchestrator は state ファイル経由で specLeader を順次起動する擬似並列方式に切り替えます。

### worktree 操作の自動化レベル

`WorktreeCreate` / `WorktreeRemove` hook の挙動は本プロジェクト着手時点で未検証です。Phase 4 で挙動を確認し、必要に応じて command hook で代替実装します。

## Phase 別実装計画

### Phase 2 (現在): ワークフロー骨子定義

- [x] `docs/workflow.md` 作成 (本ドキュメント)
- [ ] `ROADMAP.md` 再構成 (Phase 2-6)

### Phase 3: 単一 Spec 版 skill 実装

- [ ] 10 skill (brainstorming / writing-spec / spec-review / spec-leader / writing-plan / tdd-driver / verification-before-completion / receiving-code-review / cross-model-review / learn)
- [ ] 8 agent (developer / code-reviewer / security-reviewer / cross-model-reviewer / verifier / spec-reviewer / investigator / orchestrator は Phase 5)
- [ ] specLeader は単独動作可能 (orchestrator 不在前提)
- [ ] orchestrator から呼ばれる前提のインタフェース定義

### Phase 4: hook 自動化

- [ ] TDD 強制 hook (PreToolUse Edit/Write)
- [ ] verification 強制 hook (Stop)
- [ ] worktree 自動化 hook (WorktreeCreate / WorktreeRemove)
- [ ] SessionStart hook による skill 注入

### Phase 5: orchestrator 追加 (複数 Spec 並列)

- [ ] orchestrator skill 実装
- [ ] DAG 管理 (Spec 間依存関係)
- [ ] Agent Teams 多階層 subagent の動作検証
- [ ] merge 順序制御
- [ ] 並列実行時のコンフリクト解決戦略

### Phase 6: 統合改善ループ + 公開検討

- [ ] 全ステージの統合テスト
- [ ] skill-creator による各 skill の eval iteration
- [ ] memory 運用最適化
- [ ] 公開検討 (任意)

## 参考フレームワークと採用箇所

| フレームワーク | 採用箇所 |
|---|---|
| **superpowers** | skill 相互参照、TDD 強制、verification 強制、SessionStart hook、receiving-code-review |
| **OpenSpec** | 軽量 Markdown 仕様、Spec の状態管理 (propose / apply / archive 相当) |
| **spec-kit** | Plan ステージの設計 + タスク分解パターン |
| **claude-scrum-team** | Spec Review (PO 役割)、cross-model review、phase gate hook、tmux + TUI 検討 (Phase 6) |
| **BMAD-METHOD** | role-based agent 階層 (orchestrator / specLeader / workers) |
| **gstack** | 役割分離の粒度感 |
| **oh-my-claudecode** | Agent Teams 活用パターン (Phase 5) |
| **skill-creator** | 各 skill の eval ループ (Phase 6) |
| **hookify** | hook 自動生成 (Phase 4) |
