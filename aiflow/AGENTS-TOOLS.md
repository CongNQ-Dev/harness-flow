# AI Flow on agents other than Claude Code

Install for your agent with `install.sh --dir <project> --agent <agent>`
(`install.ps1` on Windows) from the ai-flow repo; it places the skills, the
`/aiflow` command and `AGENTS.md` as listed per agent below.

The skills are written with **Claude Code's tool names**. They're plain
markdown instructions, so any agent that can read/write files, run shell
commands and follow instructions can drive them — map the tool names below,
and apply the fallback rules when your agent has no equivalent.

## The four capabilities the skills lean on

| Skills say | Means | If your agent has no equivalent |
|---|---|---|
| `AskUserQuestion` | ask the user one structured multiple-choice question | Ask in chat as a numbered list, add a last option "Other — type your own answer", and **wait for the reply** before continuing. Never pick an answer yourself. |
| `Agent` / `Task` tool (subagent), `model:` | run a prompt in a fresh, isolated context and get its report back | Run the prompt yourself, inline, **one at a time**, treating it as a separate task: don't reuse assumptions from your own context, and write the same report the subagent would. The reviews still happen — sequentially instead of in parallel. |
| `Skill` tool | load another skill's SKILL.md | Open `<skills dir>/<skill>/SKILL.md` and follow it. |
| todo list (`TodoWrite`) | track tasks within a stage | Use your agent's plan/todo tool, or a checklist in chat. `status.md` and the plan's checkboxes are the durable record either way. |

`models:` in `workflow.yaml` (`sonnet`, `opus`) are Claude model aliases. On
another agent, use its own model choice for "fast / cheap" vs "most capable"
roles, or its default.

## Per agent

### Claude Code
Native. Skills in `.claude/skills/`; each `aiflow*` skill is a `/` command;
hooks in `.claude/settings.json` feed the usage log and the graph reminder.

### Codex CLI
Skills in `.agents/skills/` (invoke with `$aiflow`, or by description).
Project rules come from `AGENTS.md`.

| Skills say | Codex |
|---|---|
| `Agent`/`Task` (subagent) | `spawn_agent` (`agent_type="worker"`, the filled prompt as `message`); `wait` for the result; `close_agent` when done |
| several subagents in parallel | several `spawn_agent` calls |
| todo list | `update_plan` |
| `Skill` tool | skills load natively — follow the instructions |
| `AskUserQuestion` | fallback rule above |

Subagents need multi-agent support in `~/.codex/config.toml`:

```toml
[features]
multi_agent = true
```

Frame a subagent message as: "Your task is to perform the following. Follow
the instructions below exactly. `<agent-instructions>` … `</agent-instructions>`
Execute this now. Output ONLY the structured response the instructions ask for."

### GitHub Copilot (CLI / agent mode)
Skills in `.github/skills/`; `/aiflow` is the prompt file
`.github/prompts/aiflow.prompt.md`. Project rules come from `AGENTS.md`.

| Skills say | Copilot CLI |
|---|---|
| `Read` / `Write` / `Edit` | `view` / `create` / `edit` |
| `Bash` / `Grep` / `Glob` | `bash` / `grep` / `glob` |
| `Skill` tool | `skill` |
| `Agent`/`Task` (subagent) | `task` (`agent_type: "general-purpose"`); `read_agent` / `list_agents` for results |
| todo list | `sql` with the built-in `todos` table |
| `WebFetch` | `web_fetch` |
| `AskUserQuestion` | fallback rule above |

### Cursor
Skills in `.cursor/skills/`; `/aiflow` is `.cursor/commands/aiflow.md`.
Project rules come from `AGENTS.md`. Use Cursor's own file, terminal and
subagent tools where it has them; otherwise the fallback rules above.

### OpenCode
Skills in `.opencode/skills/`; `/aiflow` is `.opencode/commands/aiflow.md`.
Project rules come from `AGENTS.md`. Use OpenCode's own subagent/task and
todo tools where available; otherwise the fallback rules above.

### Kilo Code
Skills in `.kilo/skills/`; `/aiflow` is `.kilo/commands/aiflow.md`.
Project rules come from `AGENTS.md`. Use Kilo Code's own tools where it has
them; otherwise the fallback rules above.

### OpenClaw
Skills in `skills/` (the installer adds `user-invocable: true` and
`command-tool: true` to the `aiflow*` skills so OpenClaw treats them as
commands) and registers the workspace with `openclaw agents add <name>
--workspace <dir>`. Project rules come from `AGENTS.md`. Fallback rules
above for any capability it lacks.

## What only works in Claude Code

- **Usage log** (`log.json`: time, tokens and cost per stage) — written only
  by a Claude Code `Stop` hook that reads Claude Code's transcript. On other
  agents the skills' `aiflow_log.py start/end` calls are harmless no-ops
  (they leave small markers in the gitignored `aiflow/.state/`), and
  `log.json` isn't produced. Everything else in the flow works the same.
- **Graph reminder hook** — on other agents the same rule comes from
  `AGENTS.md` ("use `graphify query` before grepping") instead of a hook.
