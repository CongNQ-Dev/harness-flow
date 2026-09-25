# バックエンドバグ報告（PDT-1107 派生） — シーズン一覧の projectId フィルターが機能しない

> PDT-1107（bump-admin）の実機QA中に発見。bump-admin側のフロントエンド修正（コミット `52fc46b`）だけでは解決できない、bump-backend側の別問題として切り出し。

---

### 基本情報

| 項目 | 値 |
|-------|-------|
| **リポジトリ** | bump-backend |
| **対象** | Admin API |
| **種別** | Bug |
| **重要度** | 中（管理画面のシーズン一覧タブ絞り込みが機能しない） |
| **関連チケット** | PDT-1107（bump-admin側のフロント修正のみでは本問題は解決しない） |

---

### 問題の概要

管理画面のWork別シーズン一覧API `GET /admin/seasons/{workId}` は `projectId` クエリパラメータ（本編:1, 制作裏側:2）を受け付ける仕様だが、実装上このパラメータは一切使用されておらず、常に該当Workの全シーズンが返される。

---

### 再現手順

1. Stage管理画面（`https://dev-backend.bump.studio`）にログイン
2. 本編・制作裏側の両方のシーズンを持つWorkの `workId` を用意する（例: Work「buma」— 本編:「buma」「buma season-2」、制作裏側:「buma making」）
3. 以下のいずれかを実行:
   - ブラウザ: 管理画面でそのWorkのシーズン一覧を開き、「本編」タブをクリック
   - 直接リクエスト: `GET /api/v1/admin/seasons/{workId}?offset=0&projectId=1`

### 実際の動作

`projectId=1`（本編）を指定しても、`projectId=2`（制作裏側）のシーズンを含む全件が返る。`projectId` の有無・値によってレスポンスが変化しない。

実測例（Work「buma」, workId `2d672703-9eba-4786-9407-3308810bff73`）:
- `GET .../seasons/{workId}?offset=0` → 3件（本編2件+制作裏側1件）
- `GET .../seasons/{workId}?offset=0&projectId=1` → 同じ3件（本来は本編2件のみのはず）

### 期待される動作

`projectId` を指定した場合、該当プロジェクトタイプのシーズンのみが返される。

---

### 根本原因

`app/infrastructure/repository/season_admin.go` の `GetSeasonsAdmin` 関数が `projectId` 引数を受け取るが、GORMクエリに一切反映していない。

```go
// app/infrastructure/repository/season_admin.go:80
func (r *SeasonAdminRepository) GetSeasonsAdmin(workId string, offset, limit string, projectId string) ([]gormmodel.Season, int, error) {
	offsetNum, _ := strconv.Atoi(offset)

	limitNum, _ := strconv.Atoi(limit)
	if limitNum == 0 {
		limitNum = 2147483647
	}

	db := r.dbWrapper.GormReader

	var seasons []gormmodel.Season

	result := db.Scopes(
		scope.SeasonAdminFilterByWorkID(workId),   // ← workIdのみでフィルター。projectIdは未使用
	).
		Preload("Project.Work").
		Limit(limitNum).
		Offset(offsetNum).
		Find(&seasons)
	// ...
}
```

呼び出し経路: コントローラー `GetSeasonAdmin`（`app/presentation/api/controller/season_admin.go:190-213`）が `projectId` をクエリパラメータから取得し、usecase `SeasonAdminUseCase.GetSeasonsAdmin`（`app/usecase/season_admin.go:113`）経由でリポジトリまで渡すが、最終的にSQLのWHERE条件には反映されない。

OpenAPIドキュメントコメント（同コントローラー182行目付近）では `@Param projectId query string false "プロジェクトID（本編：1, 制作裏側：2） 未指定の場合、全取得"` とフィルター動作が明記されているが、実装が伴っていない。

**参考（正しく動作している類似実装）:** `GetSeasonAdminAll`（`/admin/seasons`、workId指定なしの全件取得API）は同コントローラー内でメモリ上フィルタリングしている（`app/presentation/api/controller/season_admin.go:44-70`）:

```go
for _, s := range allSeasons {
    if projectId != "" && projectId != s.ProjectMasterId {
        continue
    }
    // ...
}
```

---

### 修正方針（案）

`GetSeasonsAdmin`（`app/infrastructure/repository/season_admin.go:80`）のGORMクエリに `projectId` が指定されている場合のWHERE条件（例: `Project.ProjectMasterId` または該当カラムでの絞り込み）を追加する。`scope.SeasonAdminFilterByWorkID` と同様のscope関数を新設するか、既存クエリに条件分岐を加える形が妥当。

---

### 影響範囲

- 管理画面 > Work一覧 > シーズン一覧（Work別）のタブ絞り込み機能
- グローバルシーズン一覧（`/seasons-list`、`GetSeasonAdminAll`/`GetSeasonAdminAlt` 使用）には影響なし（別実装のため正常動作）

---

### 補足

- bump-admin側の [`src/domains/seasons/container/index.tsx`](../../../src/domains/seasons/container/index.tsx) は本問題とは別に、SWRキャッシュキーに起因するレースコンディションを修正済み（コミット `52fc46b`）。この修正自体は正当だが、本バックエンド問題が解決するまでPDT-1107の受け入れ基準（タブ絞り込みが実際に機能すること）は満たされない。
