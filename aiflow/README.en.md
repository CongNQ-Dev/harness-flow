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
`/aiflow wiki` (generate/refresh the project wiki) ·
`/aiflow <PR URL>` (review an existing PR).

Every stage stops when it finishes. Read the output, then type `/aiflow PDT-2350` again.

## Stages

| # | Stage | Run by | Output (`docs/aiflow/<ID>/`) | Human | light | full |
|---|---|---|---|---|---|---|
| 1 | Ticket normalize: affected repos, triage, branches | `/aiflow-spec` (§ Stage 1) | `ticket.md`, `status.md` | approve | ✅ | ✅ |
| 2 | Spec: root cause / design | `/aiflow-spec` (light: § 1.4 / full: § Stage 2) | `spec.md` | approve | ✅ | ✅ |
| 3 | Fix plan (tasks, one repo each) | `/aiflow-plan` | `plan.md` | approve | — | ✅ |
| 4 | Implementation (TDD + 2 reviews per task) | `/aiflow-impl` | code, `reviews/task*.md` | — | ✅ | ✅ |
| 5 | Final review across repos + test cases | `/aiflow-review` (§ Stage 5 section) | `reviews/final-review.md`, `test-cases.md` | — | — | ✅ |
| 6 | Delivery: tests, manual QA gate, PR per repo | `/aiflow-review` (§ Stage 6 section) | PR URLs in `status.md` | QA / approve | ✅ | ✅ |

**On light route, stages 1 and 2 run as one turn, not two.** For a small bug,
`aiflow-spec` investigates and writes `spec.md` inline right after triage,
behind one combined approval — no separate stop for a dialogue. This is a
fast-track (triage and the fix write-up as one step), distinct from the real
investigate-then-dialogue process full route (and every non-bug ticket)
still gets in stage 2. If the investigation finds the ticket doesn't
actually qualify as light, it falls back to full on the spot and runs the
normal stage-2 dialogue later.

Stages 5 and 6 are two separate sections inside the same `aiflow-review` skill file, not two runs of the same procedure. On the light route only stage 5's section is skipped; stage 6's always runs. You never pick the section yourself — `/aiflow` reads `status.md` and runs the right one.

`log.json` (time, tokens and estimated cost per stage) is written automatically.

**`status.md` and `log.json` track different axes, not a duplicate.** `status.md` is *progress* — which stage is done, who approved it — and it's the only thing `/aiflow` reads to decide what runs next. `log.json` is *usage* — how much time, tokens and cost each stage took — and it never feeds routing decisions. Each answers a question the other can't: "is light route actually cheaper than full", "which stage costs the most" — the AI-cost-optimization requirement from the proposal, not something `status.md` could answer on its own.

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

**How bug vs. feature is decided.** `/aiflow PDT-XXXX feature` overrides everything. Otherwise the primary signal is the Notion ticket's **種別 (type) property** — a defect-naming value (不具合 / Bug) → bug, a new/improved-behavior value (新機能 / Feature / new development) → feature — recorded in ticket.md's 種別 row as the evidence. If 種別 is empty or ambiguous, the AI reads the ticket body: broken current behavior with repro steps → bug; only a description of desired new behavior → feature. It asks you, once, only if that still doesn't resolve it — never a guess.

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

## Project wiki (`/aiflow wiki`)

The graph above is a **mechanical extraction** (AST only, free). The wiki is
**the AI reading code and writing prose** — it costs real tokens every run,
which is why it's never auto-updated by a git hook the way the graph could be.

`/aiflow wiki` (the `aiflow-wiki` skill, confirms before spending tokens):

1. reads repo topology from `workflow.yaml` `repos:` — never re-asks
   mono-repo vs. multi-repo, since this workspace already is 3 repos;
2. writes one `wiki/architecture/<repo>.md` per repo (stack, layer/module
   map, key modules) from that repo's own guides, the knowledge graph, and
   real code;
3. writes `wiki/architecture/contracts.md` (cross-repo contracts, with the
   rationale `workflow.yaml`'s `contracts:` block doesn't carry) and, when
   warranted, `wiki/architecture/decisions/`.

After the initial write, it doesn't update itself. When a ticket's spec
genuinely records an architecture decision, `aiflow-spec` may append one
small entry to `wiki/architecture/decisions/` — cheap, since it reuses that
ticket's own investigation. Run `/aiflow wiki refresh` yourself for a full
re-scan (after a big merge, or when it's been untouched a long time).

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

## Adopting this in another project

This flow isn't BUMP-specific. Every skill under `.claude/skills/aiflow*/`
reads `aiflow/workflow.yaml` for repo names, stacks and test commands — none
of that is hard-coded in the skill bodies. **You don't need to clone this
repo** — `install.sh` clones into a throwaway temp dir, copies only what's
needed, and cleans up (same mechanism as harness-workflow builder's own
`install.sh`):

```bash
curl -fsSL https://gitlab.shiftasia.com/cong.nguyen.02/ai-flow-demo/-/raw/main/install.sh | bash -s -- --dir /path/to/your-project
# or, if you already have it downloaded:
bash install.sh --dir /path/to/your-project
```

What it installs: the `/aiflow` router + its 8 stage skills, the 7 generic
skills they use internally (TDD, debugging, code review, ...),
`aiflow/scripts/`, `.claude/settings.json` (hooks), and
`aiflow/workflow.yaml.template`. **What it doesn't fill in:**
`workflow.yaml` itself (your project's repos, stacks and test commands are
yours to know — copy the template and fill it in) or your source repos'
clones. Works for a single-repo project too (list one entry under `repos:`,
set `contracts: []`).

## Where things are

| Path | What |
|---|---|
| `aiflow/workflow.yaml` | Repos, base branches, test commands, contracts, triage rules, models. Edit here. |
| `aiflow/pricing.json` | Prices used for the cost estimate in `log.json` |
| `aiflow/scripts/` | `aiflow_status.py` (board and next stage) · `aiflow_log.py` (usage log hook) · `kg_build.py` (knowledge graph) |
| `.claude/skills/aiflow*/` | The stage skills and their templates (`ticket-template.md`, `spec-template.md`, `plan-template.md`, subagent prompts) |
| `.claude/skills/aiflow/conventions.md` | Rules every stage follows: stop after each stage, gates, git, language |
| `.claude/skills/{test-driven-development,systematic-debugging,…}` | Engineering disciplines the stages load internally (hidden from the `/` menu) |

**Why these carry no `aiflow-` prefix.** Only skills prefixed `aiflow-` are
stages themselves — what `/aiflow` invokes. The other seven
(`test-driven-development`, `systematic-debugging`,
`verification-before-completion`, `receiving-code-review`,
`requesting-code-review`, `dispatching-parallel-agents`, `graphify`) are
generic engineering-discipline skills each stage loads internally when the
situation calls for it, not AI Flow-specific orchestration steps. They are
deliberately unprefixed and `user-invocable: false`, for two reasons: it
guarantees no name collides with `/aiflow-*`, and each one's `description`
follows the standard "Use when…" trigger convention — the AI loads it
automatically from that description (e.g. `systematic-debugging` on any bug,
`test-driven-development` before writing code) rather than being invoked by
name. You never call one directly; a stage does.
| `docs/aiflow/<ID>/` | One folder per ticket; `status.md` is the resume point |
| `aiflow/selected-bugs/` | Notion ticket lists (ticket ID → Notion URL) |
| `wiki/` | Architecture knowledge from `/aiflow wiki` (committed, not gitignored) |

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
