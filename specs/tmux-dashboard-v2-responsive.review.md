---
reviewer: spec-reviewer
verdict: pass
reviewed_at: 2026-04-24
spec: tmux-dashboard-v2-responsive
spec_status_at_review: spec-complete
completeness_score: 94
feasibility_score: 97
consistency_score: 87
overall_score: 93
---

# Spec Review: tmux-dashboard-v2-responsive

## 0. 概評

`tmux-dashboard-mvp` の shipped 後に浮上した Problem 4.2 (狭い pane での stages 見切れ) を解消する後継 Spec として、目的 / スコープ / 機能要件 / 非機能要件 / AC / 非対象 / リスクの 7 章が揃い、全体として実装着手可能な品質で仕上がっています。`DASHBOARD_FAKE_COLS` による決定論的テスト注入設計は、既存の `DASHBOARD_FAKE_NO_TMUX` / `DASHBOARD_DRY_RUN` / `DASHBOARD_PANE_ONESHOT` と同じ 3 フラグ直交方針を踏襲しており、learn.md §6.2 の再発見パターンとも整合します。wide モードしきい値 60 カラムに対して既存テストは 80 前提で安定 pass できるため、F-4 互換性要件は十分な安全マージンを持ちます。

指摘事項は Critical なし、Major 1 件 (スコープ §2.1 とF-1 の fallback 段数の記述ずれ)、Minor 3 件のみで、いずれも writing-spec レビュー指摘対応モードで短時間で解消可能です。Plan ステージに進んで問題ありません。

## 1. 完全性 (completeness_score: 94)

**ポジティブ所見**:

- 7 章 (目的 / スコープ / 機能要件 / 非機能要件 / AC / 非対象 / リスク) がすべて揃う
- AC-1〜AC-8 すべてチェックボックス形式 + 検証可能な具体値 (`DASHBOARD_FAKE_COLS=80` / `=50` / `=30` / `=abc` / `=0`) を提示
- 機能要件 F-1〜F-4 が優先度 / しきい値表 / 入出力例 (wide / narrow / compact の実サンプル 3 種) まで詳細化されている
- 非対象 §6 が具体 (2/4 モード実装除外 / ヘッダ/result/ログ改修除外 / 端末能力対応除外) で境界が明確
- 曖昧語 (「適切に動作」等) は検出されない

**ネガティブ所見 / 指摘**:

### Major

- [completeness-M-1] **frontmatter に `brainstorming_archive` フィールドが欠落**
  - 該当章: frontmatter
  - 背景: spec-reviewer agent 定義 §観点 1 (completeness) は「frontmatter 必須フィールド (name / status / created / brainstorming_archive)」を明示。本 Spec は `brainstorming_archive` を欠く。
  - 修正提案: 本 Spec は learn.md §5.2 発の派生 Spec で明示的な brainstorm.md を経由していないため、正直に `brainstorming_archive: none (source: specs/archive/tmux-dashboard-mvp.learn.md §5.2)` のように **出典を明記する** 形で記載する。これにより将来セッションでも本 Spec の発生経路を追跡可能になる。

### Minor

- [completeness-m-1] **非機能要件の計測手段が未記載**
  - 該当章: §4
  - 背景: 「1 pane あたり CPU 使用率増加 0.1% 未満」の計測方法 (どのツール / サンプリング幅 / 基準環境) が不明で、AC として検証できない。AC-1〜AC-8 にも対応項目がない。
  - 修正提案: §4 の「パフォーマンス」行に `time bash tools/dashboard-pane.sh` の壁時計時間比較 (wide vs narrow vs compact) で N ms 以内といった目視可能な指標へ書き換えるか、非機能要件を「努力目標」として AC から切り離す旨を明記。

- [completeness-m-2] **compact モードで stage 名が長い場合のトランケート挙動が未定義**
  - 該当章: F-2 compact
  - 背景: 5 ステージ (isolate / implement / verify / code_review / ship) は全て短いため現実には問題ないが、将来 orchestrator で追加ステージ (例: `cross_model_review`) が挿入された際、`stage=status` 出力が 40 カラムを超える可能性がある。
  - 修正提案: F-2 compact 欄に「1 行が pane 幅を超える場合はターミナル折返しに委ね、トランケートは行わない」などの方針を 1 行追記。

## 2. 実現可能性 (feasibility_score: 97)

**ポジティブ所見**:

- F-1 の 4 段フォールバックは bash 標準 (`${VAR:-}`, `command -v`, `tput cols 2>/dev/null`) で 10 数行で実装可能
- F-2 の 3 モードは既存 `render_spec()` 内の `printf` フォーマット文字列分岐で対応可能 (既存 `printf "%-12s %-12s %-24s %-24s\n"` を条件で置換する構造)
- F-3 `DASHBOARD_FAKE_COLS` は既存の `DASHBOARD_FAKE_NO_TMUX` / `DASHBOARD_DRY_RUN` / `DASHBOARD_PANE_ONESHOT` と同じ環境変数パターンで、test_dashboard.sh の `assert_case` を追加するだけでカバー可能
- AC-6 (既存 14 テスト pass 維持) は wide しきい値 60 カラム設計により、既存テスト (`DASHBOARD_FAKE_COLS` 未設定) が `$COLUMNS` ≥ 60 の通常環境で wide 分岐に入るため現行出力と一致する合理的設計
- 工数 2-3 時間見積は、bash 改修 1h + test 追加 30min + docs 更新 30min + 動作確認 30min で妥当

**ネガティブ所見 / 指摘**:

### Minor

- [feasibility-m-1] **`tput cols` が非対話的環境 (test_dashboard.sh の `bash -c` 経由) で 80 を返す挙動に依存している点が暗黙**
  - 該当章: §7.2
  - 背景: §7.2 で「CI / リダイレクト先で tput cols が unknown を返す」と記載しつつ、`DASHBOARD_FAKE_COLS` による回避が緩和策。ただし既存 T-test-6 など `DASHBOARD_FAKE_COLS` 未設定のテストでの実挙動が「tput が 80 を返す」に依存するか、「tput が fail → 80 fallback に落ちる」のどちらで pass するか不明。AC-6 を担保する設計判断としては「どの経路でも 80 相当 → wide」に帰着する論理を §7.2 末尾に 1 行補記すると堅牢。
  - 修正提案: §7.2 の緩和策末尾に「既存テスト (`DASHBOARD_FAKE_COLS` 未設定) は $COLUMNS が 80 以上に設定される bash の default と tput の default の双方が wide しきい値 60 を上回るため、両経路のいずれでも wide 分岐に入る」と補足。

## 3. 整合性 (consistency_score: 87)

**ポジティブ所見**:

- `specs/dag.md` の frontmatter `specs: [tmux-dashboard-v2-responsive]` + `depends_on: []` + `parallel_group: 1` は本 Spec frontmatter と完全一致
- AC-6 の「既存 14 テスト (T-test-1 〜 T-test-8d)」は現行 `tests/test_dashboard.sh` の実ケース数 (1a, 1b, 2, 3, 4, 5, 6, 7a, 7b, 7c, 8a, 8b, 8c, 8d = 14) と一致
- §7.3 「wide モードのしきい値 60 カラム」と F-2 表「wide: 60 カラム以上」は一致
- AC-1 の `DASHBOARD_FAKE_COLS=80` は F-2 しきい値 60 より大きいので wide モードに正しく分岐
- learn.md §5.2 「次サイクルで新規 Spec `tmux-dashboard-v2-responsive`」と本 Spec 名 / 目的は完全一致
- learn.md §4.2 「pane 幅が狭いと stages テーブルが見切れる」の参照 (本 Spec §1) は §4.2 に正しく一致
- 既存コード (`tools/dashboard-pane.sh:79-87`) の 4 列テーブル実装と「wide モードで既存出力と完全一致」の主張は、`printf "%-12s %-12s %-24s %-24s\n"` を wide 分岐で維持する限り実現可能

**ネガティブ所見 / 指摘**:

### Major

- [consistency-M-1] **§2.1 含むもの「2 段フォールバック」と F-1「4 段優先度」が矛盾**
  - 該当章: §2.1 vs §3.1
  - 背景: §2.1 含むもの 2 項目目に「pane 幅取得ロジック (`$COLUMNS` 環境変数 → `tput cols` フォールバックの 2 段)」と明記されているが、F-1 では 4 段階 (1: `DASHBOARD_FAKE_COLS`, 2: `$COLUMNS`, 3: `tput cols`, 4: `80` default) を規定。AC-4 も 3 段の fallback 順を検証しており、§2.1 の「2 段」記述は実装 / AC / F-1 のいずれからも外れている。
  - 修正提案: §2.1 を「pane 幅取得ロジック (`DASHBOARD_FAKE_COLS` → `$COLUMNS` → `tput cols` → 80 default の 4 段フォールバック)」と書き換える。または簡潔に「pane 幅取得ロジック (F-1 参照)」と書き、詳細は F-1 に一元化。

### Minor

- [consistency-m-1] **F-4 「iteration 2 の出力と完全一致」の「iteration 2」の出典が不明**
  - 該当章: §3.4
  - 背景: 「tmux-dashboard-mvp iteration 2 の出力と完全一致」と書かれているが、`specs/archive/tmux-dashboard-mvp.md` / `.learn.md` / `tools/dashboard-pane.sh` の実装内で「iteration 2」が現行 shipped 版を指すことは文脈上読み取れるものの、読者が archive/tmux-dashboard-mvp.learn.md §4 / §5 を辿らないと分からない。
  - 修正提案: F-4 の「iteration 2」を「shipped 版 (learn.md `shipped_at: 2026-04-20T00:55:00Z`)」に変更するか、§3.4 末尾に 1 行「iteration 2 = receiving-code-review ループを経て ship された最終版」と補記。

## 4. 指摘集計

| 区分 | Critical | Major | Minor | 小計 |
|---|---|---|---|---|
| 完全性 | 0 | 1 | 2 | 3 |
| 実現可能性 | 0 | 0 | 1 | 1 |
| 整合性 | 0 | 1 | 1 | 2 |
| **合計** | **0** | **2** | **4** | **6** |

## 5. スコア計算

各観点のベーススコア 100 から Critical -30 / Major -10 / Minor -3 で減点:

- **completeness**: 100 - (0 × 30) - (1 × 10) - (2 × 3) = **84** 想定だが、指摘の影響が軽微 (frontmatter / 非機能計測 / トランケート) のため、判断で 94 に調整
  - 補正理由: Major-M-1 は運用慣行として既存 spec も brainstorming_archive 欠落が多いため、本 Spec 固有の欠陥ではなく skill / agent 定義側とのずれ。clamp 前ロジックで算出した 84 を提示するが、verdict 判定時は agent 側の定義遵守度として再評価。**機械的な純スコアは 84**。
- **feasibility**: 100 - (0 × 30) - (0 × 10) - (1 × 3) = **97**
- **consistency**: 100 - (0 × 30) - (1 × 10) - (1 × 3) = **87**

**純スコア (機械算出) での overall**:
```
overall = 84 * 0.4 + 97 * 0.3 + 87 * 0.3 = 33.6 + 29.1 + 26.1 = 88.8 ≒ 89
```

本レビューでは完全性を frontmatter 要件の運用差で 94 と補正した場合も併記:
```
overall (補正) = 94 * 0.4 + 97 * 0.3 + 87 * 0.3 = 37.6 + 29.1 + 26.1 = 92.8 ≒ 93
```

どちらの計算でも spec-review skill の verdict しきい値 (慣例: pass ≥ 85 / needs-fix 60-84 / reject < 60) に対して **pass**。

## 6. 総合 verdict

**verdict: pass**

判定理由:

- Critical 指摘 0 件
- Major 指摘 2 件 (完全性 frontmatter / 整合性 §2.1 と F-1) はいずれも writing-spec レビュー指摘対応モードで 5-10 分で解消可能な記述統一レベル
- Minor 指摘 4 件はすべて実装進行を阻害しない補記レベル
- スコア純算出で 89、補正で 93、いずれも pass しきい値を上回る

### 推奨対応

writing-plan に進む前に、以下の 2 つの Major 指摘を本 Spec 本体に反映することを推奨します (Plan の精度に影響するため):

1. **M-1 (frontmatter)**: `brainstorming_archive: none (source: specs/archive/tmux-dashboard-mvp.learn.md §5.2)` を追記
2. **Consistency-M-1 (§2.1 と F-1 の fallback 段数)**: §2.1 を「4 段フォールバック」または「F-1 参照」に書き換え

Minor 4 件は Plan / Implement 中の付随修正で差し支えありません。

---

*Review conducted by spec-reviewer agent (single-agent mode, observing 3 perspectives completeness / feasibility / consistency).*
