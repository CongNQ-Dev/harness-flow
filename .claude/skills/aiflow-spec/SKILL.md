---
name: aiflow-spec
description: AI Flow stages 1–2 for a Notion ticket (e.g. PDT-2350) — stage 1 normalizes the ticket into ticket.md, detects affected repos (backend/admin/mobile) from the workspace knowledge graph, triages light/full route, creates the branch in each repo; stage 2 writes spec.md (root cause or feature design) through dialogue. Stops after each stage. Usually reached via /aiflow.
argument-hint: <TICKET-ID> [bug|feature]
---

# /aiflow-spec — チケット正規化（ステージ1）+ 仕様作成（ステージ2）

First read `.claude/skills/aiflow/conventions.md` and `aiflow/workflow.yaml`.

## 0. Which stage?

Run `python3 aiflow/scripts/aiflow_status.py <ID>`.

- no `status.md` → **Stage 1**
- `stage_done: 1` → **Stage 2**
- `stage_done >= 2` → already done: announce it (statement, not question) and
  run the stage `next_cmd` names instead — unless the user explicitly asked to
  redo the spec, in which case run Stage 2 again.

If no ID was given: show the rows of `aiflow/selected-bugs/*.md` (Notion ticket
lists, one file per team) and ask which ticket to start with `AskUserQuestion`.

---

## Stage 1 — チケット正規化

`python3 aiflow/scripts/aiflow_log.py start <ID> ticket`

### 1.1 Read the ticket

`AskUserQuestion` — how to read it:
- **Notion MCP** — search/fetch the page matching the ID (properties, body, comments, links).
- **ブラウザ（Side Peek）** — URL from `aiflow/selected-bugs/*.md`, append `?pm=s`,
  open it with the browser tool, ask the user to log in if needed, read
  everything including comments and screenshots.
- **貼り付け** — the user pastes the ticket text.

Kind: `bug` unless the argument says `feature` or the Notion ticket is a
new/maintenance development item (新規・保守開発). Ask only if it is really unclear.

### 1.2 Normalize

Fill `.claude/skills/aiflow-spec/ticket-template.md` into
`docs/aiflow/<ID>/ticket.md`. Rules from the old flow, unchanged:
- only what the ticket says; missing → `—`; never guess;
- no clarifying questions here — unclear items go to 🔍 不明点 (stage 2 handles them);
- duplicate check: compare title/summary/repro with every existing
  `docs/aiflow/*/ticket.md` (trial-period tickets were migrated there, marked
  `legacy: true`); list only real matches in 🔁 重複の可能性.

### 1.3 AI判定 — affected repos + triage (the only analysis in stage 1)

1. **Affected repos.** Query the workspace graph with the symptom and screen
   names, e.g. `graphify query "deeplink player open"`,
   `graphify query "admin seasons projectId filter"`. Follow `workflow.yaml`
   `contracts:` — a UI symptom whose data comes from the backend makes
   bump-backend 要確認 at least. Record the evidence (node / file:line / contract)
   for every row. The Notion 対象 column is a hint, not proof.
2. **Triage.** Run the `triage.light_requires_all` checklist from
   `workflow.yaml`, one row each, with evidence. Any ❌ or 不明 → `full`.
   Anything in `triage.sensitive_areas` → `full`.

### 1.4 Gate — confirm with the user

Show a short summary (title, kind, repos with evidence, recommended route with
the failing checks) and ask with `AskUserQuestion`:
- **承認** — ticket, repos and route are correct
- **修正あり** — the user corrects something (then update ticket.md and ask again)

If duplicates were found, say so in the same message.
Unless `triage.auto_light: true` and every check is ✅, the user confirms the
route. Set `ticket.md` frontmatter `status: approved`, write 確定ルート.

### 1.5 Branches

Slug: short English snake_case from the problem (e.g. `fix_duplicate_player_deeplink`).
Branch: `workflow.yaml` `branch.<kind>`. For **each** repo in `repos`:

```bash
git -C <repo> status --short            # dirty with unrelated files → stop and ask
git -C <repo> fetch origin <base_branch>
git -C <repo> checkout -b <branch> origin/<base_branch>   # exists already → git -C <repo> checkout <branch>
```

### 1.6 Close stage 1

Write `docs/aiflow/<ID>/status.md` from `status-template.md` (`stage_done: 1`,
`next: aiflow-spec`, `route`, `repos`, `branch`, `approvals.ticket`), then the
standard close from conventions §4 (commit → `aiflow_log.py end <ID> ticket` →
announce → STOP):

> 「ステージ1/6（チケット正規化）完了。対象: <repos>、ルート: <light|full>、ブランチ `<branch>` を作成。次: ステージ2（仕様作成）— `/aiflow <ID>`」

---

## Stage 2 — 仕様作成

`python3 aiflow/scripts/aiflow_log.py start <ID> spec`

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

Write `docs/aiflow/<ID>/spec.md` from `.claude/skills/aiflow-spec/spec-template.md`.
For the **light** route also fill 実装タスク (stage 3 is skipped, so stage 4
implements straight from it). Then review it yourself with
`spec-document-reviewer-prompt.md`'s checklist (for a full-route spec touching
2+ repos, dispatch it as a subagent instead) and fix issues inline.

**Re-triage.** If the spec now fails any light check (more files, a contract
change, a second repo), switch the route to `full`: update `route:` in
status.md/ticket.md, rows 3 and 5 back to ⬜, and tell the user why. Never
downgrade full → light without asking.

### 2.4 Gate

`AskUserQuestion`: **承認** / **修正あり** (edit and re-run the self-review).
If the user adds a repo, create its branch as in 1.5 and add it to `repos`.

### 2.5 Close stage 2

`spec.md` `status: approved`; status.md `stage_done: 2`, `next:` = the next
stage's skill (`aiflow-plan` for full, `aiflow-impl` for light),
`approvals.spec`; then conventions §4:

> 「ステージ2/6（仕様作成）完了。`docs/aiflow/<ID>/spec.md` を承認済み。次: ステージ3（修正プラン）— `/aiflow <ID>`」
> (light: 「次: ステージ4（修正実装）— `/aiflow <ID>`」)
