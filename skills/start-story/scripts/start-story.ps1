#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Activates a work item or issue and creates the feature branch in one step.
    Supports ADO work items and GitHub issues, selected via ISSUE_TRACKER config.

.PARAMETER Id
    Work item or issue ID. Accepts AB#38, AB38, GH#3, #3, or bare integer.

.PARAMETER Org
    Optional. ADO organisation name. Falls back to $env:ADO_ORG.

.PARAMETER Project
    Optional. ADO project name. Falls back to $env:ADO_PROJECT.

.PARAMETER User
    Optional. ADO assignee email. Falls back to $env:ADO_USER.
#>
param(
    [Parameter(Mandatory)][string]$Id,
    [string]$Org,
    [string]$Project,
    [string]$User
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Strip known prefixes (AB#, AB, GH#, #) to get numeric ID
$numericId = $Id -replace '^(AB#?|GH#|#)', ''
if ($numericId -notmatch '^\d+$') {
    Write-Error "Invalid ID: '$Id'. Expected a number, AB#N, ABN, GH#N, or #N."
    exit 1
}

# Resolve tracker: explicit config wins; fall back to ADO if ADO_ORG is present
$tracker = $env:ISSUE_TRACKER
if (-not $tracker) {
    if ($env:ADO_ORG) {
        $tracker = 'ado'
    } else {
        Write-Error "No issue tracker configured. Set ISSUE_TRACKER=github or ISSUE_TRACKER=ado (plus ADO env vars) in ~/.claude/settings.json."
        exit 1
    }
}
$tracker = $tracker.ToLower()
if ($tracker -notin @('ado', 'github')) {
    Write-Error "ISSUE_TRACKER must be 'ado' or 'github', got '$tracker'."
    exit 1
}

# Shared slug builder
function New-BranchSlug([string]$title) {
    $slug = $title.ToLower() `
        -replace '[^a-z0-9\s]', '' `
        -replace '\s+', '-' `
        -replace '-+', '-'
    $slug = $slug.Trim('-')
    if ($slug.Length -gt 40) { $slug = $slug.Substring(0, 40).TrimEnd('-') }
    return $slug
}

# Shared branch creation with exists check
function New-FeatureBranch([string]$branch) {
    if (git branch --list $branch) {
        Write-Error "Branch '$branch' already exists locally. Check it out manually or delete it first."
        exit 1
    }
    $remoteBranches = git ls-remote --heads origin $branch 2>$null
    if ($remoteBranches) {
        Write-Error "Branch '$branch' already exists on origin. Check it out manually or delete it first."
        exit 1
    }

    Write-Host ""
    Write-Host "Creating branch: $branch"
    git checkout main
    if ($LASTEXITCODE -ne 0) { Write-Error "git checkout main failed"; exit 1 }
    git pull
    if ($LASTEXITCODE -ne 0) { Write-Error "git pull failed"; exit 1 }
    git checkout -b $branch
    if ($LASTEXITCODE -ne 0) { Write-Error "git checkout -b $branch failed"; exit 1 }
    git push -u origin $branch
    if ($LASTEXITCODE -ne 0) { Write-Error "git push failed"; exit 1 }
}

# ── GitHub flow ───────────────────────────────────────────────────────────────
if ($tracker -eq 'github') {
    Write-Host "Checking gh CLI authentication..."
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Error "gh CLI is not installed or not authenticated. Run 'gh auth login' first."
        exit 1
    }
    gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "gh CLI is not installed or not authenticated. Run 'gh auth login' first."
        exit 1
    }

    Write-Host "Fetching GitHub issue #$numericId..."
    $issueJson = gh issue view $numericId --json title,number,state 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error $issueJson
        exit 1
    }
    $issue = $issueJson | ConvertFrom-Json

    Write-Host ""
    Write-Host "Issue: #$($issue.number) — $($issue.title)"
    Write-Host "  State: $($issue.state)"

    if ($issue.state -ne 'OPEN') {
        Write-Warning "Issue #$numericId is closed — proceeding anyway."
    }

    $slug   = New-BranchSlug $issue.title
    $branch = "feature/gh-$numericId-$slug"

    New-FeatureBranch $branch

    Write-Host ""
    Write-Host "Done."
    Write-Host "  Branch: $branch"
    exit 0
}

# ── ADO flow ──────────────────────────────────────────────────────────────────
if (-not $Org)     { $Org     = $env:ADO_ORG }
if (-not $Project) { $Project = $env:ADO_PROJECT }
if (-not $User)    { $User    = $env:ADO_USER }

if (-not $Org)     { Write-Error "ADO_ORG is not set. Add it to ~/.claude/settings.json env block."; exit 1 }
if (-not $Project) { Write-Error "ADO_PROJECT is not set."; exit 1 }
if (-not $User)    { Write-Error "ADO_USER is not set. Add your ADO email to ~/.claude/settings.json env block."; exit 1 }

$baseUrl = "https://dev.azure.com/$Org/$([Uri]::EscapeDataString($Project))"

Write-Host "Authenticating with Azure..."
$token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv
if (-not $token) {
    Write-Error "Failed to get ADO access token. Run 'az login' first."
    exit 1
}
$headers = @{ Authorization = "Bearer $token" }

$getUrl = "$baseUrl/_apis/wit/workItems/$numericId`?fields=System.State,System.AssignedTo,System.Title&api-version=7.1"
Write-Host "Fetching AB#$numericId..."
$item = Invoke-RestMethod -Method Get -Uri $getUrl -Headers $headers

$title    = $item.fields.'System.Title'
$state    = $item.fields.'System.State'
$assignee = ($item.fields.PSObject.Properties['System.AssignedTo']?.Value)?.uniqueName

Write-Host ""
Write-Host "Work item: AB#$numericId — $title"
Write-Host "  State:    $state"
Write-Host "  Assignee: $(if ($assignee) { $assignee } else { '(unassigned)' })"

$needsState    = $state -ne 'Active'
$needsAssignee = $assignee -ne $User

if ($needsState -or $needsAssignee) {
    $patchOps = [System.Collections.Generic.List[hashtable]]::new()
    if ($needsState)    { $patchOps.Add(@{ op = "add"; path = "/fields/System.State";      value = "Active" }) }
    if ($needsAssignee) { $patchOps.Add(@{ op = "add"; path = "/fields/System.AssignedTo"; value = $User }) }

    $body     = $patchOps | ConvertTo-Json -Depth 3 -AsArray
    $patchUrl = "$baseUrl/_apis/wit/workItems/$numericId`?api-version=7.1"

    Write-Host ""
    Write-Host "Updating work item..."
    Invoke-RestMethod -Method Patch -Uri $patchUrl -Headers $headers `
        -Body $body -ContentType "application/json-patch+json" | Out-Null

    if ($needsState)    { Write-Host "  State    → Active" }
    if ($needsAssignee) { Write-Host "  Assignee → $User" }
} else {
    Write-Host ""
    Write-Host "No ADO update needed — already Active and assigned to $User."
}

$slug   = New-BranchSlug $title
$branch = "feature/AB$numericId-$slug"

New-FeatureBranch $branch

Write-Host ""
Write-Host "Done."
Write-Host "  Branch:    $branch"
Write-Host "  Work item: $baseUrl/_workitems/edit/$numericId"
