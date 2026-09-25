# BUMP AI Flow workspace

This folder wraps three repos and runs one AI Flow across them. Start Claude
Code **here**, not inside a repo.

| Repo | What | Base branch |
|---|---|---|
| `bump-backend/` | Go API (GraphQL for the app, REST for admin) | `develop` |
| `bump-admin/` | Next.js admin console | `develop` |
| `bump-mobile-app/` | Flutter app (iOS/Android) | `main` |

Facts (test commands, contracts, triage rules, models) live in
`aiflow/workflow.yaml` — read it instead of guessing.

## The one command

- `/aiflow PDT-XXXX` — run the next stage of a ticket, then stop. New tickets start here too.
- `/aiflow` — board of all tickets.

Everything else (`/aiflow-spec`, `/aiflow-plan`, `/aiflow-impl`, `/aiflow-testgen`,
`/aiflow-review`, `/aiflow-analyze`) is what `/aiflow` calls; they can be run
directly but nobody needs to remember them. Guide: `aiflow/README.ja.md`.

When the user mentions a PDT ticket or asks to fix a bug / build a feature in
any of the repos, use `/aiflow` rather than improvising a workflow.

## Rules

- Ticket artifacts: `docs/aiflow/<TICKET-ID>/` in this workspace, written in
  **Japanese** (code, paths, identifiers stay as typed). Shared rules for every
  stage: `.claude/skills/aiflow/conventions.md`.
- Git: always `git -C <repo> ...`. Never commit to a base branch, never force-push.
- Knowledge graph: when `graphify-out/graph.json` exists here, use
  `graphify query "<question>"` / `graphify path "A" "B"` / `graphify explain "X"`
  before grepping or reading source — it covers all three repos and links shared
  types across them. Refresh with `/aiflow analyze`.
- Each repo still has its own `CLAUDE.md` with repo-specific notes; they apply
  when working on files in that repo.
