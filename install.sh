#!/usr/bin/env bash
# Installs the AI Flow skill bundle (the /aiflow router + its 8 stage skills
# + the 7 generic engineering-discipline skills it uses internally + the
# scripts, hooks and manifest template) into a target project — WITHOUT
# requiring you to `git clone` this ai-flow-demo repo yourself. Mirrors
# harness-workflow's own install.sh: clones into a throwaway temp dir, copies
# only what's needed, cleans up.
#
# What this does NOT do: fill in aiflow/workflow.yaml for you (every repo
# fact — names, stacks, test commands — is your project's own; see
# aiflow/workflow.yaml.template), or clone your project's source repos.
set -euo pipefail

REPO_URL="https://gitlab.shiftasia.com/cong.nguyen.02/ai-flow-demo.git"

PROJECT_DIR=""
REF=""
FORCE=0

usage() {
  cat <<'EOF'
Usage: install.sh [--dir <path>] [--ref <git-ref>] [--force]

  --dir <path>   Project/workspace folder to install into.
                 Prompted if omitted (default: current directory).
  --ref <ref>    Branch/tag/commit of ai-flow-demo to install from.
                 Default: the repo's default branch (main).
  --force        Overwrite existing skill directories / settings.json /
                 scripts if they already exist at the target. Without it,
                 an existing file or directory is left untouched and
                 reported as skipped, never silently clobbered.
  -h, --help     Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) PROJECT_DIR="$2"; shift 2 ;;
    --dir=*) PROJECT_DIR="${1#*=}"; shift ;;
    --ref) REF="$2"; shift 2 ;;
    --ref=*) REF="${1#*=}"; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

command -v git >/dev/null 2>&1 || { echo "Error: git is required but not found in PATH." >&2; exit 1; }

if [[ -z "$PROJECT_DIR" ]]; then
  read -r -p "Project folder to install into [.]: " PROJECT_DIR
  PROJECT_DIR="${PROJECT_DIR:-.}"
fi
mkdir -p "$PROJECT_DIR"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
echo "Target project: $PROJECT_DIR"

TMPDIR_CLONE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_CLONE"' EXIT

echo "Cloning ai-flow-demo (temporary, cleaned up after install)..."
CLONE_ARGS=(--depth 1)
[[ -n "$REF" ]] && CLONE_ARGS+=(--branch "$REF")
SOURCE_DIR="$TMPDIR_CLONE/ai-flow-demo"
git clone "${CLONE_ARGS[@]}" "$REPO_URL" "$SOURCE_DIR"

[[ -d "$SOURCE_DIR/.claude/skills/aiflow" ]] || {
  echo "Error: $SOURCE_DIR/.claude/skills/aiflow not found — unexpected repo layout." >&2
  exit 1
}

copy_dir() {
  # copy_dir <source-relative> <target-relative> <label>
  local src="$SOURCE_DIR/$1" dst="$PROJECT_DIR/$2" label="$3"
  if [[ -e "$dst" && "$FORCE" -ne 1 ]]; then
    echo "  skip (exists): $2  — re-run with --force to overwrite"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  rm -rf "$dst"
  cp -a "$src" "$dst"
  echo "  installed: $2  ($label)"
}

copy_file() {
  # copy_file <source-relative> <target-relative> <label>
  local src="$SOURCE_DIR/$1" dst="$PROJECT_DIR/$2" label="$3"
  if [[ -e "$dst" && "$FORCE" -ne 1 ]]; then
    echo "  skip (exists): $2  — re-run with --force to overwrite"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
  echo "  installed: $2  ($label)"
}

echo
echo "AI Flow skills (the pipeline):"
for skill in aiflow aiflow-spec aiflow-plan aiflow-impl aiflow-testgen aiflow-review aiflow-analyze aiflow-wiki; do
  copy_dir ".claude/skills/$skill" ".claude/skills/$skill" "stage skill"
done

echo
echo "Engineering-discipline skills (internal, hidden from the / menu):"
for skill in test-driven-development systematic-debugging verification-before-completion \
             receiving-code-review requesting-code-review dispatching-parallel-agents graphify; do
  copy_dir ".claude/skills/$skill" ".claude/skills/$skill" "internal, user-invocable: false"
done

echo
echo "Scripts, config template and hooks:"
copy_dir  "aiflow/scripts" "aiflow/scripts" "aiflow_status.py / aiflow_log.py / kg_build.py"
copy_file "aiflow/pricing.json" "aiflow/pricing.json" "model prices for the cost estimate"
copy_file "aiflow/workflow.yaml.template" "aiflow/workflow.yaml.template" "fill this in as aiflow/workflow.yaml — see next steps"

if [[ -e "$PROJECT_DIR/.claude/settings.json" ]]; then
  echo "  skip (exists): .claude/settings.json — merge the hooks from"
  echo "    $SOURCE_DIR/.claude/settings.json yourself (knowledge-graph reminder"
  echo "    PreToolUse hooks + the usage-log Stop hook); this installer never"
  echo "    overwrites a settings.json that already exists."
else
  copy_file ".claude/settings.json" ".claude/settings.json" "knowledge-graph reminder + usage-log hook"
fi

echo
echo "Scaffolding empty directories:"
mkdir -p "$PROJECT_DIR/docs/aiflow" "$PROJECT_DIR/aiflow/selected-bugs"
touch "$PROJECT_DIR/docs/aiflow/.gitkeep" "$PROJECT_DIR/aiflow/selected-bugs/.gitkeep"
echo "  docs/aiflow/.gitkeep, aiflow/selected-bugs/.gitkeep"

GITIGNORE="$PROJECT_DIR/.gitignore"
touch "$GITIGNORE"
for line in "graphify-out/" "aiflow/.state/" ".claude/settings.local.json"; do
  grep -qxF "$line" "$GITIGNORE" 2>/dev/null || echo "$line" >> "$GITIGNORE"
done
echo "  .gitignore: ensured graphify-out/, aiflow/.state/, .claude/settings.local.json"
echo "  (wiki/ is deliberately NOT gitignored — it's curated content, meant to be committed)"

echo
echo "Done. Next steps:"
echo "  1. cp aiflow/workflow.yaml.template aiflow/workflow.yaml"
echo "     — fill in project/project_code/language, each repo (path, remote,"
echo "       base_branch, stack, qa_surface, test, lint, notes), contracts (or"
echo "       contracts: [] for a single-repo project), triage.sensitive_areas."
echo "  2. Clone your project's own repo(s) as sibling folders here, matching"
echo "     the 'path:' you set per repo in workflow.yaml."
echo "  3. Open this folder in Claude Code and run: /aiflow-analyze"
echo "     (builds the knowledge graph — needs the 'graphify' CLI installed)"
echo "  4. Start your first ticket: /aiflow <TICKET-ID>"
echo
echo "Full walkthrough (adapt the repo names to yours): see aiflow/README.en.md"
echo "and aiflow/guide.html at $REPO_URL"
