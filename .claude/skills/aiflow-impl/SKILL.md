---
name: aiflow-impl
description: AI Flow stage 4 — implements plan.md (full route) or spec.md's implementation tasks (light route) task by task; per task a fresh implementer subagent does TDD inside that task's component, then a spec-compliance review and a code-quality review, writing reviews/*.md. Resumes at the first unchecked task. Stops when every task passes. Usually reached via /aiflow.
argument-hint: <TICKET-ID>
---

# /aiflow-impl — Implementation (stage 4)

First read `.claude/skills/aiflow/conventions.md` and `aiflow/workflow.yaml`.

## 0. Preconditions

`python3 aiflow/scripts/aiflow_status.py <ID>`:
- full route: needs `plan.md` `status: approved` (stage 3). Light route:
  needs `spec.md` `status: approved` with its "Implementation tasks" filled in.
- `stage_done >= 4` → already done: say so and run `next_cmd`.

`python3 aiflow/scripts/aiflow_log.py start <ID> impl`

For each affected git root: `git -C <root> branch --show-current` must be
the ticket branch (else `git -C <root> checkout <branch>`, never `-b`), and
`git -C <root> status --short` must be free of unrelated changes.

## 1. Load the tasks once

Read the task source once (plan.md, or spec.md's tasks on light) and extract
every `### Task N` with its full text, its component, its TDD flag, its file
list, and whether its steps are already checked (`- [x]`). Make a todo list
(one item per task). Resume at the first task with unchecked steps.

Refuse a task whose files fall under more than one component's `path`
(planning defect — back to `/aiflow-plan`), or whose component isn't in
`workflow.yaml`.

## 2. Per task (sequential — never two implementers in one git root at once)

Record `BASE=$(git -C <root> rev-parse HEAD)`.

**A. Implementer** — dispatch `implementer-prompt.md` (model:
`models.<route>.implementer`) with the full task text, where it fits (spec
summary, tasks done so far), the component facts block from `workflow.yaml`
(including `guides` and the matching `team_skills` path — conventions §10),
and `Work from: <component path>`.

Handle status: `DONE` → B. `DONE_WITH_CONCERNS` → read; fix correctness or
scope concerns first. `NEEDS_CONTEXT` → give it, re-dispatch. `BLOCKED` →
more context, a more capable model, a smaller task, or (the plan is wrong)
stop and tell the user. Never retry unchanged.

**B. Spec-compliance review** — dispatch `spec-reviewer-prompt.md` (model:
`models.<route>.reviewer`) with the task text, the implementer's report, the
component path and the output `language`. It reads the real code, not the
report. Write its verdict to `docs/aiflow/<ID>/reviews/task<N>-spec.md`.
❌ → the same implementer fixes → re-review, until ✅.

**C. Code-quality review** — only after B is ✅. Dispatch
`code-quality-reviewer-prompt.md` with `REPO=<git root>`, `BASE_SHA=$BASE`,
`HEAD_SHA=$(git -C <root> rev-parse HEAD)`, `LANGUAGE`, plus the component's
own review skill as the checklist when it has one (`team_skills.code_review`).
Write to `reviews/task<N>-quality.md`. Critical/Important → implementer
fixes → re-review. Minor → note and continue.

**Light route:** B and C are one reviewer call (spec compliance first, then
quality, one report) → `reviews/task<N>-review.md`.

**D. Mark done** — tick the task's checkboxes in plan.md (or spec.md), set
the status.md row to "⏳ in progress (task N/total)", commit the ticket folder
(conventions §3).

## 3. After the last task

Run each touched component's `test` once (and `lint`), fresh
(`verification-before-completion`: run it, read the output). A failure is
fixed by an implementer — with `systematic-debugging` if the cause isn't
obvious — before the stage closes.

If `knowledge_graph.enabled` and a graph exists, refresh it for the touched
git roots: `python3 aiflow/scripts/kg_build.py` (it only rebuilds roots whose
HEAD moved), so the final review queries current code.

## 4. Close

**Verify the code really landed on the ticket branch first** — a stage-4
"done" with the fix sitting uncommitted on a base branch is the worst
failure this flow can produce. For each git root a task touched:

```bash
git -C <root> branch --show-current                       # must be the ticket branch
git -C <root> status --short                              # no leftovers from the tasks
git -C <root> log --oneline origin/<base_branch>..HEAD    # at least one commit per task
```

Any check fails → don't mark the stage done. Say exactly what's wrong
("mobile-app is on `main` with `lib/x.dart` uncommitted; the ticket branch has
no commits") and stop. Move uncommitted work only with the user's OK
(`git -C <root> stash` → `checkout <branch>` → `stash pop` → commit).

`status.md` `stage_done: 4`, row done with the changed files per component,
`next: aiflow-review` (full runs stage 5 next; light goes straight to stage 6
— same skill). Conventions §5: "Stage 4/6 (Implementation) done — N tasks,
all reviews passed. Next: stage 5 (Review & test cases) — `/aiflow <ID>`."
(light: "Next: stage 6 (Delivery) — `/aiflow <ID>`.")

## Red flags

Never: skip either review · run the quality review before spec is ✅ · move
on with open Critical/Important issues · let the implementer's self-review
replace review · make a subagent read the plan file · fix code yourself in
the controller (dispatch a fix subagent) · change files outside the task's
component · mark the stage done without §4's branch check.
