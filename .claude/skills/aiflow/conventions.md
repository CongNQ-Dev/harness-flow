# AI Flow — shared conventions (every aiflow-* stage skill follows these)

Read this file and `aiflow/workflow.yaml` at the start of every stage. They
are the contract; each stage skill only adds its own procedure. If
`aiflow/workflow.yaml` doesn't exist, stop and tell the user to run
`/aiflow setup` — never guess project facts.

**Not running in Claude Code** (Codex, Copilot, Cursor, OpenCode, OpenClaw,
...)? The skills use Claude Code's tool names — read `aiflow/AGENTS-TOOLS.md`
once for your agent's equivalents and the fallback rules (no structured
question UI → numbered question in chat and wait; no subagents → run the
prompt inline, sequentially).

**On Windows:** the commands here say `python3`. If that isn't on PATH, use
`python` (or `py -3`) instead for every `python3 aiflow/scripts/...` call.
Git commands, paths with `/`, and the scripts themselves work the same.

## 1. Layout, components, git roots

`workflow.yaml` `layout:` is one of:

- **in-repo** — AI Flow lives inside the project's own git repo. Ticket docs
  (`docs/aiflow/<ID>/`) are committed **on the ticket branch**, together with
  the code, and ship in the same PR. The ticket branch must therefore exist
  before the first docs commit.
- **workspace** — a wrapper repo holds AI Flow; component repos are cloned
  beside it (gitignored by the wrapper). **The wrapper is a git root too**:
  stage 1 gives it the same ticket branch as the affected component repos
  (from `workspace_repo.base_branch`), ticket docs are committed on that
  branch, and code goes to each component repo's ticket branch. So during a
  ticket the wrapper **and** every affected repo are on
  `bug/<ID>/…` / `feature/<ID>/…` — never on `main`/`develop`. At delivery
  the wrapper gets its own docs PR/MR (`workspace_repo.pr`) and the docs
  folder is also copied into each component repo's PR
  (`pr.copy_artifacts_into_repo`).

`components:` are the units a task can change — a whole repo (`path: .`), a
package in a monorepo, or a separately cloned repo. **One task = one
component.** Resolve each component's git root once per stage:

```bash
git -C <component path> rev-parse --show-toplevel
```

Components with the **same git root share one ticket branch and one PR**
(monorepo). Components with different git roots each get their own branch
(same name) and their own PR (multi-repo). Never assume which case you're in
from the component count — resolve it.

Everything under `docs/aiflow/<ID>/` uses fixed filenames:
`status.md` · `ticket.md` · `spec.md` · `plan.md` · `reviews/` · `test-cases.md` · `log.json`

## 2. Ticket IDs

Use the ID the user gives, upper-cased (`shop-12` → `SHOP-12`). A bare number
or `#123` (a GitHub/GitLab issue) becomes `<project_code>-123`. That string is
the folder name and the `<TICKET-ID>` in branch names and PR titles.

## 3. Git rules

- Always `git -C <path> ...` — never `cd` and lose track of where you are.
- **Never commit or push to a `base_branch`** — whatever it is called
  (`main`, `master`, `develop`, a release branch…): every `base_branch` in
  `workflow.yaml` (each component's, and `workspace_repo.base_branch`). Work
  happens on the ticket branch; changes reach a base branch only through a
  PR/MR. Never force-push. **Every push needs a fresh confirmation**: before each
  `git push` (any root, any branch) ask the user via `AskUserQuestion`, naming the
  repo, branch and remote, and push only on a clear yes. An earlier approval
  (a gate, the QA answer, "create the PR") never covers a later push. Never
  switch a branch while that git root has uncommitted changes — stop and tell the user.
- **Never commit or push sensitive content** — API keys, tokens, passwords,
  private keys, `.env*`, `*.pem`/`*.key`/`*.p12`, `credentials.json`,
  service-account files, or anything else that looks like a secret. Stage
  files by explicit path (never `git add -A` / `git add .`), and before every
  commit read `git -C <root> diff --cached` for secrets. If one is staged or
  already committed, stop: unstage it, tell the user, and never push it. This
  covers ticket artifacts too (docs, logs, test cases, PR text): write a
  placeholder such as `<API_KEY>`, never the real value. Secrets are not
  rewritten out of history by a new commit, so also tell the user to rotate
  one that already reached a commit.
- **Every write to the git host needs a fresh confirmation, never automatic.**
  Besides `git push`, this covers anything `gh`/`glab` (or the host API) changes
  on GitHub/GitLab: creating a PR/MR (as a **Draft**), marking it Ready for
  review, editing its title/body/"Related" line,
  posting a comment or review, pushing to an existing PR/MR. Before each one, ask via
  `AskUserQuestion`, naming the action, target (repo, branch, PR/MR) and
  the text to be posted, and act only on a clear yes. Config flags such as
  `pr.post_review_comment` only mean "offer it", never "do it". Never merge,
  approve, request changes, close or delete a PR/MR/branch unless the user
  asks for exactly that in chat. Read-only calls (`view`, `diff`, `list`) need no
  confirmation.
- Before the first code change in a git root, check `git -C <root> status
  --short`. Unrelated changes there → stop and ask.
- Docs commits: `docs(<ID>): <stage>`, always on the ticket branch — the
  project repo's (**in-repo**) or the wrapper's (**workspace**). Never on a
  base branch. Pushing happens at delivery (stage 6), not before.
- Code commits: only on the ticket branch of the git root that owns the file.

## 4. Status is the source of truth

**Be on the ticket's branch first.** Ticket docs live on the ticket branch,
so on another branch `docs/aiflow/<ID>/` may simply not be there. Before
reading status for an existing ticket, in the repo that holds the docs (the
project repo for in-repo, the wrapper for workspace): if the current branch
doesn't contain `/<ID>/`, look for one that does —
`git -C <root> branch --list "*/<ID>/*"` (then `git -C <root> branch -r
--list "origin/*/<ID>/*"`). Found → check it out there and in every
affected component repo (same name; §3's uncommitted-changes rule applies),
and say so in one line. None found → stay put: if `docs/aiflow/<ID>/`
exists here, it's a ticket started before it had a branch (status.md
decides; the next docs commit goes on the ticket branch that stage
created or creates now); if it doesn't, it's a new ticket.
`aiflow_status.py <ID>` does this search too (local, then remote branches) and
returns `checkout_branch` when the ticket lives on another branch — treat that
as "existing ticket, wrong branch", never as new. Only `exists: false` without
`checkout_branch` means new; check this **before** asking for the ticket text.

- `docs/aiflow/<ID>/status.md` (format: `.claude/skills/aiflow-spec/status-template.md`)
  says which stage is done. Read it before doing anything for a ticket.
- `python3 aiflow/scripts/aiflow_status.py <ID>` prints `stage_done`,
  `route`, `next_stage`, `next_cmd` as JSON. Use it instead of guessing.
- **Resume = a statement, not a question**: "SHOP-12 is done through stage 3
  (Plan). Running stage 4 (Implementation) from plan.md."
- If the user explicitly asks to redo a stage, redo it and reset
  `stage_done` to the stage before it.

## 5. One stage per turn, then a hard stop

**One exception:** on the light route, `aiflow-spec` §1.4 writes stage 1 and
stage 2's output in the same run, behind one combined approval (a small
bug's triage and fix write-up are one step). That run still ends with
exactly one close as below.

Every stage ends with, **in this order, in the same turn, as real tool calls**:

1. Update `status.md` with the Edit tool (frontmatter `stage_done` / `next` /
   `updated` / `approvals`, the table row, the "Next step" line).
2. Commit the ticket folder (per §3 — which branch depends on `layout`).
3. `python3 aiflow/scripts/aiflow_log.py end <ID> <stage-id>`
4. Announce and **STOP — end the turn**. Never invoke the next stage yourself:
   "Stage N/6 (<name>) done. Output: `docs/aiflow/<ID>/<file>`. Next: stage M
   (<name>) — run `/aiflow <ID>` when ready."

At the very start of a stage run: `python3 aiflow/scripts/aiflow_log.py start <ID> <stage-id>`
(stage ids: `ticket` `spec` `plan` `impl` `review` `deliver`).

## 6. Gates (human approval)

Stages 1, 2, 3 and 6 are gated: the artifact stays `status: draft` until the
user approves it via `AskUserQuestion`. On approval set the artifact's
frontmatter `status: approved` and add `approvals.<stage-id>: human:<name> <date>`
to `status.md`. A stage whose input artifact isn't `approved` refuses to run
and says which approval is missing.

**Always name the reviewer.** Whoever reviews or approves anything — a human
(spec/plan/QA/PR approval, PR review) or an AI reviewer subagent (spec-compliance,
code-quality, final review) — is recorded by name: a `reviewer:` line at the top
of every `reviews/*.md` file (`human:<name>` or `ai:<role> (<model>)`), and
the name in every `approvals.*` entry and PR review comment. Unknown human
name → ask once; never leave a review anonymous.

## 7. Language

- Everything written under `docs/aiflow/`, PR titles/bodies and PR comments
  is in `workflow.yaml` `language:` — prose **and** headings.
- The templates in these skills are written in English. When `language`
  isn't `en`, translate their headings and labels as you fill them in.
- Never translate: frontmatter keys, filenames, component names, branch
  names, commands, code, identifiers, file paths, enum values
  (`draft`/`approved`, `light`/`full`, `bug`/`feature`).
- Talk to the user in whatever language they write in.

## 8. Talking to the user

- Every real decision uses `AskUserQuestion` (structured options; "Other" is
  added automatically). One question at a time.
- Stage boundaries are announcements, not questions.

## 9. Knowledge graph and wiki before grep

If `knowledge_graph.enabled` and `graphify-out/graph.json` exists, orient with
`graphify query "<question>"`, `graphify path "A" "B"`, `graphify explain "X"`
before reading source files, and put this rule in every subagent prompt that
explores code. If the graph is missing or stale, say once that `/aiflow
analyze` refreshes it — never block on it. If `graphify` isn't installed,
use normal code search; that's fine.

If `wiki/` exists, check `wiki/architecture/` for already-written context
(module map, contracts and their rationale) before re-deriving it. The graph
says *what calls what*; the wiki says *why*. A missing wiki is normal — never
suggest running `/aiflow wiki` mid-ticket.

## 10. Subagents

- Give each subagent the full text it needs (task text, spec excerpt,
  component facts from `workflow.yaml`) — never make it read the plan itself.
- State the working directory: `Work from: <component path>`.
- Model per role: `workflow.yaml` `models.<route>` (the Agent tool's `model:`).
- Tell it the output `language` for anything it writes under `docs/aiflow/`.
- **The component team's rules come first.** Pass `components.<name>.guides`
  (read before editing) and the matching `team_skills` entry as a file path
  (`<path>/.claude/skills/<skill>/SKILL.md`). For code, team rules win over
  AI Flow; AI Flow still governs stages, artifacts and branches.
- Never run two implementers in parallel inside the same git root.

## 11. Engineering disciplines (internal skills, not slash commands)

Load with the Skill tool when the situation applies:
`systematic-debugging` (root cause before fix), `test-driven-development`
(failing test first), `verification-before-completion` (evidence before
claims), `receiving-code-review`, `requesting-code-review`,
`dispatching-parallel-agents`, `graphify`.

`aiflow-visual` is the optional browser companion for visual questions
(mockups, diagrams, click-to-select options). It starts only after the user
agrees, never replaces a terminal answer, runs with telemetry disabled, and
its `.superpowers/` folder stays out of git.
