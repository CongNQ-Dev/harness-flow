---
name: aiflow-analyze
description: Build or refresh the workspace-wide knowledge graph (横断ナレッジグラフ) covering every repo in aiflow/workflow.yaml — updates each repo's graphify graph (AST, no LLM cost), merges them into graphify-out/graph.json with cross-repo links between shared symbols, and optionally adds design documents semantically. Run once at setup, after big merges, or when /aiflow says the graph is missing.
argument-hint: "[docs]"
---

# /aiflow-analyze — ナレッジグラフ構築・更新

Not a ticket stage; it prepares the knowledge every stage queries. No status.md
changes, no stop rule.

## 1. Code graph (always, cheap)

```bash
python3 aiflow/scripts/kg_build.py
```

It runs `graphify update .` in each repo listed in `aiflow/workflow.yaml`,
then merges into `graphify-out/graph.json` at the workspace root: node ids
become `<repo>::<id>`, every node has `repo`, and `cross_repo_same_symbol`
edges link distinctive type names that exist in several repos (a backend
GraphQL/swagger type and its generated client in the app or admin). It prints
counts and writes `graphify-out/WORKSPACE_REPORT.md`.

If `graphify` is not installed, tell the user to install it
(`pip install graphifyy` or the team's install method) and stop.

Use `--no-update` to only re-merge when the per-repo graphs are already fresh.

## 2. Design documents (only with `docs`, uses LLM tokens)

`/aiflow-analyze docs` additionally runs the `graphify` skill's semantic
extraction on the folders in `workflow.yaml` `knowledge_graph.include_docs`
(API specs, architecture docs, past ticket specs), each into its own
`<folder>/graphify-out/`, then re-merges everything:
`python3 aiflow/scripts/kg_build.py --no-update --extra docs-backend=bump-backend/docs/graphify-out/graph.json ...`
(one `--extra name=path` per doc graph). Tell the user the approximate size (number of files) and ask with
`AskUserQuestion` before starting — this step costs tokens.

## 3. Report

Show the per-repo node counts, the cross-repo link count with 5 example shared
symbols, and one example query the team can try, e.g.

```bash
graphify query "which screens call the admin seasons API"
graphify path "bump-admin::..." "bump-backend::..."
```

Remind: re-run after large merges; `/aiflow-impl` already refreshes touched
repos' graphs (`graphify update .`) after implementation.
