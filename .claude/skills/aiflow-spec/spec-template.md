# spec.md template

Written in `workflow.yaml` `language:` (translate the headings below when
that isn't `en`). Code, identifiers, paths and commands stay literal.

Two producers, one file shape:

- **Full route** — written by stage 2 (`aiflow-spec` §Stage 2) after the
  investigate-and-dialogue process. Stage 3 (`/aiflow-plan`) reads it next.
- **Light fast-track** — written by stage 1 (`aiflow-spec` §1.5) right after
  triage, no dialogue. Stage 4 (`/aiflow-impl`) reads it directly. Two
  sections differ: "Alternatives considered" is `n/a`, and "Implementation
  tasks" is filled in here instead of by stage 3.

Every section is required either way — write `n/a` rather than dropping one.

````markdown
---
type: Spec
ticket: <TICKET-ID>
kind: bug | feature
route: light | full
components: [<component>, ...]
sources: [ticket.md]               # + graph nodes / docs you relied on
generated: {by: aiflow-spec, at: YYYY-MM-DD}
status: draft                      # draft → approved at the gate
---

# Spec: <TICKET-ID> — <title>

## Root cause                      <!-- feature: "Background and goal" -->
- Problem A: `component/path/file.ext:123` — what happens and why (with evidence)
- Problem B: ...

## Approach
The approach taken and why (1–3 paragraphs).

### Alternatives considered
| Option | Why not |
|---|---|

## Changes per component           <!-- one subsection per affected component, in implementation order -->
### <component>
- Files: `path/...`
- Change: ...

## Contracts between components   <!-- API / schema / generated client / header... or "n/a" -->
| Contract | Owner | Consumers | Change | Backward compatible? | Regenerate command |
|---|---|---|---|---|---|

## Behavior
| Condition | Before | After |
|---|---|---|

## Acceptance criteria
- [ ] every acceptance criterion from ticket.md, as a verifiable statement

## Out of scope
- what this change deliberately does not do (link follow-up tickets)

## Implementation tasks            <!-- light route only; full route: "written by /aiflow-plan" -->
### Task 1: <name> (component: <component>)
- Files: `path/...`
- Test: the failing test to write → implement → run (`test_task` / `test` from workflow.yaml)
````

Self-check before asking for approval: no TBD/TODO; every acceptance
criterion in ticket.md appears; every affected component has a section;
every contract row names its regenerate command; file:line evidence for each
root cause.
