# status.md template — the resume manifest

Every ticket folder has exactly one `docs/aiflow/<TICKET-ID>/status.md`. The
**frontmatter is machine-read** by `aiflow/scripts/aiflow_status.py` (that's
how `/aiflow <ID>` knows what runs next) — keep its keys exactly as below.
The body is the human view, in `workflow.yaml` `language:`.

Every stage skill, when it finishes, updates: `stage_done`, `next`,
`updated`, the matching `approvals:` line (gated stages), its table row, and
the "Next step" line.

````markdown
---
type: AI Flow Status
ticket: SHOP-12
title: Checkout total ignores the second coupon
kind: bug                      # bug | feature
route: full                    # undecided | light | full
components: [api]              # components this ticket changes
branch: bug/SHOP-12/fix_multi_coupon_total   # same name in every git root involved
stage_done: 1                  # last completed stage number (0-6)
next: aiflow-spec              # skill that runs the next stage
approvals:                     # gate records: human:<name> <date>
  ticket: human:alex 2026-09-25
prs:                           # filled at stage 6, one line per git root
delivery: none                 # none | draft (PRs open as drafts, CI review pending) | ready
updated: 2026-09-25
---

# AI Flow status — SHOP-12

**Kind:** bug　**Route:** full (1→2→3→4→5→6)
**Components:** api
**Branch:** bug/SHOP-12/fix_multi_coupon_total

| Stage | State | Output | Approved |
|---|---|---|---|
| 1. Ticket intake (/aiflow-spec) | ✅ done | ticket.md | alex 2026-09-25 |
| 2. Spec (/aiflow-spec) | ⬜ not started | — | — |
| 3. Plan (/aiflow-plan) | ⬜ not started | — | — |
| 4. Implementation (/aiflow-impl) | ⬜ not started | — | — |
| 5. Review & test cases (/aiflow-review) | ⬜ not started | — | — |
| 6. Delivery (/aiflow-review) | ⬜ not started | — | — |

**Next step:** `/aiflow SHOP-12` (runs `/aiflow-spec` stage 2: Spec)
````

(The example ticket is illustrative — use your own IDs and components.)

State markers: `✅ done` · `⏳ in progress (task 2/4)` · `⬜ not started` ·
`⏭️ skipped (light)` — translate the words, keep the emoji.

For `route: light`, rows 3 and 5 are `⏭️ skipped (light)` from the moment the
route is confirmed. If the route is upgraded light → full during §1.5 of
`aiflow-spec`, set them back to `⬜ not started`.

**The light fast-track closes rows 1 and 2 together.** `aiflow-spec` §1.5
writes `spec.md` during stage 1. When it does, write `stage_done: 2` directly
(a light ticket never rests at `stage_done: 1`) and mark **both** rows done
with the same date:

```markdown
| 1. Ticket intake (/aiflow-spec) | ✅ done | ticket.md | alex 2026-09-25 |
| 2. Spec (/aiflow-spec §1.5, light) | ✅ done | spec.md | alex 2026-09-25 |
```

`approvals:` records who approved a gated stage (ticket, spec, plan,
deliver). Use the name the user gives; if none, `human`. On the light
fast-track `approvals.ticket` and `approvals.spec` point at the same
confirmation — expected, not a duplicate.
