---
name: push-to-ado
description: Uploads a drafted User Story or Technical Story to Azure DevOps as a work item, populating Title, Description, Acceptance Criteria, Story Points, Priority, and Tags, and optionally linking a parent feature. Also supports creating a full Epic → Feature → Story hierarchy from a structured backlog, and updating existing work items in bulk. Use when the user says "push to ADO", "create in ADO", "upload to ADO", "add to ADO", "update ADO items", or similar after stories have been drafted in conversation.
---

# Push to ADO

Three scripts are available. Choose based on what the user provides:

| Scenario | Script |
|---|---|
| Single story drafted by `/user-story` or `/technical-story` | `upload.ps1` |
| Full backlog with Epics → Features → Stories | `upload-hierarchy.ps1` |
| Bulk update existing work items with improved content | `update-work-items.ps1` |

---

## Single story — `upload.ps1`

Extracts structured fields from the story already in context and calls `upload.ps1` to create the ADO work item. Do not re-derive the API logic — all implementation lives in the script.

### Step 1 — Extract fields from the story in context

Parse the story markdown (output of `/technical-story` or `/user-story`) and collect:

| Field | Source in story markdown |
|---|---|
| `-Title` | `**Title:**` line |
| `-StoryPoints` | numeric value from `**Story Points:**` line |
| `-Priority` | value from `**Priority:**` line (Critical / High / Medium / Low) |
| `-ParentId` | parent feature ID — ask user if not already in context |
| `-Description` | composed markdown block: story statement + Out of Scope + Dependencies + Notes sections |
| `-AcceptanceCriteria` | all AC blocks only (AC1, AC2, … formatted as markdown) |
| `-Tags` | optional; semicolon-separated tags (e.g. `"Technical"`) — omit if none |

Work item type is always `User Story` — hardcoded in the script.

### Step 2 — Call the script

```powershell
pwsh ~/.claude/skills/push-to-ado/scripts/upload.ps1 `
  -Title "..." `
  -Description "..." `
  -AcceptanceCriteria "..." `
  -StoryPoints 3 `
  -Priority "High" `
  -ParentId 2881288
```

Omit `-ParentId` if no parent was provided.

Pass `-Org` and `-Project` only if the user explicitly provides them; otherwise the script reads from `$env:ADO_ORG` / `$env:ADO_PROJECT`.

### Step 3 — Report result

After the script completes, show the user the returned work item URL.
If the script errors, surface the error message and do not retry silently.

---

## Full hierarchy — `upload-hierarchy.ps1`

Use when the user provides a structured backlog with multiple Epics, Features, and Stories to create in one pass.

The script defines a `New-WorkItem` helper function that accepts any ADO work item type (`Epic`, `Feature`, `User Story`) and handles auth, parent linking, and field mapping. Technical stories are created as `User Story` type with the tag `Technical`.

### How to use it

1. Open `scripts/upload-hierarchy.ps1` and replace the placeholder comment with `New-WorkItem` calls for the user's backlog, following the call pattern documented below.
2. Run it:

```powershell
ADO_ORG=myorg ADO_PROJECT=myproject pwsh ~/.claude/skills/push-to-ado/scripts/upload-hierarchy.ps1
```

### `New-WorkItem` parameters

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `-Type` | string | yes | `Epic`, `Feature`, or `User Story` |
| `-Title` | string | yes | |
| `-Description` | string | yes | Rendered as Markdown in ADO |
| `-AcceptanceCriteria` | string | no | Rendered as Markdown; omit for Epics/Features |
| `-StoryPoints` | int | no | Omit for Epics/Features |
| `-Priority` | string | no | `Critical`, `High`, `Medium` (default), `Low` |
| `-ParentId` | int | no | ADO work item ID of the parent |
| `-Tags` | string | no | Semicolon-separated; use `"Technical"` to tag technical stories |

### Parent linking pattern

Capture the returned ID from each Epic/Feature call and pass it as `-ParentId` to its children:

```powershell
$epicId    = New-WorkItem -Type "Epic"    -Title "My Epic" ...
$featureId = New-WorkItem -Type "Feature" -Title "My Feature" -ParentId $epicId ...
             New-WorkItem -Type "User Story" -Title "My Story" -ParentId $featureId ...
```

---

## Bulk update existing items — `update-work-items.ps1`

Use when stories already exist in ADO (created via `upload-hierarchy.ps1` or manually) and need their Title, Description, Acceptance Criteria, Story Points, or Priority replaced with improved content — for example, after re-drafting stories through `/user-story` or `/technical-story`.

### How to use it

1. Open `scripts/update-work-items.ps1` and replace the placeholder comment with one `Update-WorkItem` call per item, providing the known ADO work item ID for each.
2. Run it:

```powershell
ADO_ORG=myorg ADO_PROJECT=myproject pwsh ~/.claude/skills/push-to-ado/scripts/update-work-items.ps1
```

### `Update-WorkItem` parameters

| Parameter | Type | Required | Notes |
|---|---|---|---|
| `-Id` | int | yes | Existing ADO work item ID (e.g. 42) |
| `-Title` | string | yes | Replaces the current title |
| `-Description` | string | yes | Replaces System.Description; rendered as Markdown |
| `-AcceptanceCriteria` | string | no | Replaces AC field; rendered as Markdown |
| `-StoryPoints` | int | yes | Replaces current story points |
| `-Priority` | string | yes | `Critical`, `High`, `Medium`, or `Low` |
| `-Tags` | string | no | Semicolon-separated tags; replaces existing tags when provided |

### Typical workflow

1. Draft improved stories using `/user-story` or `/technical-story`
2. Note the ADO ID of each item to update
3. Populate `update-work-items.ps1` with one `Update-WorkItem` call per item
4. Run the script — all fields are patched in a single PATCH request per item
