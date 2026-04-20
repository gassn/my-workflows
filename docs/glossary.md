# 用語集 (Glossary)

本プロジェクトで使用する用語の定義をまとめます。複数の文脈で「Phase」という語が混在し誤解を招くため、明確に区別して使用します。新しい skill / agent / hook を設計する際は、本ドキュメントの定義に従って用語を選択してください。

## 1. Project Phase (プロジェクトフェーズ)

**定義**: 本ワークフロー (`my-workflows`) 自体の構築段階を指します。

**使用文脈**: `ROADMAP.md`、本プロジェクトの開発進捗管理

**例**: Phase 1 (基礎整備) / Phase 2 (ワークフロー骨子定義) / Phase 3 (単一 Spec 版実装) / Phase 4 (hook 自動化) / Phase 5 (orchestrator 追加) / Phase 6 (統合改善・公開)

**表記**: 「Phase 1」「Phase 2」のように **Phase** (大文字始まり、英語) を使用します。文脈が ROADMAP.md または本プロジェクトの構築に関するものに限定されます。

## 2. Workflow Stage (ワークフローステージ)

**定義**: 個別の開発サイクル内で進行する段階を指します。1 つの Spec を Brainstorming から ship まで届けるプロセスの各段階に相当します。

**使用文脈**: `docs/workflow.md`、各 skill (brainstorming / writing-spec / spec-leader / ...)、各 agent

**例**: Brainstorming / Spec / Spec Review / Isolate / Plan / Implement / Verify / Code Review / ship / Learn

**表記**: 「ステージ」(日本語、カタカナ) を使用します。「フェーズ」という語は本文脈では避け、Project Phase との混同を防ぎます。

**例文**:
- ✅ 「Brainstorming ステージで要件を深掘りします」
- ✅ 「Spec Review ステージへ進む承認を得てください」
- ❌ 「Brainstorming フェーズで要件を深掘りします」(避ける)

## 3. Release Phase (リリースフェーズ)

**定義**: ユーザーが取り組むプロジェクト (= Spec の対象となるプロダクト) のリリース段階を指します。これは本ワークフローの構築段階 (Project Phase) や個別サイクル内のステージ (Workflow Stage) とは無関係です。

**使用文脈**: `brainstorming` skill の Spec 分割提案 (セクション 10) で、フェーズ単位の分割案を提示する場面

**例**: MVP / Phase 2 / Phase 3 / GA (一般公開) / Beta / Alpha

**表記**: 「Release Phase」と明記、または業界慣例の「MVP」「Phase 2」等をそのまま使用します。文脈で明確な場合は短縮可です。

**例文**:
- ✅ 「Release Phase (MVP / Phase 2) で分割します」
- ✅ 「MVP に含めるか Phase 2 に回すかをユーザーと相談します」

## 4. Spec (スペック)

**定義**: 単一の仕様単位。1 つの機能、1 つの課題、1 つの変更要求に対応する仕様書とその実装活動全体を指します。

**運用上の制約** (Spec の粒度基準):

- 1 Spec = **1 機能 / 1 課題** に対応
- 1 Spec = **1 worktree** = **1 specLeader** 担当
- 1 Spec = **1 PR** で完結する規模
- 実装期間目安: **数日〜数週間**
- 上記を超える規模は Brainstorming ステージで複数 Spec に分割します (`brainstorming` skill セクション 10 参照)

**ファイル命名規則**:

- Brainstorming ノート: `specs/<spec-name>.brainstorm.md`
- Spec ファイル: `specs/<spec-name>.md`
- 分割時 (機能単位): `specs/<project>-<feature>.brainstorm.md` (例: `specs/ecsite-auth.brainstorm.md`)
- 分割時 (Release Phase 単位): `specs/<project>-<release-phase>.brainstorm.md` (例: `specs/ecsite-mvp.brainstorm.md`)
- 分割時 (ハイブリッド): `specs/<project>-<release-phase>-<feature>.brainstorm.md` (例: `specs/ecsite-mvp-auth.brainstorm.md`)

**Spec 名のケース**: ケバブケース (kebab-case) を使用します。

**Spec 間の関係**: 複数 Spec を扱う場合、依存関係を `depends_on` フィールドに記述し、Phase 5 で実装される orchestrator agent が DAG 解決に利用します。

## 5. 階層用語

`docs/workflow.md` の階層構造で使用される用語です。

| 用語 | 定義 | 実装 Project Phase |
|---|---|---|
| **orchestrator** | 複数 Spec の DAG を管理し、specLeader を起動する最上位エージェント | Project Phase 5 |
| **specLeader** | 1 つの Spec を担当し、Workflow Stage を遷移制御するエージェント | Project Phase 3 |
| **workers** | specLeader 配下の単機能エージェント (developer / reviewer / verifier 等) | Project Phase 3 |

## 6. その他の用語

| 用語 | 定義 |
|---|---|
| **skill** | Claude Code に特定の振る舞いを起動させる Markdown 定義 (frontmatter + 本文) |
| **agent** | 特定の役割を持つサブエージェント (developer / code-reviewer 等) |
| **hook** | Claude Code のライフサイクルイベントに連動して実行される処理 (`settings.json` で定義) |
| **command** | slash command (`/foo`) として呼び出せる skill / 機能 |
| **Brainstorming ノート** | Brainstorming ステージで生成される要件深掘り結果を記述した Markdown ファイル (`specs/<spec-name>.brainstorm.md`) |
| **DAG** | 有向非巡回グラフ。Spec 間の依存関係を表現するために使用 (`spec-dag-builder` skill が生成、Project Phase 3 で実装予定) |

## 7. 用語選択の判定フロー

新しいドキュメント / skill / agent を書く際、以下の順で判定してください。

1. 「本プロジェクトの構築段階」を指す → **Project Phase** (例: Phase 3 で実装予定)
2. 「個別開発サイクル内の段階」を指す → **Workflow Stage** / 日本語で「ステージ」
3. 「ユーザープロジェクトのリリース段階」を指す → **Release Phase** (例: MVP / Phase 2)
4. 「1 つの仕様単位」を指す → **Spec**

「フェーズ」という単独の語は使用を避け、上記 1〜3 のいずれかに置き換えてください。
