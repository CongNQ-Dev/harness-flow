# architecture/<component>.md template

Written in `workflow.yaml` `language:` (translate the headings when that
isn't `en`).

```markdown
---
type: Architecture Overview
title: <component> — architecture overview
components: [<component>]
sources: [<path>/README.md, <path>/<manifest file>, graphify:<community ids>]
generated: {by: aiflow-wiki, at: YYYY-MM-DD}
status: draft
---

# <component> — architecture overview

## Stack
<language, framework, DB, key libraries — matching workflow.yaml `stack`,
confirmed against the real config files. Only what you verified.>

## Layers / modules
<the layer or module map, derived from the graph's communities and the
folder layout — bullets or a small diagram>

## Central modules
| Module | Responsibility | Main dependencies |
|---|---|---|
<the 3–6 most-connected modules>

## Boundaries
<responsibility boundaries visible in the code layout. Boundaries with other
components belong in contracts.md.>

## Things to know before changing this component
<only what helps understanding the architecture and isn't already in
workflow.yaml `notes`>
```

Every factual line needs a source: `component/path:line` or a graph node id
in `sources:`. No source → don't write the claim.
