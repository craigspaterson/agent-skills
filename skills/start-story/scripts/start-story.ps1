#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Activates an ADO work item (sets state to Active, assigns to the configured
    user) if either condition is not already met, then creates and pushes the
    corresponding feature branch.

.PARAMETER Id
    Work item ID. Accepts AB#38, AB38, or 38.

.PARAMETER Org
    Optional. ADO organisation name. Falls back to $env:ADO_ORG.

.PARAMETER Project
    Optional. ADO project name. Falls back to $env:ADO_PROJECT.

.PARAMETER User
    Optional. Assignee email. Falls back to $env:ADO_USER.
#>
param(
    [Parameter(Mandatory)][string]$Id,
    [string]$Org,
    [string]$Project,
    [string]$User
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Strip AB# or AB prefix to get numeric ID
$numericId = $Id -replace '^AB#?', ''
if ($numericId -notmatch '^\d+$') {
    Write-Error "Invalid work item ID: '$Id'. Expected a number, AB#N, or ABN."
    exit 1
}

# Config resolution
if (-not $Org)     { $Org     = $env:ADO_ORG }
if (-not $Project) { $Project = $env:ADO_PROJECT }
if (-not $User)    { $User    = $env:ADO_USER }

if (-not $Org)     { Write-Error "ADO_ORG is not set. Add it to ~/.claude/settings.json env block."; exit 1 }
if (-not $Project) { Write-Error "ADO_PROJECT is not set."; exit 1 }
if (-not $User)    { Write-Error "ADO_USER is not set. Add your ADO email to ~/.claude/settings.json env block."; exit 1 }

$baseUrl = "https://dev.azure.com/$Org/$([Uri]::EscapeDataString($Project))"

# Authentication (same pattern as push-to-ado)
Write-Host "Authenticating with Azure..."
$token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv
if (-not $token) {
    Write-Error "Failed to get ADO access token. Run 'az login' first."
    exit 1
}
$headers = @{ Authorization = "Bearer $token" }

# GET work item — fetch only the fields we need
$getUrl = "$baseUrl/_apis/wit/workItems/$numericId`?fields=System.State,System.AssignedTo,System.Title&api-version=7.1"
Write-Host "Fetching AB#$numericId..."
$item = Invoke-RestMethod -Method Get -Uri $getUrl -Headers $headers

$title    = $item.fields.'System.Title'
$state    = $item.fields.'System.State'
$assignee = $item.fields.'System.AssignedTo'.uniqueName  # email; null if unassigned

Write-Host ""
Write-Host "Work item: AB#$numericId — $title"
Write-Host "  State:    $state"
Write-Host "  Assignee: $(if ($assignee) { $assignee } else { '(unassigned)' })"

# Determine what needs changing
$needsState    = $state -ne 'Active'
$needsAssignee = $assignee -ne $User

if ($needsState -or $needsAssignee) {
    $patchOps = [System.Collections.Generic.List[hashtable]]::new()

    if ($needsState) {
        $patchOps.Add(@{ op = "add"; path = "/fields/System.State";       value = "Active" })
    }
    if ($needsAssignee) {
        $patchOps.Add(@{ op = "add"; path = "/fields/System.AssignedTo";  value = $User })
    }

    $body     = $patchOps | ConvertTo-Json -Depth 3
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

# Build branch slug from title:
# lowercase → strip non-alphanumeric → collapse spaces to hyphens → cap at 40 chars
$slug = $title.ToLower() `
    -replace '[^a-z0-9\s]', '' `
    -replace '\s+', '-' `
    -replace '-+', '-'
$slug = $slug.Trim('-')
if ($slug.Length -gt 40) { $slug = $slug.Substring(0, 40).TrimEnd('-') }

$branch = "feature/AB$numericId-$slug"

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

Write-Host ""
Write-Host "Done."
Write-Host "  Branch:    $branch"
Write-Host "  Work item: $baseUrl/_workitems/edit/$numericId"
