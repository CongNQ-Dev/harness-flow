# plan.md template (output contract of stage 3)

Labels in Japanese; code, commands, paths, identifiers exactly as typed.
`/aiflow-impl` parses the `### タスクN:` headings and each task's
`**リポジトリ:**` line — keep them exactly in this shape.

````markdown
---
type: Plan
ticket: PDT-XXXX
repos: [bump-backend, bump-mobile-app]
branch: bug/PDT-XXXX/<slug>
sources: [spec.md]
generated: {by: aiflow-plan, at: YYYY-MM-DD}
status: draft                  # draft → approved (stage 3 gate)
---

# PDT-XXXX 実装計画 — <機能名>

> **エージェント向け:** `/aiflow-impl` がタスクごとに実装者サブエージェントを起動し、仕様レビュー → 品質レビューを行う。各ステップはチェックボックス（`- [ ]`）で進捗を管理する。

**ゴール:** <1文>
**ブランチ:** `bug/PDT-XXXX/<slug>`（ステージ1で各リポジトリに作成済み）
**アーキテクチャ:** <2〜3文>
**実装順序:** bump-backend（タスク1–2）→ bump-mobile-app（タスク3–4）

---

### タスク1: <コンポーネント名>

**リポジトリ:** bump-backend
**TDD:** true            <!-- false の場合は理由を1行で -->
**ファイル:**
- 変更: `app/presentation/api/graph/schema.resolvers.go:185-200`
- テスト: `app/presentation/api/graph/schema_resolvers_test.go`

- [ ] **ステップ1: 失敗するテストを書く**

```go
func TestWork_SearchAccess_UsesHeaderSeason(t *testing.T) { ... 実際のコード ... }
```

- [ ] **ステップ2: テストを実行し、失敗することを確認する**

実行: `make test-package PKG=presentation/api/graph`
期待結果: `TestWork_SearchAccess_UsesHeaderSeason` が FAIL（理由: ...）

- [ ] **ステップ3: 最小限の実装を書く**

```go
... 実際のコード ...
```

- [ ] **ステップ4: テストを実行し、成功することを確認する**

実行: `make test-package PKG=presentation/api/graph`
期待結果: PASS

- [ ] **ステップ5: コミットする**

```bash
git -C bump-backend add app/presentation/api/graph/...
git -C bump-backend commit -m "fix(PDT-XXXX): <内容>"
```

### タスク2: GraphQLクライアント再生成

**リポジトリ:** bump-mobile-app
**TDD:** false（生成コードのみ。検証は `bin/fvm flutter analyze` と既存テスト）
...
````
