# 仕様書 — PDT-1419
# 全話無料キャンペーン新規作成画面: シーズン登録エリアの初期非表示

**ステータス:** 承認済み
**対象ファイル:** `src/components/DataDisplay/SegmentSeasonFreePromoImagesForm.tsx`

---

## 根本原因

`SegmentSeasonFreePromoImagesForm` は空の依存配列を持つ `useEffect` を持っており、マウント時に `fields.length === 0` であれば自動で空の行を1件追加する。

```tsx
// 問題箇所 (36〜46行目)
useEffect(() => {
  if (fields.length === 0) {
    append({
      seasonId: undefined,
      singleColumnImage: undefined,
      twoColumnsImage: undefined,
      displayOrder: fields.length + 1,
    });
  }
  // eslint-disable-next-line react-hooks/exhaustive-deps
}, []);
```

新規作成画面でコンポーネントがマウントされると必ずこの `useEffect` が発火し、空の行が1件レンダリングされる。これがバグの直接原因。

比較対象の `TopicsBnForm`（TOPICS画像URL/バナー画面）にはこのパターンがなく、「行を追加」ボタン押下時のみ `append` が呼ばれる。

---

## 設計

### 変更内容

**`src/components/DataDisplay/SegmentSeasonFreePromoImagesForm.tsx`**

自動追加 `useEffect`（36〜46行目）を丸ごと削除する。

削除後、コンポーネントは以下の状態で動作する:

| ケース | 動作 |
|---|---|
| 新規作成 (create) | `fields` は空配列で初期化される。シーズン行は表示されない。「シーズンを追加」ボタン押下で1件目が追加される |
| 編集 (edit) | コンテナ (`SegmentSeasonFreePromoEditContainer`) が API 取得後に `setValue("segmentSeasonFreePromoItems", items)` を呼ぶため、既存データが `fields` に反映される。自動追加 `useEffect` は不要 |

### 変更理由

- 編集フローは `useEffect` に依存していない — データは `setValue` 経由で上書きされる
- 「シーズンを追加」ボタンは既に存在しており、ユーザーが初めての行を追加できる
- 1件だけ残った場合の削除ガード（`fields.length > 1` のとき削除ボタンを表示）は変更不要

### 削除しない理由のないもの

削除対象の `useEffect` が残存することで生じるリスク:
- 将来的にフォームがリセットされると再び空行が出現する可能性がある
- 他の画面へ同パターンが波及するリスクがある

削除による影響:
- 編集画面でデータ読み込み前の一瞬、空状態が表示される（元々同じ）
- バックエンドへ空配列を送信してもバリデーションエラーになるかは別途確認が必要（スコープ外）

---

## 受け入れ基準

| # | 条件 | 検証方法 |
|---|---|---|
| 1 | 新規作成画面の初期ロード時、シーズン行が0件であること | 画面確認 |
| 2 | 「シーズンを追加」ボタンを押すと1件目のシーズン行が表示されること | 画面確認 |
| 3 | 編集画面を開くと、既存のシーズン行が正しく表示されること（リグレッション） | 画面確認 |
| 4 | 編集画面で保存した内容が変わらないこと（リグレッション） | 画面確認 |

---

## 変更ファイル一覧

| ファイル | 変更内容 |
|---|---|
| `src/components/DataDisplay/SegmentSeasonFreePromoImagesForm.tsx` | 自動追加 `useEffect`（36〜46行目）を削除 |
