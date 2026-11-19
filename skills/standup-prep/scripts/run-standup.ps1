#!/usr/bin/env pwsh
# Scheduled entry point (Task Scheduler, launchd or cron). Gathers the data, then runs
# Claude Code headless with only the tools the output step needs: no shell, and file
# writes only when output is "markdown". Settings come from the config file.
$ErrorActionPreference = 'Continue'
$skill   = Join-Path $HOME '.claude/skills/standup-prep'
$cfgPath = if ($env:STANDUP_CONFIG) { $env:STANDUP_CONFIG } else { Join-Path $HOME '.config/standup-prep/config.json' }
$logDir  = Join-Path $HOME '.local/state/standup-prep/logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir ("run-{0}.log" -f (Get-Date -Format 'yyyy-MM-dd_HHmm'))
Start-Transcript -Path $log -Append | Out-Null

function Expand-Home([string]$p) {
    if ($p -eq '~') { return $HOME }
    if ($p.StartsWith('~/') -or $p.StartsWith('~\')) { return Join-Path $HOME $p.Substring(2) }
    return $p
}

# Skip weekends (the trigger runs on weekdays, but a missed Friday run can catch up on Saturday).
if ((Get-Date).DayOfWeek -in 'Saturday', 'Sunday') { 'Weekend: nothing to do.'; Stop-Transcript | Out-Null; exit 0 }
if (-not (Test-Path $cfgPath)) { "Config not found: $cfgPath"; Stop-Transcript | Out-Null; exit 1 }
$cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
$output = if ($cfg.PSObject.Properties['output'] -and $cfg.output) { $cfg.output } else { 'markdown' }

$gather = pwsh -NoProfile -File (Join-Path $skill 'scripts/gather.ps1') | Select-Object -Last 1
"Gather file: $gather"

$claude = (Get-Command claude -ErrorAction SilentlyContinue).Source
if (-not $claude) { 'claude CLI not found on PATH'; Stop-Transcript | Out-Null; exit 1 }

$allowed = @('Read', 'Glob', 'Grep')
$addDirs = @((Split-Path $gather), $skill, (Split-Path $cfgPath))
if ($output -eq 'doc') {
    # Server-level entries allow every tool of the Claude Docs connector and the Artifact tool.
    $allowed += 'Artifact', 'mcp__claude_ai_Claude_Docs'
} else {
    $outDir = Expand-Home $(if ($cfg.PSObject.Properties['output_dir'] -and $cfg.output_dir) { $cfg.output_dir } else { '~/standups' })
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $allowed += "Write($outDir/*)"
    $addDirs += $outDir
}

# Run from the first configured repo so the same project memory loads as in interactive sessions.
$wd = Join-Path (Expand-Home $cfg.repos_root) $cfg.repos[0]
if (Test-Path $wd) { Set-Location $wd }

$dirArgs = $addDirs | ForEach-Object { '--add-dir'; $_ }
& $claude -p "/standup-prep Gather file: $gather" `
    --allowedTools ($allowed -join ',') @dirArgs --output-format text
"Exit code: $LASTEXITCODE"
Stop-Transcript | Out-Null

# The gather file holds colleagues' comments: delete it, and keep 30 days of logs.
Remove-Item $gather -Force -ErrorAction SilentlyContinue
Get-ChildItem $logDir -Filter 'run-*.log' | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force
