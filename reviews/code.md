---
reviewer: code-reviewer
spec: dashboard-color-themes
reviewed: 2026-04-24
executed_at: 2026-04-24T08:10:00Z
verdict: pass
---

# Code Review: dashboard-color-themes

## 総合判定

verdict: **pass**

Critical: 0 件、Major: 0 件、Minor: 3 件。Plan §4.1 / Spec §7.1 の 4 段検証を仕様通り実装しており、先行 `dashboard-color` Spec の `print_color` / `_color_for_status` API を壊さずにテーマ機構を追加できている。30/30 テスト pass、attack payload (コマンド置換 / コマンド連結 / 非 COLOR_ 変数) の 3 種を手元で別途実機検証し、いずれも default フォールバックで遮断されることを確認済。Minor 3 件はいずれも ship ブロックにならない軽微な品質改善事項。

## Critical

なし

## Major

なし

## Minor

- [code-Minor-1] Spec §3.2 (F-2) の「stdout に `loaded: <theme-name>` を出力 (log 用)」仕様が未実装
  - **該当**: `tools/dashboard-pane.sh:97-103` (load_theme 代入ループ)
  - **内容**: Spec §3.2 は成功時 stdout に `loaded: <theme-name>` を出力する設計、Plan §4.1 の「stdout: `loaded: <theme-name>` (log 用)」でも明記されている。実装ではエラー時の warning のみで、成功時の stdout 出力がない。
  - **影響**: 機能には影響しないが、debug 時にどのテーマが最終的にロードされたかをログから追跡できない。tmux pane では render_spec の出力と混在する懸念があるため、`warn` と同様 stderr にしても良い。
  - **修正提案**: load_theme 末尾 (line 103 付近) に `echo "loaded: ${theme_name}" >&2` を追加、または Plan を「成功時無出力」で更新 (現状 Plan との不一致解消)。

- [code-Minor-2] load_theme のヘッダーコメントが「4 段検証」と書かれているが、実装は 5 段 (theme 名 / file 存在 / 行 allowlist / quote 剥離 / 値 regex)
  - **該当**: `tools/dashboard-pane.sh:41-45` (load_theme 関数頭コメント)
  - **内容**: コメントに列挙される 4 項目は「theme 名 allowlist / 行 allowlist / quote 剥離 / 値 regex」だが、実装は file 存在チェック (line 56-60) も含む。Spec §7.1 / Plan §4.3 との用語整合性を取るなら「4 段」を「5 段」に改めるか、「file 存在」を前提条件扱いとして明記するのが望ましい。
  - **修正提案**: `# source / eval / コマンド置換を一切使わない 5 段検証` にするか、`# 4 段検証 (+ file 存在確認)` と補足する。

- [code-Minor-3] `_pending` 配列が同一 key の重複定義を上書き (last-write-wins)
  - **該当**: `tools/dashboard-pane.sh:80` (`_pending["$var"]="$val"`)
  - **内容**: theme ファイル内に `COLOR_COMPLETED='\e[32m'` が 2 行あった場合、後方の値が勝つ。Plan / Spec には「重複禁止」の記述がないため厳密には仕様逸脱ではないが、運用上「1 変数につき 1 行」が暗黙の前提であることを考えると、重複行を `had_invalid=1` 扱いにするか少なくともコメントで挙動を明示するのが保守性上望ましい。
  - **修正提案**: `[[ -v _pending["$var"] ]] && { had_invalid=1; continue; }` を追加して重複を拒否する。または現挙動を受け入れてコメント `# 同一 key は last-write-wins で許容` を足す。

## 良かった点

- `printf -v "$key"` + `export "$key"` の直接代入で、文字列中に残存する `\e` (literal) を `printf '%b'` で ESC へ変換する順序が丁寧 (line 97-102)。攻撃面を最小化しつつ理論通り動く実装。
- `declare -A _pending` を関数内で宣言することで暗黙 local スコープにしており、再帰 `load_theme "default"` 時も外側バッファを汚染しない。`local -A` でも同等だが、現状で十分安全。
- 再帰 fallback の無限ループ防止ガード (`[[ "$theme_name" != "default" ]]`) が 3 箇所 (line 52 / 58 / 88) に重複して入っており、どの失敗経路でも default.env 不在時は 1 回の warning で正しく exit する (実機で検証済)。
- `dashboard-color` Spec shipped 時の `COLOR_*` 定数定義 (line 31-38) を保持したまま load_theme で上書きする設計なので、テーマ file 自体が壊れていても fallback 定数で動作継続できる二段構え。
- テストケース T-test-12a〜12e が `DASHBOARD_FORCE_COLOR=1` と `DASHBOARD_FAKE_COLS=80` の組合せで非 TTY 環境の擬似 TTY 化を活用しており、先行 `dashboard-color` Spec の環境変数を適切に再利用。
- docs/tmux-dashboard-operation.md §3.3 が「挙動マトリクス」表 (未指定 / 標準 3 種 / 自作 / nonexistent / path traversal / 不正 entry) の 6 行で外部利用者に十分な情報を渡せている。
