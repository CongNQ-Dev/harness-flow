# ticket.md template (output of stage 1)

Map the ticket's content into this structure. **Outside the "AI assessment"
section, don't analyze — write only what the ticket says; anything not found
is `—`.** Write it in `workflow.yaml` `language:`, translating the headings
below when that isn't `en` (conventions §7).

For `kind: feature`, "Steps to reproduce" and "Expected / actual" become
"Requirements" and "Current / desired"; rows that don't apply are `—`.

````markdown
---
type: Ticket
ticket: <TICKET-ID>
kind: bug                      # bug | feature
title: <exact ticket title>
components: [<component>]      # from the AI assessment, confirmed at the gate
source: <URL | paste>
generated: {by: aiflow-spec, at: YYYY-MM-DD}
status: draft                  # draft → approved at the stage 1 gate
---

# <TICKET-ID> — <exact title>

## Basic info

| Field | Value |
|---|---|
| ID | <TICKET-ID> |
| Link | <URL or —> |
| Type (from the ticket) | <e.g. Bug / Story / label — this is the evidence for `kind`> |
| Status | — |
| Priority / severity | — |
| Assignee | — |
| Platform / environment | <e.g. iOS & Android / staging / Chrome — or —> |
| Component (as the ticket states it) | — |

## Summary

<1–2 sentences from the user's point of view. No guessing at the cause.>

## Conditions

| Condition | Value |
|---|---|
| Who is affected | <all users / a segment / a role — or —> |
| Environment | <prod / staging / local — or —> |
| Version / build | — |
| Device / OS / browser | — |
| Frequency | <always / sometimes / under a condition — or —> |
| Feature flag / experiment | — |

## Steps to reproduce          <!-- feature: "Requirements" -->

Preconditions:
- <state needed before step 1>

Steps:
1.
2.

If the ticket has none: `— (not in the ticket)`.

## Expected / actual           <!-- feature: "Current / desired" -->

| | |
|---|---|
| **Expected** | <how it should behave> |
| **Actual** | <what happens now> |

## Acceptance criteria

- [ ] <a verifiable condition that proves the fix/feature is right>
- [ ] <an edge case or variation to check too>
- [ ] <a regression check — existing behavior still works>

If the ticket gives none, derive them from "Expected".

## Impact

| | |
|---|---|
| Screens / features / endpoints | — |
| Users affected | — |
| Data / money / security impact | <yes / no / —> |

## Related

| | |
|---|---|
| Designs | — |
| Related tickets | — |
| Related PRs/MRs | — |
| Screenshots / recordings | <yes / no> |
| Notable comments | — |

## Open questions

What the ticket doesn't say and the fix needs. Stage 2 (or the light
fast-track) starts here. `none` if there are none.

- [ ] —

## AI assessment (outside the ticket — analysis is allowed here)

### Affected components

One row per `workflow.yaml` `components:` entry — never a fixed list.

| Component | Verdict | Evidence (graph node / file:line / contract) |
|---|---|---|
| <each component> | affected / not affected / needs checking | — |

### Triage

Check `triage.light_requires_all` one row at a time. Any ❌ or unknown → `full`.

| Check | Result | Evidence |
|---|---|---|
| One component only | ✅ / ❌ | — |
| Expected files changed ≤ 3 | ✅ / ❌ / unknown | — |
| No API / schema / migration / contract change | ✅ / ❌ / unknown | — |
| Root cause located (file:line) | ✅ / ❌ | — |
| Kind is bug | ✅ / ❌ | — |
| No sensitive area touched | ✅ / ❌ | — |

**Recommended route:** `light` (1→2→4→6) / `full` (1→6)
**Confirmed route:** (filled in after the user confirms)

## Possible duplicates

Only if an existing `docs/aiflow/*/ticket.md` is a close match; otherwise
omit this section.

| Ticket | Why |
|---|---|
````

## Mapping guide

| In the ticket | Goes to |
|---|---|
| Title | title (verbatim) |
| Issue type / labels / "Type" property | Basic info > Type — and the evidence for `kind` |
| Platform tags in the title (`[iOS]`, `[Web]`) | Basic info > Platform |
| Status / priority / severity / assignee | Basic info |
| Environment, version, device, frequency in the body | Conditions |
| Repro steps in the body | Steps to reproduce |
| Expected / actual in the body | Expected / actual (+ derive acceptance criteria) |
| "What should be fixed" / requirements | Acceptance criteria |
| Comments | Related > Notable comments (+ Open questions if they raise one) |
| Attachments | Related > Screenshots |
