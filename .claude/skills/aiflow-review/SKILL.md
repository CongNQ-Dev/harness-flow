---
name: aiflow-review
description: AI Flow stages 5–6 — stage 5 runs a whole-change final review across every component the ticket touched (contracts, regressions) and generates test-cases.md; stage 6 runs each component's tests, gates on manual QA, pushes, and opens one DRAFT PR (GitHub, via gh) or MR (GitLab, via glab) per git root, cross-linked; then handles the CI review's comments and, only once all are handled, marks it Ready for the customer's review. Also reviews an existing PR/MR URL. Usually reached via /aiflow.
argument-hint: <TICKET-ID> | <PR/MR URL>
---

# /aiflow-review — Review & test cases (stage 5) + Delivery (stage 6)

First read `.claude/skills/aiflow/conventions.md` and `aiflow/workflow.yaml`.

## 0. Which stage?

Argument is a PR/MR URL → **Review mode** (bottom of this file).

Otherwise `python3 aiflow/scripts/aiflow_status.py <ID>`:
- `stage_done < 4` → refuse: implementation isn't done (`/aiflow <ID>`).
- `stage_done: 4`, route `full` → **Stage 5**
- `stage_done: 4`, route `light` → **Stage 6** (stage 5 is skipped on light); with `delivery: draft` → resume at **§6.5**
- `stage_done: 5` → **Stage 6**; if `status.md` says `delivery: draft`, the PRs/MRs already exist as drafts → resume at **§6.5** (skip 6.1–6.4).
- `stage_done: 6` → done; print the URLs from `prs:`.

## PR tool per git root

For each git root, the tool is its component's `pr_tool` if set — for the
**wrapper** (workspace), `workspace_repo.pr_tool` — else `pr.tool` (`gh` =
GitHub, `glab` = GitLab). If components in one git root disagree, that's a
config error — stop and say so. Before using it, check it against the
remote's host: `github.com` / a GitHub Enterprise host needs `gh`, a GitLab
host needs `glab`. A mismatch (e.g. `pr.tool: gh` on a GitLab remote) →
use the host's tool and tell the user to set `pr_tool` there. The repo identifier comes
from `git -C <root> remote get-url origin`:

- **gh:** `[HOST/]OWNER/REPO` — drop the host for github.com, keep it for
  GitHub Enterprise (`https://ghe.acme.io/team/api.git` → `ghe.acme.io/team/api`).
- **glab:** the full https URL without `.git` works for gitlab.com and
  self-hosted GitLab alike (`git@gitlab.acme.io:grp/sub/api.git` →
  `https://gitlab.acme.io/grp/sub/api`).

| Action | gh (GitHub) | glab (GitLab) |
|---|---|---|
| auth check | `gh auth status` | `glab auth status` |
| create | `gh pr create -R <repo> --base <base> --head <branch> --title "<t>" --body-file <f>` | `glab mr create -R <repo> --target-branch <base> --source-branch <branch> --title "<t>" --description "$(cat <f>)" --yes` |
| view | `gh pr view <url> --json title,body,baseRefName,headRefName,files` | `glab mr view <iid> -R <repo> -F json` |
| diff | `gh pr diff <url>` | `glab mr diff <iid> -R <repo>` |
| comment | `gh pr comment <url> --body-file <f>` | `glab mr note create <iid> -R <repo> -m "$(cat <f>)"` (glab older than ~1.60: `glab mr note <iid> -m ...`) |
| draft create | `gh pr create --draft …` (the create row + `--draft`) | `glab mr create --draft …` (the create row + `--draft`) |
| CI status | `gh pr checks <url>` | `glab mr view <iid> -R <repo>` (pipeline) / `glab ci status` |
| read comments | `gh pr view <url> --comments` (inline: `gh api repos/<o>/<r>/pulls/<n>/comments`) | `glab mr view <iid> -R <repo> --comments` |
| mark Ready | `gh pr ready <url>` | `glab mr update <iid> -R <repo> --ready` |
| edit body | `gh pr edit <url> --body-file <f>` | `glab mr update <iid> -R <repo> --description "$(cat <f>)"` |

Flags above were checked against gh 2.x and glab 1.103; if a command errors on
an older CLI, read its `--help` and adapt rather than guessing.

Auth failing → stop and tell the user the login command (`gh auth login` /
`glab auth login`). Never try to log in for them.

---

## Stage 5 — Review & test cases (full route)

`python3 aiflow/scripts/aiflow_log.py start <ID> review`

1. **Final review** — dispatch `final-reviewer-prompt.md` for every affected
   component (model `models.full.final_reviewer`, output `language`). It
   writes `reviews/final-review.md`.
   - `verdict: issues` with Critical/Important findings → dispatch an
     implementer (`.claude/skills/aiflow-impl/implementer-prompt.md`) per
     finding in the owning component, re-run that component's `test`, then
     re-run the final review, until approved. Minor findings stay listed for
     the PR.
   Optional: for a change across 2+ components, `.claude/skills/aiflow-visual/SKILL.md`
   can show what the diff touches as a component/contract diagram.
2. **Test cases** — run the `/aiflow-testgen` procedure
   (`.claude/skills/aiflow-testgen/SKILL.md` § Procedure) → `test-cases.md`.
3. **Close** — `status.md` `stage_done: 5`, `next: aiflow-review`; conventions
   §5: "Stage 5/6 (Review & test cases) done. Final review: ✅. N test cases in
   `docs/aiflow/<ID>/test-cases.md`. Next: stage 6 (Delivery) — `/aiflow <ID>`."

---

## Stage 6 — Delivery (PR / MR)

`python3 aiflow/scripts/aiflow_log.py start <ID> deliver`

### 6.1 Automated tests (fresh)

First re-run aiflow-impl §4's branch check for every affected git root
(ticket branch checked out, clean, has commits ahead of the base branch). An
empty or wrong branch would open an empty PR — stop and say so instead.

For each affected component run its `test` (and `lint`). Any failure → stop,
show it, don't continue. (On the light route this is the only automated
gate — read the output fully.)

### 6.2 Manual QA gate

Point the user at what to check: `test-cases.md` (full route) or the spec's
acceptance criteria (light route). Then `AskUserQuestion`:

- **Checked — create the PR(s) (recommended)** → 6.3. This answer is NOT
  approval to push: 6.4 asks again before every push.
- **Found a bug the tests missed** → stop. Record it in
  `reviews/qa-findings.md`; the fix goes back through TDD — a failing test
  that reproduces it (`test-driven-development`; `systematic-debugging` for
  the cause), the fix in the owning component, a full test run — then
  `/aiflow <ID>` again (still stage 6). status.md row 6: "⏳ fixing QA findings".
- **Skip — automated tests are enough** → 6.3, recording
  `approvals.deliver: human:<name> <date> (manual QA skipped)`.

### 6.3 Ticket docs in the PR

- **in-repo:** the docs are already on the ticket branch (committed each
  stage). Nothing to copy.
- **workspace**, when `pr.copy_artifacts_into_repo: true`: for each affected
  git root, copy the ticket folder (minus `log.json`) to
  `<root>/docs/aiflow/<ID>/` and commit it on the ticket branch
  (`docs(<ID>): AI Flow artifacts`).

### 6.4 Push and open one DRAFT PR/MR per git root

With `pr.draft_first: true` (default) every PR/MR is created as a **Draft** —
the customer is not asked to review until the CI review is cleared (§6.5).
`pr.draft_first: false` creates it ready and skips §6.5.

Order: the git root of a contract **owner** first, then consumers, so
consumers' PRs can link to it. **workspace** with `workspace_repo.pr: true`:
the wrapper is one more git root — push its ticket branch last and open a
docs-only PR/MR into `workspace_repo.base_branch` (Changes = "AI Flow
ticket docs only"), linked with the others under Related.

**Before each push**, `AskUserQuestion` (conventions §3): "Push `<branch>` of
`<root>` to `origin`?" — repo, branch, remote named. Push only on a clear yes;
on no, stop and report. Ask again for every root and every later re-push.

```bash
git -C <root> push -u origin <branch>
```

Then, **before the "create" command** (table above; `--draft`), `AskUserQuestion` again
(conventions §3): show the title, base ← head and the full body, and create the
PR/MR only on a clear yes. Same for every later write to the host — editing the
"Related" line, posting the review comment: show it, ask, then do it.

Title: `pr.title` — it **must contain the task ID** (e.g. `[PROJ-123] …`) so
the PR links to the ticket in Notion. Body: the team's PR template, headings
kept **exactly as below (Vietnamese, never translated)**, content in `language`:

```markdown
### Tổng quan
### Ảnh chụp màn hình (nếu có thay đổi UI)
### Điểm cần trao đổi (nếu có)
### Các bước kiểm tra (đã kiểm tra thế nào để người review làm lại được)
```

- **Tổng quan** — what this PR changes and why: 2–3 bullets from the spec, this git
  root's components only. Then one line each for **Related PRs/MRs** (the
  other roots' links for this ticket, or "none") and **Artifacts** (spec.md,
  plan.md, reviews/final-review.md — in this branch for in-repo / copied
  docs, or the wrapper's PR/MR for workspace without copying).
- **Ảnh chụp màn hình** — before/after images when the UI changed; otherwise
  write "Không thay đổi UI" (or the `language` equivalent). Never invent images.
- **Điểm cần trao đổi** — points to ask the reviewer: open questions, trade-offs, the
  final review's Minor findings. Omit the content (keep the heading, "Không có")
  if there are none.
- **Các bước kiểm tra** — how it was actually verified, so the reviewer can redo
  it: device/environment, numbered steps, result. Take it from the TC list in
  `test-cases.md` and the manual-QA result (light route: the acceptance
  criteria and what was checked). Say honestly what was not verified.

Once every PR/MR exists, propose editing the earlier ones' "Related" line so
each links to all the others — ask before each edit.

If `pr.post_review_comment: true` and a final review exists, **offer** to post
its "Summary for PR reviewers" plus the Minor findings as one comment per PR/MR
— show the text and ask before each post.

### 6.5 CI review → fix → Ready (when `pr.draft_first: true`)

Flow: **Draft PR/MR → CI review runs → every CI comment handled → Ready for
review → customer reviews.** Right after 6.4 set `status.md` `delivery: draft`
and `prs:` (url + `draft`), leave `stage_done` as it is (5 full / 4 light), commit the ticket folder, and
stop: "Draft PRs created. The CI review is running — run `/aiflow <ID>` when
it has finished." Every later run resumes here:

1. **Read CI state** (read-only, no confirmation): `CI status` and `read
   comments` for each PR/MR. Checks still running → say so and stop; never
   poll or sleep-loop.
2. **List the CI review's comments** (the bot's/reviewer's, not yours) in
   `reviews/ci-review.md` with each comment's author (conventions §6 —
   name the reviewer), file:line and its handling. Nothing found and checks
   green → go to step 5.
3. **Handle every comment** — one of: **fix** (a code change goes back through
   the normal TDD task path of the owning component, committed on the ticket
   branch; a docs/wording fix likewise), **answer** (the comment is wrong or
   out of scope — write the reason), or **ask the user** when it's a judgment
   call. Never ignore or silently dismiss one. If a fix changes the spec or a
   contract, say so and stop for the user.
4. **Push the fixes** — `AskUserQuestion` per push (conventions §3). Replies,
   thread resolution or a new comment are also host writes: show the text and
   ask first. Then back to step 1 (CI re-runs on the new commit); repeat until
   no open CI comment is left and checks are green.
5. **Mark Ready** — only when every CI comment is fixed or answered and checks
   are green: `AskUserQuestion` "Mark `<PR/MR>` of `<root>` Ready for
   review?" (action, target, a summary of how each CI comment was handled).
   Mark Ready only on a clear yes, one root at a time; the user can say "not
   yet". Never mark Ready while a CI comment is open unless the user asks for
   exactly that in chat.
6. Ready → `delivery: ready`, then §6.6. The customer now reviews; their
   comments are handled the same way (steps 3–4) when the user runs
   `/aiflow <ID>` again, and the PR/MR stays Ready — back to Draft only if
   the user asks.

### 6.6 Close — last stage (after every PR/MR is Ready, or right after 6.4 when `pr.draft_first: false`)

`status.md`: `stage_done: 6`, `next: done`, `delivery: ready`, `prs:` one line per git root
(`<component or root name>: <url>`), `approvals.deliver`, row 6 done with the
URLs. Commit the ticket folder (conventions §3), then
`python3 aiflow/scripts/aiflow_log.py end <ID> deliver`, and announce:
"Stage 6/6 (Delivery) done. PRs are Ready for review: <urls>. This ticket's pipeline is complete."

Also show `python3 aiflow/scripts/aiflow_log.py summary <ID>` (time / tokens
/ estimated cost per stage) — the data for tuning the triage thresholds.

---

## Review mode — `/aiflow <PR/MR URL>`

For a PR/MR that didn't come through this flow (or to re-review one that did):

1. Pick the tool from the URL's host (the table above), then `view` and
   `diff` it. Find a ticket ID in the title (`[ABC-123]`); if
   `docs/aiflow/<ID>/spec.md` exists, use it as the requirements, otherwise
   the PR/MR description.
2. Dispatch `final-reviewer-prompt.md` with that diff as "the change". Write
   to `docs/aiflow/<ID>/reviews/pr-review-<component>-<number>.md`, or show
   it in chat when there's no ticket ID.
3. Show the summary and ask with `AskUserQuestion` whether to post it as a
   comment. Post only on yes. Never approve, request changes, or merge.
