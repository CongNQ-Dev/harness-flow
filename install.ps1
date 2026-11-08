# Install AI Flow into a project, for any supported coding agent (Windows).
#
#   git clone https://github.com/CongNQ-Dev/ai-flow.git
#   .\ai-flow\install.ps1 -Dir C:\code\my-app -Agent codex
#
# Same behavior as install.sh. Requires Python 3 (the AI Flow scripts use it too).
[CmdletBinding()]
param(
  [string]$Dir = (Get-Location).Path,
  [ValidateSet('', 'claude', 'codex', 'copilot', 'cursor', 'opencode', 'kilocode', 'openclaw')]
  [string]$Agent = '',
  [string]$AgentName = '',
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$Src = $PSScriptRoot

if (-not $Agent) {
  Write-Host 'Which agent will run AI Flow?'
  Write-Host '  1) Claude Code    2) Codex CLI    3) GitHub Copilot    4) Cursor'
  Write-Host '  5) OpenCode       6) Kilo Code    7) OpenClaw'
  $n = Read-Host 'Choose [1-7]'
  $Agent = @{ '1'='claude'; '2'='codex'; '3'='copilot'; '4'='cursor'; '5'='opencode'; '6'='kilocode'; '7'='openclaw' }[$n]
  if (-not $Agent) { throw 'Invalid choice.' }
}

$map = @{
  claude   = @('.claude/skills',   '',                                 'CLAUDE.md', 'Claude Code')
  codex    = @('.agents/skills',   '',                                 'AGENTS.md', 'Codex CLI')
  copilot  = @('.github/skills',   '.github/prompts/aiflow.prompt.md', 'AGENTS.md', 'GitHub Copilot')
  cursor   = @('.cursor/skills',   '.cursor/commands/aiflow.md',       'AGENTS.md', 'Cursor')
  opencode = @('.opencode/skills', '.opencode/commands/aiflow.md',     'AGENTS.md', 'OpenCode')
  kilocode = @('.kilo/skills',     '.kilo/commands/aiflow.md',         'AGENTS.md', 'Kilo Code')
  openclaw = @('skills',           '',                                 'AGENTS.md', 'OpenClaw')
}
$SkillsRel, $CmdRel, $Rules, $Label = $map[$Agent]

$Py = (Get-Command python3 -ErrorAction SilentlyContinue), (Get-Command python -ErrorAction SilentlyContinue), (Get-Command py -ErrorAction SilentlyContinue) |
  Where-Object { $_ } | Select-Object -First 1
if (-not $Py) { throw 'Python 3 is required (the AI Flow scripts use it too).' }
$Py = $Py.Source
function Invoke-Py([string]$code, [string[]]$pyArgs) {
  $tmp = [System.IO.Path]::GetTempFileName() + '.py'
  Set-Content -Path $tmp -Value $code -Encoding UTF8
  try { & $Py $tmp @pyArgs; if ($LASTEXITCODE) { throw "python step failed ($LASTEXITCODE)" } }
  finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}

New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$Project = (Resolve-Path $Dir).Path
if ($Project -eq (Resolve-Path $Src).Path) { throw '-Dir points at the ai-flow repo itself. Choose the project to install into.' }
$SkillsDir = Join-Path $Project $SkillsRel
Write-Host "Installing AI Flow for $Label"
Write-Host "  project: $Project"
Write-Host "  skills:  $SkillsRel/"

# 1. Skills
New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
Get-ChildItem -Directory (Join-Path $Src '.claude/skills') | ForEach-Object {
  $target = Join-Path $SkillsDir $_.Name
  if ((Test-Path $target) -and -not $Force) { Write-Host "  skip  $SkillsRel/$($_.Name) (exists - use -Force to overwrite)"; return }
  if (Test-Path $target) { Remove-Item $target -Recurse -Force }
  Copy-Item $_.FullName $target -Recurse
  Write-Host "  add   $SkillsRel/$($_.Name)"
}

$rewrite = @'
import os, re, sys
root, rel = sys.argv[1], sys.argv[2]
pat = re.compile(r'(?<![\w>/])\.claude/skills/')
for dp, _, files in os.walk(root):
    for f in files:
        p = os.path.join(dp, f)
        try:
            s = open(p, encoding='utf-8').read()
        except (UnicodeDecodeError, PermissionError):
            continue
        n = pat.sub(rel + '/', s)
        if n != s:
            open(p, 'w', encoding='utf-8', newline='').write(n)
'@
if ($SkillsRel -ne '.claude/skills') { Invoke-Py $rewrite @($SkillsDir, $SkillsRel) }

if ($Agent -eq 'openclaw') {
  Invoke-Py @'
import glob, os, sys
for p in glob.glob(os.path.join(sys.argv[1], 'aiflow*', 'SKILL.md')):
    s = open(p, encoding='utf-8').read()
    if not s.startswith('---\n'):
        continue
    head, rest = s[4:].split('\n---', 1)
    lines = [l for l in head.split('\n') if not l.startswith(('user-invocable:', 'command-tool:'))]
    lines += ['user-invocable: true', 'command-tool: true']
    open(p, 'w', encoding='utf-8', newline='').write('---\n' + '\n'.join(lines) + '\n---' + rest)
'@ @($SkillsDir)
}

# 2. aiflow/ runtime
$AiDir = Join-Path $Project 'aiflow'
New-Item -ItemType Directory -Force -Path $AiDir | Out-Null
foreach ($f in 'AIFLOW.md', 'AGENTS-TOOLS.md', 'pricing.json', 'workflow.yaml.template') {
  Copy-Item (Join-Path $Src "aiflow/$f") (Join-Path $AiDir $f) -Force
}
$ScriptsDir = Join-Path $AiDir 'scripts'
if (Test-Path $ScriptsDir) { Remove-Item $ScriptsDir -Recurse -Force }
Copy-Item (Join-Path $Src 'aiflow/scripts') $ScriptsDir -Recurse
Get-ChildItem $ScriptsDir -Recurse -Directory -Filter '__pycache__' | Remove-Item -Recurse -Force
if ($SkillsRel -ne '.claude/skills') { Invoke-Py $rewrite @($ScriptsDir, $SkillsRel) }
Write-Host '  add   aiflow/ (AIFLOW.md, AGENTS-TOOLS.md, scripts/, pricing.json, workflow.yaml.template)'
if (Test-Path (Join-Path $AiDir 'workflow.yaml')) { Write-Host '  keep  aiflow/workflow.yaml (your project config)' }

# 3. Project rules
Invoke-Py @'
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
    pass
else:
    s = (s.rstrip() + '\n\n' if s.strip() else '') + block + '\n'
open(rules, 'w', encoding='utf-8', newline='').write(s)
'@ @((Join-Path $Project $Rules), (Join-Path $AiDir 'AIFLOW.md'), $Agent)
Write-Host "  add   $Rules (AI Flow block between <!-- aiflow:start/end --> markers)"

# 4. /aiflow command file
if ($CmdRel) {
  $CmdFile = Join-Path $Project $CmdRel
  if ((Test-Path $CmdFile) -and -not $Force) {
    Write-Host "  skip  $CmdRel (exists - use -Force to overwrite)"
  } else {
    New-Item -ItemType Directory -Force -Path (Split-Path $CmdFile) | Out-Null
    $desc = 'AI Flow - run the next stage of a ticket (/aiflow <TICKET-ID>), or show the board (/aiflow).'
    if ($Agent -eq 'copilot') {
      $front = "---`nmode: agent`ndescription: $desc`n---"
      $args_ = '${input:args:ticket ID and options, or empty for the board}'
    } else {
      $front = "---`ndescription: $desc`n---"
      $args_ = '$ARGUMENTS'
    }
    $body = "$front`n`nRead and follow ``$SkillsRel/aiflow/SKILL.md`` (the AI Flow router) with these arguments: $args_`n`nTool names in the skills are Claude Code's; map them with ``aiflow/AGENTS-TOOLS.md``.`n"
    [System.IO.File]::WriteAllText($CmdFile, $body, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "  add   $CmdRel"
  }
}

# 5. Claude Code hooks, merged
if ($Agent -eq 'claude') {
  Invoke-Py @'
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
with open(dst, 'w', encoding='utf-8', newline='\n') as fh:
    json.dump(cur, fh, indent=2, ensure_ascii=False)
    fh.write('\n')
'@ @((Join-Path $Src '.claude/settings.json'), (Join-Path $Project '.claude/settings.json'))
  Write-Host '  add   .claude/settings.json hooks (merged with any existing ones)'
}

# 6. .gitignore
$Gi = Join-Path $Project '.gitignore'
if (-not (Test-Path $Gi)) { New-Item -ItemType File -Path $Gi | Out-Null }
$lines = @('graphify-out/', 'aiflow/.state/', '.superpowers/')
if ($Agent -eq 'claude') { $lines += '.claude/settings.local.json' }
$have = @(Get-Content $Gi)
foreach ($l in $lines) { if ($have -notcontains $l) { Add-Content -Path $Gi -Value $l } }
Write-Host '  add   .gitignore entries (graphify-out/, aiflow/.state/, .superpowers/)'

# 7. OpenClaw registration
if ($Agent -eq 'openclaw') {
  if (Get-Command openclaw -ErrorAction SilentlyContinue) {
    if (-not $AgentName) { $AgentName = Read-Host 'OpenClaw agent name' }
    & openclaw agents add $AgentName --workspace $Project
  } else {
    Write-Host "  note  'openclaw' not found - register later with:"
    Write-Host "        openclaw agents add <name> --workspace $Project"
  }
}

Write-Host ''
Write-Host "Done. Next, open $Project with $Label and run:"
if ($Agent -eq 'codex') { Write-Host '  $aiflow setup     (subagents need [features] multi_agent = true in ~/.codex/config.toml)' }
else { Write-Host '  /aiflow setup' }
Write-Host 'It writes aiflow/workflow.yaml (components, test commands, git host, language), then:'
Write-Host '  /aiflow <TICKET-ID>'
if ($Agent -ne 'claude') { Write-Host "Tool-name mapping for ${Label}: aiflow/AGENTS-TOOLS.md" }
