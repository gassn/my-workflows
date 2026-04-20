---
name: payment
created: 2026-04-16
status: brainstorming-complete
depends_on: [order]
parallel_group: 3
---

# Brainstorming: payment

## 目的
order Spec で確定した注文 (status: pending_payment) に対してクレジットカード決済を実行し、注文ステータスを paid に遷移させる機能を実装します。

## 利用者
認証済みの EC サイト利用者 (購入者)。

## 成功条件 (受け入れ基準)
- pending_payment 状態の Order に対し、Stripe でクレジットカード決済が実行できる
- 決済成功時に Order.status を paid に更新
- 決済失敗時にエラーを表示し、Order.status は pending_payment のまま
- 決済結果に応じた通知メールを送信 (既存メール送信モジュール使用)

## 制約
- **依存関係**: order Spec の Order テーブル、auth の認証必須
- **技術的制約**: Stripe API を使用。Stripe シークレットキーは環境変数で管理
- **セキュリティ制約**: カード情報はサーバに保存しない (Stripe Elements でクライアント側でトークン化)

## スコープ
### 含むもの
- 決済実行 API (POST /api/orders/:id/payment)
- Stripe Elements を組み込んだ決済 UI
- 決済成功 / 失敗通知メール送信
- Stripe Webhook 受信エンドポイント (決済状態の非同期更新)

### 含まないもの
- 返金処理
- サブスクリプション / 定期決済
- カード情報の自社保管
- 代替決済手段 (コンビニ決済 / 銀行振込等)

## リスク
- **Webhook 検証漏れ**: 署名検証なしで Webhook を受け付けると改ざんリスク。Stripe 署名検証を必須化
- **決済二重実行**: 同一 Order に対して複数回決済。Idempotency Key + Order.status チェックで防止
- **ネットワーク障害時の状態不整合**: Stripe 側成功だが自社 DB 更新失敗。Webhook で補償

## 未解決事項
- Stripe API のバージョン指定
- 決済通貨 (JPY 固定 or USD 併用)
- Webhook エンドポイントの URL パス

## Spec 間で共有する資産 (依存)
- **order の Order モデル**: status 更新対象
- **auth の認証ミドルウェア**: 決済 API 保護
- **既存メール送信モジュール**: 決済結果通知

## 切り出した理由
- 決済は外部サービス連携 (Stripe) とセキュリティ要件が特殊で、order とは別サイクルでテスト・改修することが多い
- Webhook 関連の非同期処理を切り出すことで、order Spec の実装をシンプルに保つ
