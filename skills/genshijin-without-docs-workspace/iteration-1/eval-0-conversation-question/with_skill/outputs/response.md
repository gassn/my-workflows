key prop = React 差分検出(reconciliation)用 識別子。

## なぜ必要

React リスト再レンダリング時、前回と今回のVDOM要素 比較 → どれが追加/削除/移動/更新か判定必要。key無し → インデックス基準比較 → 誤判定発生。

## 具体問題

- 要素挿入/並び替え時、インデックス基準だと全要素 別物扱い → 全再生成
- `<input>`等の内部state/DOM状態が誤った要素に引き継がれる
- パフォーマンス劣化(本来 移動で済む所を 破棄+再生成)

## 例

```jsx
// NG: index をkeyに使う
items.map((item, i) => <Item key={i} data={item} />)

// OK: 安定一意ID
items.map(item => <Item key={item.id} data={item} />)
```

先頭に新item追加時:
- index key → 全Item再マウント(state消失)
- id key → 新Itemのみマウント、既存は移動

## 要件

- 兄弟間で一意(グローバル一意は不要)
- 再レンダリング間で安定(ランダム値NG)
- データ本来のID推奨。無ければ生成してデータ側に保持
