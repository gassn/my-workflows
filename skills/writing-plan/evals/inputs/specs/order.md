---
name: order
status: spec-complete
created: 2026-04-22
brainstorming_archive: specs/archive/order.brainstorm.md
depends_on: [auth]
parallel_group: 2
---

# Spec: order

## 1. 目的
EC サイトの注文フロー (カート操作 + 注文確定)。認証済ユーザーが購入プロセスに進める。

## 2. スコープ
### 2.1 含むもの
- POST /api/cart, GET /api/cart, DELETE /api/cart/:id
- POST /api/orders (注文確定)
### 2.2 含まないもの
- 決済処理 (別 Spec)、在庫管理

## 3. 機能要件
### 3.1 cart 操作
- 認証必須 (auth の requireAuth 使用)
- Cart テーブル (user_id, product_id, quantity UNIQUE)

### 3.2 注文確定
- Order レコード生成 (status: pending_payment)

## 4. 非機能要件
| 項目 | 要件 |
|---|---|
| パフォーマンス | cart API 500ms 以内 |

## 5. 受け入れ基準
- [ ] AC-1: 認証済で cart に商品追加
- [ ] AC-2: 未認証で 401
- [ ] AC-3: 注文確定で Order レコード生成

## 6. 非対象
- 決済処理

## 7. リスクと緩和策
### 7.1 同一商品の多重追加
- 緩和策: Cart の (user_id, product_id) UNIQUE + quantity カラム

## 依存 (auth から取得)
- User モデル: order の user_id 外部キー
- requireAuth ミドルウェア: cart / order API で使用
- Cookie 名 `session`: auth と同一を前提
