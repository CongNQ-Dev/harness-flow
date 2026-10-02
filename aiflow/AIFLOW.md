# AI Flow

This project uses AI Flow: one command runs a ticket from intake to PR, one
stage at a time, with a human approval at each gate.

- `/aiflow <TICKET-ID>` — run the next stage of a ticket, then stop. A new
  ticket starts here too. (`/aiflow <ID> feature` for new development.)
- `/aiflow` — board of all tickets. `/aiflow setup` — (re)configure.

Project facts — components, paths, stacks, test commands, base branches,
ticket source, PR tool, triage rules — live in `aiflow/workflow.yaml`. Read
it instead of guessing. Shared rules for every stage: `conventions.md` in
the `aiflow` skill's folder (`.claude/skills/aiflow/` for Claude Code,
`.agents/skills/aiflow/` for Codex, `.github/skills/`, `.cursor/skills/`,
`.opencode/skills/` or `skills/` for the others). Not Claude Code? Read
`aiflow/AGENTS-TOOLS.md` for the tool-name mapping.

When the user mentions a ticket or issue ID, or asks to fix a bug / build a
feature, use `/aiflow` rather than improvising a workflow.

- Ticket artifacts go in `docs/aiflow/<TICKET-ID>/`, written in
  `workflow.yaml` `language:` (code, paths and identifiers stay as typed).
- Git: always `git -C <path> ...`; never commit to a base branch; never
  push directly to `main` (PR/MR only); never force-push.
- Every review or approval records the reviewer's name (human or AI).
- If `graphify-out/graph.json` exists, use `graphify query "<question>"` /
  `graphify path "A" "B"` / `graphify explain "X"` before grepping or reading
  source. Refresh with `/aiflow analyze`.
- Each component's own guides (`workflow.yaml` `guides:`) win over AI Flow
  for how code and tests are written.
