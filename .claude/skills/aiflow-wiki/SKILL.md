---
name: aiflow-wiki
description: Generate or refresh the workspace's project wiki — curated architecture knowledge (per-repo overview, bounded contexts, cross-repo contracts with rationale) written by the AI from real code and the knowledge graph, not auto-extracted. Inspired by harness-workflow's ingest-repo/OKF wiki, trimmed to what a bug-fix-and-small-feature flow across 3 existing repos actually needs. Uses real tokens (an LLM pass over 3 repos) — run it on demand, never automatically. Individual tickets may append small decisions/ entries later via aiflow-spec; this skill does the initial full write and any later full re-scan.
argument-hint: "[refresh]"
---

# /aiflow-wiki — プロジェクトwiki生成・更新

First read `.claude/skills/aiflow/conventions.md` and `aiflow/workflow.yaml`
(§ `wiki:`). Not a ticket stage — no `status.md` interaction, no stop rule,
no gate. Costs real tokens (this is an LLM writing prose from real code, not
`graphify update` — see `wiki: update_from_tickets` in `workflow.yaml` for
why this is never run from a hook).

## 0. Confirm before spending tokens

Tell the user in one line what this will read (which repos, roughly how
many files/graph nodes) and ask with `AskUserQuestion`:
**実行** / **キャンセル**. This mirrors `/aiflow-analyze docs`'s same courtesy
for the same reason — a repo-wide LLM pass is not free.

## 1. Topology — read, don't ask

`workflow.yaml`'s `wiki.topology` and `repos:` already say this is
**multi-repo** (3 distinct repos, not a monorepo) — do not re-interview for
it the way `harness-workflow build` would for a brand-new project. If a
future repo is added to `workflow.yaml`, it's automatically in scope here
too; nothing in this skill hard-codes the repo count.

## 2. What gets written (trimmed OKF — no SDLC-phase sections)

harness-workflow's full wiki has `stories/`, `gui/`, `designs/`, `tasks/`,
`tests/` because it drives a full greenfield SDLC. This workspace has no
`stories-write`/`gui-design`/`plan-tasks` stages — those sections would sit
empty forever. Write only what a brownfield, bug-fix-and-small-feature flow
actually uses:

```
wiki/
  index.md                       ← entry point, links everything below
  log.md                         ← append-only: what changed, when, why
  architecture/
    bump-backend.md              ← one page per repo
    bump-admin.md
    bump-mobile-app.md
    contracts.md                 ← cross-repo contracts, WITH rationale
    decisions/
      <slug>.md                  ← one ADR-style entry per real decision
```

Every concept file's frontmatter (see `architecture-template.md` /
`decision-template.md`):

```yaml
---
type: Architecture Overview | Cross-Repo Contract | Decision
title: <short, specific>
repos: [bump-backend]            # which repo(s) this concerns
sources: [repo/path/file.ext:123, graphify:<node-id>]   # never write a claim without one
generated: {by: aiflow-wiki, at: YYYY-MM-DD}
status: draft
---
```

## 3. Per-repo architecture page (`architecture/<repo>.md`)

For each repo in `workflow.yaml` `repos:`:

1. Read that repo's **own** guides first if `workflow.yaml`
   `repos.<repo>.guides` lists any (e.g. bump-mobile-app's `docs/ai/README.md`)
   — a repo's own stated architecture beats re-deriving it from scratch.
2. Query the merged graph: `graphify query "<repo> architecture overview"`,
   then look at that repo's community structure in
   `graphify-out/WORKSPACE_REPORT.md` (already computed — god nodes, biggest
   communities). This is the cheap, high-signal pass — read raw source only
   to confirm or fill a gap the graph and the repo's own docs leave open.
3. Write: stack (from `workflow.yaml` `repos.<repo>.stack`, confirmed
   against real config files), layer/module map (from the graph's
   communities, named in plain language), the 3–6 most-connected modules
   (god nodes) and what they own, and any bounded-context boundary visible
   in the code layout. Every claim: `repo/path:line` or a graphify node id.

## 4. Cross-repo contracts (`architecture/contracts.md`)

Start from `workflow.yaml`'s `contracts:` block (already names owner,
consumers, regenerate command) — this file adds the **rationale** that
block doesn't carry: why the contract exists, backward-compatibility rules
observed in the code (e.g. a header with a fallback default), and links to
any past ticket that touched it. Check `docs/aiflow/*/spec.md` for a
リポジトリ間の契約 section — PDT-1136 is a real example already in this
workspace (backend season-ID header, migrated as `legacy: true`) — cite it
as a source if it's still accurate.

## 5. Decisions (`architecture/decisions/`)

Only real, consequential decisions found in code or past specs — not a
restatement of the architecture pages. One file per decision, named
`<slug>.md`. If none are evident yet, it's fine for this directory to start
with just `.gitkeep` — don't invent decisions to fill it.

## 6. Self-review before writing anything final

Same discipline as `spec-document-reviewer-prompt.md`: no claim without a
`sources:` entry, no placeholder/TBD, no invented rationale. Everything
starts `status: draft` — there is no approval gate blocking anything else in
the flow on this, so leave it there; a human flips it to `stable` by editing
the file whenever they've actually reviewed it, at their own pace.

## 7. Write `index.md` and `log.md`

`index.md`: one line per page above, links relative to `wiki/`.
`log.md`: append (never rewrite) one entry — date, what was generated or
refreshed, by which run.

## 8. Commit and report

`git add wiki && git commit -m "docs(wiki): generate/refresh project wiki"`
on the workspace repo. Report what was written, per-repo page sizes, and
remind: `docs/aiflow/<ID>/spec.md` may append small `decisions/` entries
going forward (see `aiflow-spec`) — this skill is for the initial write and
any later full re-scan (`/aiflow-wiki refresh`), not for keeping it current
automatically.

## `refresh` argument

Same procedure, but treat existing pages as a draft to update rather than
start from blank — keep anything still accurate, add anything new the code
now shows, and flag (don't silently delete) anything that looks stale so a
human confirms before it's removed.
