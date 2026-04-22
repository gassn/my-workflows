---
name: login
spec_path: specs/login.md
status: plan-complete
created: 2026-04-22
---

# Plan: login (iter-3 v2 fixture)

## 1. 技術設計概要

Express + PostgreSQL + bcrypt + Cookie セッションのシンプルな認証実装。

## 2. アーキテクチャ

- `src/auth/`: ログイン / ログアウト / ミドルウェア
- `src/db/`: User モデル + migration
- Cookie: `session` (HttpOnly / Secure / SameSite=Lax、Max-Age=86400)

## 3. データモデル

- `users` テーブル: id / email (UNIQUE) / password_hash / created_at

## 4. API 設計

- POST /api/auth/signup / login / logout
- GET /api/me
- ミドルウェア: requireAuth

## 5. 実装タスク分解

### 5.1 タスクリスト

- [ ] T-1: User モデル + migration (45 分)
  - 入力: spec §3.1
  - 出力: `src/db/migrations/0001_users.sql` + `src/db/user.ts`
  - テスト: users テーブル作成 / email UNIQUE 制約
  - files_touched: [src/db/migrations/0001_users.sql, src/db/user.ts, tests/db/user.test.ts]
- [ ] T-2: signup API (45 分)
  - 入力: email/password、bcrypt cost 12
  - 出力: 201 + user_id + Cookie
  - テスト: 成功 / email 重複 / 弱いパスワード拒否
  - files_touched: [src/auth/signup.ts, tests/auth/signup.test.ts]
- [ ] T-3: login API (45 分)
  - 入力: email/password
  - 出力: 200 + user_id + Cookie / 401 汎用エラー
  - テスト: 成功 / 無効認証 / タイミング攻撃耐性
  - files_touched: [src/auth/login.ts, tests/auth/login.test.ts]
- [ ] T-4: logout + requireAuth (30 分)
  - 入力: Cookie
  - 出力: 204 Cookie 破棄 / 401 if 未認証
  - テスト: セッション破棄 / 保護ページ応答
  - files_touched: [src/auth/logout.ts, src/auth/middleware.ts, tests/auth/logout.test.ts]
- [ ] T-integrate: ルート登録 (15 分)
  - files_touched: [src/app.ts]
  - 依存: T-1〜T-4 完了後

### 5.2 タスク間の依存関係と並列判定

- T-1 → (T-2, T-3, T-4 並列可、files_touched 積集合空) → T-integrate

## 6. テスト戦略

- ユニット: 各 .test.ts
- 統合: E2E でサインアップ→ログイン→保護ページ→ログアウト

## 7. リスクと対応

- bcrypt コスト高 → cost 12 固定 (p95 200ms 目安)
- タイミング攻撃 → 存在しないユーザーにもダミー bcrypt 実行
