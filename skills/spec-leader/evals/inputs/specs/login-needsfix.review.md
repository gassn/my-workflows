---
spec: login
reviewed: 2026-04-20
verdict: needs-fix
scores:
  completeness: 70
  feasibility: 75
  consistency: 80
  overall: 74
---

# Spec Review: login

## 総合判定

**verdict**: `needs-fix`

**理由**: Major 3 件を検出。Critical はないが、Plan ステージ進行前に解消すべき曖昧さが複数あります。

## 1. 完全性 (score: 70/100)

### Critical
(なし)

### Major
- [M-1] 受け入れ基準の「セッションが適切に維持される」が検証不可能な文言 (該当章: §5 / 修正提案: 具体的な有効期限と Cookie の HttpOnly/Secure フラグ検証を明記)
- [M-2] レート制限の要否に関する TBD が未解消 (該当章: §7 リスク / 修正提案: Spec 段階で実装するか否かを明確化、実装する場合は 5 回/15 分などの具体値)
- [M-3] エラーメッセージの粒度に関する TBD が未解消 (該当章: §3 / 修正提案: 汎用メッセージ「メールまたはパスワードが不正」で固定するか、ブルートフォース耐性観点から明確化)

### Minor
(なし)

## 2. 実現可能性 (score: 75/100)
(指摘なし)

## 3. 整合性 (score: 80/100)
(指摘なし)

## 修正ガイド

- 本 review.md を参照しながら writing-spec をレビュー指摘対応モードで再起動してください
- spec.md の `status` を `spec-writing` に戻し、Major 3 件を順次反映してください
- 修正完了後、spec.md の `status` を `spec-complete` に戻すと spec-review が自動再起動します
