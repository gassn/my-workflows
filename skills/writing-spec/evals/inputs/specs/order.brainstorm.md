---
name: order
created: 2026-04-16
status: brainstorming-complete
depends_on: [auth]
parallel_group: 2
---

# Brainstorming: order

## 目的
EC サイトで商品をカートに追加し、注文を確定するまでのフローを実装します。認証済みユーザーが購入プロセスに進めるようにします。

## 利用者
認証済みの EC サイト利用者 (購入者)。

## 成功条件 (受け入れ基準)
- ログイン済みユーザーが商品をカートに追加できる
- カート内容の参照・数量変更・削除ができる
- 注文確定時に Order レコードが生成される (status: pending_payment)
- 未ログインユーザーはカート操作で /login にリダイレクトされる

## 制約
- **依存関係**: 認証機能 (auth Spec) が必須。auth の `requireAuth` ミドルウェアを利用
- **技術的制約**: 既存 PostgreSQL の Product テーブルを参照、新規 Order / CartItem テーブルを追加

## スコープ
### 含むもの
- カート操作 API (POST /api/cart, GET /api/cart, DELETE /api/cart/:id)
- 注文確定 API (POST /api/orders)
- カート UI (/cart ページ)

### 含まないもの
- 決済処理 (payment Spec が担当)
- 注文キャンセル
- 在庫引当ロジック (別 Spec)
- 配送情報入力

## リスク
- **同一商品の多重追加**: 同じ product_id が複数行で追加される。CartItem は (user_id, product_id) ユニーク + quantity カラムで解決
- **在庫不足**: 在庫 0 商品のカート追加。Spec で検証ポリシー決定

## 未解決事項
- カート有効期限 (セッション終了時破棄 or 永続化)
- 注文確定時の在庫チェックの有無

## Spec 間で共有する資産 (依存)
- **auth の `requireAuth` ミドルウェア**: カート / 注文 API で使用
- **auth の User モデル**: Order / CartItem の user_id 外部キー
- **payment Spec への引き渡し**: 作成した Order の id を payment Spec に引き渡す

## 切り出した理由
- 認証成立後、決済前段のカート〜注文確定フローとして独立させた
- payment Spec は本 Spec が生成する Order を前提とする
