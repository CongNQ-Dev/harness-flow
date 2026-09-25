---
name: aiflow-plan
description: AI Flow stage 3 (full route only) — reads the approved spec.md and writes plan.md, a bite-sized TDD implementation plan where every task belongs to exactly one repo (backend/admin/mobile), ordered contract-owner first, with exact files, code, commands and expected output. Stops for approval. Usually reached via /aiflow.
argument-hint: <TICKET-ID>
---

# /aiflow-plan — 修正プラン（ステージ3）

First read `.claude/skills/aiflow/conventions.md` and `aiflow/workflow.yaml`.

## 0. Preconditions

`python3 aiflow/scripts/aiflow_status.py <ID>`:
- `stage_done < 2` or `spec.md` not `status: approved` → refuse, name the missing approval.
- `route: light` → stage 3 is skipped on this route; say so and point to `/aiflow <ID>`.
- `stage_done >= 3` → already done: announce and run `next_cmd` (unless the user asked to redo the plan).

`python3 aiflow/scripts/aiflow_log.py start <ID> plan`

Verify each repo in `repos` is on the ticket branch.

## 1. Write the plan

Write `docs/aiflow/<ID>/plan.md` from `.claude/skills/aiflow-plan/plan-template.md`.
The plan is for an engineer with zero context for these codebases: exact
paths, complete code, exact commands, expected output. DRY, YAGNI, TDD,
frequent commits. (This is the old `writing-plans` discipline, unchanged.)

**Multi-repo rules (new):**
1. **One repo per task.** A task's files all live in one repo. A change that
   needs two repos is two tasks. `/aiflow-impl` refuses a task whose files span repos.
2. **Order = dependency order.** Contract owner first — the repo named as
   `owner` in `workflow.yaml`'s `contracts:` block (e.g. the backend schema /
   swagger / resolver in this project) — then a **regenerate task** in each
   consumer (`contracts[].regenerate`), then consumer tasks.
3. **Backward compatibility.** If consumers ship later than the backend, say
   how old clients keep working (e.g. fallback when a header is missing).
4. **Commands from `workflow.yaml`.** Use each repo's `test_task` / `test` /
   `lint` exactly as written there — including any wrapper it names (this
   project's mobile repo always uses `bin/fvm ...`, never plain
   `flutter`/`dart`, per its own `notes`). Resolve third-party APIs now, from
   that repo's real dependency lock/cache (Dart: `.dart_tool/package_config.json`;
   Node: `node_modules/<pkg>`; Go: `go doc`) — never leave "use library X"
   placeholders.
5. **No unit-test runner.** If a repo's `workflow.yaml` entry has no real
   `test:` command (its `notes` say so — in this project, bump-admin), use
   its `lint`/type-check command as the automated check instead and mark
   the task `tdd: false` with a reason; manual steps go to test cases in
   stage 5.

## 2. Self-review

Check the plan against the spec with fresh eyes — spec coverage (every
requirement → a task), placeholder scan (no TBD / "add error handling" /
"similar to task N"), name consistency across tasks, one-repo-per-task, and
ordering. For plans with 2+ repos or 5+ tasks, dispatch
`plan-document-reviewer-prompt.md` as a subagent instead. Fix inline.

## 3. Gate

Summarize (task count per repo, order, anything risky) and `AskUserQuestion`:
**承認** / **修正あり**.

## 4. Close stage 3

`plan.md` `status: approved`; status.md `stage_done: 3`, `next: aiflow-impl`,
`approvals.plan`; then conventions §4:

> 「ステージ3/6（修正プラン）完了。`docs/aiflow/<ID>/plan.md`（タスクN件: backend X / admin Y / mobile Z）。次: ステージ4（修正実装）— `/aiflow <ID>`」
