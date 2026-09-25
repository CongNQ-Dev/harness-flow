# spec.md template

Written in Japanese. Code, identifiers, paths, commands stay literal.
Two producers, same file shape:

- **Full route** — written by Stage 2 (`/aiflow-spec` §Stage 2) after the full
  investigate-and-dialogue process. Stage 3 (`/aiflow-plan`) reads it next.
- **Light fast-track** — written by Stage 1 (`/aiflow-spec` §1.4) inline,
  right after triage, with no dialogue. Stage 4 (`/aiflow-impl`) reads it
  directly (Stage 2 and 3 never run). Two sections differ from the full form:
  no "検討して却下した案" (there was no dialogue to compare approaches in),
  and 実装タスク is filled in here rather than by Stage 3.

Every section below is required either way; write `該当なし` rather than
dropping one — on the light fast-track, that includes the (empty)
"検討して却下した案" heading, kept for a consistent file shape.

```markdown
---
type: Spec
ticket: PDT-XXXX
kind: bug | feature
route: light | full
repos: [bump-backend, bump-mobile-app]
sources: [ticket.md]                 # + graphify nodes / docs you relied on
generated: {by: aiflow-spec, at: YYYY-MM-DD}
status: draft                        # draft → approved (stage 2 gate)
---

# 仕様: PDT-XXXX — <タイトル>

## 根本原因                     <!-- bug: 必須 / feature: 「背景と目的」に置き換え -->
- 問題A: `repo/path/file.ext:123` — 何が起きているか（根拠付き）
- 問題B: ...

## 修正方針
採用したアプローチと理由（1〜3段落）。

### 検討して却下した案
| 案 | 却下理由 |
|---|---|

## リポジトリ別の変更                <!-- 対象リポジトリごとに1節。順序 = 実装順 -->
### bump-backend
- 変更ファイル: `app/...`
- 変更内容: ...
### bump-mobile-app
- ...

## リポジトリ間の契約              <!-- API / GraphQL / swagger / ヘッダー等。なければ「該当なし」 -->
| 契約 | 提供側 | 利用側 | 変更内容 | 後方互換性 | 再生成コマンド |
|---|---|---|---|---|---|

## 振る舞い表
| 条件 | 変更前 | 変更後 |
|---|---|---|

## 受け入れ基準
- [ ] ticket.md の受け入れ基準をすべて含める（検証可能な文で）

## スコープ外
- 今回やらないこと（別チケット化するものはIDを記載）

## 実装タスク（light ルートのみ）       <!-- full ルートでは「/aiflow-plan で作成」と書く -->
### タスク1: <名前>（リポジトリ: bump-mobile-app）
- ファイル: `lib/...`
- テスト: 失敗するテストの内容 → 実装 → 実行コマンド（workflow.yaml の test_task / test）
```

Self-check before asking for approval: no TBD/TODO; every acceptance criterion
in ticket.md appears; every repo in `repos:` has a section; every contract row
names its regenerate command; file:line evidence for each root cause.
