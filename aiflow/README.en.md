# AI Flow — workspace guide (backend · admin · mobile)

One AI-driven workflow that runs across **bump-backend, bump-admin and
bump-mobile-app** from this workspace. It keeps the 6-stage flow from the free
trial and adds what the proposal asks for: a cross-project knowledge graph,
triage into a light or full route, a usage log per ticket, and one PR per repo
for cross-repo tickets.

## You only need one command

```text
/aiflow PDT-2350          run the next stage of PDT-2350 (a new ticket starts at stage 1)
/aiflow                   board of every ticket
```

Occasionally useful: `/aiflow PDT-2350 status` · `/aiflow PDT-2350 redo spec` ·
`/aiflow PDT-2350 feature` (new/maintenance development) · `/aiflow analyze` ·
`/aiflow <PR URL>` (review an existing PR).

Every stage stops when it finishes. Read the output, then type `/aiflow PDT-2350` again.

## Stages

| # | Stage | Run by | Output (`docs/aiflow/<ID>/`) | Human | light | full |
|---|---|---|---|---|---|---|
| 1 | Ticket normalize: affected repos, triage, branches | `/aiflow-spec` | `ticket.md`, `status.md` | approve | ✅ | ✅ |
| 2 | Spec: root cause / design | `/aiflow-spec` | `spec.md` | approve | ✅ | ✅ |
| 3 | Fix plan (tasks, one repo each) | `/aiflow-plan` | `plan.md` | approve | — | ✅ |
| 4 | Implementation (TDD + 2 reviews per task) | `/aiflow-impl` | code, `reviews/task*.md` | — | ✅ | ✅ |
| 5 | Final review across repos + test cases | `/aiflow-review` + `/aiflow-testgen` | `reviews/final-review.md`, `test-cases.md` | — | — | ✅ |
| 6 | Delivery: tests, manual QA gate, PR per repo | `/aiflow-review` | PR URLs in `status.md` | QA / approve | ✅ | ✅ |

`log.json` (time, tokens and estimated cost per stage) is written automatically.

**Triage (難易度判断).** At the end of stage 1 the ticket is checked against
`triage.light_requires_all` in `aiflow/workflow.yaml`: one repo, 3 files or
fewer, no API/schema/DB/contract change, root cause located, a bug rather than
a feature, no sensitive area. All ✅ → **light** (1→2→4→6, cheaper model).
Anything else → **full**. You confirm the route. If stage 2 finds more
complexity, the route is upgraded to full automatically. It is never
downgraded without asking.

**Bug vs. new development.** Only the entry point differs. A feature ticket
gets a `feature/<ID>/<slug>` branch and a design-style spec (background and
purpose instead of root cause). Stages 2–6 are the same.

## Cross-repo tickets

- Stage 1 decides which repos are affected, with evidence from the knowledge
  graph and the contracts in `workflow.yaml` (backend swagger → admin client,
  backend GraphQL → app). This covers the case where a fix needs both sides,
  e.g. PDT-1107 (admin + backend) and PDT-1136 (backend + app header).
- The same branch name is created in every affected repo.
- `plan.md` gives each task exactly one repo, contract owner first, and
  regenerates the client code explicitly.
- Stage 5 reviews the whole change across repos, checking contracts, backward
  compatibility and callers.
- Stage 6 opens one PR per repo against that repo's base branch (backend/admin
  `develop`, mobile `main`). The PRs link to each other, and the ticket docs are
  copied into each PR, so acceptance is still "read the md files".

## Knowledge graph

`/aiflow analyze` runs `aiflow/scripts/kg_build.py`, which:

1. updates each repo's graphify graph (AST only, no LLM cost);
2. merges them into `graphify-out/graph.json`, with nodes tagged by repo;
3. links distinctive type names that exist in more than one repo.

`/aiflow analyze docs` also adds design documents (this step uses tokens, so it
asks first). All stages query the graph before reading files.

## Setup (once per machine)

```bash
git clone <this workspace repo> ai-flow-demo && cd ai-flow-demo
git clone https://github.com/emole-inc/bump-backend.git
git clone https://github.com/emole-inc/bump-admin.git
git clone https://github.com/emole-inc/bump-mobile-app.git
gh auth login            # PR creation
claude                   # then: /aiflow analyze
```

Needs: `python3`, `graphify`, `gh`, and each repo's toolchain (Go, Node/yarn,
FVM/Flutter). Notion is read through the Notion MCP, the browser, or pasted text.

## Where things are

| Path | What |
|---|---|
| `aiflow/workflow.yaml` | Repos, base branches, test commands, contracts, triage rules, models. Edit here. |
| `aiflow/pricing.json` | Prices used for the cost estimate in `log.json` |
| `aiflow/scripts/` | `aiflow_status.py` (board and next stage) · `aiflow_log.py` (usage log hook) · `kg_build.py` (knowledge graph) |
| `.claude/skills/aiflow*/` | The stage skills and their templates (`ticket-template.md`, `spec-template.md`, `plan-template.md`, subagent prompts) |
| `.claude/skills/aiflow/conventions.md` | Rules every stage follows: stop after each stage, gates, git, language |
| `.claude/skills/{test-driven-development,systematic-debugging,…}` | Engineering disciplines the stages load internally (hidden from the `/` menu) |
| `docs/aiflow/<ID>/` | One folder per ticket; `status.md` is the resume point |
| `aiflow/selected-bugs/` | Notion ticket lists (ticket ID → Notion URL) |

## Picking up someone else's ticket

Run `/aiflow PDT-XXXX`. The flow reads `docs/aiflow/PDT-XXXX/status.md` and
continues from there, and no chat history is needed. To read it yourself:
`status.md` → `ticket.md` → `spec.md` → `plan.md` → `reviews/` → the branch in each repo.

## What changed from the trial flow

| Trial (per repo) | Now (workspace) |
|---|---|
| Separate copy of the flow in each repo; one graph per repo | One flow for all 3 repos; one merged graph with cross-repo links |
| About 17 skills in the `/` menu; names to remember per stage | `/aiflow`, plus 6 `aiflow-*` stage commands that nobody has to remember. Discipline skills are hidden. |
| Always the full 6 stages | Triage: light (1-2-4-6) or full route, with the model chosen per route |
| PR base hard-coded to `main` (wrong for admin/backend) | Base per repo from `workflow.yaml` |
| No usage data | `log.json` per ticket: time, tokens, estimated cost per stage |
| Bug tickets only | Bug and feature entry points; stages 2–6 are shared |
| Status table for humans only | `status.md` frontmatter is machine-readable, so `/aiflow` routes automatically |

**One flow, no copies in the repos.** The trial's per-repo flow was removed
from all three repos. The repos now sit on their base branches (`develop` /
`main`), and the graphify git hooks the trial installed in bump-mobile-app were
uninstalled. The trial tickets (PDT-1107, PDT-1136, PDT-1419) were migrated to
`docs/aiflow/` here, marked `legacy: true`, so the board and the duplicate
check still see them. The Notion ticket lists moved to `aiflow/selected-bugs/`.

What stays in the repos is the repo teams' own material, e.g. bump-mobile-app's
`CLAUDE.md`, `docs/ai/`, and `.claude/skills/bump-*`. The flow reads it
(`workflow.yaml` `guides:` / `repo_skills:`) and follows it when writing code
and tests.
