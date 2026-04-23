---
reviewer: cross-model-reviewer
spec: tmux-dashboard-mvp
executed_at: 2026-04-20T00:20:00Z
verdict: PENDING
mode: placeholder
---

# Cross-Model Review (PENDING placeholder)

Phase 3 時点では cross-model-reviewer は外部モデル (Codex / GPT / Gemini 等) への手動依頼運用のため、本ファイルは **PENDING placeholder** として生成しています。将来の spec-leader が cross-model-reviewer agent を外部モデル API で自動実行する実装に差し替わったとき、本ファイルが完全な review.md に上書きされます。

## 暫定結論

- verdict: **PENDING**
- receiving-code-review skill は本ファイルを「review 済 / 指摘なし」として扱わず、cross-model 判断を**保留**として consolidated.md に記録します
- 最終 verdict は code-reviewer と security-reviewer の 2 結果のみで算定し、cross-model 判断は Phase 5/6 以降の改修で統合します

## 今後の差替え契約 (Phase 3 改修不要インタフェース)

cross-model-reviewer agent が外部モデル呼び出しを実装した際、本ファイルは以下の構造に上書きされます。spec-leader / receiving-code-review は構造だけに依存し、内容は取り扱いません。

```yaml
---
reviewer: cross-model-reviewer
spec: <spec-name>
executed_at: <ISO-8601>
verdict: pass | needs-fix | reject
external_model: <gpt-4o / codex / gemini-pro 等>
---

# Cross-Model Review: <spec-name>

## 概評
## Critical
## Major
## Minor
## 総合 verdict
```

本 placeholder はこの構造に沿って差し替え可能な状態で閉じます。
