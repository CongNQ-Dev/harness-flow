#!/usr/bin/env python3
"""Build the workspace-wide knowledge graph (横断ナレッジグラフ). Standard library only.

  python3 aiflow/scripts/kg_build.py              # graphify update each repo, then merge
  python3 aiflow/scripts/kg_build.py --no-update  # merge existing per-repo graphs only
  python3 aiflow/scripts/kg_build.py --force      # rebuild even repos whose graph is at HEAD
  python3 aiflow/scripts/kg_build.py --no-update --extra docs=bump-backend/docs/graphify-out/graph.json
                                                  # also merge extra graphs (e.g. semantic doc graphs)

1. Runs `graphify update .` inside each repo in aiflow/workflow.yaml (AST only,
   no LLM cost) -> <repo>/graphify-out/graph.json. Repos whose graph is already
   at HEAD with a clean tree are skipped (a large repo can take many minutes).
2. Merges them into graphify-out/graph.json at the workspace root. Every node
   id is prefixed `<repo>::`, every node gets `repo`, and `source_file` becomes
   workspace-relative, so `graphify query/path/explain` answers across repos.
3. Adds cross-repo edges (`cross_repo_same_symbol`, INFERRED) between
   distinctive PascalCase symbols that exist in more than one repo — e.g. a
   GraphQL type in bump-backend and the generated Dart class in the app, or a
   swagger model and its generated TypeScript client type in bump-admin.
4. Writes graphify-out/WORKSPACE_REPORT.md.
"""
import collections
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "graphify-out")

# Too generic to link across repos even when the name matches.
GENERIC = {
    "Config", "Client", "Service", "Handler", "Response", "Request", "Options", "Result",
    "Status", "Error", "Errors", "Params", "State", "Model", "Value", "Values", "Builder",
    "Context", "Provider", "Default", "Settings", "Controller", "Repository", "Container",
    "Wrapper", "Screen", "Button", "Header", "Footer", "Layout", "Content", "Loader",
}
SYMBOL = re.compile(r"^[A-Z][a-z0-9]+(?:[A-Z][A-Za-z0-9]*)+$")  # PascalCase, 2+ words
VENDORED = re.compile(r"/(Pods|node_modules|third_party|vendor|build|\.dart_tool|\.next|generated)/")
TESTY = re.compile(r"(^|/)(test|tests|mock|mocks|__tests__|testdata)/|_test\.|\.test\.|mock", re.I)


def repos_from_manifest():
    """Read `repos:` keys from workflow.yaml without a YAML dependency."""
    repos, inside = [], False
    with open(os.path.join(ROOT, "aiflow", "workflow.yaml"), encoding="utf-8") as f:
        for line in f:
            if line.startswith("repos:"):
                inside = True
                continue
            if inside:
                if line and not line[0].isspace() and not line.startswith("#"):
                    break
                m = re.match(r"^  ([A-Za-z0-9_.-]+):\s*$", line)
                if m:
                    repos.append(m.group(1))
    return repos


UPDATE_TIMEOUT_SEC = 30 * 60


def head(repo):
    r = subprocess.run(["git", "-C", os.path.join(ROOT, repo), "rev-parse", "HEAD"],
                       capture_output=True, text=True)
    return r.stdout.strip()


def built_at(repo):
    """Commit the repo's graph was last built at (graphify's own stamp, else ours)."""
    out = os.path.join(ROOT, repo, "graphify-out")
    try:
        with open(os.path.join(out, ".aiflow_head")) as f:
            return f.read().strip()
    except OSError:
        pass
    try:
        with open(os.path.join(out, "graph.json"), encoding="utf-8") as f:
            m = re.search(r'"built_at_commit":\s*"([0-9a-f]+)"', f.read()[-300:])
            return m.group(1) if m else None
    except OSError:
        return None


def update(repo, force=False):
    path = os.path.join(ROOT, repo)
    now_head = head(repo)
    dirty = subprocess.run(["git", "-C", path, "status", "--porcelain", "--untracked-files=no"],
                           capture_output=True, text=True).stdout.strip()
    if not force and not dirty and now_head and built_at(repo) == now_head:
        print(f"[kg] {repo}: graph already at HEAD {now_head[:9]} — skipped (use --force to rebuild)")
        return
    print(f"[kg] graphify update {repo} ...", flush=True)
    try:
        r = subprocess.run(["graphify", "update", "."], cwd=path, capture_output=True, text=True,
                           timeout=UPDATE_TIMEOUT_SEC)
    except subprocess.TimeoutExpired:
        print(f"[kg]   timed out after {UPDATE_TIMEOUT_SEC // 60} min — keeping the previous graph")
        return
    if r.returncode != 0:
        print(f"[kg]   failed: {(r.stderr or r.stdout).strip()[-400:]}")
        return
    with open(os.path.join(path, "graphify-out", ".aiflow_head"), "w") as f:
        f.write(now_head)


def load(repo, path=None):
    p = path or os.path.join(ROOT, repo, "graphify-out", "graph.json")
    if not os.path.exists(p):
        print(f"[kg] {repo}: no graph ({p}) — skipped")
        return None
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def bare(label):
    label = (label or "").strip()
    label = re.sub(r"\(.*\)$", "", label)  # "Foo()" -> "Foo"
    return label.split(".")[-1]


def main(no_update, extras, force=False):
    repos = repos_from_manifest()
    if not no_update:
        for repo in repos:
            update(repo, force)
    merged = {"directed": True, "multigraph": False, "graph": {"workspace": True, "repos": repos},
              "nodes": [], "links": [], "hyperedges": []}
    stats, symbols = {}, collections.defaultdict(lambda: collections.defaultdict(list))
    src = {}  # node id -> source_file, for picking the non-test definition
    sources = [(r, None) for r in repos] + extras
    for repo, gpath in sources:
        g = load(repo, gpath)
        if not g:
            continue
        merged["directed"] = g.get("directed", True)
        stats[repo] = {"nodes": len(g["nodes"]), "links": len(g["links"]),
                       "commit": g.get("built_at_commit")}
        for n in g["nodes"]:
            n = dict(n)
            n["id"] = f"{repo}::{n['id']}"
            n["repo"] = repo
            if n.get("source_file"):
                n["source_file"] = f"{repo}/{n['source_file']}"
            if n.get("community") is not None:
                n["community"] = f"{repo}:{n['community']}"
            merged["nodes"].append(n)
            if n.get("file_type") == "code" and n.get("source_file") \
                    and not VENDORED.search(n["source_file"]):
                name = bare(n.get("label"))
                if SYMBOL.match(name) and name not in GENERIC and len(name) >= 8:
                    symbols[name][repo].append(n["id"])
                    src[n["id"]] = n["source_file"]
        for l in g["links"]:
            l = dict(l)
            l["source"], l["target"] = f"{repo}::{l['source']}", f"{repo}::{l['target']}"
            if l.get("source_file"):
                l["source_file"] = f"{repo}/{l['source_file']}"
            merged["links"].append(l)
        for h in g.get("hyperedges", []):
            merged["hyperedges"].append(h)

    cross = []
    for name, by_repo in symbols.items():
        if len(by_repo) < 2:
            continue
        # distinctive only: a name defined many times inside one repo is noise
        if any(len(ids) > 3 for ids in by_repo.values()):
            continue
        # link the real definition, not a test fixture or mock, when both exist
        reps = {repo: sorted(ids, key=lambda i: bool(TESTY.search(src[i])))[0]
                for repo, ids in by_repo.items()}
        items = sorted(reps.items())
        for i in range(len(items)):
            for j in range(i + 1, len(items)):
                cross.append({"relation": "cross_repo_same_symbol", "confidence": "INFERRED",
                              "confidence_score": 0.5, "weight": 0.5, "symbol": name,
                              "source": items[i][1], "target": items[j][1]})
    merged["links"].extend(cross)

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "graph.json"), "w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False)

    pairs = collections.Counter(
        " ↔ ".join(sorted((l["source"].split("::")[0], l["target"].split("::")[0]))) for l in cross)
    lines = ["# Workspace knowledge graph", "",
             "Generated by `aiflow/scripts/kg_build.py` (run via `/aiflow-analyze`). Query it with",
             "`graphify query \"<question>\"` from the workspace root.", "",
             "| repo | nodes | links | built at commit |", "|---|---|---|---|"]
    lines += [f"| {r} | {s['nodes']} | {s['links']} | {(s['commit'] or '-')[:9]} |" for r, s in stats.items()]
    lines += ["", f"Cross-repo links (same symbol name): **{len(cross)}**", ""]
    lines += [f"- {p}: {c}" for p, c in pairs.most_common()]
    sample = sorted({l["symbol"] for l in cross})[:60]
    if sample:
        lines += ["", "Sample shared symbols: " + ", ".join(f"`{s}`" for s in sample)]
    with open(os.path.join(OUT_DIR, "WORKSPACE_REPORT.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"[kg] merged {len(merged['nodes'])} nodes, {len(merged['links'])} links "
          f"({len(cross)} cross-repo) -> graphify-out/graph.json")


if __name__ == "__main__":
    extras = []
    for i, a in enumerate(sys.argv):
        if a == "--extra" and i + 1 < len(sys.argv):
            name, _, path = sys.argv[i + 1].partition("=")
            extras.append((name, os.path.join(ROOT, path)))
    main("--no-update" in sys.argv, extras, "--force" in sys.argv)
