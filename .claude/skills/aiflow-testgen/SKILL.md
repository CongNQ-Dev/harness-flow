---
name: aiflow-testgen
description: AI Flow test-case generator — writes docs/aiflow/<ID>/test-cases.md, numbered manual QA steps (real device for the app, browser for admin, API calls for backend, plus one end-to-end scenario for cross-repo tickets) from ticket.md, spec.md, plan.md and the diff. Runs inside stage 5 of /aiflow-review; can also be run alone after the spec is approved to prepare QA early or to regenerate.
argument-hint: <TICKET-ID>
---

# /aiflow-testgen — テストケース作成

First read `.claude/skills/aiflow/conventions.md` and `aiflow/workflow.yaml`.

## When it runs

- **Inside stage 5** — `/aiflow-review` calls this procedure after the final
  review. Stage bookkeeping (status.md, log, stop) belongs to `/aiflow-review`.
- **Standalone** (`/aiflow-testgen <ID>`) — allowed any time after `spec.md` is
  approved: before stage 4 so QA can prepare scenarios early, or after a change
  to regenerate. Standalone runs do **not** change `stage_done`; they only
  write test-cases.md and note it in status.md's 次のステップ line if relevant.
  Refuse if spec.md is not approved.

## Procedure

1. Gather: full `ticket.md`, full `spec.md`, the task list from `plan.md`
   (full route), and per repo the diff summary
   `git -C <repo> diff --stat origin/<base_branch>...HEAD` and
   `git -C <repo> log --oneline origin/<base_branch>..HEAD` — or "not
   implemented yet" before stage 4.
2. Dispatch `test-case-writer-prompt.md` (model: `models.full.test_case_writer`),
   filled with the above. Screen names and labels must match the real UI text —
   the writer may read the UI source strings to quote them exactly.
3. Check the result yourself: every acceptance criterion in spec.md is covered
   by at least one TC; a bug ticket has the original repro as a TC; a
   cross-repo ticket has the end-to-end TC; no internals or test names.
   Fix gaps by re-dispatching with the gap list.
4. If an older test-cases.md existed, keep its TC numbers stable where the
   case is unchanged, and list added/removed cases in the report.
5. Standalone only: commit the ticket folder and report the path and TC count.
