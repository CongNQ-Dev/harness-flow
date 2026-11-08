# Basic AI Flow

English · [日本語](README.ja.md)

One AI-driven development workflow for **backend**, **admin** and
**mobile-app**. This repo holds only the flow. The three source repos are
cloned inside it and ignored by git, so they are never modified by this repo.

```
ai-flow-demo/                 ← this repo: the AI Flow (start Claude Code here)
├── backend/             ← source repo (GitHub, not tracked here)
├── admin/               ← source repo (GitHub, not tracked here)
└── mobile-app/          ← source repo (GitHub, not tracked here)
```

The flow itself is the generic
`harness-ai-flow`
bundle, installed here; everything project-specific lives in
`aiflow/workflow.yaml`. Its README is the full reference, including how to
install the flow on another project and how to upgrade this one (re-install
with `--force`).

## Quick start

```bash
git clone https://github.com/cong-skills/basic-ai-flow.git
cd basic-ai-flow
git clone https://github.com/<your-org>/backend.git
git clone https://github.com/<your-org>/admin.git
git clone https://github.com/<your-org>/mobile-app.git
gh auth login      # if a repo is on GitHub  ─┐ log in to the CLI for the host
glab auth login    # if a repo is on GitLab  ─┘ you pick in /aiflow setup
claude
```

Inside Claude Code:

```text
/aiflow analyze        build the knowledge graph once (all 3 repos, ~seconds when up to date)
/aiflow PROJ-123       start or continue a ticket
```

Requirements: Claude Code, `python3`, `graphify`, `gh` and/or `glab` (for the host
you choose in `/aiflow setup` — GitHub or GitLab), plus each repo's
toolchain (Go · Node/yarn · FVM/Flutter). Notion tickets are read via the
Notion MCP, the browser, or by pasting the ticket text.

## The one command

| You type | What happens |
|---|---|
| `/aiflow PROJ-XXXX` | Runs the **next stage** of the ticket, then stops. A new ticket starts at stage 1. |
| `/aiflow` | Board of every ticket: stage, route, repos, next step |
| `/aiflow PROJ-XXXX status` | Progress + time / tokens / estimated cost per stage |
| `/aiflow PROJ-XXXX feature` | Start a new-development ticket (`feature/…` branch) instead of a bug fix |
| `/aiflow PROJ-XXXX redo spec` | Redo a stage (`ticket` `spec` `plan` `impl` `review` `deliver`) |
| `/aiflow analyze` | Refresh the cross-repo knowledge graph |
| `/aiflow wiki` | Generate/refresh the project wiki — curated architecture docs, LLM-written, costs tokens |
| `/aiflow <PR URL>` | Review an existing PR |

Run `/aiflow PROJ-XXXX` again after checking each stage's output. That's the whole loop.

Without `feature`, bug vs. feature is decided from evidence — primarily the
Notion ticket's 種別 property, then the ticket body if that's missing — not
guessed (the evidence order is in the `aiflow-spec` skill, §1.2).

## Stages

| # | Stage | You | Output in `docs/aiflow/<ID>/` | light | full |
|---|---|---|---|---|---|
| 1 | Ticket normalize: affected repos, difficulty triage, branch per repo | approve | `ticket.md` `status.md` | ✅ | ✅ |
| 2 | Spec: root cause or design | approve | `spec.md` | ✅ | ✅ |
| 3 | Fix plan: TDD tasks, one repo per task | approve | `plan.md` | — | ✅ |
| 4 | Implementation: implementer + spec review + quality review per task | — | code, `reviews/` | ✅ | ✅ |
| 5 | Final review across repos + manual test cases | — | `reviews/final-review.md` `test-cases.md` | — | ✅ |
| 6 | Delivery: tests, manual QA gate, one Draft PR per repo, CI-review fixes, then Ready | QA, approve | PR links | ✅ | ✅ |

On light route (a small bug), stages 1 and 2 run as **one** turn, not two:
`/aiflow-spec` triages, investigates, and writes `spec.md` inline right after,
behind a single combined approval — no separate dialogue stop. That's a
fast-track (triage + fix write-up as one step), not "the same dialogue, just
also gated on stage 1." Full route, and any non-bug ticket, always gets the
real stage-2 dialogue separately. Stages 5 and 6 are two sections of one
`aiflow-review` skill file, not two runs of the same procedure — light skips
only stage 5's section.

**light** (1→2→4→6) is used only when the ticket touches one repo, 3 files or
fewer, no API/schema/DB change, the root cause is located, it is a bug, and it
is not in a sensitive area (billing, auth, migration). Everything else runs
**full**. You confirm the route. The rules are in
[`aiflow/workflow.yaml`](aiflow/workflow.yaml).

## What's in this repo

| Path | Purpose |
|---|---|
| `CLAUDE.md` | Workspace rules Claude Code loads on start |
| `.claude/skills/aiflow*/` | The flow: router `aiflow` plus the stage skills, their templates and subagent prompts |
| `.claude/skills/*` (others) | Engineering disciplines used internally (TDD, debugging, verification, code review), hidden from the `/` menu |
| `.claude/settings.json` | Hooks: knowledge-graph reminder, usage logging |
| `aiflow/workflow.yaml` | **The config**: repos, base branches, test commands, cross-repo contracts, triage rules, models |
| `aiflow/scripts/` | `aiflow_status.py` (board and next stage) · `aiflow_log.py` (usage log) · `kg_build.py` (knowledge graph) |
| `aiflow/pricing.json` | Prices used for cost estimates |
| `aiflow/selected-bugs/` | Notion ticket lists |
| `wiki/` | Curated architecture docs, generated by `/aiflow-wiki` — see `aiflow-wiki/SKILL.md` |
| `docs/aiflow/<ID>/status.md` | One per ticket. Resume point — the only file `/aiflow` reads to decide what runs next |
| `docs/aiflow/<ID>/log.json` | One per ticket. Usage per stage — time, tokens, estimated cost |

Only `aiflow-` prefixed skills are stages (`/aiflow` invokes them). The rest
are deliberately unprefixed, generic engineering-discipline skills each stage
loads internally by situation (their `description` starts with "Use when…",
the standard auto-trigger convention) — `user-invocable: false` keeps them
out of the `/` menu and out of any collision with `/aiflow-*`. You never
invoke one directly.

`aiflow-visual` is the one `aiflow-` skill that is not a stage: an optional
browser companion (a local page with mockups, diagrams and click-to-select
options). Stages offer it only for visual questions, only after you agree;
telemetry is off and its `.superpowers/` folder must stay out of git.

**`status.md` and `log.json` are not redundant — they track different axes.**
`status.md` is *progress* (which stage is done, who approved it) and is the
only thing `/aiflow` reads to route. `log.json` is *usage* (time, tokens,
estimated cost per stage) and never feeds routing. Each answers a question
the other can't: "is light route actually cheaper than full", "which stage
costs the most" — the cost-optimization requirement from the proposal, not
something progress tracking alone could answer.

## Rules the flow keeps

**Stages**
- Every stage stops when it finishes. Nothing moves on without you.
- Everything under `docs/aiflow/`, plus PR text, is written in
  `workflow.yaml` `language:` (currently `en`).
- The knowledge graph is queried before any source file is read.
- Each repo team's own guidance wins for code, e.g. mobile-app's
  `CLAUDE.md`, `docs/ai/` and project-specific skills.

**Git and branches**
- Git always runs as `git -C <repo>`. It never commits to `develop`/`main`,
  never pushes directly to `main` (PR/MR only) and never force-pushes.
- **Never commits or pushes secrets.** API keys, tokens, passwords, private
  keys, `.env*` and credentials files are never staged: files are added by
  explicit path, `git diff --cached` is read before every commit, and the agent
  stops and warns if anything looks sensitive. Ticket docs use placeholders.
- While a ticket is open, **this wrapper repo and every affected repo are on
  the same ticket branch** (`bug/PROJ-XXXX/…` / `feature/PROJ-XXXX/…`). Ticket
  docs are committed on the wrapper's ticket branch, never on `main`; at
  delivery the wrapper gets its own docs-only MR alongside the repos' PRs.
  `/aiflow PROJ-XXXX` switches back to a ticket's branches by itself; the
  `/aiflow` board shows the tickets visible on the wrapper's current branch.
- PRs go to each repo's own base branch (backend/admin `develop`, mobile
  `main`). The wrapper's PR/MR goes to this repo's `main`. Each
  repo uses `gh` (GitHub) or `glab` (GitLab) — whichever host you chose for it
  in `/aiflow setup` (`pr.tool` / `pr_tool` in `aiflow/workflow.yaml`).

**Delivery (stage 6) — nothing is automatic**
- Every write to GitHub/GitLab — `git push`, creating or editing a PR/MR,
  posting a comment — asks for a fresh confirmation (action, target, text).
  An earlier approval, the QA answer or a config flag never covers it. The
  flow never merges, approves or closes a PR/MR on its own; merging happens
  only when you ask for it in chat.
- **Draft → CI review → Ready → customer.** PRs/MRs open as **Draft**; the CI
  review runs; every CI comment is fixed or answered (each push asks you);
  only then, after asking you, the PR/MR is marked **Ready for review** and the
  customer reviews. Run `/aiflow PROJ-XXXX` again after the CI review finishes
  (`delivery:` in `status.md`: `draft` → `ready`). Never Ready with open CI comments.
- PR/MR titles carry the task ID (e.g. `[PROJ-123]`). Bodies keep the team
  template headings in Japanese: 概要 / スクリーンショット / 相談項目 / 動作確認手順.
- Every review and approval records the reviewer's name — `human:<name>` or
  `ai:<role> (<model>)` in `reviews/*.md`, `status.md` approvals and PR comments.

The flow's own rules live in the generic harness-ai-flow bundle
(`conventions.md`, `aiflow/AIFLOW.md`); to pick up changes, re-install with
`--force` (see the Quick start). Guides in English and Japanese: [aiflow/README.en.md](aiflow/README.en.md) · [aiflow/README.ja.md](aiflow/README.ja.md); visual versions: [aiflow/guide.en.html](aiflow/guide.en.html) · [aiflow/guide.ja.html](aiflow/guide.ja.html).
