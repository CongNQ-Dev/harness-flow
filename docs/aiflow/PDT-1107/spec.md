# 仕様書 — PDT-1107: シーズン一覧タブ絞り込み不具合修正

## 概要

Work一覧からシーズン一覧に遷移したとき、すべて/本編/制作裏側のタブ絞り込みが機能しない。本仕様は原因を特定し、最小変更での修正方針を定める。

---

## 根本原因

`SeasonsContainer`（`src/domains/seasons/container/index.tsx`）の `useAspidaSWR` 呼び出しで、`projectId` をクエリオプションに含めているため、`projectId` が SWR キャッシュキーの一部になっている。

```ts
// 現状（バグあり）
const { data, mutate } = useAspidaSWR(apiClient.admin.seasons._workId(workId), "$get", {
  query: { offset: 0, projectId: projectId },  // projectId がキーに含まれる
});
```

タブをクリックすると以下の競合が発生する：

1. `mutate(filteredFetch, false)` → 現在のキャッシュキーにフィルター済みデータを書き込む
2. `setProjectId("1")` → SWR キーが変化し、SWR が新キー用の自動フェッチを開始する
3. マウント時の初期フェッチ（全件取得）が完了すると、古いキーのキャッシュを上書きする

Work一覧経由でのみ発生する理由：Work一覧は追加クエリパラメータ（`workPage`, `title`, `isReleased` 等）を URL に付与するため、コンポーネントの再レンダリングが増え、初期フェッチが完了する前にタブをクリックできる時間ウィンドウが広がる。

グローバルシーズン一覧（`SeasonsListContainer`）は同様の問題がない。理由：`projectId` を SWR キーに含めておらず、`revalidateOnFocus: false` を指定しているため。

---

## 修正方針

### 変更ファイル

`src/domains/seasons/container/index.tsx` のみ

### 変更内容

`useAspidaSWR` のオプションから `projectId` を除去し、予期しない自動再取得を防ぐオプションを追加する。

```ts
// 修正後
const { data, mutate } = useAspidaSWR(apiClient.admin.seasons._workId(workId), "$get", {
  query: { offset: 0 },        // projectId をキーから除外
  revalidateOnFocus: false,    // フォーカス時の自動再取得を無効化
  refreshInterval: 0,          // 定期的な自動再取得を無効化
});
```

### 変更しない理由

- `changeSeasonList` は既に `mutate` 呼び出し内で `projectId` を明示的に渡している → 変更不要
- `changePage` も `mutate` 呼び出しで `projectId` を渡している → 変更不要
- `setProjectId` の呼び出し → タブのハイライト表示に使うため変更不要

### 修正の仕組み

- SWR キーが `projectId` によらず固定になる → キー変化による競合フェッチが発生しない
- `revalidateOnFocus: false` → ウィンドウフォーカス時の自動再取得がフィルター状態を上書きしない
- `refreshInterval: 0` → 定期的な自動再取得がフィルター状態を上書きしない
- すべてのデータ取得は既に明示的な `mutate` 呼び出しで行われている → この変更はその前提を守るだけ

---

## 受け入れ基準

- [ ] 「本編」タブを選択すると、遷移経路によらず本編シーズンのみが表示される
- [ ] 「制作裏側」タブを選択すると、遷移経路によらず制作裏側シーズンのみが表示される
- [ ] 「すべて」タブを選択するとすべてのシーズンが表示される
- [ ] タブ切り替え後にページネーションしても、フィルターが維持される（例: 「本編」タブ選択後にページ2へ移動してもフィルターが保持）
- [ ] 直接URLアクセスや他の遷移経路からのアクセスでは初回表示時に全件が表示される（リグレッションなし）
- [ ] グローバルシーズン一覧（`/seasons-list`）の動作に影響しない

---

## 影響範囲

| 対象 | 変更 |
|------|------|
| `src/domains/seasons/container/index.tsx` | `useAspidaSWR` オプション変更（2行） |
| `src/domains/seasons-list/container/index.tsx` | 変更なし |
| API・ルート・その他コンポーネント | 変更なし |

---

## リスク・考慮事項

- `revalidateOnFocus: false` を設定することで、ユーザーが別タブから戻った際に自動でデータが更新されなくなる。ただし管理画面の運用上、そのようなユースケースは想定されていないため許容範囲と判断する。
- `refreshInterval: 0` により定期的なポーリングが無効になる。管理画面シーズン一覧はリアルタイム性が不要なため問題なし。
- グローバルシーズン一覧（`SeasonsListContainer`）はすでに同設定で運用されており、同一パターンの適用は安全。
