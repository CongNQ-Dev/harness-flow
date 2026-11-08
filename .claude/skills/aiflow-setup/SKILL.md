---
name: aiflow-setup
description: First-time (or repeat) configuration of AI Flow for this project — asks single-repo / monorepo / multi-repo, detects each component's stack, test and lint commands, base branch and git host (GitHub → gh, GitLab → glab) from the real files, asks only what it can't detect (language, ticket source, ticket prefix, sensitive areas), and writes aiflow/workflow.yaml. Run via `/aiflow setup`, or automatically when /aiflow finds no workflow.yaml.
argument-hint: ""
---

# /aiflow-setup — configure AI Flow for this project

Produces `aiflow/workflow.yaml` from `aiflow/workflow.yaml.template`. Nothing
else in AI Flow can run until this file exists. Not a ticket stage — no
status.md, no stop rule.

**Detect first, ask second.** Every value you can read from the repo, read.
Ask the user only for what isn't on disk, and show what you detected so they
can correct it in one pass instead of answering twenty questions.

## 0. Existing config?

If `aiflow/workflow.yaml` already exists, read it, show a short summary
(layout, components, pr tool, language, ticket source) and ask with
`AskUserQuestion`: **update it** (re-detect, keep anything the user edited by
hand unless re-detection clearly contradicts it — then ask) / **start over** /
**cancel**. Never silently overwrite.

## 1. Shape of the project — ask

`AskUserQuestion`, header "Project shape":

- **Single repo** — this folder is the project's git repo, one deployable
  unit. → `layout: in-repo`, one component, `path: .`
- **Monorepo** — this folder is one git repo containing several apps /
  services / packages. → `layout: in-repo`, one component per package.
- **Multi-repo** — the project is several separate git repos. → `layout:
  workspace`: this folder is (or becomes) a wrapper; each repo is cloned
  beside it as a subfolder and gitignored.

Recommend one based on what you see: `git rev-parse --show-toplevel` equals
this folder + workspace markers (`pnpm-workspace.yaml`, `turbo.json`,
`nx.json`, `lerna.json`, `go.work`, Cargo `[workspace]`, `settings.gradle`
with several `include`s, several package manifests under `apps/`,
`packages/`, `services/`) → monorepo; a plain single manifest → single repo;
not a git repo, or subfolders that are each their own git repo → multi-repo.

## 2. Components — detect

- **Single repo:** one component. Name it after the repo folder (short, lower-case).
- **Monorepo:** list candidate packages from the workspace markers above.
  Show them and let the user pick which are components (`multiSelect`).
  Small shared libs can stay out — a task touching them is planned in the
  component that owns the change.
- **Multi-repo:** subfolders that are git repos are candidates. Ask for any
  repo not cloned yet (name + git URL); clone it now with
  `git clone <url> <name>` and add `<name>/` to the wrapper's `.gitignore`.

For each component, read its real files and fill:

| Field | Detect from |
|---|---|
| `stack` | the manifest(s): `package.json` (framework deps), `go.mod`, `pyproject.toml`/`requirements*.txt`, `Cargo.toml`, `pom.xml`/`build.gradle*`, `pubspec.yaml`, `Gemfile`, `composer.json`, `*.csproj` — plus DB/ORM deps. One line. |
| `test` | `package.json` `scripts.test` (with the lockfile's package manager: `pnpm`/`yarn`/`npm`/`bun`), `Makefile` `test` target, `go test ./...`, `pytest` (if configured), `cargo test`, `./gradlew test`, `mvn test`, `flutter test` (via a wrapper like `bin/fvm` if the repo has one), `bundle exec rspec`, `dotnet test`. If none exists, leave it empty and say so in `notes`. |
| `test_task` | a narrower form if the tool has one (e.g. `pytest <path>`, `go test ./<pkg>/...`, `pnpm test -- <file>`). Optional. |
| `lint` | `scripts.lint` / `scripts.typecheck`, `golangci-lint`, `ruff`/`flake8`, `cargo clippy`, `./gradlew lint`, `flutter analyze`, `rubocop`. |
| `base_branch` | `git -C <path> symbolic-ref refs/remotes/origin/HEAD` → the branch name; else `main`/`master`/`develop`, whichever exists. |
| `remote` | `git -C <path> remote get-url origin`. |
| `pr_tool` | **suggestion only — never written without asking (§ 2a).** From the host of `remote`: `github.com` → `gh`, `gitlab.com` → `glab`; any other host (self-managed / Enterprise) → unknown. |
| `qa_surface` | from the stack: web frontend → `browser`, mobile app → `mobile-device`, HTTP/GraphQL service → `api`, desktop app → `desktop`, CLI → `cli`, published package → `library`. Confirm with the user in the summary. |
| `notes` | anything in the repo that an engineer must know: code generators (`openapi`, `graphql-codegen`, `sqlc`, `prisma generate`, `build_runner`), wrappers (`bin/fvm`, `./gradlew`), docker-only test targets, "no unit-test runner". |
| `guides` | files that already guide contributors or AI agents: `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md`, `docs/ai/`, `.github/copilot-instructions.md`. |
| `team_skills` | skills already in `<path>/.claude/skills/` that look like code-review or testing skills. |

**Contracts:** look for a schema one component owns and another consumes —
an OpenAPI/Swagger file referenced by another component's codegen config, a
GraphQL schema with a client codegen elsewhere, a shared protobuf. Propose
each as a `contracts:` entry with its regenerate command; empty list is fine.

## 2a. Git host — always ask

The git host decides every PR/MR command (`gh` vs `glab`), so it is **always
asked**, even when the remotes look obvious — this is the one exception to
"detect first, ask second". Ask with `AskUserQuestion`, header "Git host":
"Where are PRs/MRs created?" with options **GitHub (`gh`)**, **GitLab
(`glab`)**, **Different per repo**. Put the detected host per repo in the
question text and mark the option that matches them as "(Recommended)"; if a
remote's host is neither `github.com` nor `gitlab.com`, say it couldn't be
detected rather than guessing.

- **GitHub** / **GitLab** → every repo (wrapper included) uses that tool:
  `pr.tool: gh` or `pr.tool: glab`, no per-repo overrides.
- **Different per repo** → one follow-up question per repo (the wrapper
  repo included in `workspace` layout): GitHub or GitLab. Set the global
  `pr.tool` to the most common answer, `pr_tool` only on components that
  differ, and `workspace_repo.pr_tool` if the wrapper differs.
- If a chosen host contradicts a repo's remote (e.g. GitLab chosen, remote on
  `github.com`), say so and ask once more — don't silently override either.

Then check each chosen CLI is installed and authenticated (`gh auth status` /
`glab auth status`); if not, tell the user the exact login command — don't run
it for them. On an agent without a structured question UI, ask in chat as a
numbered list.

## 3. What only the user knows — ask (one `AskUserQuestion` round, up to 4 questions)

1. **Output language** for artifacts and PR text (`language:`). Exactly two
   options — **English** (`en`) and **Tiếng Việt** (`vi`) — and the third
   choice is the question UI's built-in "Other", where the user types any
   language (한국어, Français, Deutsch, ...; store its ISO code, e.g. `ko`).
   On an agent without a structured question UI, ask in chat as a numbered
   list: `1. English  2. Tiếng Việt  3. Other — type the language`.
2. **Ticket source** — list the ticket-system MCP servers connected in this
   session (tool names containing `notion`, `jira`/`atlassian`, `linear`,
   `github`, `gitlab`, `asana`, `clickup`, `youtrack`, `shortcut`), plus
   `ask` ("choose each time") and `paste`. (`tickets.source:`)
3. **Ticket ID prefix** — propose one from the ticket system's project key
   if you can see it, else from the project name (upper-case, short).
   (`project_code:`)
4. **Sensitive areas** (`triage.sensitive_areas:`). The user hasn't seen a
   ticket go through yet, so the question must say what a route is. Ask it
   like this (translated to the user's language):

   > "Every ticket goes one of two ways. **Light** (small bugs): short
   > spec → fix → PR, one approval. **Full**: spec → plan → implement →
   > final review + test cases → PR, an approval at each step. A ticket
   > that touches an area you pick here always goes **full**, however small
   > the fix. Which areas, if any?"

   - `multiSelect: true`. Options = up to 3 areas **this codebase actually
     has**, each with where you saw it in the description (e.g.
     "Authentication / permissions — `src/auth/`, `middleware/rbac.ts`";
     "DB migrations — `db/migrations/` (12 files)"; "Payments — `stripe`
     in package.json"). Detect from folder/file names, dependencies and the
     graph; never offer an area the code doesn't have.
   - Last option: **"None — decide per ticket"** ("no area forces the full
     route; the light/full checks still apply to every ticket").
   - The UI's "Other" lets the user type their own areas
     (comma-separated).
   - **"None" is exclusive.** If it's ticked together with any area, drop
     "None", keep the areas, and say so in one line ("Keeping Auth + DB
     migrations; ignoring 'None'.") — don't ask again.
   - None (alone) → `sensitive_areas: []`.

## 4. Confirm, then write

Show the whole resulting `workflow.yaml` (or a compact per-component table +
the global settings) and ask **write it** / **change something**. On write:

- `aiflow/workflow.yaml` from the template's structure, with every value
  filled in and every `<placeholder>` gone. Keep the template's explanatory
  comments.
- Ensure `docs/aiflow/.gitkeep` exists and `.gitignore` contains
  `graphify-out/`, `aiflow/.state/`, `.claude/settings.local.json` (and, for
  `workspace`, each component folder).
- Commit: in-repo → on the current branch **only if it isn't a base branch**,
  otherwise leave it uncommitted and tell the user to commit it on a branch
  of their choosing; workspace → same rule for the wrapper repo. Also set
  `workspace_repo.base_branch` from the wrapper's own default branch
  (`git symbolic-ref refs/remotes/origin/HEAD`, else the current branch),
  and `workspace_repo.pr_tool` from the user's § 2a answer when the
  wrapper's host differs from `pr.tool` (e.g. repos on GitHub, wrapper on GitLab).

## 5. Report

What was detected vs. asked, anything left empty on purpose (e.g. a
component with no test runner), and the next steps:

1. `/aiflow analyze` — build the knowledge graph (optional; needs `graphify`).
2. `/aiflow <TICKET-ID>` — start the first ticket.
