#!/usr/bin/env python3
"""Build the project knowledge graph for every component in aiflow/workflow.yaml.
Standard library only; needs the `graphify` CLI.

  python3 aiflow/scripts/kg_build.py              # update each git root, merge if several
  python3 aiflow/scripts/kg_build.py --no-update  # merge existing graphs only
  python3 aiflow/scripts/kg_build.py --force      # rebuild roots even if already at HEAD
  python3 aiflow/scripts/kg_build.py --no-hooks   # leave git hooks alone
  python3 aiflow/scripts/kg_build.py --no-ignore  # don't create .graphifyignore files
  python3 aiflow/scripts/kg_build.py --no-update --extra docs=path/to/graphify-out/graph.json

1. Resolves each component's git root (`git rev-parse --show-toplevel`) and
   runs `graphify update .` once per DISTINCT root. Roots whose graph is
   already at HEAD with a clean tree are skipped.
2. One git root (single repo or monorepo): that root's graphify-out/graph.json
   is the graph — nothing to merge.
3. Several git roots (multi-repo workspace): merges them into
   graphify-out/graph.json at the workspace root. Node ids become
   `<label>::<id>`, every node gets `repo`, `source_file` becomes
   workspace-relative, and `cross_repo_same_symbol` edges link distinctive
   PascalCase symbols defined in more than one root. Writes
   graphify-out/WORKSPACE_REPORT.md.
4. Git hooks (`post-commit` / `post-checkout`, via `graphify hook install`)
   keep each component's graph fresh: installed in every component git root
   that lacks them. In a multi-repo workspace the wrapper only holds docs, so
   graphify's hook blocks are REMOVED from the wrapper's own .git/hooks
   (other hook content is kept). Hooks live in .git/hooks — local, never
   committed. Skip all of this with --no-hooks.
5. A `.graphifyignore` is created in every component git root that has none
   (build output, dependencies, generated code — otherwise graphify scans
   gigabytes of `build/`, `Pods/`, `node_modules/`). An existing file is never
   touched. The new file is added to the repo's .git/info/exclude so it stays
   local and is not committed by accident; commit it yourself if the team
   wants to share it. Skip with --no-ignore.
"""
import collections
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "graphify-out")
UPDATE_TIMEOUT_SEC = 30 * 60

GENERIC = {
    "Config", "Client", "Service", "Handler", "Response", "Request", "Options", "Result",
    "Status", "Error", "Errors", "Params", "State", "Model", "Value", "Values", "Builder",
    "Context", "Provider", "Default", "Settings", "Controller", "Repository", "Container",
    "Wrapper", "Screen", "Button", "Header", "Footer", "Layout", "Content", "Loader",
}
SYMBOL = re.compile(r"^[A-Z][a-z0-9]+(?:[A-Z][A-Za-z0-9]*)+$")  # PascalCase, 2+ words
VENDORED = re.compile(r"/(Pods|node_modules|third_party|vendor|build|dist|target|\.dart_tool|\.next|\.venv|venv|generated)/")
TESTY = re.compile(r"(^|/)(test|tests|spec|mock|mocks|__tests__|testdata|fixtures)/|_test\.|\.test\.|\.spec\.|mock", re.I)


def components_from_manifest():
    """[(name, path)] from the `components:` block of workflow.yaml, no YAML dependency."""
    comps, inside, current = [], False, None
    path = os.path.join(ROOT, "aiflow", "workflow.yaml")
    if not os.path.exists(path):
        sys.exit("[kg] aiflow/workflow.yaml not found — run /aiflow setup first.")
    with open(path, encoding="utf-8") as f:
        for line in f:
            if re.match(r"^components:\s*(#.*)?$", line):
                inside = True
                continue
            if not inside:
                continue
            if line.strip() and not line[0].isspace() and not line.startswith("#"):
                break
            m = re.match(r"^  ([A-Za-z0-9_.-]+):\s*(#.*)?$", line)
            if m:
                current = m.group(1)
                comps.append([current, "."])
                continue
            m = re.match(r"^    path:\s*([^#\s]+)", line)
            if m and current:
                comps[-1][1] = m.group(1).strip("'\"")
    return [tuple(c) for c in comps]


def git(*args, cwd):
    r = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def git_roots(comps):
    """{root_abs_path: [component names]} in declaration order."""
    roots = collections.OrderedDict()
    for name, rel in comps:
        abspath = os.path.normpath(os.path.join(ROOT, rel))
        if not os.path.isdir(abspath):
            print(f"[kg] {name}: {rel} does not exist — skipped (clone it first?)")
            continue
        top = git("rev-parse", "--show-toplevel", cwd=abspath)
        if not top:
            print(f"[kg] {name}: {rel} is not inside a git repo — skipped")
            continue
        roots.setdefault(os.path.realpath(top), []).append(name)
    return roots


def built_at(root):
    out = os.path.join(root, "graphify-out")
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


def update(root, label, force):
    head = git("rev-parse", "HEAD", cwd=root)
    dirty = git("status", "--porcelain", "--untracked-files=no", cwd=root)
    if not force and not dirty and head and built_at(root) == head:
        print(f"[kg] {label}: graph already at HEAD {head[:9]} — skipped (--force to rebuild)")
        return
    print(f"[kg] graphify update {label} ...", flush=True)
    try:
        r = subprocess.run(["graphify", "update", "."], cwd=root, capture_output=True,
                           text=True, timeout=UPDATE_TIMEOUT_SEC)
    except FileNotFoundError:
        sys.exit("[kg] `graphify` is not installed — install it, or skip the knowledge graph.")
    except subprocess.TimeoutExpired:
        print(f"[kg]   timed out after {UPDATE_TIMEOUT_SEC // 60} min — keeping the previous graph")
        return
    if r.returncode != 0:
        print(f"[kg]   failed: {(r.stderr or r.stdout).strip()[-400:]}")
        return
    os.makedirs(os.path.join(root, "graphify-out"), exist_ok=True)
    with open(os.path.join(root, "graphify-out", ".aiflow_head"), "w") as f:
        f.write(head or "")


def load(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def bare(label):
    label = re.sub(r"\(.*\)$", "", (label or "").strip())
    return label.split(".")[-1]


def merge(sources):
    """sources: [(label, graph_path, root_abs)] -> writes the merged workspace graph."""
    merged = {"directed": True, "multigraph": False,
              "graph": {"workspace": True, "roots": [s[0] for s in sources]},
              "nodes": [], "links": [], "hyperedges": []}
    stats, src = {}, {}
    symbols = collections.defaultdict(lambda: collections.defaultdict(list))
    for label, gpath, root in sources:
        g = load(gpath)
        if not g:
            print(f"[kg] {label}: no graph at {gpath} — skipped")
            continue
        prefix = os.path.relpath(root, ROOT) if root else label
        stats[label] = {"nodes": len(g["nodes"]), "links": len(g["links"]),
                        "commit": g.get("built_at_commit")}
        for n in g["nodes"]:
            n = dict(n, id=f"{label}::{n['id']}", repo=label)
            if n.get("source_file"):
                n["source_file"] = f"{prefix}/{n['source_file']}"
            if n.get("community") is not None:
                n["community"] = f"{label}:{n['community']}"
            merged["nodes"].append(n)
            sf = n.get("source_file")
            if n.get("file_type") == "code" and sf and not VENDORED.search("/" + sf):
                name = bare(n.get("label"))
                if SYMBOL.match(name) and name not in GENERIC and len(name) >= 8:
                    symbols[name][label].append(n["id"])
                    src[n["id"]] = sf
        for l in g["links"]:
            l = dict(l, source=f"{label}::{l['source']}", target=f"{label}::{l['target']}")
            if l.get("source_file"):
                l["source_file"] = f"{prefix}/{l['source_file']}"
            merged["links"].append(l)
        merged["hyperedges"].extend(g.get("hyperedges", []))

    cross = []
    for name, by_root in symbols.items():
        if len(by_root) < 2 or any(len(ids) > 3 for ids in by_root.values()):
            continue
        reps = sorted((r, sorted(ids, key=lambda i: bool(TESTY.search(src[i])))[0])
                      for r, ids in by_root.items())
        for i in range(len(reps)):
            for j in range(i + 1, len(reps)):
                cross.append({"relation": "cross_repo_same_symbol", "confidence": "INFERRED",
                              "confidence_score": 0.5, "weight": 0.5, "symbol": name,
                              "source": reps[i][1], "target": reps[j][1]})
    merged["links"].extend(cross)

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "graph.json"), "w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False)

    pairs = collections.Counter(" <-> ".join(sorted((l["source"].split("::")[0],
                                                     l["target"].split("::")[0]))) for l in cross)
    lines = ["# Workspace knowledge graph", "",
             "Generated by `aiflow/scripts/kg_build.py` (`/aiflow analyze`). Query it with",
             "`graphify query \"<question>\"` from the workspace root.", "",
             "| git root | nodes | links | built at commit |", "|---|---|---|---|"]
    lines += [f"| {r} | {s['nodes']} | {s['links']} | {(s['commit'] or '-')[:9]} |"
              for r, s in stats.items()]
    lines += ["", f"Cross-repo links (same symbol name): **{len(cross)}**", ""]
    lines += [f"- {p}: {c}" for p, c in pairs.most_common()]
    sample = sorted({l["symbol"] for l in cross})[:60]
    if sample:
        lines += ["", "Sample shared symbols: " + ", ".join(f"`{s}`" for s in sample)]
    with open(os.path.join(OUT_DIR, "WORKSPACE_REPORT.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"[kg] merged {len(merged['nodes'])} nodes, {len(merged['links'])} links "
          f"({len(cross)} cross-repo) -> graphify-out/graph.json")


HOOK_MARKS = {
    "post-commit": ("# graphify-hook-start", "# graphify-hook-end"),
    "post-checkout": ("# graphify-checkout-hook-start", "# graphify-checkout-hook-end"),
}


def hooks_dir(root):
    p = git("rev-parse", "--git-path", "hooks", cwd=root)
    return os.path.normpath(os.path.join(root, p)) if p else None


def has_graphify_hooks(root):
    d = hooks_dir(root)
    if not d:
        return False
    for name, (start, _) in HOOK_MARKS.items():
        try:
            with open(os.path.join(d, name), encoding="utf-8") as f:
                if start not in f.read():
                    return False
        except OSError:
            return False
    return True


def strip_graphify_hooks(root, label):
    """Remove graphify's hook blocks from root's hooks; delete a hook file left empty."""
    d = hooks_dir(root)
    if not d:
        return
    for name, (start, end) in HOOK_MARKS.items():
        path = os.path.join(d, name)
        try:
            with open(path, encoding="utf-8") as f:
                text = f.read()
        except OSError:
            continue
        if start not in text or end not in text:
            continue
        head, _, rest = text.partition(start)
        _, _, tail = rest.partition(end)
        left = (head.rstrip() + "\n" + tail.lstrip("\n")).strip()
        if left == "" or left.startswith("#!") and len(left.splitlines()) == 1:
            os.remove(path)
            print(f"[kg] {label}: removed graphify {name} hook (wrapper holds docs only)")
        else:
            with open(path, "w", encoding="utf-8") as f:
                f.write(left + "\n")
            print(f"[kg] {label}: stripped graphify block from {name} (other hook content kept)")


def sync_hooks(roots, ws_root):
    """Component roots get graphify's git hooks; a docs-only wrapper loses them."""
    for root in roots:
        label = os.path.basename(root)
        if has_graphify_hooks(root):
            continue
        try:
            r = subprocess.run(["graphify", "hook", "install"], cwd=root,
                               capture_output=True, text=True, timeout=120)
        except (FileNotFoundError, subprocess.TimeoutExpired):
            print(f"[kg] {label}: could not run `graphify hook install` — skipped")
            continue
        print(f"[kg] {label}: graphify git hooks "
              + ("installed" if r.returncode == 0 else f"failed: {(r.stderr or r.stdout).strip()[-200:]}"))
    if ws_root not in roots and git("rev-parse", "--show-toplevel", cwd=ws_root):
        strip_graphify_hooks(ws_root, "wrapper")


GRAPHIFYIGNORE = """# Created by AI Flow (kg_build.py) — keeps graphify out of build output,
# dependencies and generated code. Edit freely; it is never overwritten.
node_modules/
.next/
dist/
out/
coverage/
vendor/
build/
target/
.gradle/
.dart_tool/
Pods/
DerivedData/
.venv/
venv/
__pycache__/
**/generated/
*.g.dart
*.freezed.dart
*.min.js
graphify-out/
**/graphify-out/
"""


def ensure_graphifyignore(root, label):
    """Create a default .graphifyignore in a component root that has none."""
    path = os.path.join(root, ".graphifyignore")
    if os.path.exists(path):
        return
    with open(path, "w", encoding="utf-8") as f:
        f.write(GRAPHIFYIGNORE)
    exclude = git("rev-parse", "--git-path", "info/exclude", cwd=root)
    if exclude:
        exclude = os.path.normpath(os.path.join(root, exclude))
        os.makedirs(os.path.dirname(exclude), exist_ok=True)
        try:
            with open(exclude, encoding="utf-8") as f:
                have = f.read()
        except OSError:
            have = ""
        if ".graphifyignore" not in have.split():
            with open(exclude, "a", encoding="utf-8") as f:
                f.write(("" if have.endswith("\n") or not have else "\n") + ".graphifyignore\n")
    print(f"[kg] {label}: created .graphifyignore (local, git-excluded)")


def main():
    no_update, force = "--no-update" in sys.argv, "--force" in sys.argv
    no_hooks = "--no-hooks" in sys.argv
    no_ignore = "--no-ignore" in sys.argv
    extras = []
    for i, a in enumerate(sys.argv):
        if a == "--extra" and i + 1 < len(sys.argv):
            name, _, path = sys.argv[i + 1].partition("=")
            extras.append((name, os.path.join(ROOT, path), None))

    roots = git_roots(components_from_manifest())
    if not roots:
        sys.exit("[kg] no component resolved to a git repo — nothing to do.")
    ws_root = os.path.realpath(ROOT)
    labels = {}
    for root, names in roots.items():
        labels[root] = names[0] if len(names) == 1 else os.path.basename(root)

    if not no_ignore:
        for root in roots:
            ensure_graphifyignore(root, labels[root])
    if not no_update:
        for root in roots:
            update(root, labels[root], force)
    if not no_hooks:
        sync_hooks(roots, ws_root)

    if len(roots) == 1:
        root = next(iter(roots))
        if root == ws_root:
            # in-repo (single repo / monorepo): graphify's own graph at the root IS the graph.
            print(f"[kg] one git root ({', '.join(roots[root])}) — the graph is "
                  f"graphify-out/graph.json; nothing to merge.")
            if extras:
                print("[kg] --extra ignored for an in-repo layout: docs inside the repo are "
                      "already in scope — run the graphify skill's semantic pass on the repo "
                      "to add them to its graph.")
            return
        # workspace with a single cloned repo: expose it at the workspace root too.
        merge([(labels[root], os.path.join(root, "graphify-out", "graph.json"), root)] + extras)
        return

    if ws_root in roots:
        sys.exit("[kg] a component at the workspace root can't be merged with other git roots "
                 "(its own graph.json is the merge output). Use layout: in-repo with components "
                 "inside the repo, or layout: workspace with no component at '.'.")
    merge([(labels[r], os.path.join(r, "graphify-out", "graph.json"), r) for r in roots] + extras)


if __name__ == "__main__":
    main()
