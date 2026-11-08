# Final Reviewer Prompt Template (stage 5, and review mode)

Dispatch once per ticket after every task passed its per-task reviews. It
reviews the **whole change across all components** against the plan — the
per-task reviewers only ever saw one task in one component, so cross-task and
cross-component problems are this reviewer's job.

```
Task tool (general-purpose, model: models.full.final_reviewer):
  description: "Final review for <TICKET-ID>"
  prompt: |
    You are the final reviewer for ticket <TICKET-ID>. Write your report in
    [LANGUAGE] (file:line references, identifiers and commands stay as-is).

    ## Requirements
    [FULL TEXT of spec.md]
    [FULL TEXT of plan.md's task list — or the spec's implementation tasks on the light route]

    ## The change, per git root
    For each git root below, run:
      git -C <root> diff --stat origin/<base_branch>...HEAD
      git -C <root> diff origin/<base_branch>...HEAD
    Git roots and their components: [e.g. "./ — components api, web (base main)"]

    If graphify-out/graph.json exists, use `graphify query` / `graphify path`
    to find callers and consumers of what changed before reading files one
    by one.

    ## Check
    1. Coverage — every requirement and acceptance criterion maps to changed
       code (name the file:line). List anything missing.
    2. Scope — nothing changed that the plan didn't ask for; no stray debug
       code, no unrelated formatting churn, no hand-edited generated files.
    3. Consistency across tasks — names, types, signatures agree.
    4. Contracts between components — for every contract in spec.md: owner
       and consumers agree (field names, types, nullability, headers);
       generated clients were regenerated, not hand-edited; old consumers
       still work if components ship separately.
    5. Regression risk — callers of changed code (use the graph) that the
       plan didn't mention; say whether each is safe and why.
    6. Tests — they assert behavior, and a bug's repro is covered.

    ## Output (write to docs/aiflow/<TICKET-ID>/reviews/final-review.md)
    ---
    type: Final Review
    ticket: <TICKET-ID>
    verdict: approved | issues
    generated: {by: aiflow-review, at: YYYY-MM-DD}
    ---
    # Final review: <TICKET-ID>          (headings translated to [LANGUAGE])
    ## Verdict: ✅ approved / ❌ needs fixes
    ## Requirement coverage (table: requirement | where implemented | state)
    ## Findings per component
    ## Contracts between components
    ## Regression risk
    ## Issues (Critical / Important / Minor, each with file:line)
    ## Summary for PR reviewers (3–5 lines — posted as the PR/MR comment)
```
