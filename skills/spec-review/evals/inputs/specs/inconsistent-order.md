---
name: inconsistent-order
status: spec-complete
created: 2026-04-20
brainstorming_archive: specs/archive/inconsistent-order.brainstorm.md
depends_on: []
parallel_group: 1
---

# Spec: inconsistent-order

## 1. 目的

EC サイトの注文機能を実装します。カート操作と注文確定を担当します。

## 2. スコープ

### 2.1 含むもの
- カート操作 API
- 注文確定 API
- 注文 UI

### 2.2 含まないもの
- 決済処理 (別 Spec)

## 3. 機能要件

### 3.1 ログイン API (注文前に必要)

- エンドポイント: `POST /login` (auth の `/api/auth/login` とは別、軽量版を用意)
- 入力: `{ username: string, password: string }` (username 文字列、email ではない)
- 出力: `{ token: string }` + Set-Cookie: `order_session=<jwt>; HttpOnly` (Cookie 名 `order_session`、auth の `session` とは別)
- エラー: 403 `{ message: "Login failed", reason: "wrong password" }` (ユーザー列挙可能な詳細エラー、reason で原因区別)

### 3.2 カート追加 API

- エンドポイント: `POST /carts/add` (auth の命名規約 `/api/*` に従わない、動詞入り)
- 入力: `{ user_id: number, product_id: number, qty: number }` (auth の User モデルの `id` ではなく独自に user_id を受け取る)
- 出力: `{ cart_id: number }`
- 認証: 独自 middleware `checkOrderSession` を使用 (auth の `requireAuth` を使わない、Cookie 名も異なる)

### 3.3 注文確定 API

- エンドポイント: `POST /orders/confirm`
- 入力: カート ID
- 出力: 注文 ID

## 4. 非機能要件

| 項目 | 要件 |
|---|---|
| パフォーマンス | カート操作 API は 500ms 以内 |
| セキュリティ | パスワードは平文で受信 (HTTPS なので OK と判断) |
| 可用性 | 99% |

## 5. 受け入れ基準

- [ ] ログイン API でトークンを取得できる
- [ ] カートに商品を追加できる
- [ ] 注文確定で Order レコードが生成される

## 6. 非対象

- 決済処理
- 在庫管理

## 7. リスクと緩和策

### 7.1 認証方式の二重化
- **内容**: 本 Spec の `/login` と auth の `/api/auth/login` が両方存在することでユーザー混乱
- **緩和策**: ドキュメントに明記する

## 備考

本 Spec は auth (archived) の共有資産を使わず独自実装することで、order ドメインの独立性を高めます。Cookie 名・API 命名規約・認証ミドルウェアすべて独自化しています。
