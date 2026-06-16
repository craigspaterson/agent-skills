---
name: start-story
description: Activates an ADO work item (sets state to Active and assigns to the configured team member if needed) then creates and pushes the feature branch. Use when the user says "start story", "start working on", "begin AB#N", "kick off AB#N", or provides a work item ID and wants to begin development.
---

# Start Story

Activates an ADO work item and creates the feature branch in one step.

## Prerequisites

Ensure these are set in `~/.claude/settings.json` under the `env` block:

```json
{
  "env": {
    "ADO_ORG": "your-org",
    "ADO_PROJECT": "your-project",
    "ADO_USER": "you@example.com"
  }
}
```

`ADO_USER` is the email address used to assign the work item. The script skips the assignment update if the work item is already assigned to that user.

## Step 1 — Parse the work item ID

Extract the numeric ID from the user's input. Accept any of these formats:
- `AB#38`
- `AB38`
- `38`

Strip any `AB#` or `AB` prefix to get the numeric ID.

## Step 2 — Call the script

```powershell
pwsh ~/.claude/skills/start-story/scripts/start-story.ps1 -Id {N}
```

Replace `{N}` with the numeric work item ID (e.g. `38`, not `AB#38` — the script handles the prefix internally but passing the number is cleanest).

Pass `-Org`, `-Project`, or `-User` only if the user explicitly overrides them; otherwise the script reads from env vars.

## Step 3 — Report result

After the script completes, tell the user:
- Whether the work item state was changed to Active (or was already Active)
- Whether the assignee was updated (or was already correct)
- The feature branch name that was created and pushed

If the script errors, surface the full error message and do not retry silently.
