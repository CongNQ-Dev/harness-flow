# architecture/decisions/<slug>.md template

Used both by `/aiflow-wiki` (initial write) and by `aiflow-spec` when a
ticket's spec records a real architecture decision (cheap append — reuses
that ticket's own investigation, no repo-wide re-scan).

```markdown
---
type: Decision
title: <一文、能動態>
repos: [bump-backend, bump-mobile-app]
sources: [docs/aiflow/PDT-XXXX/spec.md, repo/path:line]
generated: {by: aiflow-wiki | aiflow-spec, at: YYYY-MM-DD}
status: draft
---

# <タイトル>

## 背景
<なぜこの決定が必要になったか。1〜3文>

## 決定内容
<何を決めたか>

## 理由
<なぜこのアプローチを選んだか。却下した案があれば1行で>

## 影響範囲
<この決定が制約する今後の実装・リポジトリ>
```

From `aiflow-spec`: only when the spec's 修正方針 is a real architectural
choice (a new contract, a pattern change, a cross-repo boundary decision) —
not for a routine bug fix. When in doubt, don't write one; a missing
decision entry is recoverable, a noisy wiki is not.
