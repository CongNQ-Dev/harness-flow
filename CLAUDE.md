# BUMP AI Flow workspace

This folder wraps three repos and runs one AI Flow across them. Start Claude
Code **here**, not inside a repo.

| Repo | What | Base branch |
|---|---|---|
| `bump-backend/` | Go API (GraphQL for the app, REST for admin) | `develop` |
| `bump-admin/` | Next.js admin console | `develop` |
| `bump-mobile-app/` | Flutter app (iOS/Android) | `main` |

The commands, project facts and shared rules come from `@aiflow/AIFLOW.md`
(imported below) and `aiflow/workflow.yaml` — read those instead of guessing.
Guide: `README.md`.

## Rules specific to this workspace

- **Branches.** While a ticket is open, this wrapper repo **and** every repo
  the ticket touches are on the same ticket branch (`bug/PDT-XXXX/…` /
  `feature/PDT-XXXX/…`). Ticket docs are committed on the wrapper's ticket
  branch, never on `main`; code only on each repo's ticket branch, never on
  `develop`/`main`. Before working on a ticket, check that every repo involved
  is on its branch and that no ticket code sits uncommitted on a base branch.
- **Never push directly to `main`** (or `develop`) in any repo, wrapper included —
  changes reach a base branch only through a PR/MR.
- **Always record the reviewer's name.** Anyone who reviews or approves
  anything (human or AI reviewer) is named in the review file / approval entry /
  PR comment — see `.claude/skills/aiflow/conventions.md` §6.
- **Never commit the bump repos' secrets** — `bump-backend/` has `.env` and
  `serviceAccountKey.json`; they must never be staged.
- Each repo still has its own `CLAUDE.md` with repo-specific notes; they apply
  when working on files in that repo.
- **The skills are generated, not edited here.** `.claude/skills/`,
  `aiflow/scripts/`, `aiflow/AIFLOW.md`, `aiflow/AGENTS-TOOLS.md` and
  `aiflow/workflow.yaml.template` come from the generic
  [harness-ai-flow](https://gitlab.shiftasia.com/cong.nguyen.02/harness-ai-flow)
  bundle. Change them there (and its `README.md` in the same commit), then
  re-install here with `--force`; a local edit would be overwritten on the
  next upgrade. BUMP-specific settings belong in `aiflow/workflow.yaml` only.
- **Docs travel with every behavior change.** If a change to
  `aiflow/workflow.yaml` or the flow changes how a ticket runs here (branches,
  gates, commands, stages), update `README.md` in the same commit — or say
  explicitly that nothing in it went stale.

@aiflow/AIFLOW.md
