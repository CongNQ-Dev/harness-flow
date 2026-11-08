#!/usr/bin/env python3
"""AI Flow status board / next-stage resolver. Standard library only.

  python3 aiflow/scripts/aiflow_status.py            # board of every ticket
  python3 aiflow/scripts/aiflow_status.py SHOP-12    # one ticket as JSON (used by /aiflow)

Reads the YAML frontmatter of docs/aiflow/<ID>/status.md (see .claude/skills/aiflow-spec/status-template.md). Never writes anything.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
def manifest_value(key, default):
    """Read a top-level scalar from aiflow/workflow.yaml (no YAML dependency)."""
    try:
        with open(os.path.join(ROOT, "aiflow", "workflow.yaml"), encoding="utf-8") as f:
            for line in f:
                m = re.match(r"^%s:\s*([^#\s][^#]*?)\s*(#.*)?$" % re.escape(key), line)
                if m:
                    return m.group(1).strip("'\"")
    except OSError:
        pass
    return default


ARTIFACTS = os.path.join(ROOT, manifest_value("artifacts_dir", "docs/aiflow"))


def normalize_id(raw):
    """SHOP-12 / shop-12 -> SHOP-12; '#123' or '123' -> <project_code>-123."""
    raw = raw.strip().lstrip("#")
    if raw.isdigit():
        return f"{manifest_value('project_code', 'TICKET').upper()}-{raw}"
    return raw.upper()

# n -> (id, Japanese name, skill that runs it, routes it belongs to)
STAGES = {
    1: ("ticket", "Ticket intake", "aiflow-spec", ("light", "full")),
    2: ("spec", "Spec", "aiflow-spec", ("light", "full")),
    3: ("plan", "Plan", "aiflow-plan", ("full",)),
    4: ("impl", "Implementation", "aiflow-impl", ("light", "full")),
    5: ("review", "Review & test cases", "aiflow-review", ("full",)),
    6: ("deliver", "Delivery (PR)", "aiflow-review", ("light", "full")),
}


def parse_frontmatter(text):
    """Tiny YAML subset: `key: value`, `key: [a, b]`, one level of nested maps."""
    m = re.match(r"^---\n(.*?)\n---", text, re.S)
    if not m:
        return {}
    data, parent = {}, None
    for raw in m.group(1).splitlines():
        line = raw.split(" #", 1)[0].rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip())
        key, _, val = line.strip().partition(":")
        val = val.strip()
        if indent and parent is not None:
            data[parent][key] = _scalar(val)
            continue
        if val == "":
            data[key], parent = {}, key
        else:
            data[key], parent = _scalar(val), None
    return data


def _scalar(v):
    if v.startswith("[") and v.endswith("]"):
        return [x.strip().strip("'\"") for x in v[1:-1].split(",") if x.strip()]
    if re.fullmatch(r"-?\d+", v):
        return int(v)
    return v.strip("'\"")


def next_stage(done, route):
    route = route if route in ("light", "full") else "full"
    for n in range(int(done or 0) + 1, 7):
        if route in STAGES[n][3]:
            return n
    return None


def _git(*args):
    try:
        r = subprocess.run(["git", "-C", ROOT, *args], capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return None
    return r.stdout if r.returncode == 0 else None


def find_ticket_branch(tid):
    """Ticket docs live on the ticket branch, so on any other branch status.md is
    simply absent. Look for a local (then remote) branch named */<ID>/* that has
    docs/<ID>/status.md. Returns (ref, status.md text) or (None, None)."""
    out = _git("for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes")
    refs = [r for r in (out or "").split() if f"/{tid}/" in f"/{r}/" and not r.endswith("/HEAD")]
    refs.sort(key=lambda r: r.startswith(("origin/", "upstream/")))  # local branches first
    rel = os.path.relpath(os.path.join(ARTIFACTS, tid, "status.md"), ROOT).replace(os.sep, "/")
    for ref in refs:
        text = _git("show", f"{ref}:{rel}")
        if text:
            return ref, text
    return None, None


def ticket_info(tid):
    path = os.path.join(ARTIFACTS, tid, "status.md")
    branch = None
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            text = f.read()
    else:
        branch, text = find_ticket_branch(tid)
        if text is None:
            return {"ticket": tid, "exists": False, "next_stage": 1, "next_cmd": "aiflow-spec",
                    "next_name": STAGES[1][1]}
    fm = parse_frontmatter(text)
    done = fm.get("stage_done", 0)
    route = fm.get("route", "undecided")
    n = next_stage(done, route)
    info = dict(fm)
    info.update({
        "exists": True,
        "stage_done": done,
        "next_stage": n,
        "next_cmd": STAGES[n][2] if n else None,
        "next_name": STAGES[n][1] if n else "done",
    })
    if branch:
        # Not on the ticket's branch: the caller must check it out (in the wrapper and
        # every affected component repo) before continuing — never treat it as new.
        info["checkout_branch"] = branch
    return info


def board():
    if not os.path.isdir(ARTIFACTS):
        print("No tickets yet (docs/aiflow/ is empty).")
        return
    rows = []
    for tid in sorted(os.listdir(ARTIFACTS)):
        if os.path.exists(os.path.join(ARTIFACTS, tid, "status.md")):
            i = ticket_info(tid)
            comps = i.get("components") or i.get("repos") or []
            rows.append((tid, i.get("kind", "?"), i.get("route", "?"),
                         ",".join(comps) or "?",
                         f"{i['stage_done']}/6", i["next_name"],
                         f"/{i['next_cmd']}" if i["next_cmd"] else "-"))
    if not rows:
        print("No tickets yet (docs/aiflow/ is empty).")
        return
    head = ("ticket", "kind", "route", "components", "done", "next", "command")
    widths = [max(len(str(r[c])) for r in rows + [head]) for c in range(len(head))]
    fmt = "  ".join("{:<%d}" % w for w in widths)
    print(fmt.format(*head))
    print(fmt.format(*("-" * w for w in widths)))
    for r in rows:
        print(fmt.format(*r))


if __name__ == "__main__":
    if len(sys.argv) > 1:
        print(json.dumps(ticket_info(normalize_id(sys.argv[1])), ensure_ascii=False, indent=2))
    else:
        board()
