# Basic AI Flow workspace

This folder wraps three repos and runs one AI Flow across them. Start Claude
Code **here**, not inside a repo.

| Repo | What | Base branch |
|---|---|---|
| `backend/` | Go API (GraphQL for the app, REST for admin) | `develop` |
| `admin/` | Next.js admin console | `develop` |
| `mobile-app/` | Flutter app (iOS/Android) | `main` |

The commands, project facts and shared rules come from `@aiflow/AIFLOW.md`
(imported below) and `aiflow/workflow.yaml` — read those instead of guessing.
Guide: `README.md` / `README.ja.md` / `README.vi.md`; visual versions in English, Japanese and Vietnamese:
`aiflow/guide.en.html`, `aiflow/guide.ja.html`, `aiflow/guide.vi.html`.

## Rules specific to this workspace

- **Branches.** While a ticket is open, this wrapper repo **and** every repo
  the ticket touches are on the same ticket branch (`bug/PROJ-XXXX/…` /
  `feature/PROJ-XXXX/…`). Ticket docs are committed on the wrapper's ticket
  branch, never on `main`; code only on each repo's ticket branch, never on
  `develop`/`main`. Before working on a ticket, check that every repo involved
  is on its branch and that no ticket code sits uncommitted on a base branch.
- **Never push directly to `main`** (or `develop`) in any repo, wrapper included —
  changes reach a base branch only through a PR/MR.
- **Every push needs a fresh confirmation.** Before each `git push` (any repo,
  any branch) ask the user, naming repo/branch/remote; never push on your own,
  and an earlier approval doesn't cover a later push.
- **Every write to GitHub/GitLab needs a fresh confirmation.** Push, creating or
  editing a PR/MR, posting a comment: ask first (action, target, text), never
  automatic. Never merge, approve or close unless asked in chat.
- **Always record the reviewer's name.** Anyone who reviews or approves
  anything (human or AI reviewer) is named in the review file / approval entry /
  PR comment — see `.claude/skills/aiflow/conventions.md` §6.
- **Never commit or push sensitive content** (keys, tokens, passwords, `.env*`,
  credentials files) — see `conventions.md` §3. In the component repos
  secret files such as `.env` must never be staged.
- Each repo still has its own `CLAUDE.md` with repo-specific notes; they apply
  when working on files in that repo.
- **Graphify git hooks go in each child repo, never in the wrapper.**
  `graphify hook install` (post-commit / post-checkout) must be run inside
  `admin/`, `backend/` and `mobile-app/`. The wrapper only holds
  docs, so its hook would rebuild an almost empty graph — don't install it
  there (`/aiflow analyze` already handles both). Hooks live in `.git/hooks/`,
  so they are local to each machine and not committed.
- **This repo is the source of AI Flow.** `.claude/skills/`, `aiflow/scripts/`,
  `aiflow/AIFLOW.md`, `aiflow/AGENTS-TOOLS.md` and `aiflow/workflow.yaml.template`
  are edited here and shipped to other projects by `install.sh` / `install.ps1`,
  for any agent. The installer rewrites `.claude/skills/` paths for the target
  agent, so keep internal references in that form. If a change affects what gets
  installed (folders, command files, rules block), update both installers in the
  same commit. Project-specific settings belong in `aiflow/workflow.yaml` only.
- **Docs travel with every behavior change.** If a change to
  `aiflow/workflow.yaml` or the flow changes how a ticket runs here (branches,
  gates, commands, stages), update `README.md`, `README.ja.md`, `README.vi.md` **and the three visual guides**
  (`aiflow/guide.en.html`, `aiflow/guide.ja.html`, `aiflow/guide.vi.html`), kept in sync with each other, in the same commit — or
  say explicitly that nothing in them went stale.

@aiflow/AIFLOW.md
