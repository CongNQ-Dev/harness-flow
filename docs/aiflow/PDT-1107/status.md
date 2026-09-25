---
type: AI Flow Status
ticket: PDT-1107
title: 【管理画面】 Workー覧からシーズン一覧に遷移した時、すべて/本編/制作裏側のタブ絞り込みができない
kind: bug
route: full
repos: [bump-admin]
branch: bug/PDT-1107/fix_season_tab_filter
stage_done: 6
next: done
legacy: true   # trial run, migrated from bump-admin/docs/aiflow
prs:
  bump-admin: https://github.com/emole-inc/bump-admin/pull/585
updated: 2026-07-28
---
# AI Flow ステータス — PDT-1107

**最終更新:** 2026-07-28
**ブランチ:** bug/PDT-1107/fix_season_tab_filter

| ステージ | 状態 | 成果物 |
|---|---|---|
| 1. チケット正規化 (bump-ticket-normalize) | ✅ 完了 | ticket.md |
| 2. 仕様 (brainstorming) | ✅ 完了 | spec.md |
| 3. 実装計画 (writing-plans) | ✅ 完了 | plan.md |
| 4. 実装 (subagent-driven-development) | ✅ 完了 | fix commit 52fc46b |
| 5. レビュー・テスト (subagent-driven-development) | ⚠️ ブラウザ実機QAでブロッカー発見 | reviews/final-review.md, test-cases.md |
| 6. PR作成 (finishing-a-development-branch) | ✅ 完了（フロントエンドのみ） | PR #585 |

**次のステップ:** bump-backend側の `GetSeasonsAdmin` に `projectId` WHERE条件を追加するバグを別チケットで対応する（`docs/aiflow/PDT-1107/backend-bug-report.md` 参照）。

---

## ⚠️ 実機QAで発見したブロッカー（2026-07-28）

Stage管理画面のdevバックエンド（`https://dev-backend.bump.studio`）に対してブラウザで実際にタブ切り替えを検証した結果、**フロントエンド修正（コミット52fc46b）を適用してもタブ絞り込みは機能しない**ことを確認した。

### 再現内容

- Work「buma」（本編シーズン2件「buma」「buma season-2」、制作裏側シーズン1件「buma making」）で、Work一覧 → シーズン一覧 → 「本編」タブをクリック
- 実際に送信されたリクエスト: `GET /api/v1/admin/seasons/{workId}?offset=0&projectId=1`
- レスポンスは3件全部（制作裏側の「buma making」も含む）を返す → フロントは受け取ったデータをそのまま表示するため、絞り込みが効かないように見える

### 根本原因（bump-backendリポジトリ側）

`app/infrastructure/repository/season_admin.go` の `GetSeasonsAdmin` 関数が `projectId` 引数を**一切使用していない**:

```go
func (r *SeasonAdminRepository) GetSeasonsAdmin(workId string, offset, limit string, projectId string) ([]gormmodel.Season, int, error) {
    ...
    result := db.Scopes(
        scope.SeasonAdminFilterByWorkID(workId),
    ).
        Preload("Project.Work").
        Limit(limitNum).
        Offset(offsetNum).
        Find(&seasons)
    ...
}
```

`projectId` はコントローラー（`app/presentation/api/controller/season_admin.go:202`, `GetSeasonAdmin`）で受け取られ、usecase経由でここまで渡ってくるが、GORMクエリのWHERE条件には一切反映されない。OpenAPIドキュメント（`@Param projectId query string false ...`）ではフィルターすると明記されているが、実装が伴っていない。

比較として、グローバルシーズン一覧が使う `GetSeasonAdminAll`（`/admin/seasons`、bump-adminの`/seasons-list`ページが使用）はコントローラー内でメモリ上フィルタリングしており、正しく動作する。

### 影響

- PDT-1107の受け入れ基準（「本編」「制作裏側」タブで実際に絞り込まれること）は、bump-admin側の変更のみでは満たせない
- 今回のフロントエンド修正（SWRキーからprojectId除去 + revalidateOnFocus/refreshInterval無効化）自体は正当な修正（レースコンディション解消）だが、対象APIがそもそもフィルターしていないため、ユーザーから見た症状（「タブを切り替えても常に全件表示される」）は解消されない
- bump-backend側で `GetSeasonsAdmin`（`app/infrastructure/repository/season_admin.go:80`）に `projectId` によるWHERE条件を追加する対応が必要

### 未実施のテストケース

TC-03〜TC-05はTC-01/TC-02の失敗により保留。バックエンド側修正後に再実施が必要。
