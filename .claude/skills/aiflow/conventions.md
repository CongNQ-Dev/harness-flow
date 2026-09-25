# AI Flow — shared conventions (every aiflow-* stage skill follows these)

Read this file and `aiflow/workflow.yaml` at the start of every stage. They are
the contract; the stage skill only adds its own procedure.

## 1. Workspace layout

This workspace is the **only** AI Flow. The repos carry no copy of it — only
their owners' own guides/skills (see `workflow.yaml` `guides:` / `repo_skills:`).

```
ai-flow-demo/                      ← workspace repo (GitLab). Run Claude Code HERE.
├── aiflow/workflow.yaml           ← repos, base branches, test commands, triage, models
├── docs/aiflow/<TICKET-ID>/       ← ticket artifacts (source of truth, Japanese)
├── graphify-out/graph.json        ← workspace knowledge graph (all repos, /aiflow-analyze)
├── bump-backend/  bump-admin/  bump-mobile-app/   ← separate git repos (GitHub)
```

- Artifacts live in the **workspace** folder `docs/aiflow/<TICKET-ID>/` — one
  folder per ticket, fixed filenames, no dates or slugs:
  `status.md` · `ticket.md` · `spec.md` · `plan.md` · `reviews/` · `test-cases.md` · `log.json`
- Code changes live in each affected repo, on a branch with the **same name in
  every repo** (`bug/<ID>/<slug>` or `feature/<ID>/<slug>`), created from that
  repo's `base_branch` in `workflow.yaml`.
- At delivery (stage 6) the ticket folder is copied into each repo's branch as
  `docs/aiflow/<ID>/` so reviewers can accept the change by reading md files
  in the PR.

## 2. Git rules (multi-repo)

- Always run git with `git -C <repo-path> ...` — never `cd` and forget where you are.
- Workspace commits: `git add docs/aiflow/<ID> && git commit -m "docs(<ID>): <stage>"`
  on the workspace repo's current branch. Do not push the workspace repo
  unless the user asks.
- Code commits go only to the ticket branch of the repo that owns the file.
  Never commit to a repo's `base_branch`. Never force-push. Never switch a
  repo's branch while it has uncommitted changes — stop and tell the user.
- Before the first code change in a repo, check `git -C <repo> status --short`.
  If it is dirty with files unrelated to this ticket, stop and ask.

## 3. Status is the source of truth

- `docs/aiflow/<ID>/status.md` (format: `.claude/skills/aiflow-spec/status-template.md`)
  says which stage is done. Read it before doing anything for a ticket.
- `python3 aiflow/scripts/aiflow_status.py <ID>` prints `stage_done`,
  `route`, `next_stage`, `next_cmd` as JSON. Use it instead of guessing.
- **Resume = statement, not question.** If the requested stage is already done,
  say so and run the next one:
  > 「PDT-2350 はステージ3（修正プラン）まで完了しています。ステージ4（修正実装）を plan.md を読んで実行します。」
- If the user explicitly asks to redo a stage, redo that stage and reset
  `stage_done` to the stage before it.

## 4. One stage per turn, then a hard stop

Every stage ends with, **in this order, in the same turn, as real tool calls**:

1. Update `status.md` with the Edit tool (frontmatter `stage_done` / `next` /
   `updated` / `approvals`, the table row, 次のステップ).
2. Commit the ticket folder in the workspace repo.
3. `python3 aiflow/scripts/aiflow_log.py end <ID> <stage-id>`
4. Announce and **STOP — end the turn**. Never invoke the next stage yourself.
   Announcement format (Japanese):
   > 「ステージ N/6（<名前>）完了。成果物: `docs/aiflow/<ID>/<file>`。次: ステージ M（<名前>）— 準備ができたら `/aiflow <ID>` を実行してください。」

At the very beginning of a stage run: `python3 aiflow/scripts/aiflow_log.py start <ID> <stage-id>`
(stage ids: `ticket` `spec` `plan` `impl` `review` `deliver`). This feeds `log.json`.

## 5. Gates (human approval)

Stages 1, 2, 3 and 6 are gated: the artifact stays `status: draft` until the
user approves it via `AskUserQuestion`. On approval set the artifact's
frontmatter `status: approved` and add `approvals.<stage-id>: human:<name> <date>`
to `status.md`. A stage whose input artifact is not `approved` refuses to run
and says which approval is missing.

## 6. Talking to the user

- Every real decision uses `AskUserQuestion` (structured options; "Other" is
  added automatically). One question at a time.
- Stage boundaries are announcements, not questions.
- Everything written under `docs/aiflow/`, PR titles/bodies and PR comments is
  **Japanese**. Code, identifiers, file paths, commands stay as typed.
  Chat with the user in the language they use.

## 7. Knowledge graph before grep

When `graphify-out/graph.json` exists at the workspace root, orient with
`graphify query "<question>"` (cross-repo), `graphify path "A" "B"`,
`graphify explain "X"` before reading source files. Include this rule in every
subagent prompt that explores code. If the graph is missing or older than the
repo HEADs, tell the user once that `/aiflow-analyze` will refresh it — do not
block on it.

## 8. Subagents

- Give each subagent the full text it needs (task text, spec excerpt, repo
  facts from `workflow.yaml`) — never make it read the plan file itself.
- Always state the working directory: `Work from: <workspace>/<repo>`.
- Choose the model from `workflow.yaml` `models.<route>` (Agent tool `model:`).
- Require Japanese for any markdown the subagent writes under `docs/aiflow/`.
- **Repo owners' rules come first.** For the task's repo, pass `repos.<repo>.guides`
  (tell the subagent to read them before editing) and the matching
  `repos.<repo>.repo_skills` entry as a file path
  (`<repo>/.claude/skills/<name>/SKILL.md`) — e.g. a mobile UseCase change follows
  `bump-usecase-testing`, a ViewModel change `bump-viewmodel-testing`, and the
  mobile quality review uses `bump-code-review`. If a repo rule conflicts with an
  AI Flow rule, the repo rule wins for code; AI Flow rules still govern stages,
  artifacts and git branch handling.
- Never run two implementers in parallel on the same repo.

## 9. Engineering disciplines (internal skills, not slash commands)

Load them with the Skill tool when the situation applies:
`systematic-debugging` (root cause before fix), `test-driven-development`
(failing test first), `verification-before-completion` (evidence before
claims), `receiving-code-review`, `requesting-code-review`,
`dispatching-parallel-agents`, `graphify`.
