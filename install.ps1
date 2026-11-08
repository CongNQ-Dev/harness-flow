# Install AI Flow into a project — an onboarding that sets up only what you pick (Windows).
#
#   git clone https://github.com/CongNQ-Dev/harness-flow.git
#   .\harness-flow\install.ps1 -Dir C:\code\my-app          # asks step by step
#
# Same steps and result as install.sh: agent(s), git host, language, features.
# Choices are saved in aiflow\install.yaml; /aiflow setup reads them.
[CmdletBinding()]
param(
  [string]$Dir = (Get-Location).Path,
  [string]$Agent = '',          # one or more, comma-separated
  [string]$GitHost = '',        # github | gitlab | mixed
  [string]$GitlabHost = '',
  [string]$Language = '',
  [string]$Features = '',       # graph,visual,wiki | none
  [string]$AgentName = '',
  [switch]$Yes,
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$Src = $PSScriptRoot

$Py = @('python3', 'python', 'py') | ForEach-Object { Get-Command $_ -ErrorAction SilentlyContinue } | Select-Object -First 1
if (-not $Py) { throw 'Python 3 is required (the AI Flow scripts use it too).' }
$Py = $Py.Source
function Invoke-Py([string]$code, [string[]]$pyArgs) {
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("aiflow_" + [guid]::NewGuid().ToString('N') + '.py')
  [System.IO.File]::WriteAllText($tmp, $code, (New-Object System.Text.UTF8Encoding $false))
  try { & $Py $tmp @pyArgs; if ($LASTEXITCODE) { throw "python step failed ($LASTEXITCODE)" } }
  finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}
function Ask([string]$prompt, [string]$default) {
  if ($Yes) { return $default }
  $r = Read-Host "$prompt [$default]"; if ($r) { return $r } else { return $default }
}
function YesNo([string]$prompt, [bool]$default) {
  if ($Yes) { return $default }
  $r = Read-Host ("$prompt [" + $(if ($default) { 'Y/n' } else { 'y/N' }) + ']')
  if (-not $r) { return $default }
  return $r.ToLower().StartsWith('y')
}

Write-Host 'AI Flow onboarding'; Write-Host ''

# 1. Agents
$all = 'claude', 'codex', 'copilot', 'cursor', 'opencode', 'kilocode', 'openclaw'
$labels = 'Claude Code', 'Codex CLI', 'GitHub Copilot', 'Cursor', 'OpenCode', 'Kilo Code', 'OpenClaw'
if (-not $Agent) {
  if ($Yes) { throw '-Agent is required with -Yes.' }
  Write-Host '1) Which agent(s) will run AI Flow? (comma-separated, e.g. 2,3)'
  for ($i = 0; $i -lt $all.Count; $i++) { Write-Host ("   {0}) {1}" -f ($i + 1), $labels[$i]) }
  $picks = (Read-Host '   Choose') -split '[,\s]+' | Where-Object { $_ }
  $Agent = ($picks | ForEach-Object {
    if ($_ -notmatch '^[1-7]$') { throw "Invalid choice: $_" }; $all[[int]$_ - 1] }) -join ','
}
$agents = $Agent -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
foreach ($a in $agents) { if ($all -notcontains $a) { throw "Unknown agent '$a'." } }

# 2. Git host
if (-not $GitHost) {
  if ($Yes) { $GitHost = 'github' } else {
    Write-Host ''; Write-Host '2) Where are pull/merge requests created?'
    Write-Host '   1) GitHub (gh)   2) GitLab (glab)   3) Different per repo (decided in /aiflow setup)'
    $p = Read-Host '   Choose [1]'; if (-not $p) { $p = '1' }
    $GitHost = @{ '1' = 'github'; '2' = 'gitlab'; '3' = 'mixed' }[$p]
    if (-not $GitHost) { throw 'Invalid choice.' }
  }
}
if ('github', 'gitlab', 'mixed' -notcontains $GitHost) { throw '-GitHost must be github, gitlab or mixed.' }
if ($GitHost -ne 'github' -and -not $GitlabHost) { $GitlabHost = Ask '   GitLab host (gitlab.com, or your self-managed host name)' 'gitlab.com' }
$GitlabHost = ($GitlabHost -replace '^https?://', '') -replace '/.*$', ''

# 3. Language
if (-not $Language) {
  if ($Yes) { $Language = 'en' } else {
    Write-Host ''; Write-Host '3) Language for ticket docs and PR text?'
    Write-Host '   1) English   2) 日本語   3) Tiếng Việt   4) Other (type its ISO code)'
    $p = Read-Host '   Choose [1]'; if (-not $p) { $p = '1' }
    switch ($p) { '1' { $Language = 'en' } '2' { $Language = 'ja' } '3' { $Language = 'vi' }
      '4' { $Language = Read-Host '   ISO code (e.g. ko, fr)' } default { throw 'Invalid choice.' } }
  }
}

# 4. Features
$fGraph = $false; $fVisual = $false; $fWiki = $false
if ($Features) {
  if ($Features -ne 'none') {
    foreach ($f in ($Features -split ',')) {
      switch ($f.Trim()) { 'graph' { $fGraph = $true } 'visual' { $fVisual = $true } 'wiki' { $fWiki = $true }
        default { throw "Unknown feature '$f' (graph, visual, wiki, none)." } }
    }
  }
} else {
  if (-not $Yes) { Write-Host ''; Write-Host '4) Optional features' }
  $fGraph = YesNo '   Knowledge graph — maps the code so the agent reads less (needs the graphify CLI)' $true
  $fVisual = YesNo '   Visual companion — local browser page for mockups and diagrams' $false
  $fWiki = YesNo '   Project wiki — /aiflow wiki writes architecture docs (uses tokens)' $true
}

# Target
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$Project = (Resolve-Path $Dir).Path
if ($Project -eq (Resolve-Path $Src).Path) { throw '-Dir points at the harness-flow repo itself. Choose the project to install into.' }
$skip = @()
if (-not $fGraph) { $skip += 'graphify', 'aiflow-analyze' }
if (-not $fVisual) { $skip += 'aiflow-visual' }
if (-not $fWiki) { $skip += 'aiflow-wiki' }
$b = { param($x) if ($x) { '1' } else { '0' } }

Write-Host ''
Write-Host "Installing into $Project"
Write-Host ("  agents: {0} | git host: {1}{2} | language: {3}" -f ($agents -join ','), $GitHost, $(if ($GitlabHost) { " ($GitlabHost)" } else { '' }), $Language)
Write-Host ("  features: knowledge graph={0} visual={1} wiki={2}" -f (& $b $fGraph), (& $b $fVisual), (& $b $fWiki))
Write-Host ''

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

# aiflow/ runtime
$AiDir = Join-Path $Project 'aiflow'
New-Item -ItemType Directory -Force -Path $AiDir | Out-Null
foreach ($f in 'AIFLOW.md', 'AGENTS-TOOLS.md', 'pricing.json', 'workflow.yaml.template') {
  Copy-Item (Join-Path $Src "aiflow/$f") (Join-Path $AiDir $f) -Force
}
$ScriptsDir = Join-Path $AiDir 'scripts'
if (Test-Path $ScriptsDir) { Remove-Item $ScriptsDir -Recurse -Force }
Copy-Item (Join-Path $Src 'aiflow/scripts') $ScriptsDir -Recurse
Get-ChildItem $ScriptsDir -Recurse -Directory -Filter '__pycache__' | Remove-Item -Recurse -Force
Write-Host '  add   aiflow/ runtime (AIFLOW.md, AGENTS-TOOLS.md, scripts/, pricing.json, workflow.yaml.template)'
if (Test-Path (Join-Path $AiDir 'workflow.yaml')) { Write-Host '  keep  aiflow/workflow.yaml (your project config)' }

Invoke-Py @'
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
open(out, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
'@ @((Join-Path $AiDir 'install.yaml'), ($agents -join ','), $GitHost, $GitlabHost, $Language, (& $b $fGraph), (& $b $fVisual), (& $b $fWiki))
Write-Host '  add   aiflow/install.yaml (your onboarding choices)'; Write-Host ''

$map = @{
  claude   = @('.claude/skills',   '',                                 'CLAUDE.md', 'Claude Code')
  codex    = @('.agents/skills',   '',                                 'AGENTS.md', 'Codex CLI')
  copilot  = @('.github/skills',   '.github/prompts/aiflow.prompt.md', 'AGENTS.md', 'GitHub Copilot')
  cursor   = @('.cursor/skills',   '.cursor/commands/aiflow.md',       'AGENTS.md', 'Cursor')
  opencode = @('.opencode/skills', '.opencode/commands/aiflow.md',     'AGENTS.md', 'OpenCode')
  kilocode = @('.kilo/skills',     '.kilo/commands/aiflow.md',         'AGENTS.md', 'Kilo Code')
  openclaw = @('skills',           '',                                 'AGENTS.md', 'OpenClaw')
}

foreach ($a in $agents) {
  $SkillsRel, $CmdRel, $Rules, $Label = $map[$a]
  $SkillsDir = Join-Path $Project $SkillsRel
  Write-Host "[$Label] skills -> $SkillsRel/"
  New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
  Get-ChildItem -Directory (Join-Path $Src '.claude/skills') | ForEach-Object {
    $target = Join-Path $SkillsDir $_.Name
    if ($skip -contains $_.Name) {
      if (Test-Path $target) { Write-Host "  note  $SkillsRel/$($_.Name) left in place (feature not chosen; delete it if unused)" }
      return
    }
    if ((Test-Path $target) -and -not $Force) { Write-Host "  skip  $SkillsRel/$($_.Name) (exists - use -Force)"; return }
    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
    Copy-Item $_.FullName $target -Recurse
    Write-Host "  add   $SkillsRel/$($_.Name)"
  }
  if ($SkillsRel -ne '.claude/skills') { Invoke-Py $rewrite @($SkillsDir, $SkillsRel) }

  if ($a -eq 'openclaw') {
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

  Invoke-Py @'
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
open(rules, 'w', encoding='utf-8', newline='').write(s)
'@ @((Join-Path $Project $Rules), (Join-Path $AiDir 'AIFLOW.md'), $a, (& $b $fGraph))
  Write-Host "  add   $Rules (AI Flow block between <!-- aiflow:start/end --> markers)"

  if ($CmdRel) {
    $CmdFile = Join-Path $Project $CmdRel
    if ((Test-Path $CmdFile) -and -not $Force) { Write-Host "  skip  $CmdRel (exists - use -Force)" }
    else {
      New-Item -ItemType Directory -Force -Path (Split-Path $CmdFile) | Out-Null
      $desc = 'AI Flow — run the next stage of a ticket (/aiflow <TICKET-ID>), or show the board (/aiflow).'
      if ($a -eq 'copilot') { $front = "---`nmode: agent`ndescription: $desc`n---"; $argv = '${input:args:ticket ID and options, or empty for the board}' }
      else { $front = "---`ndescription: $desc`n---"; $argv = '$ARGUMENTS' }
      $body = "$front`n`nRead and follow ``$SkillsRel/aiflow/SKILL.md`` (the AI Flow router) with these arguments: $argv`n`nTool names in the skills are Claude Code's; map them with ``aiflow/AGENTS-TOOLS.md``.`n"
      [System.IO.File]::WriteAllText($CmdFile, $body, (New-Object System.Text.UTF8Encoding $false))
      Write-Host "  add   $CmdRel"
    }
  }

  if ($a -eq 'claude') {
    Invoke-Py @'
import json, os, sys
src, dst, graph = sys.argv[1:4]
new = json.load(open(src, encoding='utf-8'))
if graph != '1':
    new['hooks'].pop('PreToolUse', None)
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
'@ @((Join-Path $Src '.claude/settings.json'), (Join-Path $Project '.claude/settings.json'), (& $b $fGraph))
    Write-Host '  add   .claude/settings.json hooks (merged)'
  }

  if ($a -eq 'openclaw') {
    if (Get-Command openclaw -ErrorAction SilentlyContinue) {
      if (-not $AgentName) { $AgentName = Ask '  OpenClaw agent name' 'aiflow' }
      & openclaw agents add $AgentName --workspace $Project
    } else { Write-Host "  note  'openclaw' not found - register later: openclaw agents add <name> --workspace $Project" }
  }
  Write-Host ''
}

# .gitignore
$Gi = Join-Path $Project '.gitignore'
if (-not (Test-Path $Gi)) { New-Item -ItemType File -Path $Gi | Out-Null }
$lines = @('aiflow/.state/')
if ($fGraph) { $lines += 'graphify-out/' }
if ($fVisual) { $lines += '.superpowers/' }
if ($agents -contains 'claude') { $lines += '.claude/settings.local.json' }
$have = @(Get-Content $Gi)
foreach ($l in $lines) { if ($have -notcontains $l) { Add-Content -Path $Gi -Value $l } }
Write-Host ("  add   .gitignore entries: " + ($lines -join ' '))

# Checks
Write-Host ''; Write-Host 'Checks'
function Test-Cli([string]$c, [string[]]$authArgs, [string]$url, [string]$login) {
  if (-not (Get-Command $c -ErrorAction SilentlyContinue)) { Write-Host "  x $c not installed - $url"; return }
  & $c @authArgs *> $null
  if ($LASTEXITCODE -eq 0) { Write-Host "  ok $c installed and logged in" } else { Write-Host "  ! $c not logged in - run: $login" }
}
$gl = if ($GitlabHost) { $GitlabHost } else { 'gitlab.com' }
if ($GitHost -ne 'gitlab') { Test-Cli 'gh' @('auth', 'status') 'https://cli.github.com' 'gh auth login' }
if ($GitHost -ne 'github') {
  $login = if ($gl -ne 'gitlab.com') { "glab auth login --hostname $gl" } else { 'glab auth login' }
  Test-Cli 'glab' @('auth', 'status', '--hostname', $gl) 'https://gitlab.com/gitlab-org/cli' $login
}
if ($fGraph) {
  if (Get-Command graphify -ErrorAction SilentlyContinue) { Write-Host '  ok graphify installed' }
  else { Write-Host '  x graphify not installed - the knowledge graph stays off until it is' }
}
if ($agents -contains 'codex') { Write-Host '  - Codex: subagents need [features] multi_agent = true in ~/.codex/config.toml' }

Write-Host ''
Write-Host "Done. Open $Project with your agent and run /aiflow setup"
Write-Host '($aiflow setup in Codex). It reads aiflow/install.yaml, detects your repos and'
Write-Host 'asks only what is left, then writes aiflow/workflow.yaml. Then: /aiflow <TICKET-ID>'
