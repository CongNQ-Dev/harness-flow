#!/usr/bin/env python3
"""AI Flow status board / next-stage resolver. Standard library only.

  python3 aiflow/scripts/aiflow_status.py            # board of every ticket
  python3 aiflow/scripts/aiflow_status.py PDT-2350   # one ticket as JSON (used by /aiflow)

Reads the YAML frontmatter of docs/aiflow/<ID>/status.md (see the template in
.claude/skills/aiflow-spec/status-template.md). Never writes anything.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ARTIFACTS = os.path.join(ROOT, "docs", "aiflow")

# n -> (id, Japanese name, skill that runs it, routes it belongs to)
STAGES = {
    1: ("ticket", "チケット正規化", "aiflow-spec", ("light", "full")),
    2: ("spec", "仕様作成", "aiflow-spec", ("light", "full")),
    3: ("plan", "修正プラン", "aiflow-plan", ("full",)),
    4: ("impl", "修正実装", "aiflow-impl", ("light", "full")),
    5: ("review", "レビュー・テストケース作成", "aiflow-review", ("full",)),
    6: ("deliver", "納品（PR作成）", "aiflow-review", ("light", "full")),
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


def ticket_info(tid):
    path = os.path.join(ARTIFACTS, tid, "status.md")
    if not os.path.exists(path):
        return {"ticket": tid, "exists": False, "next_stage": 1, "next_cmd": "aiflow-spec",
                "next_name": STAGES[1][1]}
    with open(path, encoding="utf-8") as f:
        fm = parse_frontmatter(f.read())
    done = fm.get("stage_done", 0)
    route = fm.get("route", "undecided")
    n = next_stage(done, route)
    info = dict(fm)
    info.update({
        "exists": True,
        "stage_done": done,
        "next_stage": n,
        "next_cmd": STAGES[n][2] if n else None,
        "next_name": STAGES[n][1] if n else "完了",
    })
    return info


def board():
    if not os.path.isdir(ARTIFACTS):
        print("No tickets yet (docs/aiflow/ is empty).")
        return
    rows = []
    for tid in sorted(os.listdir(ARTIFACTS)):
        if os.path.exists(os.path.join(ARTIFACTS, tid, "status.md")):
            i = ticket_info(tid)
            repos = i.get("repos") or []
            rows.append((tid, i.get("kind", "?"), i.get("route", "?"),
                         ",".join(r.replace("bump-", "") for r in repos) or "?",
                         f"{i['stage_done']}/6", i["next_name"],
                         f"/{i['next_cmd']}" if i["next_cmd"] else "-"))
    if not rows:
        print("No tickets yet (docs/aiflow/ is empty).")
        return
    head = ("ticket", "kind", "route", "repos", "done", "next", "command")
    widths = [max(len(str(r[c])) for r in rows + [head]) for c in range(len(head))]
    fmt = "  ".join("{:<%d}" % w for w in widths)
    print(fmt.format(*head))
    print(fmt.format(*("-" * w for w in widths)))
    for r in rows:
        print(fmt.format(*r))


if __name__ == "__main__":
    if len(sys.argv) > 1:
        print(json.dumps(ticket_info(sys.argv[1].upper()), ensure_ascii=False, indent=2))
    else:
        board()
