---
name: aiflow-review
description: AI Flow stages 5–6 — stage 5 runs a whole-change final review across every component the ticket touched (contracts, regressions) and generates test-cases.md; stage 6 runs each component's tests, gates on manual QA, pushes, and opens one PR (GitHub, via gh) or MR (GitLab, via glab) per git root, cross-linked, with the review summary as a comment. Also reviews an existing PR/MR URL. Usually reached via /aiflow.
argument-hint: <TICKET-ID> | <PR/MR URL>
---

# /aiflow-review — Review & test cases (stage 5) + Delivery (stage 6)

First read `.claude/skills/aiflow/conventions.md` and `aiflow/workflow.yaml`.

## 0. Which stage?

Argument is a PR/MR URL → **Review mode** (bottom of this file).

Otherwise `python3 aiflow/scripts/aiflow_status.py <ID>`:
- `stage_done < 4` → refuse: implementation isn't done (`/aiflow <ID>`).
- `stage_done: 4`, route `full` → **Stage 5**
- `stage_done: 4`, route `light` → **Stage 6** (stage 5 is skipped on light)
- `stage_done: 5` → **Stage 6**
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

- **Checked — create the PR(s) (recommended)** → 6.3. This answer is the
  approval to push and open PRs/MRs.
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

### 6.4 Push and open one PR/MR per git root

Order: the git root of a contract **owner** first, then consumers, so
consumers' PRs can link to it. **workspace** with `workspace_repo.pr: true`:
the wrapper is one more git root — push its ticket branch last and open a
docs-only PR/MR into `workspace_repo.base_branch` (Changes = "AI Flow
ticket docs only"), linked with the others under Related.

```bash
git -C <root> push -u origin <branch>
# then the "create" command for that root's tool (table above)
```

Title: `pr.title` with `<TICKET-ID>` and a title in `language`. Body (in
`language`), in this order: **Summary** (2–3 bullets from the spec) ·
**Changes** (this git root's components only) · **Related PRs/MRs** (the
other roots' links for this ticket, or "none") · **Artifacts** (links to
spec.md, plan.md, reviews/final-review.md — in this branch for in-repo /
copied docs, or the wrapper's PR/MR for workspace without copying) ·
**Test plan** (the TC list from test-cases.md, or the acceptance criteria on
light). Once every PR/MR exists, edit the earlier ones' "Related" section so
each links to all the others.

If `pr.post_review_comment: true` and a final review exists, post its
"Summary for PR reviewers" plus the Minor findings as one comment per PR/MR.

### 6.5 Close — last stage

`status.md`: `stage_done: 6`, `next: done`, `prs:` one line per git root
(`<component or root name>: <url>`), `approvals.deliver`, row 6 done with the
URLs. Commit the ticket folder (conventions §3), then
`python3 aiflow/scripts/aiflow_log.py end <ID> deliver`, and announce:
"Stage 6/6 (Delivery) done. PRs: <urls>. This ticket's pipeline is complete."

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
