---
name: auth
created: 2026-04-16
status: brainstorming-complete
depends_on: []
parallel_group: 1
---

# Brainstorming: auth

## 目的
EC サイト全体で共通利用する認証基盤を構築します。後続の order (注文), payment (決済) の両 Spec がユーザー認証を前提とするため、最上流に認証機能を切り出します。

## 利用者
EC サイト利用者 (購入者)。管理者認証は別 Spec で扱う。

## 成功条件 (受け入れ基準)
- メールアドレスとパスワードでサインアップ / ログインできる
- セッションは Cookie ベース (HttpOnly / Secure)
- ログアウトでセッション破棄
- ログイン済みユーザーのみ /account, /orders, /checkout にアクセス可能

## 制約
- **技術的制約**: Express + PostgreSQL 構成、bcrypt でパスワードハッシュ化
- **依存関係**: 他 Spec (order, payment) が本 Spec の認証 API を参照するため、最初にリリース

## スコープ
### 含むもの
- サインアップ / ログイン / ログアウト
- セッション Cookie 発行・破棄
- ミドルウェア (認証必須エンドポイント保護)
- ユーザー情報取得 API (GET /api/me)

### 含まないもの
- パスワードリセット
- ソーシャルログイン
- 2 要素認証
- 管理者認証

## リスク
- **セッションハイジャック**: Cookie 盗難。HttpOnly / Secure / SameSite=Lax で緩和
- **ブルートフォース**: パスワード総当たり。レート制限を Spec で判断

## 未解決事項
- セッション有効期限
- /api/me のレスポンス形式

## Spec 間で共有する資産
- **認証ミドルウェア** (`requireAuth`): order / payment が import して使用
- **ユーザーモデル** (`User` テーブル): order / payment が user_id で参照

## 切り出した理由
- order / payment の両者が認証を前提とするため、認証基盤を独立 Spec として最上流に切り出し
