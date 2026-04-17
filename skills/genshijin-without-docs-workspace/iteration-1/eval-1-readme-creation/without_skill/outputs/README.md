# todo-cli

シンプルなタスク管理ができる TypeScript 製の CLI ツールです。タスクの追加・一覧表示・完了マークを、ターミナルから素早く行えます。

## 特徴

- タスクの追加
- タスク一覧の表示
- タスクの完了マーク
- TypeScript で実装されており、型安全
- 依存が少なく軽量

## 必要要件

- Node.js **20 以上**
- npm（Node.js に同梱）

Node.js のバージョンは以下で確認できます。

```bash
node --version
```

## インストール

### npm からグローバルインストール

```bash
npm install -g todo-cli
```

### ソースからインストール

```bash
git clone https://github.com/your-org/todo-cli.git
cd todo-cli
npm install
npm run build
npm link
```

インストール後、`todo` コマンドが利用可能になります。

## 使い方

### タスクを追加する

```bash
todo add "牛乳を買う"
```

出力例:

```
Added: #1 牛乳を買う
```

### タスク一覧を表示する

```bash
todo list
```

出力例:

```
[ ] #1 牛乳を買う
[x] #2 資源ごみを出す
[ ] #3 書類を提出する
```

`[x]` が付いているものは完了済みのタスクです。

### タスクを完了にする

ID を指定して完了マークを付けます。

```bash
todo done 1
```

出力例:

```
Completed: #1 牛乳を買う
```

## コマンド一覧

| コマンド | 説明 |
| --- | --- |
| `todo add <title>` | 新しいタスクを追加する |
| `todo list` | 登録されているタスクを一覧表示する |
| `todo done <id>` | 指定した ID のタスクを完了にする |
| `todo --help` | ヘルプを表示する |
| `todo --version` | バージョンを表示する |

## データの保存場所

タスクはローカルの JSON ファイルに保存されます（既定では `~/.todo-cli/tasks.json`）。

## 開発

```bash
# 依存関係のインストール
npm install

# 開発時実行（ts-node 等）
npm run dev -- list

# ビルド
npm run build

# テスト
npm test
```

## ライセンス

MIT
