---
name: auth
status: archived
created: 2026-04-15
shipped: 2026-04-17
---

# Spec: auth (archived)

## 1. 目的

EC サイトの認証基盤。セッション Cookie ベースで、後続 Spec (order / payment 等) が認証を前提とするため最上流に配置。

## 3. 機能要件

### 3.1 サインアップ API

- エンドポイント: `POST /api/auth/signup`
- 入力: `{ email: string, password: string }`
- 出力: `{ user_id: number, email: string }` + Set-Cookie: `session=<token>; HttpOnly; Secure; SameSite=Lax`

### 3.2 ログイン API

- エンドポイント: `POST /api/auth/login`
- 入力: `{ email: string, password: string }`
- 出力: `{ user_id: number, email: string }` + Set-Cookie: `session=<token>; HttpOnly; Secure; SameSite=Lax`
- エラー: 401 `{ error: "invalid_credentials" }` (ユーザー列挙対策のため原因を区別しない)

### 3.3 ログアウト API

- エンドポイント: `POST /api/auth/logout`
- 入力: (Cookie 経由、body なし)
- 出力: 204 No Content + Set-Cookie: `session=; Max-Age=0`

### 3.4 現在ユーザー取得 API

- エンドポイント: `GET /api/me`
- 出力: `{ user_id: number, email: string, created_at: string }`

### 3.5 認証ミドルウェア

- 名前: `requireAuth`
- 挙動: Cookie `session` を検証し、無効なら 401 `{ error: "unauthenticated" }`

## 共有資産 (後続 Spec が参照)

- `User` モデル (テーブル: `users`): `id` / `email` / `password_hash` / `created_at`
- `requireAuth` ミドルウェア: order / payment などの認証必須エンドポイントで使用
- Cookie 名: `session` (全 Spec 共通、他名を使わない)

## API 命名規約

- すべて `/api/` プレフィックス
- リソース + 動詞なし (例: `/api/orders`、`/api/orders/:id`)
- 認証関連は `/api/auth/*` 名前空間
