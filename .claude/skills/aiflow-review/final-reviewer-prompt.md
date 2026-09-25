# Final Reviewer Prompt Template (stage 5)

Dispatch once per ticket after every task passed its per-task reviews. It
reviews the **whole change across all repos** against the plan — the per-task
reviewers only ever saw one task in one repo, so cross-task and cross-repo
problems are this reviewer's job.

```
Task tool (general-purpose, model: models.full.final_reviewer):
  description: "Final review for <TICKET-ID>"
  prompt: |
    You are the final reviewer for ticket <TICKET-ID>. Write your report in
    Japanese (file:line references, identifiers and commands stay as-is).

    ## Requirements
    [FULL TEXT of spec.md]
    [FULL TEXT of plan.md task list — or spec.md 実装タスク on the light route]

    ## The change, per repo
    For each repo below run, from the workspace root:
      git -C <repo> diff --stat origin/<base_branch>...HEAD
      git -C <repo> diff origin/<base_branch>...HEAD
    Repos: [bump-backend (base develop), bump-mobile-app (base main), ...]

    If graphify-out/graph.json exists at the workspace root, use
    `graphify query` / `graphify path` to find callers and consumers of what
    changed before reading files one by one.

    ## Check
    1. Coverage — every requirement and acceptance criterion maps to changed
       code (name the file:line). List anything missing.
    2. Scope — nothing changed that the plan did not ask for; no stray debug
       code, no unrelated formatting churn, no generated files edited by hand.
    3. Cross-task consistency — names, types, signatures agree across tasks.
    4. Cross-repo contracts — for every contract in spec.md: provider and
       consumers agree (field names, types, nullability, headers); generated
       clients were regenerated, not hand-edited; old clients still work
       (backward compatibility) if the repos ship separately.
    5. Regression risk — callers of changed functions (use the graph) that the
       plan did not mention; say whether each is safe and why.
    6. Tests — the tests assert behavior, and the bug's repro is covered.

    ## Output (write to docs/aiflow/<TICKET-ID>/reviews/final-review.md)
    ---
    type: Final Review
    ticket: <TICKET-ID>
    verdict: approved | issues
    generated: {by: aiflow-review, at: YYYY-MM-DD}
    ---
    # 最終レビュー: <TICKET-ID>
    ## 判定: ✅ 承認 / ❌ 要修正
    ## 要件カバレッジ（表: 要件 | 実装箇所 | 状態）
    ## リポジトリ別の所見
    ## リポジトリ間の契約チェック
    ## リグレッションリスク
    ## 指摘事項（Critical / Important / Minor、各 file:line）
    ## PRレビュアー向け要約（3〜5行 — PRコメントにそのまま使う）
```
