# Basic AI Flow — guide

English · [日本語](README.ja.md) · Visual version: [guide.en.html](guide.en.html)

One AI-driven workflow for **backend** (Go), **admin** (Next.js) and
**mobile-app** (Flutter). Start Claude Code in the workspace root
(`ai-flow-demo`), not inside a repo. It runs one stage at a time and always
stops for you.

## The one command

| You type | What happens |
|---|---|
| `/aiflow PROJ-XXXX` | Runs the **next stage** of the ticket, then stops. A new ticket starts at stage 1. |
| `/aiflow` | Board of every ticket: stage, route, repos, next step |
| `/aiflow PROJ-XXXX status` | Progress, plus time / tokens / estimated cost per stage |
| `/aiflow PROJ-XXXX feature` | New-development ticket (`feature/…` branch) instead of a bug fix |
| `/aiflow PROJ-XXXX redo <stage>` | Redo a stage (`ticket` `spec` `plan` `impl` `review` `deliver`) |
| `/aiflow analyze` | Refresh the cross-repo knowledge graph (free) |
| `/aiflow wiki` | Write/refresh the project wiki (LLM, costs tokens) |
| `/aiflow <PR/MR URL>` | Review an existing PR/MR |

## Stages

| # | Stage | You | Output in `docs/aiflow/<ID>/` | light | full |
|---|---|---|---|---|---|
| 1 | Ticket: read Notion, bug vs feature, affected repos, triage, branch | approve | `ticket.md` `status.md` | ✅ | ✅ |
| 2 | Spec: root cause or design | approve | `spec.md` | ✅ | ✅ |
| 3 | Plan: TDD tasks, one repo per task | approve | `plan.md` | — | ✅ |
| 4 | Implementation: implementer + spec review + quality review per task | — | code, `reviews/` | ✅ | ✅ |
| 5 | Final review across repos + manual test cases | — | `reviews/final-review.md` `test-cases.md` | — | ✅ |
| 6 | Delivery: tests, manual QA gate, one **Draft** PR/MR per git root, CI-review fixes, then Ready | QA, approve | PR/MR links | ✅ | ✅ |

**light** (1→2→4→6) only when: one repo, 3 files or fewer, no API/schema/DB
change, root cause located, it is a bug, and not a sensitive area (billing,
auth, migration). Stages 1 and 2 then run in one turn with one approval.
Everything else is **full**. The route is only ever upgraded, never silently
downgraded. `status.md` is the resume point (progress); `log.json` is usage
(time, tokens, cost) and never affects routing.

## Mandatory rules

1. **Never push directly to `main`.** Changes reach a base branch only through
   a PR/MR. No commits on `develop`/`main`, no force-push. Never commit secrets (keys, tokens, `.env*`).
2. **Every write to GitHub/GitLab asks first.** `git push`, creating or editing
   a PR/MR, posting a comment: the agent shows the action, target and exact
   text, and acts only on a clear yes. An earlier approval, the QA answer or a
   config flag never covers a later write. It never merges, approves or closes
   a PR/MR on its own; merging happens only when you ask in chat.
3. **Name the reviewer.** Every review and approval records `human:<name>` or
   `ai:<role> (<model>)` in `reviews/*.md`, the `status.md` approvals and PR/MR
   comments.
4. **One ticket branch everywhere.** While a ticket is open, the wrapper and
   every affected repo are on the same `bug/PROJ-XXXX/…` or
   `feature/PROJ-XXXX/…` branch.

## PR/MR template

The title carries the task ID, e.g. `[PROJ-123] …`, so the PR links to the
Notion task. The body keeps the team headings in Japanese:

| Heading | Content |
|---|---|
| 概要 | What this PR changes and why; links to related PRs and the spec/plan/review |
| スクリーンショット（UIの変更があれば） | Before/after images if the UI changed, otherwise say there is no UI change |
| 相談項目（あれば） | Points to ask the reviewer, incl. Minor findings; "なし" if none |
| 動作確認手順 | How it was verified so the reviewer can repeat it: device, steps, result; say what was not tested |

## Delivery order (stage 6)

**Draft PR/MR → CI review runs → every CI comment handled → Ready for review →
customer reviews.**

1. Run each repo's tests.
2. QA gate: "checked, create the PRs" — this is **not** consent to push.
3. Confirm → push `<branch>` of `<repo>` to `origin`.
4. Confirm → create the PR/MR **as a Draft** (title, base ← head and full body
   shown). The flow stops; `status.md` says `delivery: draft`.
5. When the CI review has finished, run `/aiflow <ID>` again. The agent reads the
   CI comments and checks (read-only), writes them to `reviews/ci-review.md` with
   the reviewer's name, and fixes or answers each one. Each push, reply or
   resolve asks you first. Repeat until no CI comment is open and checks are green.
6. Confirm → mark the PR/MR **Ready for review** (never while a CI comment is
   open). `delivery: ready`; the customer reviews, and their comments are
   handled the same way on the next `/aiflow <ID>`.
7. Merge only when you ask for it in chat.

Each repo — the wrapper included — uses `gh` (GitHub) or `glab` (GitLab),
whichever host was chosen for it in `/aiflow setup` (`pr.tool` / `pr_tool` in
`aiflow/workflow.yaml`). Bases: backend/admin `develop`, mobile and wrapper `main`.

## Updating the flow

Skills and rules come from the generic
`harness-ai-flow`
bundle. Change them there (with its README), then re-install here with
`install.sh --force`; edits under `.claude/skills/` get overwritten.

Optional: `aiflow-visual` is a browser companion (local page for mockups and
diagrams); stages offer it only for visual questions and only after you agree.
Telemetry is off; keep `.superpowers/` out of git.
Project-specific settings live only in `aiflow/workflow.yaml`.
