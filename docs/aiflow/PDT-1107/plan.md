# シーズン一覧タブ絞り込み不具合修正 実装計画

> **エージェント向け:** 必須サブスキル: このプランをタスクごとに実装するには baiflow:subagent-driven-development を使用すること。各ステップはチェックボックス（`- [ ]`）で進捗を管理する。

**ゴール:** Work一覧からシーズン一覧に遷移した際に、すべて/本編/制作裏側のタブ絞り込みが正しく機能するよう修正する。

**ブランチ:** bug/PDT-1107/fix_season_tab_filter（Stage 1で作成済み。現在チェックアウト中）

**アーキテクチャ:** `SeasonsContainer` の `useAspidaSWR` オプションから `projectId` を除去し、SWR キャッシュキーを固定化する。これにより、タブクリック時に発生する「mutate による書き込み」と「SWR キー変化による自動フェッチ」の競合を排除する。全データ取得は既存の明示的 `mutate` 呼び出しが担うため、他コードの変更は不要。

**技術スタック:** Next.js (pages router), React, @aspida/swr, TypeScript 4.5.2

---

## 変更ファイル一覧

| ファイル | 種別 | 変更内容 |
|---|---|---|
| `src/domains/seasons/container/index.tsx` | 変更 | `useAspidaSWR` オプション 3行修正 |

---

## タスク1: `useAspidaSWR` オプション修正

**ファイル:**
- 変更: `src/domains/seasons/container/index.tsx:39-41`

### 事前確認

このプロジェクトにはユニットテストがないため、変更前後の動作確認は手動で行う。手順はタスク末尾に記載する。

---

- [ ] **ステップ1: 現在のコードを確認する**

`src/domains/seasons/container/index.tsx` の 39〜41 行目が以下になっていることを確認する：

```ts
const { data, mutate } = useAspidaSWR(apiClient.admin.seasons._workId(workId), "$get", {
  query: { offset: 0, projectId: projectId },
});
```

---

- [ ] **ステップ2: `useAspidaSWR` オプションを修正する**

39〜41 行目を以下に書き換える（`projectId` をキーから外し、自動再取得を無効化）：

```ts
const { data, mutate } = useAspidaSWR(apiClient.admin.seasons._workId(workId), "$get", {
  query: { offset: 0 },
  revalidateOnFocus: false,
  refreshInterval: 0,
});
```

**変更点の意味:**
- `projectId: projectId` を `query` から削除 → SWR キャッシュキーが `projectId` の値に依存しなくなる。キー変化による自動フェッチが発生しない。
- `revalidateOnFocus: false` → ウィンドウフォーカス（別タブから戻る等）によって自動再フェッチが走らなくなる。フィルター状態が上書きされない。
- `refreshInterval: 0` → 定期ポーリングを無効化。フィルター状態が上書きされない。
- `changeSeasonList` と `changePage` は既に明示的 `mutate` 呼び出しで `projectId` を渡しているため変更不要。

---

- [ ] **ステップ3: TypeScript の型チェックを実行する**

```bash
npx tsc --noEmit
```

期待結果: エラーなしで終了する（ゼロ出力またはウォーニングのみ）。

`useAspidaSWR` のオプション型は `projectId` を `query` に持つことを必須としていないため（`projectId?: string | undefined`）、型エラーは発生しない。

---

- [ ] **ステップ4: lint を実行する**

```bash
yarn lint:eslint src/domains/seasons/container/index.tsx
```

期待結果: エラーなし。

---

- [ ] **ステップ5: 開発サーバーを起動して手動確認する**

```bash
yarn dev
```

ブラウザで Stage 管理画面（ローカル）を開き、以下の手順で動作を確認する：

**確認手順A（バグ再現経路）:**
1. Work一覧（`/`）に移動する
2. 任意の Work の「シーズン一覧」ボタンをクリックする
3. シーズン一覧画面（`/seasons-list/[workId]`）が開いたら「本編」タブをクリックする
4. 本編シーズンのみが表示されることを確認する ✓
5. 「制作裏側」タブをクリックする
6. 制作裏側シーズンのみが表示されることを確認する ✓
7. 「すべて」タブをクリックする
8. すべてのシーズンが表示されることを確認する ✓

**確認手順B（ページネーション + フィルター維持）:**
1. 上記手順A の途中、「本編」タブを選択した状態でページ2に移動する（データが1ページ分以上ある場合）
2. 本編シーズンのみが引き続き表示されることを確認する ✓

**確認手順C（リグレッション確認）:**
1. `LocalTab` の表示（タブのハイライト）が選択と一致していることを確認する ✓
2. URL直接アクセス（`/seasons-list/[workId]`）でも同様にタブが機能することを確認する ✓
3. グローバルシーズン一覧（`/seasons-list`）のタブが引き続き機能することを確認する（このファイルは変更していないが念のため） ✓

---

- [ ] **ステップ6: 変更をコミットする**

```bash
git add src/domains/seasons/container/index.tsx
git commit -m "fix(PDT-1107): remove projectId from SWR key to fix season tab filter race condition

タブクリック時にprojectIdのSWRキー変化が自動フェッチを引き起こし、
初期フェッチとの競合でフィルターが上書きされるバグを修正。
revalidateOnFocus/refreshIntervalを無効化しSeasonsListContainerと同パターンに統一。"
```

---

## 完了チェックリスト（スペックとの照合）

| 受け入れ基準 | 対応ステップ |
|---|---|
| 「本編」タブで本編のみ表示（遷移経路によらず） | ステップ2 + ステップ5A |
| 「制作裏側」タブで制作裏側のみ表示（遷移経路によらず） | ステップ2 + ステップ5A |
| 「すべて」タブで全件表示 | ステップ2 + ステップ5A |
| タブ切り替え後にページネーションしてもフィルター維持 | ステップ2 + ステップ5B |
| 直接URLアクセスで全件表示（リグレッションなし） | ステップ2 + ステップ5C |
| グローバルシーズン一覧に影響なし | ステップ5C |
