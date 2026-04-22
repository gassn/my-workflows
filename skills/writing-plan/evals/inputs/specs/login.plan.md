---
name: login
spec_path: specs/login.md
status: plan-complete
created: 2026-04-19
---

# Plan: login (既存、上書き確認用の placeholder)

## 1. 技術設計概要

Express + PostgreSQL 構成でメール・パスワード認証を実装します。

## 5. 実装タスク分解

### 5.1 タスクリスト

- [ ] T-1: User テーブル migration (見積: 30 分)
- [ ] T-2: bcrypt パスワードハッシュ化実装 (見積: 40 分)
- [ ] T-3: ログイン API 実装 (見積: 60 分)
