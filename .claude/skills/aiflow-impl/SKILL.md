---
name: aiflow-impl
description: AI Flow stage 4 — implements plan.md (full route) or spec.md's 実装タスク (light route) task by task across backend/admin/mobile repos; per task a fresh implementer subagent does TDD in that task's repo, then a spec-compliance review and a code-quality review, writing reviews/*.md. Resumes at the first unchecked task. Stops when all tasks pass. Usually reached via /aiflow.
argument-hint: <TICKET-ID>
---

# /aiflow-impl — 修正実装（ステージ4）

First read `.claude/skills/aiflow/conventions.md` and `aiflow/workflow.yaml`.
This is the old `subagent-driven-development` Stage 4, made repo-aware.

## 0. Preconditions

`python3 aiflow/scripts/aiflow_status.py <ID>`:
- full route: needs `plan.md` `status: approved` (stage 3). light route: needs
  `spec.md` `status: approved` with a filled 実装タスク section.
- `stage_done >= 4` → already done: announce and run `next_cmd`.

`python3 aiflow/scripts/aiflow_log.py start <ID> impl`

For each repo in `repos`: `git -C <repo> branch --show-current` must be the
ticket branch (else `git -C <repo> checkout <branch>`, never `-b`), and
`git -C <repo> status --short` must be clean of unrelated changes.

## 1. Load the tasks once

Read the task source once (plan.md, or spec.md 実装タスク on light), extract
every `### タスクN` with its full text, its `**リポジトリ:**`, `**TDD:**`,
file list, and whether its steps are already checked (`- [x]`). Create a
todo list (one item per task). Resume at the first task with unchecked steps.

Refuse a task whose files span more than one repo (planning defect — send the
user back to `/aiflow-plan`), or whose repo is not in `workflow.yaml`.

## 2. Per task (sequential — never two implementers at once)

Record `BASE=$(git -C <repo> rev-parse HEAD)`.

**A. Implementer** — dispatch `implementer-prompt.md` (model:
`models.<route>.implementer`), filling: full task text, where it fits
(spec summary, previous tasks done), repo facts block from `workflow.yaml`
(including `guides` and the matching `repo_skills` path, per conventions §8),
`Work from: <workspace>/<repo>`.

Handle status: `DONE` → B. `DONE_WITH_CONCERNS` → read; correctness/scope
concerns get fixed first. `NEEDS_CONTEXT` → give the context, re-dispatch.
`BLOCKED` → more context, a more capable model, a smaller task, or (plan is
wrong) stop and tell the user. Never retry the same thing unchanged.

**B. Spec compliance review** — dispatch `spec-reviewer-prompt.md` (model:
`models.<route>.reviewer`) with the task text, the implementer's report, and
the repo path. It reads the real code, not the report. Write its verdict to
`docs/aiflow/<ID>/reviews/task<N>-spec.md` (Japanese). ❌ → the same
implementer fixes → re-review. Repeat until ✅.

**C. Code quality review** — only after B is ✅. Dispatch
`code-quality-reviewer-prompt.md` with `REPO`, `BASE_SHA=$BASE`,
`HEAD_SHA=$(git -C <repo> rev-parse HEAD)`, plus the repo's own review skill
when it has one (`repo_skills.code_review`, e.g. mobile `bump-code-review`) as
the review checklist. Write to
`reviews/task<N>-quality.md`. Critical/Important issues → implementer fixes →
re-review. Minor → note and continue.

**Light route:** B and C are merged into one reviewer call (spec compliance
first, then quality, in one report) → `reviews/task<N>-review.md`.

**D. Mark done** — tick the task's checkboxes in plan.md (or spec.md), set the
status.md row to `⏳ 進行中（タスクN/総数）`, commit the ticket folder.

## 3. After the last task

Run each touched repo's `test` command from `workflow.yaml` once (use
`verification-before-completion`: run it fresh, read the output). A failure
is fixed by an implementer (with `systematic-debugging` if the cause is not
obvious) before the stage closes.

If code changed after the knowledge graph was built, run `graphify update .`
inside each touched repo (AST only, cheap), then
`python3 aiflow/scripts/kg_build.py --no-update` to re-merge the workspace
graph, so the final review queries current code.

## 4. Close stage 4

status.md `stage_done: 4`, row `✅ 完了` with the changed files per repo,
`next:` = `aiflow-review` (both routes: full runs stage 5, light goes straight
to stage 6 — the same skill). Then conventions §4:

> 「ステージ4/6（修正実装）完了 — 全Nタスク、全レビュー承認済み（backend: x commits / mobile: y commits）。次: ステージ5（レビュー・テストケース作成）— `/aiflow <ID>`」
> (light: 「次: ステージ6（納品・PR作成）— `/aiflow <ID>`」)

## Red flags

Never: skip either review · run quality review before spec is ✅ · move on with
open Critical/Important issues · let the implementer's self-review replace
review · make a subagent read the plan file · fix code yourself in the
controller (dispatch a fix subagent) · commit in a repo the task doesn't own.
