---
name: aiflow
description: The one AI Flow command. `/aiflow PDT-2350` runs the next stage of that ticket (normalize → spec → plan → implement → review/test cases → PR) across bump-backend, bump-admin and bump-mobile-app, then stops. `/aiflow` alone shows the board of all tickets. Also `/aiflow PDT-2350 feature`, `/aiflow PDT-2350 redo spec`, `/aiflow analyze`. Use whenever the user mentions a PDT ticket, a bug to fix, or continuing AI Flow work.
argument-hint: "[<TICKET-ID> [feature | redo <stage> | status] | analyze]"
---

# /aiflow — AI Flow entry point (router)

The user only needs to remember this command. It figures out where a ticket
is and runs **exactly one** stage, then stops. Read
`.claude/skills/aiflow/conventions.md` once per session.

## Dispatch on the arguments

| Input | Action |
|---|---|
| *(nothing)* | Board: run `python3 aiflow/scripts/aiflow_status.py` and show it, then the 3-line help below. |
| `analyze` | Invoke the `aiflow-analyze` skill. |
| `<ID>` or `<ID> feature` | **Run next stage** (below). `feature` marks a new ticket as 新規・保守開発. |
| `<ID> status` | Show `docs/aiflow/<ID>/status.md` + `python3 aiflow/scripts/aiflow_log.py summary <ID>`. Run nothing. |
| `<ID> redo <stage>` | Stage = `ticket`/`spec`/`plan`/`impl`/`review`/`deliver` (or its number). Confirm with `AskUserQuestion` that later artifacts will be regenerated, set `stage_done` to the stage before it, then invoke that stage's skill. |
| `<ID> testcases` | Invoke `aiflow-testgen` for that ticket (standalone). |
| a PR URL | Invoke `aiflow-review` with the URL (PR review mode). |
| free text ("continue 2350", "PDT-2350の続き") | Map it to one of the rows above; ask only if it's truly ambiguous. |

Ticket IDs are case-insensitive; normalize to upper case (`pdt-2350` → `PDT-2350`).

## Run next stage

1. `python3 aiflow/scripts/aiflow_status.py <ID>` → JSON with `stage_done`,
   `route`, `next_stage`, `next_cmd`, `next_name`.
2. If `next_cmd` is null → the ticket is done; print its PR URLs and stop.
3. **Knowledge-graph check (once per session):** if `graphify-out/graph.json`
   is missing at the workspace root, say one line:
   「ナレッジグラフが未作成です。精度向上のため `/aiflow analyze` を推奨します（続行は可能）。」
   Do not block.
4. Announce as a statement (never a question), e.g.
   > 「PDT-2350 はステージ2（仕様作成）まで完了。ステージ4（修正実装）を実行します（light ルートのためステージ3は省略）。」
   New ticket: 「PDT-2350 を新規チケットとして開始します（ステージ1: チケット正規化）。」
5. Invoke the skill named by `next_cmd` with the Skill tool, args `<ID>` (plus
   `feature` if given). Follow it; it ends the turn with a stop.

## Help text (for the board view)

```
/aiflow PDT-XXXX            次のステージを実行（新規チケットもこれで開始）
/aiflow PDT-XXXX status     進捗・処理ログを表示        /aiflow analyze   ナレッジグラフ更新
/aiflow PDT-XXXX redo spec  ステージをやり直す          /aiflow <PR URL>  既存PRをレビュー
```

## Stages (for reference)

| # | Stage | Skill | light | full |
|---|---|---|---|---|
| 1 | チケット正規化 | aiflow-spec (§Stage 1) | ✅ | ✅ |
| 2 | 仕様作成 | aiflow-spec (§Stage 2) | ✅ | ✅ |
| 3 | 修正プラン | aiflow-plan | — | ✅ |
| 4 | 修正実装 | aiflow-impl | ✅ | ✅ |
| 5 | レビュー・テストケース作成 | aiflow-review (§Stage 5) | — | ✅ |
| 6 | 納品（PR作成） | aiflow-review (§Stage 6) | ✅ | ✅ |

Stages 5 and 6 are both written inside the single `aiflow-review` skill file
as two separate sections — not two invocations of the same procedure. On the
light route, stage 5's section never runs; stage 6's section always does.
`/aiflow` picks the right section by reading `status.md`, same as any other
stage; you never choose the section yourself.

The route (light/full) is decided by triage at the end of stage 1, confirmed by
the user, and can only be upgraded (light → full) automatically.
