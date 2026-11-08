#!/usr/bin/env bash
# Install AI Flow into a project — an onboarding that sets up only what you pick.
#
#   git clone https://github.com/CongNQ-Dev/harness-flow.git
#   ./harness-flow/install.sh --dir ~/code/my-app          # asks step by step
#
# Steps (each skipped when its flag is given):
#   1. agent(s)       claude, codex, copilot, cursor, opencode, kilocode, openclaw
#   2. git host       github | gitlab | mixed — checks gh / glab is installed and logged in
#   3. language       of ticket docs and PR text
#   4. features       knowledge graph, visual companion, project wiki
# Choices are saved in aiflow/install.yaml; /aiflow setup reads them instead of
# asking again. The skills in this repo (.claude/skills/) are the single source.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="" AGENTS="" GIT_HOST="" GITLAB_HOST="" LANGUAGE="" FEATURES="" AGENT_NAME=""
FORCE=0 YES=0

usage() {
  cat <<'EOF'
Usage: install.sh [options]          (no options = interactive onboarding)

  --dir <path>          Project to install into (default: current directory).
  --agent <a[,b...]>    claude | codex | copilot | cursor | opencode | kilocode | openclaw
  --git-host <host>     github | gitlab | mixed (mixed = chosen per repo in /aiflow setup)
  --gitlab-host <name>  Self-managed GitLab host name (default gitlab.com).
  --language <code>     en | ja | vi | any ISO code — ticket docs and PR text.
  --features <list>     graph,visual,wiki — or "none". Default when --yes: graph,wiki.
  --yes                 Accept defaults for anything not given (non-interactive).
  --force               Overwrite skills / command files that already exist.
  --agent-name <name>   OpenClaw only: name for `openclaw agents add`.
  -h, --help            Show this help.

Never overwritten: aiflow/workflow.yaml, your own text in CLAUDE.md / AGENTS.md
(the AI Flow block sits between markers), existing hooks in .claude/settings.json.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) PROJECT_DIR="$2"; shift 2 ;;         --dir=*) PROJECT_DIR="${1#*=}"; shift ;;
    --agent) AGENTS="$2"; shift 2 ;;            --agent=*) AGENTS="${1#*=}"; shift ;;
    --git-host) GIT_HOST="$2"; shift 2 ;;       --git-host=*) GIT_HOST="${1#*=}"; shift ;;
    --gitlab-host) GITLAB_HOST="$2"; shift 2 ;; --gitlab-host=*) GITLAB_HOST="${1#*=}"; shift ;;
    --language) LANGUAGE="$2"; shift 2 ;;       --language=*) LANGUAGE="${1#*=}"; shift ;;
    --features) FEATURES="$2"; shift 2 ;;       --features=*) FEATURES="${1#*=}"; shift ;;
    --agent-name) AGENT_NAME="$2"; shift 2 ;;   --agent-name=*) AGENT_NAME="${1#*=}"; shift ;;
    --yes|-y) YES=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

PY="$(command -v python3 || command -v python || true)"
[[ -n "$PY" ]] || { echo "Error: python3 is required (the AI Flow scripts use it too)." >&2; exit 1; }

ask() {  # ask <prompt> <default> -> REPLY
  if [[ "$YES" -eq 1 ]]; then REPLY="$2"; return; fi
  read -r -p "$1 [$2]: " REPLY
  REPLY="${REPLY:-$2}"
}
yesno() {  # yesno <prompt> <default y|n> -> 0 for yes
  local d="$2"
  if [[ "$YES" -eq 1 ]]; then [[ "$d" == y ]]; return; fi
  read -r -p "$1 [$( [[ $d == y ]] && echo Y/n || echo y/N )]: " REPLY
  REPLY="$(echo "${REPLY:-$d}" | tr '[:upper:]' '[:lower:]')"
  [[ "$REPLY" == y* ]]
}

echo "AI Flow onboarding"
echo

# --- 1. Agents -------------------------------------------------------------
ALL_AGENTS=(claude codex copilot cursor opencode kilocode openclaw)
LABELS=("Claude Code" "Codex CLI" "GitHub Copilot" "Cursor" "OpenCode" "Kilo Code" "OpenClaw")
if [[ -z "$AGENTS" ]]; then
  if [[ "$YES" -eq 1 ]]; then echo "Error: --agent is required with --yes." >&2; exit 1; fi
  echo "1) Which agent(s) will run AI Flow? (comma-separated, e.g. 2,3)"
  for i in "${!ALL_AGENTS[@]}"; do printf "   %d) %s\n" $((i+1)) "${LABELS[$i]}"; done
  read -r -p "   Choose: " picks
  AGENTS=""
  for p in ${picks//,/ }; do
    [[ "$p" =~ ^[1-7]$ ]] || { echo "Invalid choice: $p" >&2; exit 1; }
    AGENTS="${AGENTS:+$AGENTS,}${ALL_AGENTS[$((p-1))]}"
  done
  [[ -n "$AGENTS" ]] || { echo "No agent chosen." >&2; exit 1; }
fi
for a in ${AGENTS//,/ }; do
  case "$a" in claude|codex|copilot|cursor|opencode|kilocode|openclaw) ;;
    *) echo "Error: unknown agent '$a'." >&2; exit 1 ;; esac
done

# --- 2. Git host -------------------------------------------------------------
if [[ -z "$GIT_HOST" ]]; then
  if [[ "$YES" -eq 1 ]]; then GIT_HOST=github
  else
    echo
    echo "2) Where are pull/merge requests created?"
    echo "   1) GitHub (gh)   2) GitLab (glab)   3) Different per repo (decided in /aiflow setup)"
    read -r -p "   Choose [1]: " p
    case "${p:-1}" in 1) GIT_HOST=github ;; 2) GIT_HOST=gitlab ;; 3) GIT_HOST=mixed ;;
      *) echo "Invalid choice." >&2; exit 1 ;; esac
  fi
fi
case "$GIT_HOST" in github|gitlab|mixed) ;; *) echo "Error: --git-host must be github, gitlab or mixed." >&2; exit 1 ;; esac
if [[ "$GIT_HOST" != github && -z "$GITLAB_HOST" ]]; then
  ask "   GitLab host (gitlab.com, or your self-managed host name)" "gitlab.com"; GITLAB_HOST="$REPLY"
fi
GITLAB_HOST="${GITLAB_HOST#https://}"; GITLAB_HOST="${GITLAB_HOST#http://}"; GITLAB_HOST="${GITLAB_HOST%%/*}"

# --- 3. Language -------------------------------------------------------------
if [[ -z "$LANGUAGE" ]]; then
  if [[ "$YES" -eq 1 ]]; then LANGUAGE=en
  else
    echo
    echo "3) Language for ticket docs and PR text?"
    echo "   1) English   2) 日本語   3) Tiếng Việt   4) Other (type its ISO code)"
    read -r -p "   Choose [1]: " p
    case "${p:-1}" in 1) LANGUAGE=en ;; 2) LANGUAGE=ja ;; 3) LANGUAGE=vi ;;
      4) read -r -p "   ISO code (e.g. ko, fr): " LANGUAGE ;;
      *) echo "Invalid choice." >&2; exit 1 ;; esac
  fi
fi

# --- 4. Optional features ----------------------------------------------------
F_GRAPH=0 F_VISUAL=0 F_WIKI=0
if [[ -n "$FEATURES" ]]; then
  [[ "$FEATURES" == none ]] || for f in ${FEATURES//,/ }; do
    case "$f" in graph) F_GRAPH=1 ;; visual) F_VISUAL=1 ;; wiki) F_WIKI=1 ;;
      *) echo "Error: unknown feature '$f' (graph, visual, wiki, none)." >&2; exit 1 ;; esac
  done
else
  [[ "$YES" -eq 1 ]] || { echo; echo "4) Optional features"; }
  if yesno "   Knowledge graph — maps the code so the agent reads less (needs the graphify CLI)" y; then F_GRAPH=1; fi
  if yesno "   Visual companion — local browser page for mockups and diagrams" n; then F_VISUAL=1; fi
  if yesno "   Project wiki — /aiflow wiki writes architecture docs (uses tokens)" y; then F_WIKI=1; fi
fi

# --- Target ------------------------------------------------------------------
PROJECT_DIR="${PROJECT_DIR:-$PWD}"
mkdir -p "$PROJECT_DIR"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
[[ "$PROJECT_DIR" != "$SRC" ]] || { echo "Error: --dir points at the harness-flow repo itself. Choose the project to install into." >&2; exit 1; }

SKIP=" "
[[ "$F_GRAPH" -eq 1 ]]  || SKIP+="graphify aiflow-analyze "
[[ "$F_VISUAL" -eq 1 ]] || SKIP+="aiflow-visual "
[[ "$F_WIKI" -eq 1 ]]   || SKIP+="aiflow-wiki "

echo
echo "Installing into $PROJECT_DIR"
echo "  agents: $AGENTS | git host: $GIT_HOST${GITLAB_HOST:+ ($GITLAB_HOST)} | language: $LANGUAGE"
echo "  features: knowledge graph=$F_GRAPH visual=$F_VISUAL wiki=$F_WIKI"
echo

REWRITE_PY='
import os, re, sys
root, rel = sys.argv[1], sys.argv[2]
pat = re.compile(r"(?<![\w>/])\.claude/skills/")
for dp, _, files in os.walk(root):
    for f in files:
        p = os.path.join(dp, f)
        try:
            s = open(p, encoding="utf-8").read()
        except (UnicodeDecodeError, PermissionError):
            continue
        n = pat.sub(rel + "/", s)
        if n != s:
            open(p, "w", encoding="utf-8").write(n)
'

# --- aiflow/ runtime (shared by every agent) ---------------------------------
mkdir -p "$PROJECT_DIR/aiflow"
for f in AIFLOW.md AGENTS-TOOLS.md pricing.json workflow.yaml.template; do
  cp "$SRC/aiflow/$f" "$PROJECT_DIR/aiflow/$f"
done
rm -rf "$PROJECT_DIR/aiflow/scripts"
cp -R "$SRC/aiflow/scripts" "$PROJECT_DIR/aiflow/scripts"
find "$PROJECT_DIR/aiflow/scripts" -name '__pycache__' -type d -prune -exec rm -rf {} +
echo "  add   aiflow/ runtime (AIFLOW.md, AGENTS-TOOLS.md, scripts/, pricing.json, workflow.yaml.template)"
if [[ -f "$PROJECT_DIR/aiflow/workflow.yaml" ]]; then echo "  keep  aiflow/workflow.yaml (your project config)"; fi

"$PY" - "$PROJECT_DIR/aiflow/install.yaml" "$AGENTS" "$GIT_HOST" "$GITLAB_HOST" "$LANGUAGE" "$F_GRAPH" "$F_VISUAL" "$F_WIKI" <<'PYEOF'
import sys
out, agents, host, glhost, lang, g, v, w = sys.argv[1:]
b = lambda x: 'true' if x == '1' else 'false'
lines = [
    '# Written by install.sh / install.ps1 — the choices made at install time.',
    '# /aiflow setup reads these instead of asking again. Re-run the installer to change them.',
    'agents: [%s]' % ', '.join(agents.split(',')),
    'git_host: %s   # github | gitlab | mixed (mixed: chosen per repo in /aiflow setup)' % host,
]
if host != 'github':
    lines.append('gitlab_host: %s' % (glhost or 'gitlab.com'))
lines += ['language: %s' % lang, 'features:',
          '  knowledge_graph: %s   # graphify + /aiflow analyze' % b(g),
          '  visual: %s            # aiflow-visual browser companion' % b(v),
          '  wiki: %s              # /aiflow wiki' % b(w)]
open(out, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
PYEOF
echo "  add   aiflow/install.yaml (your onboarding choices)"
echo

# --- Per agent ---------------------------------------------------------------
install_agent() {
  local AGENT="$1" SKILLS_REL CMD_REL RULES LABEL
  case "$AGENT" in
    claude)   SKILLS_REL=".claude/skills";   CMD_REL="";                                 RULES="CLAUDE.md"; LABEL="Claude Code" ;;
    codex)    SKILLS_REL=".agents/skills";   CMD_REL="";                                 RULES="AGENTS.md"; LABEL="Codex CLI" ;;
    copilot)  SKILLS_REL=".github/skills";   CMD_REL=".github/prompts/aiflow.prompt.md"; RULES="AGENTS.md"; LABEL="GitHub Copilot" ;;
    cursor)   SKILLS_REL=".cursor/skills";   CMD_REL=".cursor/commands/aiflow.md";       RULES="AGENTS.md"; LABEL="Cursor" ;;
    opencode) SKILLS_REL=".opencode/skills"; CMD_REL=".opencode/commands/aiflow.md";     RULES="AGENTS.md"; LABEL="OpenCode" ;;
    kilocode) SKILLS_REL=".kilo/skills";     CMD_REL=".kilo/commands/aiflow.md";         RULES="AGENTS.md"; LABEL="Kilo Code" ;;
    openclaw) SKILLS_REL="skills";           CMD_REL="";                                 RULES="AGENTS.md"; LABEL="OpenClaw" ;;
  esac
  local SKILLS_DIR="$PROJECT_DIR/$SKILLS_REL"
  echo "[$LABEL] skills -> $SKILLS_REL/"
  mkdir -p "$SKILLS_DIR"
  local d name target
  for d in "$SRC"/.claude/skills/*/; do
    name="$(basename "$d")"; target="$SKILLS_DIR/$name"
    if [[ "$SKIP" == *" $name "* ]]; then
      if [[ -e "$target" ]]; then echo "  note  $SKILLS_REL/$name left in place (feature not chosen; delete it if unused)"; fi
      continue
    fi
    if [[ -e "$target" && "$FORCE" -ne 1 ]]; then echo "  skip  $SKILLS_REL/$name (exists — use --force)"; continue; fi
    rm -rf "$target"; cp -R "$d" "$target"
    echo "  add   $SKILLS_REL/$name"
  done
  if [[ "$SKILLS_REL" != ".claude/skills" ]]; then "$PY" -c "$REWRITE_PY" "$SKILLS_DIR" "$SKILLS_REL"; fi

  if [[ "$AGENT" == openclaw ]]; then
    "$PY" - "$SKILLS_DIR" <<'PYEOF'
import glob, os, sys
for p in glob.glob(os.path.join(sys.argv[1], 'aiflow*', 'SKILL.md')):
    s = open(p, encoding='utf-8').read()
    if not s.startswith('---\n'):
        continue
    head, rest = s[4:].split('\n---', 1)
    lines = [l for l in head.split('\n') if not l.startswith(('user-invocable:', 'command-tool:'))]
    lines += ['user-invocable: true', 'command-tool: true']
    open(p, 'w', encoding='utf-8').write('---\n' + '\n'.join(lines) + '\n---' + rest)
PYEOF
  fi

  # Rules file: CLAUDE.md imports AIFLOW.md; AGENTS.md carries it inline.
  "$PY" - "$PROJECT_DIR/$RULES" "$PROJECT_DIR/aiflow/AIFLOW.md" "$AGENT" "$F_GRAPH" <<'PYEOF'
import os, sys
rules, aiflow_md, agent, graph = sys.argv[1:5]
start, end = '<!-- aiflow:start -->', '<!-- aiflow:end -->'
if agent == 'claude':
    body = '@aiflow/AIFLOW.md'
else:
    body = open(aiflow_md, encoding='utf-8').read().strip()
    if graph == '1':
        body += ('\n\nIf `graphify-out/graph.json` exists, run `graphify query "<question>"` '
                 'before grepping or reading source files; read raw files only after that, '
                 'or to change specific lines.')
block = start + '\n' + body + '\n' + end
s = open(rules, encoding='utf-8').read() if os.path.exists(rules) else ''
if start in s and end in s:
    s = s[:s.index(start)] + block + s[s.index(end) + len(end):]
elif agent == 'claude' and '@aiflow/AIFLOW.md' in s:
    pass
else:
    s = (s.rstrip() + '\n\n' if s.strip() else '') + block + '\n'
open(rules, 'w', encoding='utf-8').write(s)
PYEOF
  echo "  add   $RULES (AI Flow block between <!-- aiflow:start/end --> markers)"

  if [[ -n "$CMD_REL" ]]; then
    local CMD_FILE="$PROJECT_DIR/$CMD_REL" FRONT ARGS
    if [[ -e "$CMD_FILE" && "$FORCE" -ne 1 ]]; then echo "  skip  $CMD_REL (exists — use --force)"
    else
      mkdir -p "$(dirname "$CMD_FILE")"
      if [[ "$AGENT" == copilot ]]; then FRONT=$'mode: agent\n'; ARGS='${input:args:ticket ID and options, or empty for the board}'
      else FRONT=""; ARGS='$ARGUMENTS'; fi
      printf -- '---\n%sdescription: AI Flow — run the next stage of a ticket (/aiflow <TICKET-ID>), or show the board (/aiflow).\n---\n\nRead and follow `%s/aiflow/SKILL.md` (the AI Flow router) with these arguments: %s\n\nTool names in the skills are Claude Code'"'"'s; map them with `aiflow/AGENTS-TOOLS.md`.\n' \
        "$FRONT" "$SKILLS_REL" "$ARGS" > "$CMD_FILE"
      echo "  add   $CMD_REL"
    fi
  fi

  if [[ "$AGENT" == claude ]]; then
    "$PY" - "$SRC/.claude/settings.json" "$PROJECT_DIR/.claude/settings.json" "$F_GRAPH" <<'PYEOF'
import json, os, sys
src, dst, graph = sys.argv[1:4]
new = json.load(open(src, encoding='utf-8'))
if graph != '1':
    new['hooks'].pop('PreToolUse', None)   # the knowledge-graph reminders
cur = json.load(open(dst, encoding='utf-8')) if os.path.exists(dst) else {}
hooks = cur.setdefault('hooks', {})
for event, entries in new.get('hooks', {}).items():
    have = hooks.setdefault(event, [])
    for e in entries:
        if e not in have:
            have.append(e)
os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(dst, 'w', encoding='utf-8') as fh:
    json.dump(cur, fh, indent=2, ensure_ascii=False)
    fh.write('\n')
PYEOF
    echo "  add   .claude/settings.json hooks (usage log$( [[ $F_GRAPH -eq 1 ]] && echo ', graph reminders' ); merged)"
  fi

  if [[ "$AGENT" == openclaw ]]; then
    if command -v openclaw >/dev/null 2>&1; then
      if [[ -z "$AGENT_NAME" ]]; then ask "  OpenClaw agent name" "aiflow"; AGENT_NAME="$REPLY"; fi
      openclaw agents add "$AGENT_NAME" --workspace "$PROJECT_DIR"
    else
      echo "  note  'openclaw' not found — register later: openclaw agents add <name> --workspace $PROJECT_DIR"
    fi
  fi
}

for a in ${AGENTS//,/ }; do install_agent "$a"; echo; done

# --- .gitignore ----------------------------------------------------------------
GI="$PROJECT_DIR/.gitignore"; touch "$GI"
GI_LINES=("aiflow/.state/")
[[ "$F_GRAPH" -eq 1 ]]  && GI_LINES+=("graphify-out/")
[[ "$F_VISUAL" -eq 1 ]] && GI_LINES+=(".superpowers/")
[[ ",$AGENTS," == *",claude,"* ]] && GI_LINES+=(".claude/settings.local.json")
for line in "${GI_LINES[@]}"; do grep -qxF "$line" "$GI" || echo "$line" >> "$GI"; done
echo "  add   .gitignore entries: ${GI_LINES[*]}"

# --- Environment checks ----------------------------------------------------------
echo
echo "Checks"
check_cli() {  # check_cli <cmd> <auth-args...>
  local c="$1"; shift
  if ! command -v "$c" >/dev/null 2>&1; then
    if [[ "$c" == gh ]]; then echo "  ✗ gh not installed — https://cli.github.com"
    else echo "  ✗ glab not installed — https://gitlab.com/gitlab-org/cli"; fi
    return 0
  fi
  if "$c" "$@" >/dev/null 2>&1; then echo "  ✓ $c installed and logged in"
  elif [[ "$c" == glab && "${GITLAB_HOST:-gitlab.com}" != gitlab.com ]]; then echo "  ! glab not logged in — run: glab auth login --hostname $GITLAB_HOST"
  else echo "  ! $c not logged in — run: $c auth login"; fi
}
if [[ "$GIT_HOST" != gitlab ]]; then check_cli gh auth status; fi
if [[ "$GIT_HOST" != github ]]; then check_cli glab auth status --hostname "${GITLAB_HOST:-gitlab.com}"; fi
if [[ "$F_GRAPH" -eq 1 ]]; then
  if command -v graphify >/dev/null 2>&1; then echo "  ✓ graphify installed"
  else echo "  ✗ graphify not installed — the knowledge graph stays off until it is"; fi
fi
if [[ ",$AGENTS," == *",codex,"* ]]; then echo "  • Codex: subagents need [features] multi_agent = true in ~/.codex/config.toml"; fi

echo
echo "Done. Open $PROJECT_DIR with your agent and run /aiflow setup"
echo "(\$aiflow setup in Codex). It reads aiflow/install.yaml, detects your repos and"
echo "asks only what's left, then writes aiflow/workflow.yaml. Then: /aiflow <TICKET-ID>"
