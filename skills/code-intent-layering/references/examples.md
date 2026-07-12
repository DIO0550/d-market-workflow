# 意図レイヤリングの実例集

各レイヤーの良い例・悪い例。例は TypeScript で書いているが、判断基準は言語に依存しない。

## Contents

- コードコメントの例
  - 悪い例: How の言い換え
  - Why-not: 却下した代替案
  - Why-not: 互換性制約
  - Why-not: 性能上の崖
  - 局所的な Why: 順序依存
  - 局所的な Why: セキュリティ境界
  - 出典番号（issue・仕様書）の添え方
- フォールバックの例
- テストの例
- コミットメッセージの例

---

## コードコメントの例

### 悪い例: How の言い換え — 消す

```ts
// ユーザーIDでキャッシュを検索する
const cached = cache.get(userId);
```

コードを読めば分かることの繰り返し。コードだけが変更されるとコメントが嘘になる。

```ts
// ステータスが active か確認してからメールを送る
if (user.status === "active") {
  await sendMail(user);
}
```

これも同様。条件が変わるたびにコメントの追従が必要になるだけで、情報を足していない。

### Why-not: 却下した代替案 — 残す

```ts
// Map ではなく LRU を使う。セッション数は無制限に増えるため、
// 素朴な Map に置き換えるとメモリリークが再発する（#482 参照）。
const cached = lruCache.get(userId);
```

「もっと単純にできそう」に見える箇所ほど、なぜ単純化しないかを書く価値がある。

### Why-not: 互換性制約 — 残す

```ts
// レスポンスの日付は ISO 8601 ではなく epoch 秒のまま返す。
// v1 クライアント（モバイルの旧バージョン）が数値前提でパースしており、
// 形式を変えると強制アップデートなしでは壊れる。
res.json({ createdAt: toEpochSeconds(order.createdAt) });
```

### Why-not: 性能上の崖 — 残す

```ts
// ここでは ORM のリレーション展開を使わない。
// 注文明細は1リクエストで数千件になることがあり、
// eager load に変えると N+1 は消えるが応答が数秒に劣化する（ベンチ済み）。
const items = await db.raw(ORDER_ITEMS_SQL, [orderId]);
```

### 局所的な Why: 順序依存 — 残す

```ts
// 順序が重要: 監査ログは課金確定の前に書く。
// 逆にすると課金失敗時に監査証跡が残らない。
await auditLog.record(order);
await billing.charge(order);
```

順序を入れ替えてもコンパイルは通り、テストもすり抜けやすい。壊れ方が非自明な箇所はその場に理由を残す。

### 局所的な Why: セキュリティ境界 — 残す

```ts
// ファイル名はクライアント入力をそのまま使わず必ず再生成する。
// パストラバーサル（../）対策で、ここが唯一の防御点。
const safeName = generateFileName(upload.extension);
```

### 出典番号（issue・仕様書）の添え方

```ts
// 悪い例: 番号だけ — 参照先が消えたり読めない環境では意図も消える
// #482
const cached = lruCache.get(userId);

// 良い例: 要点を一行で書いた上で番号を付ける
// 素朴な Map だとセッション増でメモリリークする（#482）。
const cached = lruCache.get(userId);

// 良い例: 仕様書番号も同様
// 締め処理は月末ではなく末営業日に走らせる（SPEC-031 5.2）。
const closingDate = lastBusinessDayOf(month);
```

コメントが意図を運び、番号は詳細な経緯への入口として機能する。この分担なら参照先が失われてもコメントは嘘にならない。

## フォールバックの例

### 悪い例: 不要な try-catch

```ts
function getUser(id: string): User | null {
  try {
    return repo.findById(id);
  } catch {
    return null;
  }
}
```

`findById` は見つからなければ null を返す設計で、ここで捕まえるべき例外はない。「念のため」の catch は、実際に何かが投げられたとき（DB接続断など）に本来伝播すべき失敗まで null に変換し、呼び出し元では「ユーザーがいない」と区別できなくなる。

### 悪い例: とりあえずの既定値

```ts
// 型定義上 profile は必須フィールド
const name = user.profile?.name ?? "";
```

型で保証済みの値への「とりあえず」の防御。もし本当に欠けるならデータ不整合であり、空文字でごまかさず失敗させるべき。この種の分岐はテストされない死んだ経路として残り続ける。

### 悪い例: 動かすための既定値フォールバック

```ts
let config: Config;
try {
  config = await loadConfig(path);
} catch {
  config = DEFAULT_CONFIG;
}
```

仕様で合意されていないのに「動くこと」を優先した例。設定ファイルの破損やパスミスが無言のまま既定値動作になる。

### 良い例: 失敗をそのまま伝播させる

```ts
function getUser(id: string): User | null {
  return repo.findById(id);
}
```

エラー処理を書かないことが正解の場合も多い。想定外の失敗はシステム境界（エントリポイント、リクエストハンドラ）まで伝播させ、そこで一元的に処理する。

### 良い例: 仕様としてのフォールバック

```ts
try {
  return await recommendItems(userId, limit);
} catch (err) {
  // 推薦APIの障害時は人気順で代替する（SPEC-044）。
  // 推薦は補助機能であり、一覧ごと落とすより劣化提供が望ましいと合意済み。
  // 障害に気づけるよう warn ログとメトリクスを必ず残す。
  logger.warn("recommendation fallback", { err });
  metrics.increment("recommend.fallback");
  return popularItems(limit);
}
```

Why（なぜ許容するか）と出典番号のコメント、観測手段（ログ・メトリクス）が揃っている。このフォールバック挙動自体をテストで固定する。

## テストの例

### 悪い例: 実装手順の複製

```ts
test("processOrder", () => {
  // 実装と同じ手順をなぞっているだけで、何を守りたいのか読み取れない
  const order = createOrder();
  const validated = validate(order);
  const priced = applyPrice(validated);
  expect(priced).toEqual(applyPrice(validate(createOrder())));
});
```

実装をリファクタリングしただけで壊れ、振る舞いの契約を何も固定していない。

### 良い例: 条件と期待結果を固定する

```ts
test("在庫が不足している商品を含む注文は、全体が拒否され在庫は減らない", async () => {
  const order = orderWith({ items: [inStock(1), outOfStock(1)] });

  await expect(processOrder(order)).rejects.toThrow(OutOfStockError);
  expect(await stockOf(inStock(1).id)).toBe(initialStock);
});
```

テスト名が What（条件と期待結果）を宣言し、本文は観測可能な結果と不変条件（在庫が減らない）を検証している。

## コミットメッセージの例

### 悪い例: diff の要約だけ

```text
OrderService の processOrder を修正

processOrder の在庫チェックを変更し、ループを Promise.all に置き換えた。
```

何が変わったかは diff が示している。なぜ変えたのかが残らない。

### 良い例: Why を残す

```text
注文処理の在庫チェックを一括検証に変更

セール開始直後に在庫チェックが逐次実行でタイムアウトし、
注文が途中まで処理されて在庫と注文データが不整合になる障害が起きた（INC-231）。
全品目を先に検証してから確定する方式にし、部分処理を起こさないようにする。
品目ごとのロック方式も検討したが、デッドロックの温床になるため採らなかった。
```

なぜ今（障害対応）、なぜこの方向（部分処理の排除）、却下した代替案（品目ロック）が揃っている。
