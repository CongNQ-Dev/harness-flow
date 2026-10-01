---
name: aiflow
description: The one AI Flow command. `/aiflow <TICKET-ID>` runs the next stage of that ticket (intake → spec → plan → implement → review/test cases → PR) across the components declared in aiflow/workflow.yaml, then stops. `/aiflow` alone shows the board of all tickets. Also `/aiflow setup` (first-time configuration), `/aiflow <ID> feature`, `/aiflow <ID> status`, `/aiflow <ID> redo <stage>`, `/aiflow analyze`, `/aiflow wiki`, `/aiflow <PR/MR URL>`. Use whenever the user mentions a ticket or issue ID, a bug to fix, a feature to build, or continuing AI Flow work.
argument-hint: "[setup | <TICKET-ID> [feature | status | redo <stage> | testcases] | analyze | wiki [refresh] | <PR/MR URL>]"
---

# /aiflow — AI Flow entry point (router)

The user only needs to remember this command. It figures out where a ticket
is and runs **the next stage**, then stops — one stage per turn, except the
light route's small-bug fast-track, which does stages 1+2 together
(conventions §5). Read `.claude/skills/aiflow/conventions.md` once per session.

## 0. Configured yet?

If `aiflow/workflow.yaml` doesn't exist, the only thing that can run is
setup. Say so in one line and invoke the `aiflow-setup` skill — unless the
user only asked for help, in which case show the help text below.

## Dispatch on the arguments

| Input | Action |
|---|---|
| *(nothing)* | Board: `python3 aiflow/scripts/aiflow_status.py`, then the help text below. If `tickets.lists_dir` has files, mention that `/aiflow` can pick a ticket from them. |
| `setup` | Invoke `aiflow-setup` (re-running it on an existing `workflow.yaml` updates it). |
| `analyze` / `analyze docs` | Invoke `aiflow-analyze` (pass `docs` through). |
| `wiki` / `wiki refresh` | Invoke `aiflow-wiki` (pass `refresh` through). |
| `<ID>` or `<ID> feature` | **Run next stage** (below). `feature` marks a new ticket as new development instead of a bug fix. |
| `<ID> status` | Show `docs/aiflow/<ID>/status.md` + `python3 aiflow/scripts/aiflow_log.py summary <ID>`. Run nothing. |
| `<ID> redo <stage>` | Stage = `ticket`/`spec`/`plan`/`impl`/`review`/`deliver` (or its number). Confirm with `AskUserQuestion` that later artifacts will be regenerated, set `stage_done` to the stage before it, then invoke that stage's skill. |
| `<ID> testcases` | Invoke `aiflow-testgen` for that ticket (standalone). |
| a PR / MR URL | Invoke `aiflow-review` with the URL (review mode). |
| free text ("continue 12", "keep going on SHOP-12") | Map it to one of the rows above; ask only if it's truly ambiguous. |

Normalize ticket IDs per conventions §2.

## Run next stage

0. Get onto the ticket's branch if it already has one (conventions §4,
   first paragraph) — otherwise an existing ticket looks brand new.
1. `python3 aiflow/scripts/aiflow_status.py <ID>` → JSON with `stage_done`,
   `route`, `next_stage`, `next_cmd`, `next_name`.
2. If `next_cmd` is null → the ticket is done; print its PR URLs and stop.
3. **Knowledge graph check (once per session):** if `knowledge_graph.enabled`
   and `graphify-out/graph.json` is missing, say one line recommending
   `/aiflow analyze` (optional — continue either way).
4. Announce as a statement, e.g. "SHOP-12 is done through stage 2 (Spec).
   Running stage 4 (Implementation) — stage 3 is skipped on the light route."
   New ticket: "Starting SHOP-12 (stage 1: ticket intake)."
5. Invoke the skill named by `next_cmd` with the Skill tool, args `<ID>`
   (plus `feature` if given). Follow it; it ends the turn with a stop.

## Help text (for the board view — translate to the user's language)

```
/aiflow <ID>              run the next stage (a new ticket starts here too)
/aiflow <ID> feature      start a new ticket as a feature, not a bug fix
/aiflow <ID> status       progress + time/tokens/cost per stage
/aiflow <ID> redo spec    redo a stage
/aiflow analyze           refresh the knowledge graph
/aiflow wiki              generate / refresh the project wiki (costs tokens)
/aiflow <PR/MR URL>       review an existing PR or MR
/aiflow setup             (re)configure aiflow/workflow.yaml
```

## Stages (for reference)

| # | Stage | Skill (section) | light | full |
|---|---|---|---|---|
| 1 | Ticket intake | aiflow-spec (§Stage 1) | ✅ | ✅ |
| 2 | Spec | aiflow-spec (§1.4 on light / §Stage 2 on full) | ✅ | ✅ |
| 3 | Plan | aiflow-plan | — | ✅ |
| 4 | Implementation | aiflow-impl | ✅ | ✅ |
| 5 | Review & test cases | aiflow-review (§Stage 5) | — | ✅ |
| 6 | Delivery (PR/MR) | aiflow-review (§Stage 6) | ✅ | ✅ |

On the light route, stages 1 and 2 are one run of `aiflow-spec`, not two —
the router doesn't need to know; the skill decides internally. Stages 5 and 6
are two sections of one `aiflow-review` file; `status.md` picks the section.

The route is decided by triage at the end of stage 1 and re-checked against
real code before anything is written. The user confirms it. It can be
upgraded light → full automatically, never downgraded silently.
