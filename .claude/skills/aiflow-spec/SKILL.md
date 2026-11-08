---
name: aiflow-spec
description: AI Flow stages 1–2 for a ticket — stage 1 reads the ticket (from a connected ticket-system MCP such as Notion, Jira, Linear, GitHub or GitLab, the gh/glab CLI, or pasted text), normalizes it into ticket.md, decides bug vs feature, detects which components it affects, triages light vs full route, and creates the ticket branch. For a small bug on the light route, stage 1 also writes spec.md inline (root cause + task, no dialogue, one combined approval). Full route stops after stage 1; stage 2 then writes spec.md through an investigate-and-dialogue process. Usually reached via /aiflow.
argument-hint: <TICKET-ID> [feature]
---

# /aiflow-spec — Ticket intake (stage 1) + Spec (stage 2)

First read `.claude/skills/aiflow/conventions.md` and `aiflow/workflow.yaml`.

**The light route is a fast-track, not just "fewer stages later."** For a
small bug, stage 1 itself writes `spec.md` inline — no separate dialogue, one
combined approval: triage, then either write the fix directly or hand off to
the full process. The full route, and every `kind: feature` ticket, stops
after stage 1 and gets the real stage 2 dialogue on the next run. §1.5 is
where the split happens.

## 0. Which stage?

`python3 aiflow/scripts/aiflow_status.py <ID>`:

- no `status.md` → **Stage 1**. If `docs/aiflow/<ID>/ticket.md` already
  exists, an earlier stage-1 run was interrupted: **resume it, don't start
  over** — take `kind`, title and components from that ticket.md, check
  out the ticket branch right away (§1.3, using the `branch:` slug if one
  was recorded), skip §1.1–1.3 unless the user says the ticket changed,
  and reuse a draft `spec.md` in §1.5 (re-verify its evidence, don't
  rewrite it). Say so: "PROJ-12 has an unfinished stage 1 (ticket.md from
  <date>) — resuming from it."
- `stage_done: 1` → **Stage 2** (only reachable on the full route — a light
  ticket never rests at `stage_done: 1`)
- `stage_done >= 2` → already done: say so (a statement) and run `next_cmd`
  instead — unless the user explicitly asked to redo the spec: then Stage 2
  (full) or §1.5 (light) again.

No ID given: if `tickets.lists_dir` has `.md` files, show their rows and ask
which ticket to start (`AskUserQuestion`); otherwise ask for the ID.

---

## Stage 1 — Ticket intake (on the light route, spec too)

`python3 aiflow/scripts/aiflow_log.py start <ID> ticket`

### 1.1 Read the ticket

Use `workflow.yaml` `tickets.source`. If it names a specific source, use it
without asking. If it's `ask`, build the options from **what is actually
available in this session** and ask with `AskUserQuestion` (max 4 options,
"Other" is added automatically):

1. Ticket-system MCP servers that are connected — look at the loaded or
   deferred tool names: `notion`, `jira` / `atlassian`, `linear`, `github`,
   `gitlab`, `asana`, `clickup`, `youtrack`, `shortcut`. List up to 3,
   preferring the one the ID's format suggests (`#123` → GitHub/GitLab;
   `ABC-123` → Jira/Linear).
2. If there's room and no matching MCP: the issue tracker of a component's
   own host through its CLI — `gh issue view <n> -R <owner/repo> --comments`
   or `glab issue view <n> -R <group/project> --comments`.
3. **Always last: "Paste the ticket text"** — the user pastes title, body,
   repro steps, comments.

Whatever the source, read everything: title, type/labels, status, priority,
body, repro steps, expected vs actual, attachments/screenshots, comments,
links. If the source needs a login, tell the user and wait.

### 1.2 Kind: bug or feature — decide with evidence, in this order

1. `/aiflow <ID> feature` → `feature`. Decided.
2. The ticket system's own **type field** (Jira issue type, Linear/GitHub/GitLab
   labels, a Notion "Type" property, ...): a defect value (Bug, Defect,
   Incident, 不具合, ...) → `bug`; a new/changed-behavior value (Feature,
   Story, Enhancement, Improvement, ...) → `feature`. Record which value
   decided it in ticket.md — it's the evidence.
3. No type field, or it's ambiguous (Task, Chore, empty): the body describes
   *broken current behavior* with repro steps / expected-vs-actual → `bug`;
   it only describes *desired new behavior* → `feature`.
4. Still unclear → one `AskUserQuestion` (bug fix / new feature). Never
   guess: `kind` sets the branch prefix, the template sections, and whether
   the light route is possible at all.

### 1.3 Ticket branch first, then normalize

**Check out the ticket branch before writing any file**, so nothing of this
ticket ever lands on a base branch — not even a draft. `kind` is known now
(§1.2), which is all the branch name needs:

- Slug: short English snake_case from the ticket title
  (`fix_duplicate_modal_on_deeplink`). Branch: `workflow.yaml`
  `branch.<kind>`.
- In the repo that holds the ticket docs — the wrapper (`.`) for
  **workspace**, the project repo for **in-repo** — run §1.6's commands now
  (base: `workspace_repo.base_branch` for the wrapper, the component's
  `base_branch` for in-repo). Say it in one line: "Switched to
  `bug/SHOP-12/fix_…` (wrapper) — the ticket docs go there."
- Component repos (workspace) get the same branch in §1.6, once §1.4 knows
  which ones are affected.

Then fill `.claude/skills/aiflow-spec/ticket-template.md` into
`docs/aiflow/<ID>/ticket.md`, in `language` (conventions §7):

- only what the ticket says; missing → `—`; never guess;
- no clarifying questions here — unclear items go to "Open questions"
  (resolved in §1.5 on the fast-track, or in stage 2's dialogue);
- duplicate check: compare title/summary/repro with every existing
  `docs/aiflow/*/ticket.md`; list only real matches under "Possible duplicates".

### 1.4 AI assessment — affected components + triage (symptom-level)

1. **Affected components.** One row per entry in `workflow.yaml`
   `components:` (never a fixed list). Query the knowledge graph with the
   symptom and screen/endpoint names if it exists; follow `contracts:` — a
   symptom whose data comes from a contract's owner makes that owner at
   least "needs checking". Evidence for every row (graph node / file:line /
   contract). What the ticket itself says is a hint, not proof.
2. **Triage.** Run `triage.light_requires_all`, one row each, with evidence.
   Any ❌ or unknown → `full`. Anything in `triage.sensitive_areas` → `full`.

This is a **preliminary** recommendation. §1.5 re-checks it against real
code before anything is finalized.

### 1.5 Light fast-track (small bug only) — investigate + write spec.md inline

**Only when §1.4 recommends `light` and `kind: bug`.** Otherwise go to §1.6
with the recommended route (full route and every feature always get the real
stage 2 dialogue).

Do this now, in the same run — one gate, not two:

1. **Investigate (read-only).** `systematic-debugging` phases 1–2: trace the
   symptom to the root cause with the graph (if any), then read the exact
   lines. Every claim needs `component/path:line`. No edits, no tests yet.
2. **Re-check triage against what you found** (real file count, whether a
   contract/schema actually changes, whether a second component is involved).
   - Still passes → step 3.
   - Fails → not a small bug after all. Set route `full`, go to §1.6 with the
     full-route gate, and say why ("the fix also needs an API contract change
     — switching to the full route"). Stage 2 runs the dialogue next time.
3. **Resolve blocking unknowns minimally.** If an open question truly blocks
   writing the fix, ask it as **one** `AskUserQuestion`. If answering needs a
   comparison of 2–3 real approaches, that's evidence for the full route:
   escalate per step 2 instead of guessing.
4. **Write `docs/aiflow/<ID>/spec.md`** from `spec-template.md`, light form:
   root cause (with evidence) + the one approach taken + "Alternatives
   considered" as `n/a` (no dialogue to compare in — keep the heading) +
   "Implementation tasks". Self-review against
   `spec-document-reviewer-prompt.md`'s checklist inline and fix issues.
5. **Optional wiki entry.** Only if the approach is a real architectural
   choice (rare for a small bug) and `wiki/` exists: add one file from
   `.claude/skills/aiflow-wiki/decision-template.md` to
   `wiki/architecture/decisions/`. Otherwise skip silently.

### 1.6 Branches

Slug: short English snake_case from the problem (`fix_duplicate_modal_on_deeplink`).
Branch: `workflow.yaml` `branch.<kind>`. For **each distinct git root** among
the affected components (conventions §1):

```bash
git -C <root> status --short            # unrelated changes → stop and ask
git -C <root> fetch origin <base_branch>
git -C <root> checkout -b <branch> --no-track origin/<base_branch>   # exists → git -C <root> checkout <branch>
```

`--no-track` matters: without it git sets the new branch's upstream to
`origin/<base_branch>`, and a plain `git push` then tries to push the ticket
branch **to the base branch** (rejected by branch protection, and never what
we want). Delivery pushes with `git push -u origin <branch>`, which sets the
right upstream.

The repo holding the docs is already on the branch (§1.3) — skip it here.
**workspace:** the wrapper branched from `workspace_repo.base_branch` (no
remote → from the local base branch); now give every affected component repo
the **same branch name**. Keep the slug chosen in §1.3 even if the
investigation suggests a better one.

### 1.7 Gate — confirm with the user

**Full route** (from the start, or escalated in §1.5.2): summary — title,
kind (+ evidence), components (+ evidence), recommended route (+ failing
checks) — then `AskUserQuestion`: **Approve** / **Needs changes** (update
ticket.md and ask again).

**Light fast-track** (§1.5 completed): one combined confirmation for ticket
**and** spec **and** tasks — title, root cause with evidence, the fix, the
component, the task list — then **Approve** (both files approved now) /
**Needs changes** (fix inline, ask again).

Mention possible duplicates before either gate. Set `ticket.md` `status:
approved` (both paths) and, on the fast-track, `spec.md` `status: approved`.
Unless `triage.auto_light: true` and every check passed, the user confirms
the route.

### 1.8 Close

**Full route (or escalated):** write `status.md` from `status-template.md`
(`stage_done: 1`, `next: aiflow-spec`, `kind`, `route`, `components`,
`branch`, `approvals.ticket`), then conventions §5 (commit → `aiflow_log.py
end <ID> ticket` → announce → STOP):
"Stage 1/6 (Ticket intake) done. Components: <list>. Route: full. Branch
`<branch>`. Next: stage 2 (Spec) — `/aiflow <ID>`."

**Light fast-track:** `status.md` with both stages closed — `stage_done: 2`,
`next: aiflow-impl`, `approvals.ticket` and `approvals.spec` from the one
confirmation — then the same close with **both** log calls:

```bash
python3 aiflow/scripts/aiflow_log.py end <ID> ticket
python3 aiflow/scripts/aiflow_log.py end <ID> spec
```

"Stages 1–2/6 (Ticket intake + Spec) done — light route, no dialogue.
Component: <name>. Root cause: <one sentence>. Next: stage 4
(Implementation) — `/aiflow <ID>`."

---

## Stage 2 — Spec (full route only)

`python3 aiflow/scripts/aiflow_log.py start <ID> spec`

Never runs for a light ticket (its spec was written in §1.5). If `route:
light` and `stage_done: 1` coexist, stage 1 was interrupted mid-fast-track —
re-run §1.5 instead.

Refuse if `ticket.md` isn't `status: approved`. Check each affected git root
is on the ticket branch; if not, check it out (never `-b`).

<HARD-GATE>
No code, no plan, no implementation in this stage. Output is spec.md only.
</HARD-GATE>

### 2.1 Investigate (read-only)

- **bug:** `systematic-debugging` phases 1–2, read-only — trace the symptom
  to the root cause across components (graph first if it exists), then read
  the exact lines. Every root-cause claim needs `component/path:line`.
- **feature:** explore the existing screens/endpoints/modules the feature
  touches, across components, and the contracts involved.

### 2.2 Dialogue

1. Resolve every open question — one `AskUserQuestion` at a time.
2. Propose 2–3 approaches with trade-offs; lead with the recommendation.
3. Present the design in short sections (root cause or goal / approach /
   per-component changes / contracts / behavior) and get agreement on each.
   Scale to the ticket — a small change gets a few sentences per section.
4. If it spans independent subsystems, propose splitting the ticket.
5. When a question is visual (UI layouts, a flow, a cross-component
   diagram), load `.claude/skills/aiflow-visual/SKILL.md` and offer the
   browser companion for that question; words-only questions stay here.

YAGNI. Follow each component's existing patterns and `notes`.

### 2.3 Write + self-review

Write `docs/aiflow/<ID>/spec.md` from `spec-template.md`, full form
("Alternatives considered" lists the dialogue's approaches; "Implementation
tasks" says "written by /aiflow-plan"). Self-review with
`spec-document-reviewer-prompt.md`'s checklist (dispatch it as a subagent for
a spec touching 2+ components) and fix inline.

**Optional wiki entry.** If the approach is a real architectural decision (a
new contract, a boundary change, a pattern others should follow) and `wiki/`
exists, add one file from `.claude/skills/aiflow-wiki/decision-template.md`
to `wiki/architecture/decisions/`. Otherwise skip silently.

### 2.4 Gate

`AskUserQuestion`: **Approve** / **Needs changes** (edit, re-run the
self-review). If the user adds a component, create its branch as in §1.6.

### 2.5 Close

`spec.md` `status: approved`; `status.md` `stage_done: 2`, `next: aiflow-plan`,
`approvals.spec`; conventions §5: "Stage 2/6 (Spec) done. Next: stage 3
(Plan) — `/aiflow <ID>`."
