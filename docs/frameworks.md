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

## 10. Spec駆動フレームワーク詳細比較

Spec-Driven Development (SDD) は「仕様書を一次成果物とし、コードはそこから派生させる」開発パラダイムです。2026年現在、軽量から重量まで多様な実装が存在します。本プロジェクトの「自分専用に最適化」「段階的構築」方針との相性を見極めるため、主要フレームワークを比較します。

### 10.1 OpenSpec (Fission-AI)

**URL**: https://github.com/Fission-AI/OpenSpec, https://openspec.pro/

軽量 SDD の代表格。純粋な Markdown ファイルのみで仕様を管理し、Python 不要・5分でセットアップ可能です。

**ワークフロー**: `propose` → `apply` → `archive` の 3 状態マシン

**特徴**:
- `npm install -g @fission-ai/openspec` のみで導入可能
- Claude Code / Cursor / GitHub Copilot / Cline / Windsurf に CLI 統合
- 各フェーズが「考える間を与える」程度の軽さに留まり、長大な成果物を強制しない
- 重量級 SDD (Spec Kit 等) の rigid phase gates と対照的

**参考にしたい要素**:
- 軽量さの極致 (3 コマンド + Markdown のみ)
- Claude Code との CLI 統合パターン
- 「フェーズはあるが artifact は最小」という設計バランス

### 10.2 Intent (living-spec 系)

**URL**: 詳細未調査 (2026年の SDD ツール比較記事で頻出)

**特徴**:
- 仕様書とコードを継続的に同期させる「living-spec」アプローチ
- 静的仕様 (static-spec) ツールが実装乖離時に手動再調整を必要とするのに対し、エージェント作業中もドキュメントを自動同期

**参考にしたい要素**:
- spec とコードの drift を防ぐ仕組み (本プロジェクトでは hook で代替検討)

### 10.3 Kiro (AWS)

**URL**: https://kiro.dev/

AWS 製のスペックファースト IDE。Claude Code とは別環境ですが、設計思想は参照価値があります。

**3 本柱**:
- **Steering**: プロジェクト全体の指針ファイル (CLAUDE.md 相当)
- **Specs**: requirements / design / tasks の 3 ファイル生成
- **Hooks**: ファイル変更等のイベントトリガー

**参考にしたい要素**:
- requirements / design / tasks の 3 ファイル分割パターン
- Steering と Specs の階層分離 (本プロジェクトの CLAUDE.md と skill の関係に対応)

### 10.4 BMAD-METHOD (bmad-code-org)

**URL**: https://github.com/bmad-code-org/BMAD-METHOD

Breakthrough Method of Agile AI-Driven Development。Spec 単独ではなく Multi-agent + Agile lifecycle を統合した重量フレームワークです。

**特徴**:
- 12+ の専門 domain agent (PM / Architect / Developer / UX 等)
- analysis → planning → architecture → implementation の lifecycle
- Party Mode: 複数 agent persona を 1 セッションに同居
- ソフトウェア以外 (entertainment / 創作 / 経営 / 健康) にも適用

**参考にしたい要素**:
- 役割別 agent と Spec フェーズの統合方式 (gstack と類似だが規模が大きい)
- Party Mode の concurrent persona 設計

### 10.5 Agent OS (buildermethods)

**URL**: https://buildermethods.com/agent-os

「coding standards for AI-powered development」を掲げるフレームワーク。Spec 駆動と coding convention 強制を組み合わせます。

**参考にしたい要素**:
- コーディング規約と spec の同居パターン

### 10.6 既出の Spec 駆動系 (再掲)

セクション 3 と 9 で言及済みのため詳細省略しますが、本比較に含めます:

- **spec-kit** (GitHub 公式): Specify → Plan → Tasks。中量・テンプレート豊富
- **claude-code-spec-workflow** (Pimzino): Requirements → Design → Tasks → Impl + bug fix
- **Spec-Flow** (marcusgoll): Spec-Driven + quality gates + token budgets
- **claude-scrum-team** (sohei56): vibe coding と SDD の中間、Mandatory Requirements Sprint

### 10.7 比較サマリ

| 名前 | 重さ | 形式 | フェーズ | Claude Code 適合 | 本プロジェクト示唆 |
|---|---|---|---|---|---|
| **OpenSpec** | 極軽 | Markdown + CLI 3コマンド | propose / apply / archive | ◎ (CLI統合) | 軽量 skill の参考第一候補 |
| **Intent** | 軽 | living-spec | 継続同期 | △ (要確認) | hook 設計の参考 |
| **CLAUDE.md / AGENTS.md** | 極軽 | 単一 Markdown | フェーズなし | ◎ (native) | 既に活用中 |
| **spec-kit** | 中 | テンプレ + CLI | Specify / Plan / Tasks | ○ | フェーズ設計の参考 |
| **claude-code-spec-workflow** | 中 | command 群 | Requirements / Design / Tasks / Impl | ◎ | bug fix workflow が独自 |
| **Spec-Flow** | 中重 | quality gates + budgets | 多段ゲート | ○ | token budget 概念 |
| **Kiro** | 重 | IDE 組込 | Steering / Specs / Hooks | × (別IDE) | 設計思想のみ参照 |
| **BMAD-METHOD** | 重 | Multi-agent + lifecycle | analysis〜impl | ○ | role-based + spec 統合例 |
| **Agent OS** | 中 | standards + spec | 規約駆動 | ○ | コーディング規約との同居 |
| **claude-scrum-team** | 重 | tmux + Agent Teams | scrum ceremonies | ◎ | 重量側の限界例 |

**示唆**: 本プロジェクトの「段階的構築」方針には **OpenSpec の軽量さ** と **CLAUDE.md ベースの軽量 SDD** が最も親和的です。重量級 (Kiro / BMAD / scrum-team) は Phase 5 以降の統合ワークフロー設計時に参照します。

### 10.8 出典 (2026年4月時点)

- [Fission-AI/OpenSpec](https://github.com/Fission-AI/OpenSpec/)
- [OpenSpec公式サイト](https://openspec.pro/)
- [Spec-Driven Development is Eating Software Engineering: A Map of 30+ Agentic Coding Frameworks (Vishal Mysore, Medium 2026-03)](https://medium.com/@visrow/spec-driven-development-is-eating-software-engineering-a-map-of-30-agentic-coding-frameworks-6ac0b5e2b484)
- [6 Best Spec-Driven Development Tools for AI Coding in 2026 (Augment Code)](https://www.augmentcode.com/tools/best-spec-driven-development-tools)
- [AWS Kiro vs Claude Code vs GitHub Copilot 2026 Enterprise Guide](https://signalovernoise.karlekar.cloud/discovery-2026-04-01-kiro-comparison.html)
- [BMAD-METHOD GitHub](https://github.com/bmad-code-org/BMAD-METHOD)
- [Agent OS (buildermethods)](https://buildermethods.com/agent-os)

## 設計思想別の分類

| タイプ | 代表フレームワーク | 強制するもの |
|---|---|---|
| TDD 駆動 | superpowers | テスト先行・systematic debugging |
| Role-based | gstack, BMAD-METHOD | 役割分担ワークフロー |
| Spec-driven (軽量) | OpenSpec, Intent, CLAUDE.md/AGENTS.md | 最小フェーズで仕様先行 |
| Spec-driven (中量) | spec-kit, claude-code-spec-workflow, Spec-Flow, Agent OS | 仕様 → 計画 → タスク分解 |
| Spec-driven (重量) | Kiro, BMAD-METHOD, claude-scrum-team | 仕様 + ceremony + 役割分離 |
| 大量 skill 盛り | everything-claude-code, claude-code-plugins-plus-skills | 網羅性 |
| Context 管理 | GSD | 長セッション対策 |
| Multi-agent | oh-my-claudecode, claude-scrum-team, claude-mpm, BMAD-METHOD | 並列実行と役割分離 |

## 本プロジェクトで取り入れる優先順位

1. **superpowers**: skill 核設計の基準として最優先で参照します。
2. **OpenSpec**: 軽量 Spec 駆動の参考第一候補。Markdown only / 3 コマンドという最小構成は本プロジェクトの「段階的構築」方針と相性が良いです。
3. **spec-kit**: 中量 Spec 駆動のフェーズ設計と CLI 化を参照します。
4. **claude-scrum-team**: 長時間タスクの可視化、phase gate、cross-model review を参照します。
5. **oh-my-claudecode**: Agent Teams の実装例と trigger phrase 設計を参照します。
6. **gstack**: 役割分離の粒度感を参照します。
7. **BMAD-METHOD**: 役割別 agent と Spec を統合した重量例として、Phase 3 以降に参照します。
8. **everything-claude-code**: 大規模化した際の組織化方法を参照します。

## 11. パターン分類表 (skill / hook / agent / command 横断索引)

新しい skill / hook / agent / command を設計する際に「どのフレームワークの何を参照すれば良いか」を即引きするための索引表です。各セルには代表的な構成要素を記載し、本プロジェクトでの採用検討度を併記します。

**採用検討度の凡例**:
- ◎: Phase 1〜2 で参照する一次ソース
- ○: Phase 3〜5 で参照する候補
- △: 設計思想のみ参照 (実装は流用しない)
- ×: 互換性が低い、または本プロジェクトの方向性に合わない

### 11.1 横断比較表

| フレームワーク | skill | hook | agent | command | その他 | 採用検討度 |
|---|---|---|---|---|---|---|
| **superpowers** | brainstorming, writing-plans, executing-plans, TDD, systematic-debugging 等 14 種、相互参照 | SessionStart で `using-superpowers` 強制注入 | code-reviewer | `/brainstorm`, `/write-plan`, `/execute-plan` | Red Flags 表、DOT graph による挙動制御 | ◎ |
| **OpenSpec** | (skill 概念なし、Markdown spec が代替) | (なし、CLI 駆動) | (なし) | `/opsx:propose`, `/opsx:apply`, `/opsx:archive` | npm CLI、Markdown spec の状態マシン | ◎ |
| **spec-kit** | (テンプレート群が skill 相当) | (CLI 初期化のみ) | (なし) | `specify init`、Specify / Plan / Tasks | テンプレートファースト、再現性重視 | ○ |
| **claude-code-spec-workflow** | Requirements / Design / Tasks / Impl の各 phase 用 | (要確認) | (要確認) | フェーズ別 slash command 群 | bug fix workflow が独立 | ○ |
| **claude-scrum-team** | 14 ceremony skills (要件抽出〜統合テスト) | phase gate hook (フェーズ完了判定) | Scrum Master + 最大 6 Developer + Code/Security/Codex reviewer | `scrum-start.sh` (tmux 起動) | tmux + Textual TUI ダッシュボード、cross-model review | ○ |
| **oh-my-claudecode** | 36 skills | (要確認) | 19 agents (Autopilot 含む) | trigger phrase: `ultrawork` / `deepsearch` / `autopilot` | Claude Code Agent Teams native | ○ |
| **gstack** | 9 役割別 workflow skill | (なし) | CEO / Designer / Eng Manager / Release Manager / Doc Engineer / QA 等 | reframe / plan / review / browser QA / ship / learn | role-based governance | ○ |
| **BMAD-METHOD** | 20+ workflow (analyst/PM/architect/dev) | Kiro 連携時に Hooks | 12+ domain expert (PM, Architect, Dev, UX 等) | (Party Mode 含む multi-agent invocation) | agile lifecycle、cross-domain (創作/経営も) | ○ |
| **everything-claude-code** | 156 skills | hooks 多数 | 38 agents | 72 commands | MCP 統合、複数 AI ツール対応 | △ |
| **claude-mpm** | (skill 群多数、要確認) | (要確認) | 47+ agents、ライフサイクル管理 | GitHub-first SDK mode | multi-channel orchestration、plugin system | △ |
| **Compound Engineering Plugin** | (Claude/Codex/Cursor 共通) | (IDE抽象層) | (要確認) | (要確認) | multi-IDE 抽象化 | △ |
| **Spec-Flow** | quality gates 群 | gate 通過判定 | (要確認) | フェーズ別 command | token budget 管理 | △ |
| **Agent OS** | coding standards + spec | (要確認) | (要確認) | (要確認) | 規約と spec の同居 | △ |
| **Kiro (AWS)** | Specs (requirements/design/tasks) | Hooks (ファイル変更等) | (IDE組込) | (IDE UI) | Steering ファイル (CLAUDE.md相当)、IDE 統合 | × (別IDE、設計のみ参照) |
| **Intent** | (living-spec) | spec-code 同期 hook | (要確認) | (要確認) | living-spec 自動同期 | △ |
| **GSD** | context rot 防止 skill | (要確認) | (要確認) | (要確認) | 長セッション対策特化 | △ |
| **skill-creator** | skill draft → eval → iteration | (なし) | (なし) | skill 生成 command | iteration ワークスペース管理 | ◎ (既使用) |
| **hookify** | (なし) | 会話履歴から hook 自動生成 | (なし) | hookify CLI | 履歴分析エンジン | ○ (Phase 4) |
| **claude-md-management** | CLAUDE.md audit | (なし) | (なし) | audit / improve command | CLAUDE.md 改善ループ | ○ (Phase 5) |

### 11.2 構成要素別 採用候補マッピング

新 skill / hook / agent / command を作る際、まず参照すべきフレームワークを構成要素別に逆引きします。

**skill を作るとき**:
- 第一参照: **superpowers** (相互参照、pushy description、Red Flags)
- 軽量に作りたい: **OpenSpec** (Markdown のみで仕様を skill 化)
- 役割別に分けたい: **gstack** (粒度感) → **BMAD-METHOD** (規模拡大時)
- eval ループで磨きたい: **skill-creator** (既使用)

**hook を作るとき**:
- SessionStart: **superpowers** (using-superpowers 注入パターン)
- phase gate: **claude-scrum-team** (フェーズ完了判定)
- Pre/PostToolUse: 公式ドキュメント + **hookify** で履歴駆動生成
- spec-code 同期: **Intent** (living-spec) ※要追加調査
- ファイル変更トリガー: **Kiro** (Hooks 仕様) ※設計思想のみ

**agent を作るとき**:
- code-reviewer 単独: **superpowers** (`agents/code-reviewer.md`)
- 役割別 multi-agent: **gstack** (役割粒度) → **BMAD-METHOD** (12+ persona)
- 並列 orchestration: **oh-my-claudecode** (Autopilot) → **claude-scrum-team** (Scrum Master + Developer)
- cross-model review: **claude-scrum-team** (Codex 独立審査)

**command を作るとき**:
- 単純な workflow trigger: **superpowers** (`/brainstorm` 等の直球命名)
- spec lifecycle: **OpenSpec** (`/opsx:propose|apply|archive`)
- フェーズ駆動: **spec-kit** (Specify/Plan/Tasks) または **claude-code-spec-workflow**
- trigger phrase で intent 検出: **oh-my-claudecode** (Autopilot)

**その他 (UI / 可視化 / 統合)**:
- tmux + TUI: **claude-scrum-team** (4パネル ダッシュボード)
- multi-IDE 抽象化: **Compound Engineering Plugin**
- MCP / plugin system: **everything-claude-code**, **claude-mpm**

### 11.3 本プロジェクトに取り込まない理由 (× / △ の補足)

- **Kiro**: AWS 純正 IDE で Claude Code とは別環境。Steering / Specs / Hooks の設計思想のみ参照し、実装は流用しません。
- **everything-claude-code / claude-mpm**: 大規模すぎて「段階的構築」方針に反します。Phase 5 以降の組織化局面で参照します。
- **Compound Engineering Plugin**: 本プロジェクトは Claude Code 単一環境を前提とするため multi-IDE 抽象化は不要です。
- **Spec-Flow / Agent OS / Intent / GSD**: 一次調査のみ実施、深掘りは必要に迫られた時点で行います。
