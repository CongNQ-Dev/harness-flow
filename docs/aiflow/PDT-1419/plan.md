# シーズン登録エリア初期非表示 実装計画

> **エージェント向け:** 必須サブスキル: このプランをタスクごとに実装するには baiflow:subagent-driven-development を使用すること。各ステップはチェックボックス（`- [ ]`）で進捗を管理する。

**ゴール:** 全話無料キャンペーン新規作成画面でシーズン登録エリアが初期状態で表示されないようにする（TOPICS画面と挙動を統一する）

**ブランチ:** bug/PDT-1419/fix_campaign_season_area_initial_state（Stage 1で作成済み。現在チェックアウト中）

**アーキテクチャ:** `SegmentSeasonFreePromoImagesForm.tsx` にあるマウント時の自動 `append` `useEffect`（36〜46行目）を削除する。編集フローはコンテナ側の `setValue` でデータを注入するため、この `useEffect` に依存していない。変更は1ファイル・1ブロックの削除のみ。

**技術スタック:** Next.js, React, React Hook Form (`useFieldArray`), TypeScript

---

### タスク1: `useEffect` 自動追加ブロックを削除する

**ファイル:**
- 変更: `src/components/DataDisplay/SegmentSeasonFreePromoImagesForm.tsx:36-46`

- [ ] **ステップ1: 変更前の状態を確認する**

  36〜46行目に以下のブロックがあることを確認する:

  ```tsx
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

- [ ] **ステップ2: `useEffect` ブロックを削除する**

  上記の `useEffect` ブロック（36〜46行目、空行含む）を丸ごと削除する。

  削除後、35行目の `handleDeleteSeason` 関数の閉じ括弧のすぐ後に以下の `useEffect`（`listPatternTypeWatch` を監視するもの）が続く形になる:

  ```tsx
  const handleDeleteSeason = (index: number) => {
    if (fields.length > 1) {
      remove(index);
    }
  };

  useEffect(() => {
    items.forEach((item: any, idx: number) => {
      if (
        (listPatternTypeWatch === "singleColumn" && item.listPatternType !== "singleColumn") ||
        (listPatternTypeWatch === "twoColumns" && item.listPatternType !== "twoColumns")
      ) {
        setValue(`segmentSeasonFreePromoItems.${idx}.singleColumnImage`, undefined);
        setValue(`segmentSeasonFreePromoItems.${idx}.twoColumnsImage`, undefined);
      }
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [listPatternTypeWatch]);
  ```

- [ ] **ステップ3: TypeScript の型チェックを実行する**

  実行:
  ```bash
  yarn type-check
  ```

  期待結果: エラーなしで完了する

- [ ] **ステップ4: Lint を実行する**

  実行:
  ```bash
  yarn lint:eslint src/components/DataDisplay/SegmentSeasonFreePromoImagesForm.tsx
  ```

  期待結果: エラー・警告なし（unused import 等が出た場合は修正する）

- [ ] **ステップ5: コミットする**

  ```bash
  git add src/components/DataDisplay/SegmentSeasonFreePromoImagesForm.tsx
  git commit -m "fix(PDT-1419): remove auto-append useEffect to hide season area on initial create"
  ```

---

### タスク2: 動作確認（手動）

**ファイル:** なし（確認のみ）

- [ ] **ステップ1: 開発サーバーを起動する**

  実行:
  ```bash
  yarn dev
  ```

  ブラウザで管理画面（http://localhost:3000）を開く

- [ ] **ステップ2: 新規作成画面の初期状態を確認する**

  1. 全話無料キャンペーン一覧（`/segment-season-free-promo-list`）を開く
  2. 「新規作成」ボタンを押下する
  3. 画面下部を確認する

  **期待結果:** シーズン行が0件の状態でフォームが表示される（「シーズン ＊必須」の見出しと「シーズンを追加」ボタンは表示されるが、シーズン選択行・画像アップロード行が表示されない）

- [ ] **ステップ3: 「シーズンを追加」ボタンの動作を確認する**

  「シーズンを追加」ボタンを押下する

  **期待結果:** シーズン選択ドロップダウン・画像アップロードエリアを含む行が1件追加される

- [ ] **ステップ4: 編集画面のリグレッションを確認する**

  1. 全話無料キャンペーン一覧から既存のキャンペーンの「編集」ボタンを押下する
  2. 編集画面を開く

  **期待結果:** 保存済みのシーズン行が正しく表示される（既存データが消えていない）

- [ ] **ステップ5: 編集画面で保存が正常に動作することを確認する**

  編集画面で何も変更せずに「保存する」ボタンを押下する

  **期待結果:** 「編集が完了しました」モーダルが表示される。エラーにならない

---

## 変更ファイル一覧

| ファイル | 変更内容 |
|---|---|
| `src/components/DataDisplay/SegmentSeasonFreePromoImagesForm.tsx` | 自動追加 `useEffect`（36〜46行目）を削除 |
