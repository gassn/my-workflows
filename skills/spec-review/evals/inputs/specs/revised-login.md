---
name: revised-login
status: spec-complete
created: 2026-04-20
revised: 2026-04-21
brainstorming_archive: specs/archive/revised-login.brainstorm.md
review_iteration: 2
---

# Spec: revised-login (前回 review で needs-fix、修正反映済み)

## 1. 目的

Web アプリケーションにログイン機能を追加し、ユーザーが自身のアカウントで保護領域 (/dashboard) にアクセスできるようにします。

## 2. スコープ

### 2.1 含むもの
- サインアップ (メール + パスワード)
- ログイン / ログアウト
- セッション管理 (Cookie)
- 認証失敗時のエラー表示
- レート制限 (M-2 指摘を反映して追加)

### 2.2 含まないもの
- パスワードリセット
- ソーシャルログイン
- 2 要素認証

## 3. 機能要件

### 3.1 ログイン API

- エンドポイント: `POST /api/auth/login`
- 入力: `{ email: string, password: string }`
- 出力: 200 + `{ user_id: number, email: string }` + Set-Cookie: `session=<token>; HttpOnly; Secure; SameSite=Lax; Max-Age=86400`
- **エラー (M-3 反映)**: 401 `{ error: "invalid_credentials" }` — 汎用メッセージで固定 (ユーザー列挙攻撃対策、詳細差分を返さない)
- **レート制限 (M-2 反映)**: IP ベース、15 分間で 5 回失敗すると 15 分ロック (429 `{ error: "rate_limited", retry_after: 900 }`)

### 3.2 ログアウト API

- エンドポイント: `POST /api/auth/logout`
- 挙動: セッション破棄 + Set-Cookie: `session=; Max-Age=0`

## 4. 非機能要件

| 項目 | 要件 |
|---|---|
| パフォーマンス | ログイン API p95: 300ms 以下 |
| セキュリティ | bcrypt (cost 12)、HttpOnly + Secure + SameSite=Lax、レート制限 |
| 可用性 | 99.5% |

## 5. 受け入れ基準 (M-1 反映: 全項目を検証可能な粒度に)

- [ ] 有効なメール + パスワードでログイン時に 200 応答 + session Cookie が設定される
- [ ] Cookie の HttpOnly / Secure / SameSite=Lax フラグが設定される (ブラウザ DevTools で確認)
- [ ] 不正な認証情報で 401 応答 + エラーメッセージが `invalid_credentials` (汎用) であること
- [ ] セッション有効期限 24 時間 (Max-Age=86400) が設定される
- [ ] ログアウト後に同じ Cookie で保護ページアクセス時に 401
- [ ] 同一 IP から 15 分で 6 回目のログイン失敗時に 429 応答 (retry_after=900)
- [ ] レート制限は 15 分後にリセットされる

## 6. 非対象

- パスワードリセット
- ソーシャルログイン

## 7. リスクと緩和策

### 7.1 セッションハイジャック
- **内容**: Cookie 盗難による不正ログイン
- **緩和策**: HttpOnly + Secure + SameSite=Lax Cookie

### 7.2 ブルートフォース
- **内容**: パスワード総当たり
- **緩和策**: IP ベースレート制限 (5 回 / 15 分)

### 7.3 bcrypt コスト
- **内容**: cost 過大で応答遅延、過小で脆弱
- **緩和策**: cost 12 固定 (p95: 200ms 程度、要件 300ms 内)

## 修正履歴 (本 Spec の revision)

- 2026-04-21: spec-review iteration-1 needs-fix (Major 3 件) の指摘を反映
  - **M-1**: 受け入れ基準の「セッションが適切に維持される」を具体化 (時間 / Cookie フラグ / 401 応答の検証可能項目に分割)
  - **M-2**: レート制限の要否を「実装する」として確定、具体値 (5 回 / 15 分、429 応答 + retry_after=900) を明記
  - **M-3**: エラーメッセージ粒度を「汎用メッセージで固定」として確定、ユーザー列挙攻撃対策を明示
