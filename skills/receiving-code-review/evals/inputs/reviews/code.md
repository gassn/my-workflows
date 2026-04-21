---
reviewer: code-reviewer
spec: login
reviewed: 2026-04-21
verdict: needs-fix
---

# Code Review: login

## 総合判定
verdict: needs-fix (Major 2 件)

## Critical
(なし)

## Major
- [code-Major-1] `src/auth/login.ts` L42: パスワード比較が string 比較 (`===`) になっており、bcrypt.compare を使っていない (該当: SKILL.md Plan §7.3)
- [code-Major-2] `src/middleware/requireAuth.ts`: セッション Cookie の `httpOnly` フラグが設定されていない

## Minor
- [code-Minor-1] `login.test.ts` の setup 関数が冗長 (fixture ヘルパに抽出推奨)
