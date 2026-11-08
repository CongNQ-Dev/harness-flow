#!/usr/bin/env python3
"""Per-stage usage log -> docs/aiflow/<ID>/log.json. Standard library only.

  aiflow_log.py start <ID> <stage>     # called by a stage skill when it begins
  aiflow_log.py end   <ID> <stage>     # called by a stage skill right before it stops
  aiflow_log.py hook                   # Claude Code Stop hook (JSON on stdin)
  aiflow_log.py summary <ID>           # print per-stage totals (re-prices with the current pricing.json)

How it works: `start` drops a marker in aiflow/.state/. The Stop hook runs at
the end of every turn; for each open marker it sums token usage from this
session's transcript (and its subagent transcripts) since the stage started,
and rewrites that stage's entry in log.json. After `end`, the next hook run
writes the final numbers and removes the marker. Cost is an API-equivalent
estimate from aiflow/pricing.json. Failures are swallowed: logging must never
break the flow.
"""
import datetime as dt
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
STATE = os.path.join(ROOT, "aiflow", ".state")
def _artifacts_dir():
    try:
        with open(os.path.join(ROOT, "aiflow", "workflow.yaml"), encoding="utf-8") as f:
            for line in f:
                m = re.match(r"^artifacts_dir:\s*([^#\s]+)", line)
                if m:
                    return m.group(1).strip("'\"")
    except OSError:
        pass
    return "docs/aiflow"


ARTIFACTS = os.path.join(ROOT, _artifacts_dir())
PRICING = os.path.join(ROOT, "aiflow", "pricing.json")


def now():
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")


def parse_ts(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))


def marker_path(tid, stage):
    return os.path.join(STATE, f"{tid}__{stage}.json")


def cmd_start(tid, stage):
    os.makedirs(STATE, exist_ok=True)
    with open(marker_path(tid, stage), "w") as f:
        json.dump({"ticket": tid, "stage": stage, "started_at": now(), "session_id": None,
                   "closing": False}, f)
    print(f"aiflow log: started {tid} {stage}")


def cmd_end(tid, stage):
    p = marker_path(tid, stage)
    if not os.path.exists(p):
        print(f"aiflow log: no open run for {tid} {stage}")
        return
    with open(p) as f:
        m = json.load(f)
    m.update({"closing": True, "ended_at": now()})
    with open(p, "w") as f:
        json.dump(m, f)
    print(f"aiflow log: {tid} {stage} will be finalized at end of turn")


def usage_since(transcript, since, until):
    """Sum usage per model across the main transcript and subagent transcripts."""
    files = [transcript]
    base = transcript[:-6] if transcript.endswith(".jsonl") else transcript
    files += glob.glob(os.path.join(base, "subagents", "*.jsonl"))
    per_msg = {}
    for path in files:
        try:
            with open(path, encoding="utf-8") as f:
                for line in f:
                    if '"usage"' not in line:
                        continue
                    try:
                        e = json.loads(line)
                    except ValueError:
                        continue
                    msg = e.get("message") or {}
                    u = msg.get("usage")
                    ts = e.get("timestamp")
                    if not u or not ts:
                        continue
                    t = parse_ts(ts)
                    if t < since or t > until:
                        continue
                    # streamed messages repeat their usage; keep the last line per message id
                    per_msg[(path, msg.get("id") or e.get("uuid"))] = (msg.get("model", "unknown"), u)
        except OSError:
            continue
    models = {}
    for model, u in per_msg.values():
        if model.startswith("<"):  # synthetic entries
            continue
        cc = u.get("cache_creation") or {}
        w1h = cc.get("ephemeral_1h_input_tokens", 0)
        w5m = cc.get("ephemeral_5m_input_tokens", u.get("cache_creation_input_tokens", 0) - w1h)
        agg = models.setdefault(model, {"calls": 0, "input": 0, "output": 0,
                                        "cache_write_5m": 0, "cache_write_1h": 0, "cache_read": 0})
        agg["calls"] += 1
        agg["input"] += u.get("input_tokens", 0)
        agg["output"] += u.get("output_tokens", 0)
        agg["cache_write_5m"] += max(w5m, 0)
        agg["cache_write_1h"] += w1h
        agg["cache_read"] += u.get("cache_read_input_tokens", 0)
    return models


def _prices():
    try:
        with open(PRICING) as f:
            return json.load(f)["models"]
    except (OSError, ValueError, KeyError):
        return {}


def cost(models, prices=None):
    """(USD estimate or None, [models with no price]). Longest-prefix match, so
    claude-sonnet-5 never prices claude-sonnet-5-5. One unpriced model makes the
    whole estimate None — a partial sum would look like a real, smaller cost."""
    prices = _prices() if prices is None else prices
    total, unpriced = 0.0, []
    for model, agg in models.items():
        key = max((k for k in prices if model.startswith(k)), key=len, default=None)
        if key is None:
            unpriced.append(model)
            continue
        total += sum(agg[k] * prices[key][k] for k in ("input", "output", "cache_write_5m",
                                                        "cache_write_1h", "cache_read")) / 1e6
    return (None if unpriced or not models else round(total, 4)), unpriced


def reprice(log):
    """Recompute every run's estimate from its stored token counts, so adding a
    model to pricing.json fixes old entries too."""
    prices = _prices()
    for r in log["runs"]:
        r["cost_usd_estimate"], r["unpriced_models"] = cost(r.get("models", {}), prices)
        if not r["unpriced_models"]:
            del r["unpriced_models"]
    costs = [r["cost_usd_estimate"] for r in log["runs"]]
    log["total_cost_usd_estimate"] = (None if not costs or None in costs
                                      else round(sum(costs), 4))


def write_entry(m, models, session_id, until):
    path = os.path.join(ARTIFACTS, m["ticket"], "log.json")
    if not os.path.isdir(os.path.dirname(path)):
        return  # ticket folder not created yet (stage 1 before first write)
    try:
        with open(path) as f:
            log = json.load(f)
    except (OSError, ValueError):
        log = {"ticket": m["ticket"], "runs": []}
    totals = {k: sum(a[k] for a in models.values())
              for k in ("calls", "input", "output", "cache_write_5m", "cache_write_1h", "cache_read")}
    entry = {
        "stage": m["stage"],
        "started_at": m["started_at"],
        "ended_at": m.get("ended_at") if m.get("closing") else None,
        "wall_clock_sec": int((until - parse_ts(m["started_at"])).total_seconds()),
        "session_id": session_id,
        "models": models,
        "totals": totals,
        "cost_usd_estimate": None,  # set by reprice()
    }
    log["runs"] = [r for r in log["runs"]
                   if not (r["stage"] == m["stage"] and r["started_at"] == m["started_at"])]
    log["runs"].append(entry)
    log["runs"].sort(key=lambda r: r["started_at"])
    reprice(log)
    with open(path, "w") as f:
        json.dump(log, f, ensure_ascii=False, indent=2)


def cmd_hook():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return
    transcript, sid = payload.get("transcript_path"), payload.get("session_id")
    if not transcript or not os.path.exists(transcript):
        return
    for mp in glob.glob(os.path.join(STATE, "*.json")):
        with open(mp) as f:
            m = json.load(f)
        if m.get("session_id") is None:
            # claim the marker if this session is the one that ran `start` for it
            with open(transcript, encoding="utf-8") as f:
                if f"aiflow_log.py start {m['ticket']} {m['stage']}" not in f.read():
                    continue
            m["session_id"] = sid
            with open(mp, "w") as f:
                json.dump(m, f)
        if m["session_id"] != sid:
            continue
        until = dt.datetime.now(dt.timezone.utc)
        models = usage_since(transcript, parse_ts(m["started_at"]), until)
        write_entry(m, models, sid, until)
        if m.get("closing"):
            os.remove(mp)


def cmd_summary(tid):
    path = os.path.join(ARTIFACTS, tid, "log.json")
    if not os.path.exists(path):
        print(f"No log for {tid}")
        return
    with open(path) as f:
        log = json.load(f)
    reprice(log)
    with open(path, "w") as f:
        json.dump(log, f, ensure_ascii=False, indent=2)
    usd = lambda v: f"{v:.2f}" if v is not None else "n/a"
    print(f"{'stage':<10}{'min':>6}{'calls':>7}{'in+cache':>12}{'output':>10}{'USD(est)':>10}")
    for r in log["runs"]:
        t = r["totals"]
        inp = t["input"] + t["cache_write_5m"] + t["cache_write_1h"] + t["cache_read"]
        print(f"{r['stage']:<10}{r['wall_clock_sec'] // 60:>6}{t['calls']:>7}{inp:>12}"
              f"{t['output']:>10}{usd(r['cost_usd_estimate']):>10}")
    print(f"total USD (API-equivalent estimate): {usd(log['total_cost_usd_estimate'])}")
    missing = sorted({m for r in log["runs"] for m in r.get("unpriced_models", [])})
    if missing:
        print(f"n/a = no price for {', '.join(missing)} — add it to aiflow/pricing.json, "
              f"then run summary again.")


if __name__ == "__main__":
    try:
        a = sys.argv[1:]
        if a[:1] == ["start"] and len(a) == 3:
            cmd_start(a[1].upper(), a[2])
        elif a[:1] == ["end"] and len(a) == 3:
            cmd_end(a[1].upper(), a[2])
        elif a[:1] == ["hook"]:
            cmd_hook()
        elif a[:1] == ["summary"] and len(a) == 2:
            cmd_summary(a[1].upper())
        else:
            print(__doc__)
    except Exception as exc:  # never break the flow because of logging
        print(f"aiflow log: skipped ({exc})", file=sys.stderr)
    sys.exit(0)
