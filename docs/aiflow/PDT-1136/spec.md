# スペック: PDT-1136 — 検索アクセス数のシーズン帰属修正

## 根本原因

`app/presentation/api/graph/schema.resolvers.go:191` の `Work` リゾルバーが、検索流入時の検索アクセス計上に `work.MainSeasonID` を使用している。

`work.MainSeasonID` は `app/domain/entity/work.go:38` でシーズンナンバー1のIDとして明示的に設定されるため、シーズン2以降を検索・再生した場合でも常にシーズン1が計上される。

## 修正方針

新しい HTTP ヘッダー `X-Bump-Season-Id` を追加し、モバイルクライアントが検索結果からナビゲートする際に実際のシーズンIDを送信できるようにする。既存の `X-Bump-Traffic-Source` ヘッダーと同じパターンを踏襲する。

- ヘッダーが存在する場合 → そのシーズンIDを使用
- ヘッダーが存在しない場合 → 現状の `work.MainSeasonID` にフォールバック（後方互換性を維持）

GraphQL スキーマの変更は不要。

## 変更ファイル

### 1. `app/util/context.go`

定数と getter/setter を追加する：

```go
BUMPSeasonIDName = "X-Bump-Season-Id"

func SetSeasonID(c echo.Context, seasonID string) {
    c.Set(BUMPSeasonIDName, seasonID)
}

func GetSeasonID(c echo.Context) string {
    v := c.Get(BUMPSeasonIDName)
    if v == nil {
        return ""
    }
    return v.(string)
}
```

### 2. `app/presentation/api/middleware/context.go`

`BindContext` 関数内で新ヘッダーをパースして echo context にセットする：

```go
seasonID := c.Request().Header.Get(util.BUMPSeasonIDName)
util.SetSeasonID(c, seasonID)
```

### 3. `app/presentation/api/graph/schema.resolvers.go`

`Work` リゾルバーのアクセス計上ロジックを修正する。ヘッダーから取得したシーズンIDを優先し、なければ `work.MainSeasonID` にフォールバックする：

**変更前:**
```go
case "SearchResult", "SearchRanking":
    timeZone := util.GetTimeZone(eC)
    logger.Info(eC, fmt.Sprintf("season search ranking count , season id : %s", work.MainSeasonID))
    r.ISeasonSearchCountUseCase.UpsertSeasonSearchCount(user.ID, work.MainSeasonID, al, timeZone, vo.GetCountryCodeForContent(al).String())
```

**変更後:**
```go
case "SearchResult", "SearchRanking":
    timeZone := util.GetTimeZone(eC)
    seasonID := util.GetSeasonID(eC)
    if seasonID == "" {
        seasonID = work.MainSeasonID
    }
    logger.Info(eC, fmt.Sprintf("season search ranking count , season id : %s", seasonID))
    r.ISeasonSearchCountUseCase.UpsertSeasonSearchCount(user.ID, seasonID, al, timeZone, vo.GetCountryCodeForContent(al).String())
```

## テスト方針

`app/usecase/season_search_count_test.go` は変更なし（ユースケース層は正しく動作している）。

`app/util/context.go` の `GetSeasonID` / `SetSeasonID` はシンプルなので個別テスト不要（既存の GetTrafficSource と同じパターン）。

リゾルバーの `Work` 関数に対して以下のテストケースを追加する（既存のリゾルバーテストがなければ新規ファイルを作成せず、ユースケースのモック検証として実装）：

| テストケース | X-Bump-Season-Id ヘッダー | X-Bump-Traffic-Source | 期待する seasonId |
|---|---|---|---|
| ヘッダーあり・SearchResult流入 | `season_2_id` | `SearchResult` | `season_2_id` |
| ヘッダーなし・SearchResult流入 | （なし） | `SearchResult` | `work.MainSeasonID` |
| SearchResult以外の流入 | `season_2_id` | `Direct` | 計上なし（呼び出しなし） |

## 受け入れ基準

- [ ] シーズン2以降のシーズンを検索から再生した場合、そのシーズンIDで `UpsertSeasonSearchCount` が呼ばれること
- [ ] `X-Bump-Season-Id` ヘッダーがない場合、従来通り `work.MainSeasonID` で計上されること（後方互換性）
- [ ] `SearchResult` / `SearchRanking` 以外の流入元では計上されないこと（既存動作を維持）
- [ ] ログの `season id` も正しいシーズンIDを出力すること

## 影響範囲

- 変更対象: `app/util/context.go`、`app/presentation/api/middleware/context.go`、`app/presentation/api/graph/schema.resolvers.go`
- GraphQL スキーマ変更: なし
- モバイル側対応: `X-Bump-Season-Id` ヘッダーを検索結果からの遷移時に送信する（別途モバイルチームと連携）
- 既存の急上昇ランキング・通常ランキング機能: 影響なし
