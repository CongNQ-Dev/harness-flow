---
name: aiflow-review
description: AI Flow stages 5–6 — stage 5 runs a whole-change final review across every repo the ticket touched (contracts, regressions) and generates test-cases.md; stage 6 runs each repo's tests, gates on manual QA, copies the ticket docs into each repo, pushes, and opens one PR per repo (cross-linked) with the review summary as a PR comment. Also reviews an existing PR URL. Usually reached via /aiflow.
argument-hint: <TICKET-ID> | <PR-URL>
---

# /aiflow-review — レビュー・テストケース作成（ステージ5）+ 納品（ステージ6）

First read `.claude/skills/aiflow/conventions.md` and `aiflow/workflow.yaml`.

## 0. Which stage?

Argument is a GitHub PR URL → **PR mode** (bottom of this file).

Otherwise `python3 aiflow/scripts/aiflow_status.py <ID>`:
- `stage_done < 4` → refuse: implementation is not done (`/aiflow <ID>`).
- `stage_done: 4`, route `full` → **Stage 5**
- `stage_done: 4`, route `light` → **Stage 6** (stage 5 is skipped on light)
- `stage_done: 5` → **Stage 6**
- `stage_done: 6` → done; print the PR URLs from `prs:`.

---

## Stage 5 — レビュー・テストケース作成 (full route)

`python3 aiflow/scripts/aiflow_log.py start <ID> review`

1. **Final review** — dispatch `final-reviewer-prompt.md` for all repos in
   `repos`. It writes `reviews/final-review.md`.
   - `verdict: issues` with Critical/Important findings → dispatch an
     implementer (`.claude/skills/aiflow-impl/implementer-prompt.md`) per
     finding in the owning repo, re-run that repo's `test`, then re-run the
     final review. Repeat until approved. Minor findings stay listed for the PR.
2. **Test cases** — run the `/aiflow-testgen` procedure
   (`.claude/skills/aiflow-testgen/SKILL.md` § Procedure) → `test-cases.md`.
3. **Close** — status.md `stage_done: 5`, `next: aiflow-review`; conventions §4:
   > 「ステージ5/6（レビュー・テストケース作成）完了。最終レビュー: ✅。テストケース N件: `docs/aiflow/<ID>/test-cases.md`。次: ステージ6（納品・PR作成）— `/aiflow <ID>`」

---

## Stage 6 — 納品（PR作成）

`python3 aiflow/scripts/aiflow_log.py start <ID> deliver`

### 6.1 Automated tests (fresh)

For each repo in `repos`, run its `test` command from `workflow.yaml` (and
`lint`). Any failure → stop, show the failures, do not continue. (Light route:
this is the only automated gate, so read the output fully.)

### 6.2 Manual QA gate

Point the user at the checks to run: `test-cases.md` (full route) or the
受け入れ基準 in spec.md (light route). Then `AskUserQuestion`:

- **確認OK — PRを作成する（推奨）** → 6.3. This answer is the approval to push
  and open PRs.
- **不具合あり — テストで検出できていない** → stop. Write down what the user
  found in `reviews/qa-findings.md`; the fix goes back through TDD: a failing
  test reproducing it (`test-driven-development`, root cause with
  `systematic-debugging`), fix in the owning repo, full test run, then re-run
  `/aiflow <ID>` (still stage 6). Set status.md row 6 to `⏳ QA指摘対応中`.
- **スキップ — 自動テストで十分** → 6.3 (record `approvals.deliver: human:<name> <date> (manual QA skipped)`).

### 6.3 Put the docs into each repo branch

When `pr.copy_artifacts_into_repo: true`: for each repo, copy the ticket folder
(minus `log.json`) to `<repo>/docs/aiflow/<ID>/` and commit it on the ticket
branch: `git -C <repo> add docs/aiflow/<ID> && git -C <repo> commit -m "docs(<ID>): AI Flow 成果物"`.
Reviewers accept by reading these md files in the PR.

### 6.4 Push and open one PR per repo

Order: the contract owner repo first (`workflow.yaml` contracts[].owner — e.g. this
project's backend), then consumers, so consumer PRs can link to it.

```bash
git -C <repo> push -u origin <branch>
gh pr create -R emole-inc/<repo> --base <base_branch> --head <branch> \
  --title "[<ID>] <日本語タイトル>" --body-file <tmp body file>
```

Body (Japanese), in this order: `## 概要` (2–3 bullets from spec) ·
`## 変更内容`（このリポジトリ分） · `## 関連PR`（the other repos' PRs for this
ticket, or 「なし」） · `## 成果物`（links to `docs/aiflow/<ID>/spec.md`, `plan.md`,
`reviews/final-review.md` in this branch） · `## テスト計画` (the TC list from
test-cases.md, or the acceptance criteria on light). After all PRs exist, edit
the earlier PRs' `## 関連PR` with `gh pr edit` so every PR links to every other.

If `pr.post_review_comment: true` and a final review exists, post its
「PRレビュアー向け要約」 plus Minor findings as one comment per PR
(`gh pr comment <url> --body-file ...`).

### 6.5 Close — terminal stage

status.md: `stage_done: 6`, `next: done`, `prs:` one line per repo
(`bump-backend: https://...`), `approvals.deliver`, row 6 `✅ 完了` with the
URLs. Commit the workspace ticket folder, then
`python3 aiflow/scripts/aiflow_log.py end <ID> deliver` and announce:

> 「ステージ6/6（納品・PR作成）完了。PR: <urls>。このチケットのパイプラインは完了です。」

Also show `python3 aiflow/scripts/aiflow_log.py summary <ID>` (time / tokens /
estimated cost per stage) — this is the data used to tune the triage thresholds.

---

## PR mode — `/aiflow-review <PR-URL>`

For a PR that did not come through this flow (or to re-review one that did):

1. `gh pr view <url> --json title,body,baseRefName,headRefName,files` and
   `gh pr diff <url>`. Find the ticket ID in the title (`[PDT-XXXX]`); if
   `docs/aiflow/<ID>/spec.md` exists, use it as the requirements, otherwise the
   PR description.
2. Dispatch `final-reviewer-prompt.md` with the PR diff as "the change".
   Write to `docs/aiflow/<ID>/reviews/pr-review-<repo>-<number>.md` (or show
   it in chat when there is no ticket ID).
3. Show the summary and ask with `AskUserQuestion` whether to post it as a PR
   comment. Post only on yes. Never approve, request changes, or merge.
