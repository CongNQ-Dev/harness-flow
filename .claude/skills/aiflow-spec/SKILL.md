---
name: aiflow-spec
description: AI Flow stages 1–2 for a Notion ticket (e.g. PDT-2350) — stage 1 normalizes the ticket into ticket.md, detects affected repos (backend/admin/mobile) from the workspace knowledge graph, and triages light/full route. For a small bug that triages light, stage 1 also writes spec.md inline in the same run (root cause + task, no dialogue — one combined approval, mirroring a bugfix fast-track) and creates the branch; full route stops after stage 1, and stage 2 runs separately with a full investigate-and-dialogue spec. Usually reached via /aiflow.
argument-hint: <TICKET-ID> [bug|feature]
---

# /aiflow-spec — チケット正規化（ステージ1）+ 仕様作成（ステージ2）

First read `.claude/skills/aiflow/conventions.md` and `aiflow/workflow.yaml`.

**Light route is a fast-track, not just "fewer stages later."** For a small
bug, Stage 1 itself writes `spec.md` inline — no separate dialogue stage, one
combined approval — the same shape as a bugfix triage-and-fix-write step:
decide fast-track vs. escalate with cited evidence, then either write the fix
directly or hand off to the full process. Full route, and any ticket that
isn't `kind: bug`, always stops after Stage 1 and gets the real Stage 2
dialogue on the next run. See §1.4 for exactly where the split happens.

## 0. Which stage?

Run `python3 aiflow/scripts/aiflow_status.py <ID>`.

- no `status.md` → **Stage 1**
- `stage_done: 1` → **Stage 2** (only reachable when route is `full` — a
  light ticket never rests at `stage_done: 1`; §1.7 either finishes both
  stages in one run or falls back to `full` before stopping)
- `stage_done >= 2` → already done: announce it (statement, not question) and
  run the stage `next_cmd` names instead — unless the user explicitly asked to
  redo the spec, in which case run Stage 2 (full route) or re-run Stage 1's
  §1.4 fast-track (light route) again.

If no ID was given: show the rows of `aiflow/selected-bugs/*.md` (Notion ticket
lists, one file per team) and ask which ticket to start with `AskUserQuestion`.

---

## Stage 1 — チケット正規化（省略版は仕様まで一括）

`python3 aiflow/scripts/aiflow_log.py start <ID> ticket`

### 1.1 Read the ticket

`AskUserQuestion` — how to read it:
- **Notion MCP** — search/fetch the page matching the ID (properties, body, comments, links).
- **ブラウザ（Side Peek）** — URL from `aiflow/selected-bugs/*.md`, append `?pm=s`,
  open it with the browser tool, ask the user to log in if needed, read
  everything including comments and screenshots.
- **貼り付け** — the user pastes the ticket text.

### Kind: bug or feature — decide with evidence, in this order

1. **Explicit argument.** `/aiflow <ID> feature` → `kind: feature`, decided,
   skip the rest.
2. **Notion's 種別 property**, if the ticket has one — this is the primary
   signal, not a fallback. A value naming a defect (不具合 / Bug / バグ) →
   `bug`. A value naming new or improved behavior (新機能 / Feature /
   Enhancement / 新規開発 / 保守開発) → `feature`. Record which value decided
   it in ticket.md's 基本情報 > 種別 row — that row is also the evidence for
   this decision, not just display text.
3. **No 種別, or it's ambiguous** (`Task`, `Chore`, `Improvement`, empty).
   Read the ticket body: it names *broken* current behavior with repro steps
   and an expected-vs-actual gap → `bug`. It only describes *desired* new
   behavior, with no current behavior being wrong → `feature`.
4. **Still unclear after step 3** — ask **one** `AskUserQuestion`
   (バグ対応 / 新規・保守開発) before continuing. Never guess past this point;
   `kind` decides the branch prefix, the ticket-template section headings,
   and — via `triage.light_requires_all` — whether light route is even
   possible for this ticket.

### 1.2 Normalize

Fill `.claude/skills/aiflow-spec/ticket-template.md` into
`docs/aiflow/<ID>/ticket.md`. Rules from the old flow, unchanged:
- only what the ticket says; missing → `—`; never guess;
- no clarifying questions here — unclear items go to 🔍 不明点 (resolved in
  §1.4 for the fast-track, or in Stage 2's dialogue for full route);
- duplicate check: compare title/summary/repro with every existing
  `docs/aiflow/*/ticket.md` (trial-period tickets were migrated there, marked
  `legacy: true`); list only real matches in 🔁 重複の可能性.

### 1.3 AI判定 — affected repos + triage (symptom-level evidence)

1. **Affected repos.** Query the workspace graph with the symptom and screen
   names, e.g. `graphify query "deeplink player open"`,
   `graphify query "admin seasons projectId filter"`. Follow `workflow.yaml`
   `contracts:` — a UI symptom whose data comes from the backend makes
   bump-backend 要確認 at least. Record the evidence (node / file:line / contract)
   for every row. The Notion 対象 column is a hint, not proof.
2. **Triage.** Run the `triage.light_requires_all` checklist from
   `workflow.yaml`, one row each, with evidence. Any ❌ or 不明 → `full`.
   Anything in `triage.sensitive_areas` → `full`.

This is a **preliminary** recommendation — cheap, symptom-level evidence
only. §1.4 re-checks it against real code before anything is finalized.

### 1.4 Light fast-track (small bug only) — investigate + write spec.md inline

**Only when 1.3's recommendation is `light` and `kind: bug`.** Otherwise skip
straight to §1.5 with the recommended route as-is (full route, and every
`kind: feature` ticket, always gets the real dialogue in Stage 2 — a feature
is never "small" in the sense this fast-track means).

Do this now, in the same run, instead of stopping — the whole point is one
gate, not two:

1. **Investigate (read-only).** `systematic-debugging` Phase 1–2: trace the
   symptom to the root cause across repos with `graphify query/path`, then
   read the exact lines. Every claim needs `repo/path:line`. No code edits,
   no tests yet.
2. **Re-check the triage checklist against what you found.** File count,
   whether a contract/schema actually changed, whether a second repo is
   really involved — the things symptom-level evidence in §1.3 couldn't see.
   - **Still passes** → continue to step 3.
   - **Fails now** → this was not actually a small bug. Stop the fast-track:
     set the route to `full`, go to §1.5 with the full-route gate (ticket +
     repos + route only — no spec work happened, nothing to show for it
     yet), and say what you found in the announcement, e.g. 「調査の結果、
     backend の契約変更も必要なため完全版に切り替えます」. Stage 2 runs the
     real dialogue on the next invocation, same as any full-route ticket.
3. **Resolve blocking unknowns minimally.** If 🔍 不明点 has something the
   fix genuinely cannot be written without, ask it as **one**
   `AskUserQuestion` — not a back-and-forth. If answering it would require
   comparing 2–3 real design approaches, that need is itself evidence this
   ticket needs the full dialogue: treat it as a triage failure and escalate
   per step 2 instead of guessing an approach.
4. **Write `docs/aiflow/<ID>/spec.md`** from
   `.claude/skills/aiflow-spec/spec-template.md`, its **light-fast-track
   form**: root cause (with evidence) + the one approach taken +
   "検討して却下した案" written as `該当なし` (no dialogue to compare
   approaches in — keep the heading, per the template's own rule) +
   実装タスク. Self-review inline against
   `spec-document-reviewer-prompt.md`'s checklist (no subagent — one repo,
   small enough to just re-read) and fix issues before the gate.

### 1.5 Gate — confirm with the user

**Full route** (recommended from the start, or escalated back to it in
§1.4.2): show a short summary — title, kind, repos with evidence, recommended
route with the failing checks — `AskUserQuestion`:
- **承認** — ticket, repos and route are correct
- **修正あり** — the user corrects something (then update ticket.md and ask again)

**Light fast-track** (§1.4 completed): one combined confirmation covering
ticket **and** spec **and** the task(s) together — show title, root cause
(with evidence), the fix, repos, and the task list in the same message, then
`AskUserQuestion`:
- **承認** — ticket・仕様・タスクすべて正しい → both files approved in this
  same turn
- **修正あり** — the user corrects something; fix inline (`ticket.md` and/or
  `spec.md`) and ask again, still in this run

If duplicates were found in §1.2, say so before either gate. Set
`ticket.md` frontmatter `status: approved` (both paths); on the fast-track
also set `spec.md`'s `status: approved`.

### 1.6 Branches

Slug: short English snake_case from the problem (e.g. `fix_duplicate_player_deeplink`).
Branch: `workflow.yaml` `branch.<kind>`. For **each** repo in `repos`:

```bash
git -C <repo> status --short            # dirty with unrelated files → stop and ask
git -C <repo> fetch origin <base_branch>
git -C <repo> checkout -b <branch> origin/<base_branch>   # exists already → git -C <repo> checkout <branch>
```

### 1.7 Close

**Full route (or escalated in §1.4.2):** write `docs/aiflow/<ID>/status.md`
from `status-template.md` (`stage_done: 1`, `next: aiflow-spec`, `route`,
`repos`, `branch`, `approvals.ticket`), then the standard close from
conventions §4 (commit → `aiflow_log.py end <ID> ticket` → announce → STOP):

> 「ステージ1/6（チケット正規化）完了。対象: <repos>、ルート: <light|full>、ブランチ `<branch>` を作成。次: ステージ2（仕様作成）— `/aiflow <ID>`」

**Light fast-track:** write `status.md` with **both** stages closed in this
one run — `stage_done: 2`, `next: aiflow-impl`, `approvals.ticket` and
`approvals.spec` both recorded from the single §1.5 confirmation — then the
same conventions §4 close, but note both `aiflow_log.py end` calls
(`ticket` and `spec` — both were started together, since no separate `spec`
stage-boundary happened):

```bash
python3 aiflow/scripts/aiflow_log.py end <ID> ticket
python3 aiflow/scripts/aiflow_log.py end <ID> spec
```

> 「ステージ1-2/6（チケット正規化・仕様）完了（省略版・対話なし）。対象:
> <repos>、根本原因: <一文>。`docs/aiflow/<ID>/spec.md` 承認済み。次: ステージ4
> （修正実装）— `/aiflow <ID>`」

---

## Stage 2 — 仕様作成（完全版のみ）

`python3 aiflow/scripts/aiflow_log.py start <ID> spec`

**Full route only.** This section never runs for a light-route ticket — its
spec was already written inline at §1.4. Refuse (and point at §1.4) if
`route: light` and `stage_done: 1` somehow coexist; that combination means
Stage 1 was interrupted mid-fast-track, not that this section should run.

Refuse if `ticket.md` is not `status: approved`. Check each repo is on the
ticket branch (`git -C <repo> branch --show-current`); if not, check it out
(never `-b`).

<HARD-GATE>
No code, no plan, no implementation in this stage. Output is spec.md only.
</HARD-GATE>

### 2.1 Investigate (read-only)

- **bug:** follow `systematic-debugging` Phase 1–2 **read-only** — trace from
  the symptom to the root cause across repos with `graphify query/path`, then
  read the exact lines. Every root-cause claim needs `repo/path:line`.
  Do not edit code; do not write tests yet.
- **feature:** explore the existing screens/APIs the feature touches, across
  repos, and the contracts involved.

### 2.2 Dialogue (the old brainstorming flow, kept)

1. Resolve every item in 🔍 不明点 — one `AskUserQuestion` at a time.
2. Propose 2–3 approaches with trade-offs, lead with the recommendation.
3. Present the design in short sections (root cause / fix / per-repo changes /
   contracts / behavior) and get agreement on each before moving on.
   Scale to the ticket: a small bug gets a few sentences per section.
4. If the change spans independent subsystems, propose splitting the ticket.

YAGNI: no unrequested features. Follow each repo's existing patterns
(`workflow.yaml` `repos.<repo>.notes`).

### 2.3 Write + self-review

Write `docs/aiflow/<ID>/spec.md` from `.claude/skills/aiflow-spec/spec-template.md`
(full form — 検討して却下した案 lists the dialogue's 2–3 compared approaches).
実装タスク here is written by Stage 3 (`/aiflow-plan`), not here — leave that
section as "`/aiflow-plan` で作成". Then review it yourself with
`spec-document-reviewer-prompt.md`'s checklist (for a spec touching 2+ repos,
dispatch it as a subagent instead) and fix issues inline.

### 2.4 Gate

`AskUserQuestion`: **承認** / **修正あり** (edit and re-run the self-review).
If the user adds a repo, create its branch as in §1.6 and add it to `repos`.

### 2.5 Close stage 2

`spec.md` `status: approved`; status.md `stage_done: 2`, `next: aiflow-plan`,
`approvals.spec`; then conventions §4:

> 「ステージ2/6（仕様作成）完了。`docs/aiflow/<ID>/spec.md` を承認済み。次: ステージ3（修正プラン）— `/aiflow <ID>`」
