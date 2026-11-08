---
name: aiflow-testgen
description: AI Flow test-case generator — writes docs/aiflow/<ID>/test-cases.md, numbered manual QA steps tailored to each affected component's qa_surface (API request, browser, mobile device, desktop app, CLI, library snippet), plus one end-to-end scenario when several components are involved, from ticket.md, spec.md, plan.md and the diff. Runs inside stage 5 of /aiflow-review; can also run alone once the spec is approved, to prepare QA early or to regenerate.
argument-hint: <TICKET-ID>
---

# /aiflow-testgen — Test cases

First read `.claude/skills/aiflow/conventions.md` and `aiflow/workflow.yaml`.

## When it runs

- **Inside stage 5** — `/aiflow-review` calls this procedure after the final
  review. Stage bookkeeping (status.md, log, stop) belongs to `/aiflow-review`.
- **Standalone** (`/aiflow <ID> testcases`) — any time after `spec.md` is
  approved: before stage 4 so QA can prepare, or later to regenerate. It
  never changes `stage_done`. Refuse if spec.md isn't approved.

## Procedure

(Optional: the end-to-end scenario can be shown as a cross-component flow via
`.claude/skills/aiflow-visual/SKILL.md`; `test-cases.md` stays plain text.)

1. Gather: full `ticket.md`, full `spec.md`, the task list from `plan.md`
   (full route), and for each affected git root
   `git -C <root> diff --stat origin/<base_branch>...HEAD` and
   `git -C <root> log --oneline origin/<base_branch>..HEAD` — or "not
   implemented yet" before stage 4. Also each affected component's
   `qa_surface` from `workflow.yaml`.
2. Dispatch `test-case-writer-prompt.md` (model:
   `models.full.test_case_writer`) with the above and the output `language`.
   UI labels must match what the product actually shows — the writer may
   read the UI source strings to quote them exactly.
3. Check the result: every acceptance criterion in spec.md is covered by at
   least one test case; a bug has its original repro as a test case; a
   multi-component ticket has the end-to-end case; no internals or test
   names. Re-dispatch with the gap list if needed.
4. If an older test-cases.md exists, keep TC numbers stable where the case
   is unchanged, and list added/removed cases.
5. Standalone only: commit the ticket folder (conventions §3), report the
   path and the case count.
