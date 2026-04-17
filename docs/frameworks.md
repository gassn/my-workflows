# 参考フレームワーク一覧

本プロジェクトの設計にあたって参考にするフレームワーク・ツール群をまとめたドキュメントです。各フレームワークの強みと、本プロジェクトに取り入れたい要素を整理しています。

## 1. superpowers (obra/superpowers)

**URL**: https://github.com/obra/superpowers

TDD とシステマティックな開発プロセスを強制する agentic skills framework です。Anthropic 公式プラグインマーケットプレイスにも登録されています。

**構造**:
- `skills/` 配下に 14 の相互参照する skill (brainstorming / writing-plans / executing-plans / TDD / systematic-debugging 等)
- `hooks/` の SessionStart hook で `using-superpowers` skill を強制注入
- `agents/` に code-reviewer エージェント定義
- `commands/` に slash command (/brainstorm, /write-plan, /execute-plan)

**参考にしたい要素**:
- skill 間の相互参照による連続ワークフロー設計
- SessionStart hook による自動トリガー機構
- Red Flags 表や DOT graph による挙動強制の工夫
- skill description の「pushy」な書き方 (undertrigger 対策)

## 2. gstack (garrytan/gstack)

**URL**: https://github.com/garrytan/gstack, https://gstack.lol/

Garry Tan (Y Combinator CEO) の個人 OSS です。役割別の workflow skill を 9 個束ねており、単一の AI に対して CEO / Designer / Eng Manager / Release Manager / Doc Engineer / QA などの役割を演じさせます。

**参考にしたい要素**:
- Role-based governance (役割分担による挙動制御)
- slash command 駆動の明示的な workflow 遷移
- reframe → plan → review → browser QA → ship → learn の開発サイクル設計

## 3. spec-kit (github/spec-kit)

**URL**: https://github.com/github/spec-kit

GitHub 公式の仕様駆動開発 (Spec-Driven Development) ツールキットです。MIT ライセンスで、CLI・テンプレート・プロンプトをパッケージ化しています。

**ワークフロー**: Specify → Plan → Tasks の 3 フェーズ

**参考にしたい要素**:
- 仕様 → 技術計画 → 小さなタスク分解への明確な段階設計
- CLI 化による初期セットアップの自動化 (`specify init <project> --ai claude`)
- テンプレートファーストの再現性確保

## 4. everything-claude-code (affaan-m)

**URL**: https://github.com/affaan-m/everything-claude-code

10 ヶ月以上の実戦投入で鍛えられた大規模プラグイン。38 agents / 156 skills / 72 commands / hooks / MCP を備えます。

**参考にしたい要素**:
- 大規模 skill 群の組織化手法
- 複数 AI ツール (Claude Code / Codex / Opencode / Cursor) への対応設計
- エンジニアリングチーム向けの production-ready な構造

## 5. oh-my-claudecode (Yeachan-Heo)

**URL**: https://github.com/yeachan-heo/oh-my-claudecode, https://ohmyclaudecode.com/

Claude Code の Agent Teams 機能 (native) を前提にした multi-agent orchestration フレームワークです。19 agents + 36 skills を備え、Autopilot が意図を検出して自動的に agents をオーケストレーションします。

**参考にしたい要素**:
- Claude Code native の Agent Teams 機能の活用方法
- trigger phrase 駆動のモード切替 ("ultrawork" / "deepsearch" / "autopilot")
- 学習コストを下げる設計 (Claude Code syntax 不要)
- Autopilot 方式の intent 検出ロジック

## 6. claude-scrum-team (sohei56)

**URL**: https://github.com/sohei56/claude-scrum-team

Claude Code Agent Teams を活用した AI 駆動スクラム開発チームです。vibe coding と Spec-Driven Development の中間を狙い、検査と適応のループを提供します。

**構造**:
- `scrum-start.sh` で tmux セッションを起動
- 14 ceremony skills (要件抽出〜統合テスト)
- Scrum Master (Delegate mode) + 最大 6 Developer エージェント
- 3 層の独立レビュー (Code / Security / Codex cross-model)
- Textual ベースの TUI ダッシュボード (4 パネル表示)

**参考にしたい要素**:
- tmux による長時間並列タスクの可視化と制御
- phase gate hook (フェーズ間の完了判定)
- 動的チームサイジング (PBI 数に応じて最大 6 Developer)
- cross-model review (Codex による独立審査)
- 初期 Sprint を要件抽出専用にする設計 ("Mandatory Requirements Sprint")
- ユーザーの役割を PO (承認/レビュー/リリース判定) に限定する責務分離

## 7. Compound Engineering Plugin (EveryInc)

**URL**: https://github.com/EveryInc/compound-engineering-plugin

複数の AI ツール (Claude Code / Codex / Cursor) をまたいで動作する公式プラグインです。

**参考にしたい要素**:
- multi-IDE 抽象化の手法
- プラットフォーム間の挙動の差異吸収

## 8. claude-mpm (bobmatnyc)

**URL**: https://github.com/bobmatnyc/claude-mpm

Claude Multi-Agent Project Manager。47+ agents を管理し、multi-channel orchestration / GitHub-first SDK mode / plugin system を備えます。

**参考にしたい要素**:
- 大規模エージェント群のライフサイクル管理
- GitHub 連携を前提にしたワークフロー
- plugin system の内部構造

## 9. その他の関連ツール

### workflow / orchestration 系

| 名前 | 特徴 |
|---|---|
| **GSD** (Get Stuff Done) | context rot 防止特化 |
| **Hermes** | superpowers 系の代替 |
| **wshobson/agents** | intelligent automation |
| **barkain/claude-code-workflow-orchestration** | 自動タスク分解 + native plan mode 統合 |
| **Spec-Flow** (marcusgoll) | Spec-Driven + quality gates + token budgets |
| **claude-code-spec-workflow** (Pimzino) | Requirements → Design → Tasks → Impl + bug fix |
| **dev-workflows framework** | end-to-end AI 開発 workflow |
| **claude-code-workflows** (shinpr) | 専門 AI agent 駆動 |

### marketplace / 集約系

| 名前 | 特徴 |
|---|---|
| **claude-code-plugins-plus-skills** (jeremylongshore) | 340 plugins / 1367 skills + CCPI package manager |
| **awesome-claude-plugins** (quemsah) | プラグイン採用メトリクス集計 |
| **claude-code-ultimate-guide** (FlorianBruniaux) | リソース評価と agent-teams workflow 解説 |

### skill 開発補助

| 名前 | 特徴 |
|---|---|
| **skill-creator** | 公式プラグイン。skill の draft → eval → iteration ループを自動化 |
| **hookify** | 会話履歴分析から自動的に hook ルール化 |
| **claude-md-management** | CLAUDE.md の audit と改善 |

### 他エコシステム

| 名前 | 特徴 |
|---|---|
| **Cursor Rules** (`.cursorrules`, `.cursor/rules/*.mdc`) | プロジェクト単位の指示 |
| **Aider** (`CONVENTIONS.md`) | チャット駆動コーディング、git 連携 |
| **Cline / Roo Code** | MCP + tool 駆動の VSCode 統合エージェント |
| **Continue** (`config.yaml`) | IDE 内エージェント設定 |
| **Windsurf Cascade** (`.windsurfrules`) | ルール + メモリ統合 |
| **agents.md** (agentsmd.net) | AGENTS.md 規格化運動 |

## 設計思想別の分類

| タイプ | 代表フレームワーク | 強制するもの |
|---|---|---|
| TDD 駆動 | superpowers | テスト先行・systematic debugging |
| Role-based | gstack | 役割分担ワークフロー |
| Spec-driven | spec-kit, Spec-Flow | 仕様 → 計画 → タスク分解 |
| 大量 skill 盛り | everything-claude-code, claude-code-plugins-plus-skills | 網羅性 |
| Context 管理 | GSD | 長セッション対策 |
| Multi-agent | oh-my-claudecode, claude-scrum-team, claude-mpm | 並列実行と役割分離 |

## 本プロジェクトで取り入れる優先順位

1. **superpowers**: skill 核設計の基準として最優先で参照します。
2. **spec-kit**: 仕様駆動のフェーズ設計と CLI 化を参照します。
3. **claude-scrum-team**: 長時間タスクの可視化、phase gate、cross-model review を参照します。
4. **oh-my-claudecode**: Agent Teams の実装例と trigger phrase 設計を参照します。
5. **gstack**: 役割分離の粒度感を参照します。
6. **everything-claude-code**: 大規模化した際の組織化方法を参照します。
