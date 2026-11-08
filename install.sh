#!/usr/bin/env bash
# Install AI Flow into a project, for any supported coding agent.
#
#   git clone https://github.com/CongNQ-Dev/ai-flow.git
#   ./ai-flow/install.sh --dir ~/code/my-app --agent codex
#
# The skills in this repo (.claude/skills/) are the single source. The installer
# copies them into the agent's skills folder, rewrites internal paths, adds the
# project rules file (CLAUDE.md or AGENTS.md), the /aiflow command where the agent
# needs one, and the aiflow/ runtime (scripts, manifest template, tool mapping).
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR=""
AGENT=""
AGENT_NAME=""
FORCE=0

usage() {
  cat <<'EOF'
Usage: install.sh [--dir <path>] [--agent <agent>] [--force] [--agent-name <name>]

  --dir <path>        Project to install into (default: current directory).
  --agent <agent>     claude | codex | copilot | cursor | opencode | kilocode | openclaw
                      Prompted if omitted.
  --force             Overwrite skills / command files that already exist.
  --agent-name <name> OpenClaw only: name for `openclaw agents add`.
  -h, --help          Show this help.

Never overwritten: aiflow/workflow.yaml (your project config), existing content
of CLAUDE.md / AGENTS.md (the AI Flow block is added or refreshed between markers),
existing hooks in .claude/settings.json (AI Flow hooks are merged in).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) PROJECT_DIR="$2"; shift 2 ;;
    --dir=*) PROJECT_DIR="${1#*=}"; shift ;;
    --agent) AGENT="$2"; shift 2 ;;
    --agent=*) AGENT="${1#*=}"; shift ;;
    --agent-name) AGENT_NAME="$2"; shift 2 ;;
    --agent-name=*) AGENT_NAME="${1#*=}"; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$AGENT" ]]; then
  echo "Which agent will run AI Flow?"
  echo "  1) Claude Code    2) Codex CLI    3) GitHub Copilot    4) Cursor"
  echo "  5) OpenCode       6) Kilo Code    7) OpenClaw"
  read -r -p "Choose [1-7]: " n
  case "$n" in
    1) AGENT=claude ;; 2) AGENT=codex ;; 3) AGENT=copilot ;; 4) AGENT=cursor ;;
    5) AGENT=opencode ;; 6) AGENT=kilocode ;; 7) AGENT=openclaw ;;
    *) echo "Invalid choice." >&2; exit 1 ;;
  esac
fi

case "$AGENT" in
  claude)   SKILLS_REL=".claude/skills";   CMD_REL="";                               RULES="CLAUDE.md"; LABEL="Claude Code" ;;
  codex)    SKILLS_REL=".agents/skills";   CMD_REL="";                               RULES="AGENTS.md"; LABEL="Codex CLI" ;;
  copilot)  SKILLS_REL=".github/skills";   CMD_REL=".github/prompts/aiflow.prompt.md"; RULES="AGENTS.md"; LABEL="GitHub Copilot" ;;
  cursor)   SKILLS_REL=".cursor/skills";   CMD_REL=".cursor/commands/aiflow.md";     RULES="AGENTS.md"; LABEL="Cursor" ;;
  opencode) SKILLS_REL=".opencode/skills"; CMD_REL=".opencode/commands/aiflow.md";   RULES="AGENTS.md"; LABEL="OpenCode" ;;
  kilocode) SKILLS_REL=".kilo/skills";     CMD_REL=".kilo/commands/aiflow.md";       RULES="AGENTS.md"; LABEL="Kilo Code" ;;
  openclaw) SKILLS_REL="skills";           CMD_REL="";                               RULES="AGENTS.md"; LABEL="OpenClaw" ;;
  *) echo "Error: unknown agent '$AGENT'." >&2; usage >&2; exit 1 ;;
esac

PY="$(command -v python3 || command -v python || true)"
[[ -n "$PY" ]] || { echo "Error: python3 is required (the AI Flow scripts use it too)." >&2; exit 1; }

PROJECT_DIR="${PROJECT_DIR:-$PWD}"
mkdir -p "$PROJECT_DIR"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
if [[ "$PROJECT_DIR" == "$SRC" ]]; then
  echo "Error: --dir points at the ai-flow repo itself. Choose the project to install into." >&2
  exit 1
fi

SKILLS_DIR="$PROJECT_DIR/$SKILLS_REL"
echo "Installing AI Flow for $LABEL"
echo "  project: $PROJECT_DIR"
echo "  skills:  $SKILLS_REL/"

# 1. Skills -----------------------------------------------------------------
mkdir -p "$SKILLS_DIR"
for d in "$SRC"/.claude/skills/*/; do
  name="$(basename "$d")"
  target="$SKILLS_DIR/$name"
  if [[ -e "$target" && "$FORCE" -ne 1 ]]; then
    echo "  skip  $SKILLS_REL/$name (exists — use --force to overwrite)"
    continue
  fi
  rm -rf "$target"
  cp -R "$d" "$target"
  echo "  add   $SKILLS_REL/$name"
done

# Internal references point at .claude/skills/; rewrite them for this agent.
# "<path>/.claude/skills" (a component repo's own team skills) is left alone.
if [[ "$SKILLS_REL" != ".claude/skills" ]]; then
  "$PY" - "$SKILLS_DIR" "$SKILLS_REL" <<'PYEOF'
import os, re, sys
root, rel = sys.argv[1], sys.argv[2]
pat = re.compile(r'(?<![\w>/])\.claude/skills/')
for dp, _, files in os.walk(root):
    for f in files:
        if not f.endswith(('.md', '.sh', '.py', '.json', '.yaml', '.yml', '.txt', '.html', '.js')):
            continue
        p = os.path.join(dp, f)
        try:
            s = open(p, encoding='utf-8').read()
        except UnicodeDecodeError:
            continue
        n = pat.sub(rel + '/', s)
        if n != s:
            open(p, 'w', encoding='utf-8').write(n)
PYEOF
fi

# OpenClaw treats skills as commands only when flagged in the frontmatter.
if [[ "$AGENT" == "openclaw" ]]; then
  "$PY" - "$SKILLS_DIR" <<'PYEOF'
import glob, os, sys
for p in glob.glob(os.path.join(sys.argv[1], 'aiflow*', 'SKILL.md')):
    s = open(p, encoding='utf-8').read()
    if not s.startswith('---\n'):
        continue
    head, rest = s[4:].split('\n---', 1)
    lines = [l for l in head.split('\n')
             if not l.startswith(('user-invocable:', 'command-tool:'))]
    lines += ['user-invocable: true', 'command-tool: true']
    open(p, 'w', encoding='utf-8').write('---\n' + '\n'.join(lines) + '\n---' + rest)
PYEOF
fi

# 2. aiflow/ runtime --------------------------------------------------------
mkdir -p "$PROJECT_DIR/aiflow"
for f in AIFLOW.md AGENTS-TOOLS.md pricing.json workflow.yaml.template; do
  cp "$SRC/aiflow/$f" "$PROJECT_DIR/aiflow/$f"
done
rm -rf "$PROJECT_DIR/aiflow/scripts"
cp -R "$SRC/aiflow/scripts" "$PROJECT_DIR/aiflow/scripts"
find "$PROJECT_DIR/aiflow/scripts" -name '__pycache__' -type d -prune -exec rm -rf {} +
if [[ "$SKILLS_REL" != ".claude/skills" ]]; then
  "$PY" - "$PROJECT_DIR/aiflow/scripts" "$SKILLS_REL" <<'PYEOF'
import os, re, sys
pat = re.compile(r'(?<![\w>/])\.claude/skills/')
for dp, _, files in os.walk(sys.argv[1]):
    for f in files:
        p = os.path.join(dp, f)
        try:
            s = open(p, encoding='utf-8').read()
        except UnicodeDecodeError:
            continue
        n = pat.sub(sys.argv[2] + '/', s)
        if n != s:
            open(p, 'w', encoding='utf-8').write(n)
PYEOF
fi
echo "  add   aiflow/ (AIFLOW.md, AGENTS-TOOLS.md, scripts/, pricing.json, workflow.yaml.template)"
if [[ -f "$PROJECT_DIR/aiflow/workflow.yaml" ]]; then
  echo "  keep  aiflow/workflow.yaml (your project config)"
fi

# 3. Project rules: CLAUDE.md imports AIFLOW.md; AGENTS.md carries it inline ---
"$PY" - "$PROJECT_DIR/$RULES" "$PROJECT_DIR/aiflow/AIFLOW.md" "$AGENT" <<'PYEOF'
import os, sys
rules, aiflow_md, agent = sys.argv[1:4]
start, end = '<!-- aiflow:start -->', '<!-- aiflow:end -->'
if agent == 'claude':
    body = '@aiflow/AIFLOW.md'
else:
    body = open(aiflow_md, encoding='utf-8').read().strip() + (
        '\n\nIf `graphify-out/graph.json` exists, run `graphify query "<question>"` '
        'before grepping or reading source files; read raw files only after that, '
        'or to change specific lines.')
block = start + '\n' + body + '\n' + end
s = open(rules, encoding='utf-8').read() if os.path.exists(rules) else ''
if start in s and end in s:
    s = s[:s.index(start)] + block + s[s.index(end) + len(end):]
elif agent == 'claude' and '@aiflow/AIFLOW.md' in s:
    pass  # already imported by hand
else:
    s = (s.rstrip() + '\n\n' if s.strip() else '') + block + '\n'
open(rules, 'w', encoding='utf-8').write(s)
PYEOF
echo "  add   $RULES (AI Flow block between <!-- aiflow:start/end --> markers)"

# 4. /aiflow command for agents that need a command file ---------------------
if [[ -n "$CMD_REL" ]]; then
  CMD_FILE="$PROJECT_DIR/$CMD_REL"
  if [[ -e "$CMD_FILE" && "$FORCE" -ne 1 ]]; then
    echo "  skip  $CMD_REL (exists — use --force to overwrite)"
  else
    mkdir -p "$(dirname "$CMD_FILE")"
    if [[ "$AGENT" == "copilot" ]]; then
      cat > "$CMD_FILE" <<EOF
---
mode: agent
description: AI Flow — run the next stage of a ticket (/aiflow <TICKET-ID>), or show the board (/aiflow).
---

Read and follow \`$SKILLS_REL/aiflow/SKILL.md\` (the AI Flow router) with these arguments: \${input:args:ticket ID and options, or empty for the board}

Tool names in the skills are Claude Code's; map them with \`aiflow/AGENTS-TOOLS.md\`.
EOF
    else
      cat > "$CMD_FILE" <<EOF
---
description: AI Flow — run the next stage of a ticket (/aiflow <TICKET-ID>), or show the board (/aiflow).
---

Read and follow \`$SKILLS_REL/aiflow/SKILL.md\` (the AI Flow router) with these arguments: \$ARGUMENTS

Tool names in the skills are Claude Code's; map them with \`aiflow/AGENTS-TOOLS.md\`.
EOF
    fi
    echo "  add   $CMD_REL"
  fi
fi

# 5. Claude Code hooks (usage log + graph reminder), merged ------------------
if [[ "$AGENT" == "claude" ]]; then
  "$PY" - "$SRC/.claude/settings.json" "$PROJECT_DIR/.claude/settings.json" <<'PYEOF'
import json, os, sys
src, dst = sys.argv[1:3]
new = json.load(open(src, encoding='utf-8'))
cur = json.load(open(dst, encoding='utf-8')) if os.path.exists(dst) else {}
hooks = cur.setdefault('hooks', {})
for event, entries in new.get('hooks', {}).items():
    have = hooks.setdefault(event, [])
    for e in entries:
        if e not in have:
            have.append(e)
os.makedirs(os.path.dirname(dst), exist_ok=True)
json.dump(cur, open(dst, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
open(dst, 'a', encoding='utf-8').write('\n')
PYEOF
  echo "  add   .claude/settings.json hooks (merged with any existing ones)"
fi

# 6. .gitignore ---------------------------------------------------------------
GI="$PROJECT_DIR/.gitignore"
touch "$GI"
for line in "graphify-out/" "aiflow/.state/" ".superpowers/"; do
  grep -qxF "$line" "$GI" || echo "$line" >> "$GI"
done
[[ "$AGENT" == "claude" ]] && { grep -qxF ".claude/settings.local.json" "$GI" || echo ".claude/settings.local.json" >> "$GI"; }
echo "  add   .gitignore entries (graphify-out/, aiflow/.state/, .superpowers/)"

# 7. OpenClaw workspace registration ------------------------------------------
if [[ "$AGENT" == "openclaw" ]]; then
  if command -v openclaw >/dev/null 2>&1; then
    [[ -n "$AGENT_NAME" ]] || read -r -p "OpenClaw agent name: " AGENT_NAME
    openclaw agents add "$AGENT_NAME" --workspace "$PROJECT_DIR"
  else
    echo "  note  'openclaw' not found — register later with:"
    echo "        openclaw agents add <name> --workspace $PROJECT_DIR"
  fi
fi

echo
echo "Done. Next, open $PROJECT_DIR with $LABEL and run:"
case "$AGENT" in
  codex) echo "  \$aiflow setup     (Codex invokes skills with \$; subagents need [features] multi_agent = true in ~/.codex/config.toml)" ;;
  *)     echo "  /aiflow setup" ;;
esac
echo "It writes aiflow/workflow.yaml (components, test commands, git host, language), then:"
echo "  /aiflow <TICKET-ID>"
[[ "$AGENT" != "claude" ]] && echo "Tool-name mapping for $LABEL: aiflow/AGENTS-TOOLS.md"
exit 0
