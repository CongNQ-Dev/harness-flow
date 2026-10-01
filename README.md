# BUMP AI Flow

One AI-driven development workflow for **bump-backend**, **bump-admin** and
**bump-mobile-app**. This repo holds only the flow. The three source repos are
cloned inside it and ignored by git, so they are never modified by this repo.

```
ai-flow-demo/                 ← this repo: the AI Flow (start Claude Code here)
├── bump-backend/             ← source repo (GitHub, not tracked here)
├── bump-admin/               ← source repo (GitHub, not tracked here)
└── bump-mobile-app/          ← source repo (GitHub, not tracked here)
```

**Visual guide:** open [`aiflow/guide.html`](aiflow/guide.html) in a browser (日本語 / English).
Full reference: [`aiflow/README.ja.md`](aiflow/README.ja.md) · [`aiflow/README.en.md`](aiflow/README.en.md)

**Want this flow on a different project?** It's not BUMP-specific — every
skill reads repo facts from `aiflow/workflow.yaml`, nothing is hard-coded.
Run [`install.sh`](install.sh) against that project; it clones this repo into
a temp dir and copies only the skill bundle, so you never clone it directly.
See "Adopting this in another project" in
[`aiflow/README.en.md`](aiflow/README.en.md).

## Quick start

```bash
git clone https://gitlab.shiftasia.com/cong.nguyen.02/ai-flow-demo.git
cd ai-flow-demo
git clone https://github.com/emole-inc/bump-backend.git
git clone https://github.com/emole-inc/bump-admin.git
git clone https://github.com/emole-inc/bump-mobile-app.git
gh auth login
claude
```

Inside Claude Code:

```text
/aiflow analyze        build the knowledge graph once (all 3 repos, ~seconds when up to date)
/aiflow PDT-2350       start or continue a ticket
```

Requirements: Claude Code, `python3`, `graphify`, `gh`, plus each repo's
toolchain (Go · Node/yarn · FVM/Flutter). Notion tickets are read via the
Notion MCP, the browser, or by pasting the ticket text.

## The one command

| You type | What happens |
|---|---|
| `/aiflow PDT-XXXX` | Runs the **next stage** of the ticket, then stops. A new ticket starts at stage 1. |
| `/aiflow` | Board of every ticket: stage, route, repos, next step |
| `/aiflow PDT-XXXX status` | Progress + time / tokens / estimated cost per stage |
| `/aiflow PDT-XXXX feature` | Start a new-development ticket (`feature/…` branch) instead of a bug fix |
| `/aiflow PDT-XXXX redo spec` | Redo a stage (`ticket` `spec` `plan` `impl` `review` `deliver`) |
| `/aiflow analyze` | Refresh the cross-repo knowledge graph |
| `/aiflow wiki` | Generate/refresh the project wiki — curated architecture docs, LLM-written, costs tokens |
| `/aiflow <PR URL>` | Review an existing PR |

Run `/aiflow PDT-XXXX` again after checking each stage's output. That's the whole loop.

Without `feature`, bug vs. feature is decided from evidence — primarily the
Notion ticket's 種別 property, then the ticket body if that's missing — not
guessed; see [`aiflow/README.en.md`](aiflow/README.en.md) § "How bug vs.
feature is decided".

## Stages

| # | Stage | You | Output in `docs/aiflow/<ID>/` | light | full |
|---|---|---|---|---|---|
| 1 | Ticket normalize: affected repos, difficulty triage, branch per repo | approve | `ticket.md` `status.md` | ✅ | ✅ |
| 2 | Spec: root cause or design | approve | `spec.md` | ✅ | ✅ |
| 3 | Fix plan: TDD tasks, one repo per task | approve | `plan.md` | — | ✅ |
| 4 | Implementation: implementer + spec review + quality review per task | — | code, `reviews/` | ✅ | ✅ |
| 5 | Final review across repos + manual test cases | — | `reviews/final-review.md` `test-cases.md` | — | ✅ |
| 6 | Delivery: tests, manual QA gate, one PR per repo | QA, approve | PR links | ✅ | ✅ |

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

**`status.md` and `log.json` are not redundant — they track different axes.**
`status.md` is *progress* (which stage is done, who approved it) and is the
only thing `/aiflow` reads to route. `log.json` is *usage* (time, tokens,
estimated cost per stage) and never feeds routing. Each answers a question
the other can't: "is light route actually cheaper than full", "which stage
costs the most" — the cost-optimization requirement from the proposal, not
something progress tracking alone could answer.

## Rules the flow keeps

- Every stage stops when it finishes. Nothing moves on without you.
- Everything under `docs/aiflow/`, plus PR text, is written in Japanese.
- Git always runs as `git -C <repo>`. It never commits to `develop`/`main` and never force-pushes.
  PRs go to each repo's own base branch (backend/admin `develop`, mobile `main`).
- While a ticket is open, **this wrapper repo and every affected repo are on
  the same ticket branch** (`bug/PDT-XXXX/…` / `feature/PDT-XXXX/…`). Ticket
  docs are committed on the wrapper's ticket branch, never on `main`; at
  delivery the wrapper gets its own docs-only PR alongside the repos' PRs.
  `/aiflow PDT-XXXX` switches back to a ticket's branches by itself; the
  `/aiflow` board shows the tickets visible on the wrapper's current branch.
- Each repo team's own guidance wins for code, e.g. bump-mobile-app's
  `CLAUDE.md`, `docs/ai/` and `bump-*` skills.
- The knowledge graph is queried before any source file is read.
