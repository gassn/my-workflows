---
name: auth
status: spec-complete
created: 2026-04-22
brainstorming_archive: specs/archive/auth.brainstorm.md
depends_on: []
parallel_group: 1
---

# Spec: auth

## 1. 目的
EC サイトの認証基盤。後続 Spec (order) が認証前提のため最上流に配置。

## 2. スコープ
### 2.1 含むもの
- POST /api/auth/signup / login / logout
- requireAuth ミドルウェア
- users テーブル
### 2.2 含まないもの
- OAuth、パスワードリセット

## 3. 機能要件
### 3.1 login
- 入力: email/password、出力: 200 + session Cookie (HttpOnly/Secure/SameSite=Lax) / 401 `invalid_credentials` 汎用
- bcrypt cost 12

## 4. 非機能要件
| 項目 | 要件 |
|---|---|
| セキュリティ | bcrypt + HttpOnly Cookie + rate limit 5/15min |

## 5. 受け入れ基準
- [ ] AC-1: 有効認証で 200 + Cookie
- [ ] AC-2: 無効で 401 汎用
- [ ] AC-3: レート制限 429 + retry_after=900

## 6. 非対象
- OAuth

## 7. リスクと緩和策
### 7.1 ブルートフォース
- 緩和策: IP レート制限

## 共有資産 (後続 Spec が参照)
- User モデル (users テーブル): id / email / password_hash / created_at
- requireAuth ミドルウェア: order が再利用
- `/api/auth/*` 名前空間 + Cookie 名 `session` (全 Spec 共通)
