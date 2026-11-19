#!/usr/bin/env pwsh
# Collects what changed since the previous standup and writes it as one
# Markdown file for the standup-prep skill to read. Read-only: it fetches and
# queries, it never pushes, comments or changes a work item or issue.
# Settings come from the config file (see config.example.json), never from this script.
param(
    [string]$Since,                 # local date/time; default = previous workday at workday_start
    [string]$OutDir = (Join-Path ([IO.Path]::GetTempPath()) 'standup-prep'),
    [string]$Config = $(if ($env:STANDUP_CONFIG) { $env:STANDUP_CONFIG } else { Join-Path $HOME '.config/standup-prep/config.json' })
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

function Expand-Home([string]$p) {
    if (-not $p) { return $p }
    if ($p -eq '~') { return $HOME }
    if ($p.StartsWith('~/') -or $p.StartsWith('~\')) { return Join-Path $HOME $p.Substring(2) }
    return $p
}
function Get-Setting($obj, [string]$name, $default = $null) {
    if ($obj -and $obj.PSObject.Properties[$name] -and $null -ne $obj.$name -and "$($obj.$name)" -ne '') { return $obj.$name }
    return $default
}

if (-not (Test-Path $Config)) {
    Write-Error "Config not found: $Config. Copy config.example.json there and edit it."
    exit 1
}
$cfg = Get-Content $Config -Raw | ConvertFrom-Json

$owner    = Get-Setting $cfg 'github_owner'
$root     = Expand-Home (Get-Setting $cfg 'repos_root' (Get-Location).Path)
$repos    = @(Get-Setting $cfg 'repos' @())
$ado      = Get-Setting $cfg 'ado'
$adoOrg   = Get-Setting $ado 'org' $env:ADO_ORG
$adoProj  = Get-Setting $ado 'project' $env:ADO_PROJECT
$adoUser  = Get-Setting $ado 'user' $env:ADO_USER
$tracker  = Get-Setting $cfg 'issue_tracker' $(if ($adoOrg) { 'ado' } else { 'github' })
$deploys  = @(Get-Setting $cfg 'deploy_workflows' @())
$memDir   = Expand-Home (Get-Setting $cfg 'memory_dir')
$dayStart = Get-Setting $cfg 'workday_start' '09:00'
$gitEmail = Get-Setting $cfg 'git_email' (git config user.email 2>$null)
if (-not $repos) { Write-Error "No repos configured in $Config"; exit 1 }
$ownerArgs = if ($owner) { @('--owner', $owner) } else { @() }
$ownerPfx  = if ($owner) { "$owner/" } else { '' }

# The standup this prepares for: today before noon, else the next workday.
$standup = (Get-Date).Date
if ((Get-Date).Hour -ge 12) { $standup = $standup.AddDays(1) }
while ($standup.DayOfWeek -in 'Saturday', 'Sunday') { $standup = $standup.AddDays(1) }
if (-not $Since) {
    # From the previous standup (previous workday at workday_start).
    $d = $standup.AddDays(-1)
    while ($d.DayOfWeek -in 'Saturday', 'Sunday') { $d = $d.AddDays(-1) }
    $Since = "$($d.ToString('yyyy-MM-dd')) $dayStart"
}
$sinceLocal = Get-Date $Since
$sinceUtc   = $sinceLocal.ToUniversalTime()
$sinceDate  = $sinceLocal.ToString('yyyy-MM-dd')
$sinceIso   = $sinceUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$out = Join-Path $OutDir ("gather-{0}.md" -f $standup.ToString('yyyy-MM-dd'))
$sb = [System.Text.StringBuilder]::new()
function Add([string]$line = '') { [void]$sb.AppendLine($line) }

$me = (gh api user --jq .login 2>$null)
Add "# Standup data"
Add ""
Add "- Standup date: $($standup.ToString('yyyy-MM-dd ddd'))"
Add "- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm') local"
Add "- Since: $($sinceLocal.ToString('yyyy-MM-dd HH:mm')) local ($sinceIso)"
Add "- GitHub user: $me; work tracker: $tracker"
Add ""

# ---------------------------------------------------------------- commits
Add "## Commits (all branches, mine)"
foreach ($r in $repos) {
    $dir = Join-Path $root $r
    if (-not (Test-Path $dir)) { Add "- $r`: (not cloned)"; continue }
    git -C $dir fetch -q --all --prune 2>$null
    $authorArg = if ($gitEmail) { @("--author=$gitEmail") } else { @() }
    $log = git -C $dir log --all --since="$sinceIso" @authorArg --no-merges `
        --format='%h|%ad|%D|%s' --date=format:'%m-%d %H:%M' 2>$null
    if ($log) {
        Add "### $r"
        foreach ($l in $log) { Add "- $l" }
    }
}
Add ""

# ---------------------------------------------------------------- pull requests
function Add-PrSearch([string]$title, [string[]]$args2) {
    Add "## $title"
    $json = gh search prs @args2 @ownerArgs --limit 50 `
        --json repository,number,title,state,isDraft,url,updatedAt,author 2>$null
    $items = @()
    if ($json) { $items = @($json | ConvertFrom-Json) }
    $items = @($items | Where-Object { $repos -contains $_.repository.name -and $_.author.login -notmatch 'dependabot|renovate' })
    if (-not $items) { Add "- none"; Add ""; return }
    foreach ($p in $items) {
        $extra = ''
        if ($p.state -eq 'open') {
            $v = gh pr view $p.number -R "$ownerPfx$($p.repository.name)" `
                --json reviewDecision,statusCheckRollup,headRefName 2>$null | ConvertFrom-Json
            if ($v) {
                $checks = @($v.statusCheckRollup)
                $fail = @($checks | Where-Object { $_.conclusion -in 'FAILURE', 'TIMED_OUT', 'CANCELLED' }).Count
                $pend = @($checks | Where-Object { -not $_.conclusion -and $_.status -ne 'COMPLETED' }).Count
                $extra = " | review: $($v.reviewDecision) | checks: $($checks.Count) total, $fail failing, $pend pending | branch: $($v.headRefName)"
            }
        }
        $draft = if ($p.isDraft) { ' (draft)' } else { '' }
        Add "- $($p.repository.name)#$($p.number) [$($p.state)$draft] $($p.title)$extra | $($p.url)"
    }
    Add ""
}
Add-PrSearch 'PRs I authored, updated since' @('--author', '@me', '--updated', ">=$sinceDate")
Add-PrSearch 'PRs I reviewed or commented on, updated since' @('--commenter', '@me', '--updated', ">=$sinceDate")
Add-PrSearch 'Open PRs waiting for my review' @('--review-requested', '@me', '--state', 'open')
Add-PrSearch 'All my open PRs' @('--author', '@me', '--state', 'open')

# ---------------------------------------------------------------- workflow runs
Add "## Workflow runs I started, since"
foreach ($r in $repos) {
    $runs = gh run list -R "$ownerPfx$r" --user $me --created ">=$sinceDate" --limit 30 `
        --json workflowName,displayTitle,headBranch,conclusion,status,createdAt,url 2>$null
    if (-not $runs) { continue }
    $runs = @($runs | ConvertFrom-Json)
    if (-not $runs) { continue }
    Add "### $r"
    foreach ($x in $runs) {
        $res = if ($x.conclusion) { $x.conclusion } else { $x.status }
        Add "- $($x.createdAt) $($x.workflowName) | $($x.displayTitle) | $($x.headBranch) | $res"
    }
}
Add ""

# ---------------------------------------------------------------- configured deploy workflows (any author)
foreach ($w in $deploys) {
    $label = Get-Setting $w 'label' "Latest runs of $($w.workflow)"
    Add "## $label ($($w.repo), any author)"
    $dep = gh run list -R "$ownerPfx$($w.repo)" --workflow $w.workflow --limit 3 `
        --json headBranch,createdAt,conclusion,displayTitle 2>$null
    if ($dep) { foreach ($x in ($dep | ConvertFrom-Json)) { Add "- $($x.createdAt) $($x.headBranch) $($x.conclusion) $($x.displayTitle)" } }
    Add ""
}

# ---------------------------------------------------------------- work items
if ($tracker -eq 'github') {
    Add "## GitHub issues"
    foreach ($q in @(
        @{ Title = 'Issues I touched since'; Args = @('--involves', '@me', '--updated', ">=$sinceDate") },
        @{ Title = 'Open issues assigned to me'; Args = @('--assignee', '@me', '--state', 'open') })) {
        Add "### $($q.Title)"
        $json = gh search issues @($q.Args) @ownerArgs --limit 50 --json repository,number,title,state,url,labels 2>$null
        $items = @(); if ($json) { $items = @($json | ConvertFrom-Json) }
        $items = @($items | Where-Object { $repos -contains $_.repository.name })
        if (-not $items) { Add "- none"; continue }
        foreach ($i in $items) {
            $labels = (@($i.labels) | ForEach-Object { $_.name }) -join ','
            Add "- $($i.repository.name)#$($i.number) [$($i.state)] $($i.title) | labels: $labels | $($i.url)"
        }
    }
    Add ""
} elseif ($tracker -eq 'ado') {
Add "## ADO work items"
$token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv 2>$null
if (-not $token -or -not $adoOrg -or -not $adoProj -or -not $adoUser) {
    Add "- ADO unavailable: az login required, or ado.org/project/user missing from config"
} else {
    $h = @{ Authorization = "Bearer $token" }
    $wiqlBase = "https://dev.azure.com/$adoOrg/$([Uri]::EscapeDataString($adoProj))/_apis/wit/wiql?timePrecision=true&api-version=7.1"
    $queries = [ordered]@{
        'Changed since, assigned to me or changed by me' = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '$adoProj' AND [System.ChangedDate] >= '$($sinceUtc.ToString('yyyy-MM-ddTHH:mm:ssZ'))' AND ([System.AssignedTo] = '$adoUser' OR [System.ChangedBy] = '$adoUser') ORDER BY [System.ChangedDate] DESC"
        'Open, assigned to me (stories, bugs, tasks)'   = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '$adoProj' AND [System.AssignedTo] = '$adoUser' AND [System.WorkItemType] IN ('User Story', 'Bug', 'Task') AND [System.State] IN ('New', 'Active') ORDER BY [System.IterationPath] DESC"
    }
    $seenDetail = @{}
    foreach ($q in $queries.GetEnumerator()) {
        Add "### $($q.Key)"
        $res = $null
        try {
            $res = Invoke-RestMethod -Method Post -Uri $wiqlBase -Headers $h -ContentType 'application/json' `
                -Body (@{ query = $q.Value } | ConvertTo-Json)
        } catch { Add "- query failed: $($_.Exception.Message)" }
        $ids = @()
        if ($res -and $res.workItems) { $ids = @($res.workItems.id | Select-Object -First 60) }
        if (-not $ids) { Add "- none"; continue }
        $fields = 'System.Id,System.Title,System.State,System.WorkItemType,System.IterationPath,System.Tags,System.ChangedDate,System.ChangedBy,System.Description'
        $items = Invoke-RestMethod -Uri "https://dev.azure.com/$adoOrg/_apis/wit/workitems?ids=$($ids -join ',')&fields=$fields&api-version=7.1" -Headers $h
        foreach ($w in $items.value) {
            $f = $w.fields
            foreach ($opt in 'System.Tags', 'System.Description') {
                if (-not $f.PSObject.Properties[$opt]) { $f | Add-Member -NotePropertyName $opt -NotePropertyValue '' }
            }
            $iter = ($f.'System.IterationPath' -split '\\')[-1]
            Add "- AB#$($w.id) [$($f.'System.WorkItemType') | $($f.'System.State') | $iter] $($f.'System.Title') | tags: $($f.'System.Tags') | changed $($f.'System.ChangedDate') by $(if ($f.PSObject.Properties['System.ChangedBy']) { $f.'System.ChangedBy'.uniqueName })"
            if (($f.'System.State' -in 'New', 'Active') -and -not $seenDetail.ContainsKey($w.id)) {
                $seenDetail[$w.id] = $true
                $desc = ''
                if ($f.PSObject.Properties['System.Description']) { $desc = [string]$f.'System.Description' }
                $desc = ($desc -replace '<[^>]+>', ' ' -replace '&nbsp;', ' ' -replace '&quot;', '"' -replace '&amp;', '&' -replace '\s+', ' ').Trim()
                if ($desc.Length -gt 1500) { $desc = $desc.Substring(0, 1500) + '...' }
                if ($desc) { Add "    - description: $desc" }
            }
        }
        # Comments added since on the items in the first query.
        if ($q.Key -like 'Changed*') {
            foreach ($id in ($ids | Select-Object -First 25)) {
                try {
                    $c = Invoke-RestMethod -Uri "https://dev.azure.com/$adoOrg/$([Uri]::EscapeDataString($adoProj))/_apis/wit/workItems/$id/comments?api-version=7.1-preview.4" -Headers $h
                    foreach ($cm in @($c.comments | Where-Object { [datetime]$_.createdDate -ge $sinceUtc })) {
                        $t = ($cm.text -replace '<[^>]+>', ' ' -replace '\s+', ' ').Trim()
                        if ($t.Length -gt 600) { $t = $t.Substring(0, 600) + '...' }
                        Add "    - comment on AB#$id by $($cm.createdBy.uniqueName): $t"
                    }
                } catch { }
            }
        }
    }
}
Add ""
}

# ---------------------------------------------------------------- memory
if ($memDir) {
    Add "## Memory files changed since"
    if (Test-Path $memDir) {
        Get-ChildItem $memDir -Filter *.md | Where-Object { $_.LastWriteTime -ge $sinceLocal -and $_.Name -ne 'MEMORY.md' } |
            ForEach-Object { Add "- $($_.FullName)" }
    }
    Add ""
}

Set-Content -Path $out -Value $sb.ToString() -Encoding utf8
Write-Output $out
