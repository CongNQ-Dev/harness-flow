---
name: aiflow-plan
description: AI Flow stage 3 (full route only) — reads the approved spec.md and writes plan.md, a bite-sized TDD implementation plan where every task belongs to exactly one component, ordered contract-owner first, with exact files, code, commands and expected output. Stops for approval. Usually reached via /aiflow.
argument-hint: <TICKET-ID>
---

# /aiflow-plan — Plan (stage 3)

First read `.claude/skills/aiflow/conventions.md` and `aiflow/workflow.yaml`.

## 0. Preconditions

`python3 aiflow/scripts/aiflow_status.py <ID>`:
- `stage_done < 2` or `spec.md` not `status: approved` → refuse, name the missing approval.
- `route: light` → stage 3 is skipped on this route; say so, point to `/aiflow <ID>`.
- `stage_done >= 3` → already done: say so and run `next_cmd` (unless the user asked to redo the plan).

`python3 aiflow/scripts/aiflow_log.py start <ID> plan`

Check each affected git root is on the ticket branch.

## 1. Write the plan

Write `docs/aiflow/<ID>/plan.md` from `.claude/skills/aiflow-plan/plan-template.md`,
in `language` (conventions §7). The plan is for an engineer with zero context
for these codebases: exact paths, complete code, exact commands, expected
output. DRY, YAGNI, TDD, frequent commits.

**Component rules:**
1. **One component per task.** All of a task's files live under one
   component's `path`. A change needing two components is two tasks.
   `/aiflow-impl` refuses a task whose files span components.
2. **Dependency order.** Contract owner first — the component named `owner`
   in `workflow.yaml` `contracts:` — then a **regenerate task** in each
   consumer (`contracts[].regenerate`), then the consumer's own tasks.
3. **Backward compatibility.** If consumers can ship later than the owner,
   say how old clients keep working (a default when a new field/header is
   missing, a versioned endpoint, ...).
4. **Commands from `workflow.yaml`.** Use each component's `test_task` /
   `test` / `lint` exactly as written — including any wrapper its `notes`
   require. Resolve third-party APIs now, from the component's real
   dependency lock or cache (Node `node_modules/<pkg>`, Go `go doc`, Python
   the venv's site-packages, Dart `.dart_tool/package_config.json`,
   JVM the resolved jar, ...) — never leave "use library X" placeholders.
5. **No test runner.** If a component has no real `test:` command (its
   `notes` say so), use its `lint` / type-check command as the automated
   check, mark the task `TDD: false` with the reason, and leave manual
   checks to the test cases in stage 5.
6. **Team rules.** If the component lists `guides` or `team_skills`, the
   plan follows them (e.g. the team's testing skill decides how a test is
   structured).

## 2. Self-review

Against the spec with fresh eyes: coverage (every requirement → a task),
placeholders (no TBD / "add error handling" / "similar to task N"), name
consistency across tasks, one-component-per-task, ordering. For plans with
2+ components or 5+ tasks, dispatch `plan-document-reviewer-prompt.md` as a
subagent instead. Fix inline.

## 3. Gate

Summarize (task count per component, order, anything risky) and
`AskUserQuestion`: **Approve** / **Needs changes**.

## 4. Close

`plan.md` `status: approved`; `status.md` `stage_done: 3`, `next:
aiflow-impl`, `approvals.plan`; conventions §5: "Stage 3/6 (Plan) done — N
tasks (<component>: x, <component>: y). Next: stage 4 (Implementation) —
`/aiflow <ID>`."
