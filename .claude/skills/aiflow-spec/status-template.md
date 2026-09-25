# status.md template — the resume manifest

Every ticket folder has exactly one `docs/aiflow/<TICKET-ID>/status.md`. The
**frontmatter is machine-read** by `aiflow/scripts/aiflow_status.py` (that is
how `/aiflow <ID>` knows what to run next), so keep its keys exactly as below.
The body is the human view, in Japanese.

Every stage skill, when it finishes, updates: `stage_done`, `next`, `updated`,
the matching `approvals:` line (gated stages), the table row, and 次のステップ.

```markdown
---
type: AI Flow Status
ticket: PDT-2350
title: 【iOS/Android】プレイヤー表示状態でアプリ外からのDeepLink押下で、プレイヤーが二重で表示される
kind: bug                      # bug | feature
route: full                    # undecided | light | full
repos: [bump-mobile-app]       # repos this ticket changes
branch: bug/PDT-2350/fix_duplicate_player_deeplink   # same name in every repo listed
stage_done: 1                  # last completed stage number (0-6)
next: aiflow-spec              # skill that runs the next stage
approvals:                     # gate records: human:<name> <date>
  ticket: human:sasaki 2026-09-25
prs:                           # filled at stage 6, one line per repo
updated: 2026-09-25
---

# AI Flow ステータス — PDT-2350

**種別:** 不具合対応　**ルート:** 完全版（1→2→3→4→5→6）
**対象リポジトリ:** bump-mobile-app
**ブランチ:** bug/PDT-2350/fix_duplicate_player_deeplink

| ステージ | 状態 | 成果物 | 承認 |
|---|---|---|---|
| 1. チケット正規化 (/aiflow-spec) | ✅ 完了 | ticket.md | sasaki 2026-09-25 |
| 2. 仕様作成 (/aiflow-spec) | ⬜ 未着手 | — | — |
| 3. 修正プラン (/aiflow-plan) | ⬜ 未着手 | — | — |
| 4. 修正実装 (/aiflow-impl) | ⬜ 未着手 | — | — |
| 5. レビュー・テストケース作成 (/aiflow-review) | ⬜ 未着手 | — | — |
| 6. 納品・PR作成 (/aiflow-review) | ⬜ 未着手 | — | — |

**次のステップ:** `/aiflow PDT-2350`（= `/aiflow-spec` ステージ2: 仕様作成）
```

Status markers: `✅ 完了` · `⏳ 進行中（タスク2/4）` · `⬜ 未着手` · `⏭️ 省略（light）`

For `route: light`, rows 3 and 5 are `⏭️ 省略（light）` from the moment the
route is confirmed. If the route is upgraded light → full during stage 1's
fast-track investigation (§1.4 of `aiflow-spec`), change them back to `⬜ 未着手`.

**Light fast-track closes rows 1 and 2 together.** `aiflow-spec` §1.4 writes
`spec.md` inline during stage 1 — there is no separate stage-2 run for a
light ticket. When it does, write `stage_done: 2` directly (never a resting
`stage_done: 1` for a light ticket that completed §1.4) and mark **both**
rows `✅ 完了` with the same `updated` date, from the one combined approval:

```markdown
| 1. チケット正規化 (/aiflow-spec) | ✅ 完了 | ticket.md | sasaki 2026-09-25 |
| 2. 仕様作成 (/aiflow-spec §1.4 省略版) | ✅ 完了 | spec.md | sasaki 2026-09-25 |
```

`approvals:` records who approved a gated stage (1 ticket, 2 spec, 3 plan,
6 manual test). Use the name the user gives; if they give none, use `human`.
On the light fast-track, `approvals.ticket` and `approvals.spec` both point
at the same confirmation — that's expected, not a duplicate to clean up.
