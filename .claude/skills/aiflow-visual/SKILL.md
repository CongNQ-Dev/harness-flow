---
name: aiflow-visual
description: Optional visual companion for AI Flow stages — a local web page that shows UI mockups, flow/architecture diagrams and side-by-side options while a stage asks a design question, and records the user's click-to-select answers. Loaded by aiflow-spec, aiflow-plan, aiflow-review, aiflow-testgen and aiflow-analyze only when a question is easier to answer by seeing it. Never required.
user-invocable: false
---

# AI Flow visual companion

A tiny local server (no dependencies, Node only) that serves HTML you write to
the user's browser and records which option they click. It replaces a wall of
text with a picture when — and only when — the picture is the better question.
Everything else stays in the terminal. The mechanics (server, CSS classes,
events format) are in `visual-companion.md` next to this file; this page says
when and how AI Flow uses it.

Vendored from [obra/superpowers](https://github.com/obra/superpowers)
(`skills/brainstorming/`, MIT — see `LICENSE-superpowers.txt`).

## When a stage may use it

Per question, never per session: **would the user answer better by seeing it?**

| Stage | Visual question (yes) | Stays in the terminal (no) |
|---|---|---|
| spec §2.2 dialogue | UI mockups / layout options for a web or mobile screen; a before/after flow; a diagram of the contract between components | scope, requirements, root cause, data-model or API trade-off lists |
| plan | task ordering across components as a diagram, only when the dependency graph is hard to read as a list | task text, code, commands |
| review (stage 5) | the change as a component/contract diagram so the user can see what the diff touches | findings, verdicts, test results |
| testgen | the end-to-end scenario as a flow across components | numbered QA steps |
| analyze | the component/contract map after the graph is built | node counts, queries |

If the stage is not on this list, or the question is words-only, do not start it.

## Rules

1. **Ask first, once per ticket.** Before the first screen, `AskUserQuestion`:
   "Open the visual companion in your browser for this question?" —
   **Yes** / **No, terminal only**. Remember a "No" for the rest of the stage
   (conventions §8: one question at a time). The server serves only on
   localhost and never sends project content anywhere, but it does open a
   browser tab, so it is the user's call.
2. **Never block on it.** Every visual question must also be answerable in the
   terminal; the click events only add structured detail. If the server fails
   to start or the browser is unreachable, say so in one line and continue in
   the terminal.
3. **Telemetry off.** The server loads a brand logo from primeradiant.com
   unless disabled. Always start it with `SUPERPOWERS_DISABLE_TELEMETRY=1`.
4. **Keep the full URL.** The URL printed by the server contains `?key=…`;
   give the user the complete URL, never a bare `http://localhost:port`.
5. **Keep it out of git.** Pass `--project-dir <wrapper or repo root>` so
   screens persist in `.superpowers/brainstorm/`, and make sure `.superpowers/`
   is in that repo's `.gitignore` (add it if missing — a local edit, but do
   not commit it with ticket code). Mockups are throwaway; the decision goes
   into `spec.md` / `plan.md` as text.
6. **Record the outcome in the artifact.** When a visual choice settles, write
   it into the stage's document (spec "Alternatives considered", plan note),
   in `language:`, not as a screenshot reference.
7. **Stop it when the stage ends.** `bash .claude/skills/aiflow-visual/scripts/stop-server.sh <session_dir>`
   before the stage's closing message (conventions §5 hard stop).

## Procedure

```bash
SUPERPOWERS_DISABLE_TELEMETRY=1 bash .claude/skills/aiflow-visual/scripts/start-server.sh \
  --project-dir <root> --open
```

Then follow "The Loop" in `visual-companion.md`: write a new HTML fragment to
`screen_dir` (file-creation tool, new filename each time), tell the user the
URL and what is on screen, end the turn, and on the next turn read
`state_dir/events` together with their terminal reply. Use `--foreground` and
your agent's background-run mechanism where `visual-companion.md` says the
environment reaps detached processes (`aiflow/AGENTS-TOOLS.md` for non-Claude
agents). Needs `node` on PATH; without it, skip the companion silently.
