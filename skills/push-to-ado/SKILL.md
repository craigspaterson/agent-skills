---
name: push-to-ado
description: Uploads a drafted User Story or Technical Story to Azure DevOps as a work item, populating Title, Description, Acceptance Criteria, Story Points, Priority, and optionally linking a parent feature. Use when the user says "push to ADO", "create in ADO", "upload to ADO", "add to ADO", or similar after a story has been drafted in conversation.
---

# Push to ADO

Extracts structured fields from the story already in context and calls `upload.ps1` to create the ADO work item. Do not re-derive the API logic — all implementation lives in the script.

## Step 1 — Extract fields from the story in context

Parse the story markdown (output of `/technical-story` or `/user-story`) and collect:

| Field | Source in story markdown |
|---|---|
| `-Title` | `**Title:**` line |
| `-StoryPoints` | numeric value from `**Story Points:**` line |
| `-Priority` | value from `**Priority:**` line (Critical / High / Medium / Low) |
| `-ParentId` | parent feature ID — ask user if not already in context |
| `-Description` | composed markdown block: story statement + Out of Scope + Dependencies + Notes sections |
| `-AcceptanceCriteria` | all AC blocks only (AC1, AC2, … formatted as markdown) |

Work item type is always `User Story` — hardcoded in the script.

## Step 2 — Call the script

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

## Step 3 — Report result

After the script completes, show the user the returned work item URL.
If the script errors, surface the error message and do not retry silently.
