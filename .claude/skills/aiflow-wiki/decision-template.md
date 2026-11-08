# architecture/decisions/<slug>.md template

Used by `/aiflow-wiki` (initial write) and by `aiflow-spec` when a ticket's
spec records a real architecture decision (a cheap append — it reuses that
ticket's own investigation, no repo-wide re-scan). Written in
`workflow.yaml` `language:`.

```markdown
---
type: Decision
title: <one sentence, active voice>
components: [<component>, ...]
sources: [docs/aiflow/<TICKET-ID>/spec.md, <component>/path:line]
generated: {by: aiflow-wiki | aiflow-spec, at: YYYY-MM-DD}
status: draft
---

# <title>

## Context
<why this decision was needed — 1–3 sentences>

## Decision
<what was decided>

## Why
<why this approach; rejected alternatives in one line each>

## Consequences
<what this constrains from now on — future changes, components affected>
```

From `aiflow-spec`: only when the spec's approach is a real architectural
choice (a new contract, a pattern change, a boundary between components) —
never for a routine fix. When in doubt, don't write one: a missing entry is
recoverable, a noisy wiki isn't.
