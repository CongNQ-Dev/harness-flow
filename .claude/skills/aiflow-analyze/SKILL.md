---
name: aiflow-analyze
description: Build or refresh the knowledge graph for every component in aiflow/workflow.yaml — runs graphify once per distinct git root (AST only, no LLM cost, skipping roots already at HEAD), and for multi-repo workspaces merges the graphs into graphify-out/graph.json with cross-repo links between shared symbols. Optionally adds design documents semantically (costs tokens). Run at setup, after big merges, or when /aiflow says the graph is missing.
argument-hint: "[docs]"
---

# /aiflow-analyze — Knowledge graph

Not a ticket stage: no status.md, no stop rule. Needs the `graphify` CLI; if
it isn't installed, say so (install with `pip install graphifyy` or your
team's method) and stop — every other skill works without a graph.

## 1. Code graph (always; cheap)

```bash
python3 aiflow/scripts/kg_build.py
```

It resolves each component's git root and runs `graphify update .` once per
distinct root (roots already built at HEAD with a clean tree are skipped;
`--force` rebuilds). Then:

- **One git root** (single repo or monorepo — `layout: in-repo`): that
  root's own `graphify-out/graph.json` *is* the graph. Nothing to merge.
- **Several git roots** (multi-repo workspace): it merges them into the
  workspace's `graphify-out/graph.json` — node ids become `<root>::<id>`,
  every node gets `repo`, and `cross_repo_same_symbol` edges link
  distinctive type names defined in more than one root (a schema type and
  its generated client, say). It also writes `graphify-out/WORKSPACE_REPORT.md`.

`--no-update` only re-merges.

## 2. Design documents (only with `docs`; uses LLM tokens)

`/aiflow analyze docs` adds the folders in `knowledge_graph.include_docs`
through the `graphify` skill's semantic extraction:

- **in-repo:** run it on the repo itself — the docs live in the repo, so
  they go into the root graph directly (no merge step).
- **workspace:** run it on each folder into its own `<folder>/graphify-out/`,
  then re-merge:
  `python3 aiflow/scripts/kg_build.py --no-update --extra <name>=<folder>/graphify-out/graph.json ...`.
Tell the user roughly how many files that is and ask with `AskUserQuestion`
before starting.

## 3. Report

Node counts per git root, the cross-repo link count with a few example
shared symbols (multi-repo only), and one query to try:

```bash
graphify query "where is the order total calculated"
```
