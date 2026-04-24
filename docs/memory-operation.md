# Claude Code auto memory の本プロジェクト運用方針

Claude Code には永続的な file-based memory system (`~/.claude/projects/<encoded-path>/memory/`) が備わっており、会話を跨いで情報を保持できます。本プロジェクトでの memory 機能の扱いを整理します。

## 現状 (2026-04-24 時点)

本プロジェクトの memory ディレクトリ (`~/.claude/projects/-home-gassn-my-workflows/memory/`) は **補助的に運用開始** しました。設計知識は引き続き以下の 3 階層で管理し、memory はドキュメントに吸収できない user / feedback 情報のみに限定しています。

| 階層 | 媒体 | 例 |
|---|---|---|
| ルール / 横断方針 | `CLAUDE.md` | 設計思想、git 運用、skill/agent 配置方法、参考フレームワーク優先順位 |
| 個別コンポーネント設計 | `skills/<name>/SKILL.md` / `agents/<name>.md` | 各 skill / agent の起動条件・役割・入出力・アンチパターン |
| Phase / プロジェクト進捗 | `docs/phase<N>-completion.md` / `ROADMAP.md` | Phase 3/4/5 の実装履歴・知見・未対応事項 |
| ユーザー個人 / 対話指針 (memory 限定) | `~/.claude/projects/.../memory/*.md` | 作業スタイル、コミュニケーション嗜好、繰り返し指摘される feedback |

2026-04-24 時点で保存済の memory 3 件:

- `user_profile.md` (type: user): gassn の作業スタイル / 志向 / 公開方針
- `feedback_status_freshness.md` (type: feedback): iteration 中の progress.json 最新化
- `feedback_choice_based_progression.md` (type: feedback): 選択肢提示 + 推奨案形式での進行

プロジェクト状態 / Phase 進捗 / 参照情報は引き続き docs/ 側に集約し、memory には入れません (重複保守回避)。

## auto memory を docs に集約しない判断の根拠 (user / feedback のみ memory に保存)

1. **本プロジェクト = 環境拡張プロジェクト**: 通常の開発プロジェクトと異なり、成果物自体が Claude Code の振る舞いを定義する資産 (skill / agent / hook) であり、資産として外部化するほうが自然
2. **docs/ の充実**: 9 ステージのワークフロー定義 / コンポーネントマップ / 完了レポート等で、設計意図・判断根拠・進捗がすべて文書化されている
3. **skill / agent / hook の frontmatter**: 起動トリガー・責務・アンチパターンが各コンポーネントに埋め込まれており、Claude が必要時に Read で取得可能
4. **SessionStart hook の `load-session-skills.sh`**: using-superpowers 方式でインデックス常駐、詳細は必要時に Read、を実現済み
5. **auto memory の重複運用を避ける**: 同じ情報が memory と docs 両方にあると、どちらが最新か不明で保守コスト増

ただし以下 2 種類は docs に馴染まないため memory に限定保存:

- **user 系 (ユーザー個人の作業スタイル / 志向)**: 公開ドキュメントに書くと第三者にとってノイズ / プライバシー感も出る
- **feedback 系 (対話の進め方 / 繰り返し指摘される運用)**: 「A/B/C 選択肢で進める」等の対話スタイルは、公開ドキュメントよりセッション横断 memory が適する

## 積極運用すべきシナリオ (将来の検討項目)

以下のシナリオでは auto memory の利用が合理的な可能性があります:

### 1. ユーザー (個人) の学習履歴

ユーザーが特定技術 (例: Rust 初心者 / React 熟練者) の場合、回答の粒度を調整するための user memory は文書化より memory が適する。ただし本プロジェクトは「環境拡張」なので通常の開発セッションで個人ユーザー情報を使う頻度が低い → 現状は不要。

### 2. 繰り返し発生する誤解 / 設計選択の履歴

過去セッションで検討して却下した案を、次セッションで再検討しないための feedback memory は docs に書くほど大きくない場合に有用。現状は phase<N>-completion.md や iter-N benchmark に記録しているため代替可。

### 3. プロジェクト外部の参照情報

`docs/frameworks.md` に参考フレームワーク一覧はあるが、各フレームワークの最新 URL / 更新状況を追跡する reference memory は memory が適する可能性。現状は `docs/frameworks.md` で十分。

## 将来 memory を使う場合のガイドライン

もし本プロジェクトで auto memory を使う場面が生じた場合、以下に従ってください:

### 書くべきもの

- **ユーザー個人の role / 学習履歴**: 「このユーザーは Claude Code 環境拡張をしている」「Phase 進捗の追跡を重視」等、共通文脈
- **feedback 履歴**: ユーザーが強く指示した方針 (例: "brainstorming を直接 context に入れるな")
- **プロジェクト外部の参照ポインタ**: 「hookify の最新ドキュメントは <URL>」等、外部情報の場所

### 書くべきでないもの

- **docs / SKILL.md に既にある情報** (重複で保守困難)
- **コード規約 / skill 設計規約** (CLAUDE.md で統一)
- **Phase 進捗や完了レポート** (phase<N>-completion.md に集約)
- **ephemeral な作業状態** (current task、in-progress の詳細)

### 運用ルール

1. **記録前に docs に書けないか検討**: docs / CLAUDE.md / SKILL.md に収まるなら memory 不要
2. **1 ファイル 1 話題**: memory は個別ファイルに分割、MEMORY.md でインデックス化
3. **定期的な rotation**: 古くなった memory は削除、陳腐化した情報を残さない
4. **feedback memory の Why / How to apply**: ユーザー指示の背景と適用場面を明記

## 他の Claude Code プロジェクトとの関係

本プロジェクトのメタな特性 (Claude Code 自体を拡張する) から得た知見:

- **通常の開発プロジェクト**: auto memory が価値を発揮 (会話を跨ぐ個人理解 + プロジェクト文脈)
- **環境拡張 / 設定リポジトリ (本プロジェクト)**: docs 中心で auto memory は補助的

他 Claude Code プロジェクトで本プロジェクトを参考にする場合、memory 運用方針は各プロジェクトの性質に合わせて再検討してください。

## 関連ドキュメント

- `CLAUDE.md`: 本プロジェクトの設計思想 + skill/agent/hook 配置方法
- `docs/components-map.md`: skill + agent + hook の俯瞰
- `docs/phase3-completion.md` 〜 `phase5-completion.md`: Phase ごとの完了レポート
- `ROADMAP.md`: 全 Phase の段階的構築計画
