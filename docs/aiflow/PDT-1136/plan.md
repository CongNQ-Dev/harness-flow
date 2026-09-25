# PDT-1136 検索アクセス数シーズン帰属修正 実装計画

> **エージェント向け:** 必須サブスキル: このプランをタスクごとに実装するには baiflow:subagent-driven-development を使用すること。各ステップはチェックボックス（`- [ ]`）で進捗を管理する。

**ゴール:** 検索結果からシーズン2以降を再生した際、急上昇ランキングのアクセス計上が実際に検索されたシーズンのIDで行われるよう修正する。

**ブランチ:** bug/PDT-1136/fix_search_access_season_attribution（Stage 1で作成済み。現在チェックアウト中のブランチをそのまま記載する）

**アーキテクチャ:** 新しい HTTP ヘッダー `X-Bump-Season-Id` を追加する。既存の `X-Bump-Traffic-Source` ヘッダーと同じパターンで、ミドルウェアがヘッダーを読んで echo コンテキストにセットし、`Work` リゾルバーがそれを読む。ヘッダー未送信時は従来の `work.MainSeasonID` にフォールバックするため後方互換性を維持する。

**技術スタック:** Go, Echo v4, gqlgen, gomock

---

## 変更ファイル一覧

| ファイル | 変更種別 | 内容 |
|---|---|---|
| `app/util/context.go` | 変更 | `BUMPSeasonIDName` 定数、`SetSeasonID`/`GetSeasonID` 関数を追加 |
| `app/util/context_test.go` | 変更 | `TestGetSeasonID` テストを追加 |
| `app/presentation/api/middleware/context.go` | 変更 | `BindContext` で `X-Bump-Season-Id` ヘッダーをパースしてセット |
| `app/presentation/api/graph/schema.resolvers.go` | 変更 | `Work` リゾルバーのシーズンID取得ロジックを修正 |
| `app/presentation/api/graph/work_resolver_test.go` | 新規作成 | `Work` リゾルバーの検索アクセス計上テスト |

---

### タスク1: `GetSeasonID` / `SetSeasonID` を util/context.go に追加

**ファイル:**
- 変更: `app/util/context.go`
- テスト: `app/util/context_test.go`

- [ ] **ステップ1: 失敗するテストを書く**

`app/util/context_test.go` の末尾に追加する（既存の `import` はそのまま、`context` は使用しないので不要）:

```go
func TestGetSeasonID(t *testing.T) {
	tests := []struct {
		name     string
		setValue string
		want     string
	}{
		{
			name:     "セットされたシーズンIDを返す",
			setValue: "season_2_id",
			want:     "season_2_id",
		},
		{
			name:     "セットされていない場合は空文字を返す",
			setValue: "",
			want:     "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			eC := GenEchoContextMock("GET", "/test")
			if tt.setValue != "" {
				SetSeasonID(eC, tt.setValue)
			}
			got := GetSeasonID(eC)
			assert.Equal(t, tt.want, got)
		})
	}
}
```

- [ ] **ステップ2: テストを実行し、失敗することを確認する**

実行: `make test-util`
期待結果: `undefined: SetSeasonID` で FAIL する

- [ ] **ステップ3: `app/util/context.go` に定数と関数を追加する**

`BUMPTrafficSourceName = "X-Bump-Traffic-Source"` の行の直後に定数を追加する:

```go
BUMPSeasonIDName = "X-Bump-Season-Id"
```

`SetTrafficeSource` 関数の直後に getter/setter を追加する:

```go
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

- [ ] **ステップ4: テストを実行し、成功することを確認する**

実行: `make test-util`
期待結果: PASS

- [ ] **ステップ5: コミットする**

```bash
git add app/util/context.go app/util/context_test.go
git commit -m "feat: add GetSeasonID/SetSeasonID to util/context"
```

---

### タスク2: ミドルウェアで `X-Bump-Season-Id` ヘッダーをパース

**ファイル:**
- 変更: `app/presentation/api/middleware/context.go`

- [ ] **ステップ1: `BindContext` 関数に 2 行追加する**

`SetTrafficeSource` の行（`util.SetTrafficeSource(c, trafficSoruce)`）の直後に追加する:

```go
seasonID := c.Request().Header.Get(util.BUMPSeasonIDName)
util.SetSeasonID(c, seasonID)
```

変更後の該当箇所は以下の通り:

```go
trafficSoruce := c.Request().Header.Get(util.BUMPTrafficSourceName)
util.SetTrafficeSource(c, trafficSoruce)

seasonID := c.Request().Header.Get(util.BUMPSeasonIDName)
util.SetSeasonID(c, seasonID)
```

- [ ] **ステップ2: コンパイルを確認する**

実行: `go build ./app/presentation/api/middleware/...`
期待結果: エラーなし

- [ ] **ステップ3: コミットする**

```bash
git add app/presentation/api/middleware/context.go
git commit -m "feat: parse X-Bump-Season-Id header in BindContext middleware"
```

---

### タスク3: `Work` リゾルバーの検索アクセス計上をシーズンIDヘッダー優先に修正

**ファイル:**
- 変更: `app/presentation/api/graph/schema.resolvers.go:186-192`
- テスト: `app/presentation/api/graph/work_resolver_test.go`（新規作成）

- [ ] **ステップ1: 失敗するテストを新規ファイルに書く**

`app/presentation/api/graph/work_resolver_test.go` を新規作成する:

```go
package graph

import (
	"context"
	"testing"

	"github.com/kohakudo-inc/bump-backend/app/domain/entity"
	mock_usecase "github.com/kohakudo-inc/bump-backend/app/test/mock/usecase"
	"github.com/kohakudo-inc/bump-backend/app/usecase"
	"github.com/kohakudo-inc/bump-backend/app/util"
	"github.com/stretchr/testify/assert"
	"go.uber.org/mock/gomock"
)

// makeWorkCtx は指定した trafficSource と seasonID をセットした echo コンテキストを
// graph リゾルバーが期待する context.Context にラップして返す。
func makeWorkCtx(trafficSource, seasonID string) context.Context {
	eC := util.GenEchoContextMock("GET", "/graphql")
	util.SetTrafficeSource(eC, trafficSource)
	util.SetSeasonID(eC, seasonID)
	return eC.Request().Context()
}

func TestWork_SearchCountSeasonAttribution(t *testing.T) {
	tests := []struct {
		name             string
		trafficSource    string
		headerSeasonID   string
		mainSeasonID     string
		expectedSeasonID string
		expectUpsert     bool
	}{
		{
			name:             "SearchResult流入かつヘッダーあり: ヘッダーのシーズンIDで計上する",
			trafficSource:    "SearchResult",
			headerSeasonID:   "season_2_id",
			mainSeasonID:     "season_1_id",
			expectedSeasonID: "season_2_id",
			expectUpsert:     true,
		},
		{
			name:             "SearchResult流入かつヘッダーなし: MainSeasonIDにフォールバックする",
			trafficSource:    "SearchResult",
			headerSeasonID:   "",
			mainSeasonID:     "season_1_id",
			expectedSeasonID: "season_1_id",
			expectUpsert:     true,
		},
		{
			name:             "SearchRanking流入かつヘッダーあり: ヘッダーのシーズンIDで計上する",
			trafficSource:    "SearchRanking",
			headerSeasonID:   "season_2_id",
			mainSeasonID:     "season_1_id",
			expectedSeasonID: "season_2_id",
			expectUpsert:     true,
		},
		{
			name:           "SearchResult以外の流入: UpsertSeasonSearchCountを呼ばない",
			trafficSource:  "Direct",
			headerSeasonID: "season_2_id",
			mainSeasonID:   "season_1_id",
			expectUpsert:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			ctrl := gomock.NewController(t)

			workUseCase := mock_usecase.NewMockIWorkUseCase(ctrl)
			userUseCase := mock_usecase.NewMockIUserUseCase(ctrl)
			searchCountUseCase := mock_usecase.NewMockISeasonSearchCountUseCase(ctrl)

			resolver := &queryResolver{
				Resolver: &Resolver{
					IWorkUseCase:              workUseCase,
					IUserUseCase:              userUseCase,
					ISeasonSearchCountUseCase: searchCountUseCase,
				},
			}

			work := &entity.Work{
				ID:           "work_1_id",
				MainSeasonID: tt.mainSeasonID,
			}
			user := &usecase.UserPresentationDto{ID: "user_1_id"}

			workUseCase.EXPECT().
				GetWork(gomock.Any(), "work_1_id", gomock.Any(), gomock.Any()).
				Return(work, nil)
			userUseCase.EXPECT().
				FindUser("", "").
				Return(user, nil).
				AnyTimes()

			if tt.expectUpsert {
				searchCountUseCase.EXPECT().
					UpsertSeasonSearchCount(
						"user_1_id",
						tt.expectedSeasonID,
						gomock.Any(),
						gomock.Any(),
						gomock.Any(),
					).Return(nil)
			}

			ctx := makeWorkCtx(tt.trafficSource, tt.headerSeasonID)
			result, err := resolver.Work(ctx, "work_1_id")

			assert.NoError(t, err)
			assert.NotNil(t, result)
		})
	}
}
```

- [ ] **ステップ2: テストを実行し、失敗することを確認する**

実行: `make test-package PKG=presentation/api/graph`
期待結果: `"SearchResult流入かつヘッダーあり"` のテストが `UpsertSeasonSearchCount` の期待引数不一致で FAIL する（現在は `season_1_id` で呼ばれているため）

- [ ] **ステップ3: `schema.resolvers.go` の `Work` リゾルバーを修正する**

`app/presentation/api/graph/schema.resolvers.go` の 186〜192 行目を以下に置き換える:

変更前:
```go
switch util.GetTrafficSource(eC) {
case "SearchResult", "SearchRanking":
    timeZone := util.GetTimeZone(eC)

    logger.Info(eC, fmt.Sprintf("season search ranking count , season id : %s", work.MainSeasonID))
    r.ISeasonSearchCountUseCase.UpsertSeasonSearchCount(user.ID, work.MainSeasonID, al, timeZone, vo.GetCountryCodeForContent(al).String())
}
```

変更後:
```go
switch util.GetTrafficSource(eC) {
case "SearchResult", "SearchRanking":
    timeZone := util.GetTimeZone(eC)
    seasonID := util.GetSeasonID(eC)
    if seasonID == "" {
        seasonID = work.MainSeasonID
    }
    logger.Info(eC, fmt.Sprintf("season search ranking count , season id : %s", seasonID))
    r.ISeasonSearchCountUseCase.UpsertSeasonSearchCount(user.ID, seasonID, al, timeZone, vo.GetCountryCodeForContent(al).String())
}
```

- [ ] **ステップ4: テストを実行し、すべて成功することを確認する**

実行: `make test-package PKG=presentation/api/graph`
期待結果: 4 テストすべて PASS

- [ ] **ステップ5: util テストも念のため通ることを確認する**

実行: `make test-util`
期待結果: PASS

- [ ] **ステップ6: コミットする**

```bash
git add app/presentation/api/graph/schema.resolvers.go app/presentation/api/graph/work_resolver_test.go
git commit -m "fix: use X-Bump-Season-Id header for search access attribution in Work resolver"
```
