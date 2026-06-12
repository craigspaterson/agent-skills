#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Creates an Azure DevOps User Story work item from a drafted story.

.PARAMETER Title
    Work item title.

.PARAMETER Description
    Markdown content for System.Description (story statement, out of scope, dependencies, notes).

.PARAMETER AcceptanceCriteria
    Markdown content for Microsoft.VSTS.Common.AcceptanceCriteria (AC blocks only).

.PARAMETER StoryPoints
    Fibonacci story point value (1, 2, 3, 5, 8, 13).

.PARAMETER Priority
    Priority label: Critical, High, Medium, or Low.

.PARAMETER ParentId
    Optional. ADO work item ID of the parent feature to link as parent.

.PARAMETER Org
    Optional. ADO organisation name. Falls back to $env:ADO_ORG.

.PARAMETER Project
    Optional. ADO project name. Falls back to $env:ADO_PROJECT.
#>
param(
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$Description,
    [Parameter(Mandatory)][string]$AcceptanceCriteria,
    [Parameter(Mandatory)][int]$StoryPoints,
    [Parameter(Mandatory)][string]$Priority,
    [int]$ParentId,
    [string]$Org,
    [string]$Project
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Config resolution ---
if (-not $Org)     { $Org     = $env:ADO_ORG }
if (-not $Project) { $Project = $env:ADO_PROJECT }

if (-not $Org) {
    $Org = Read-Host "ADO organisation name (e.g. 'myorg' for https://dev.azure.com/myorg)"
    Write-Host "Tip: set `$env:ADO_ORG in ~/.claude/settings.json to avoid this prompt."
}
if (-not $Project) {
    $Project = Read-Host "ADO project name"
    Write-Host "Tip: set `$env:ADO_PROJECT in ~/.claude/settings.json to avoid this prompt."
}

$baseUrl = "https://dev.azure.com/$Org/$([Uri]::EscapeDataString($Project))"

# --- Authentication ---
Write-Host "Authenticating with Azure..."
$token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv
if (-not $token) {
    Write-Error "Failed to get ADO access token. Ensure you are logged in with 'az login'."
    exit 1
}
$headers = @{ Authorization = "Bearer $token" }

# --- Priority mapping ---
$priorityMap = @{ Critical = 1; High = 2; Medium = 3; Low = 4 }
$priorityValue = $priorityMap[$Priority]
if (-not $priorityValue) {
    Write-Warning "Unknown priority '$Priority', defaulting to Medium (3)."
    $priorityValue = 3
}

# --- Build JSON Patch body ---
$patchOps = [System.Collections.Generic.List[hashtable]]::new()

$patchOps.Add(@{ op = "add"; path = "/fields/System.Title";                              value = $Title })
$patchOps.Add(@{ op = "add"; path = "/fields/System.Description";                        value = $Description })
$patchOps.Add(@{ op = "add"; path = "/multilineFieldsFormat/System.Description";         value = "Markdown" })
$patchOps.Add(@{ op = "add"; path = "/fields/Microsoft.VSTS.Common.AcceptanceCriteria";  value = $AcceptanceCriteria })
$patchOps.Add(@{ op = "add"; path = "/multilineFieldsFormat/Microsoft.VSTS.Common.AcceptanceCriteria"; value = "Markdown" })
$patchOps.Add(@{ op = "add"; path = "/fields/Microsoft.VSTS.Scheduling.StoryPoints";     value = $StoryPoints })
$patchOps.Add(@{ op = "add"; path = "/fields/Microsoft.VSTS.Common.Priority";            value = $priorityValue })

if ($ParentId) {
    $parentUrl = "https://dev.azure.com/$Org/$([Uri]::EscapeDataString($Project))/_apis/wit/workItems/$ParentId"
    $patchOps.Add(@{
        op    = "add"
        path  = "/relations/-"
        value = @{
            rel        = "System.LinkTypes.Hierarchy-Reverse"
            url        = $parentUrl
            attributes = @{ comment = "" }
        }
    })
}

$body = $patchOps | ConvertTo-Json -Depth 5

# --- Create work item ---
$workItemType = "User Story"
$encodedType  = [Uri]::EscapeDataString($workItemType)
$createUrl    = "$baseUrl/_apis/wit/workItems/`$$encodedType`?api-version=7.1"

Write-Host "Creating '$workItemType' in ADO..."
$response = Invoke-RestMethod `
    -Method Patch `
    -Uri $createUrl `
    -Headers $headers `
    -Body $body `
    -ContentType "application/json-patch+json"

$itemId  = $response.id
$itemUrl = "https://dev.azure.com/$Org/$([Uri]::EscapeDataString($Project))/_workitems/edit/$itemId"

Write-Host ""
Write-Host "Work item created: AB#$itemId"
Write-Host $itemUrl
