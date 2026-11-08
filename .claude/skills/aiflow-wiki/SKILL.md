---
name: aiflow-wiki
description: Generate or refresh the project wiki — curated architecture knowledge (one overview page per component, the contracts between components with their rationale, and real architecture decisions) written by the AI from the real code, each component team's own docs, and the knowledge graph. Costs real tokens (an LLM pass over the codebase), so it's run on demand, never automatically; individual tickets may append small decision entries later via aiflow-spec.
argument-hint: "[refresh]"
---

# /aiflow-wiki — Project wiki

First read `.claude/skills/aiflow/conventions.md` and `aiflow/workflow.yaml`
(`wiki:`). Not a ticket stage — no status.md, no stop rule, no gate.

## 0. Confirm before spending tokens

Say in one line what this will read (which components, roughly how many
files / graph nodes) and ask with `AskUserQuestion`: **Run** / **Cancel**.
Unlike `graphify update` (AST only, free), this is an LLM writing prose from
code — that's why it's never run from a hook.

## 1. Shape — read it, don't ask

`workflow.yaml` already says it: `layout`, and how many components share
which git root (conventions §1). Don't re-interview for single vs. mono vs.
multi-repo — `/aiflow setup` already did.

## 2. What gets written

Only what a bug-fix and feature flow on an existing codebase actually uses —
no user-story, GUI-design or task sections (there are no stages producing
them):

```
wiki/
  index.md                      ← entry point, links everything below
  log.md                        ← append-only: what changed, when, why
  architecture/
    <component>.md              ← one page per workflow.yaml component
    contracts.md                ← contracts between components, WITH rationale
                                   (omit for a single component)
    decisions/
      <slug>.md                 ← one ADR-style entry per real decision
```

Every page's frontmatter (see `architecture-template.md` / `decision-template.md`):

```yaml
---
type: Architecture Overview | Cross-Component Contract | Decision
title: <short, specific>
components: [<component>]
sources: [<component>/path/file.ext:123, graphify:<node-id>]   # no claim without one
generated: {by: aiflow-wiki, at: YYYY-MM-DD}
status: draft
---
```

Write it in `language` (conventions §7).

## 3. One page per component (`architecture/<component>.md`)

1. Read the component's **own** docs first (`guides:` in workflow.yaml, its
   README) — the team's stated architecture beats re-deriving it.
2. If a graph exists: `graphify query "<component> architecture overview"`
   and the component's biggest communities / most-connected nodes (in
   `graphify-out/GRAPH_REPORT.md`, or `WORKSPACE_REPORT.md` for a
   workspace). The cheap, high-signal pass — read raw source only to
   confirm or fill a gap.
3. Write: stack (`workflow.yaml` `stack`, confirmed against real config),
   the layer/module map (named in plain language), the 3–6 most central
   modules and what they own, and visible bounded-context boundaries.
   Every claim cites a `component/path:line` or a graph node.

## 4. Contracts (`architecture/contracts.md`, several components only)

Start from `workflow.yaml` `contracts:` (owner, consumers, regenerate
command) and add what it doesn't carry: why the contract exists, the
backward-compatibility rules visible in the code, and links to past tickets
that changed it (look for a "Contracts between components" section in
`docs/aiflow/*/spec.md`).

## 5. Decisions (`architecture/decisions/`)

Only real, consequential decisions found in the code or past specs. One file
each, `<slug>.md`. None evident yet → the folder starts with just
`.gitkeep`; never invent decisions to fill it.

## 6. Self-review

No claim without a `sources:` entry, no placeholder/TBD, no invented
rationale. Everything stays `status: draft`; nothing in the flow is gated
on it — a human sets `stable` after actually reviewing a page.

## 7. `index.md`, `log.md`, commit, report

`index.md`: one line per page, links relative to `wiki/`. `log.md`: append
(never rewrite) one entry — date, what was generated or refreshed. Commit
(`docs(wiki): generate/refresh project wiki` — in-repo: not on a base
branch; if you're on one, leave it uncommitted and say so). Report what was
written and remind that tickets may append small `decisions/` entries; a
full re-scan is `/aiflow wiki refresh`.

## `refresh`

Same procedure, treating existing pages as a draft to update: keep what's
still accurate, add what the code now shows, and **flag** (don't silently
delete) anything that looks stale so a human confirms before it goes.
