---
name: start-story
description: Activates a work item or issue and creates the feature branch in one step. Supports ADO work items and GitHub issues, selected via the ISSUE_TRACKER config setting. Use when the user says "start story", "start working on", "begin AB#N", "kick off AB#N", "start issue #N", or provides a work item/issue ID and wants to begin development.
---

# Start Story

Activates a work item or issue and creates the feature branch in one step.
Supports ADO work items and GitHub issues via the `ISSUE_TRACKER` config
setting.

## Prerequisites

Set `ISSUE_TRACKER` in `~/.claude/settings.json` under the `env` block:

```json
{
  "env": {
    "ISSUE_TRACKER": "github"
  }
}
```

Or for ADO:

```json
{
  "env": {
    "ISSUE_TRACKER": "ado",
    "ADO_ORG": "your-org",
    "ADO_PROJECT": "your-project",
    "ADO_USER": "you@example.com"
  }
}
```

**Fallback:** If `ISSUE_TRACKER` is not set but `ADO_ORG` is present, the skill
behaves as `ISSUE_TRACKER=ado` with no error.

### GitHub flow requirements

- `gh` CLI installed and authenticated (`gh auth login`)

### ADO flow requirements

- `ADO_ORG`, `ADO_PROJECT`, and `ADO_USER` set in the env block
- Azure CLI authenticated (`az login`)

## Step 1 — Parse the ID

Extract the numeric ID from the user's input. Accept any of these formats:

| Format | Example | Tracker hint                         |
| ------ | ------- | ------------------------------------ |
| `AB#N` | `AB#38` | ADO (prefix stripped)                |
| `ABN`  | `AB38`  | ADO (prefix stripped)                |
| `GH#N` | `GH#3`  | GitHub (prefix stripped)             |
| `#N`   | `#3`    | GitHub (prefix stripped)             |
| `N`    | `3`     | Resolved from `ISSUE_TRACKER` config |

Strip all prefixes — routing is driven by `ISSUE_TRACKER`, not the prefix
format.

## Step 2 — Call the script

```powershell
pwsh ~/.claude/skills/start-story/scripts/start-story.ps1 -Id {N}
```

Replace `{N}` with the ID exactly as the user provided it (e.g. `3`, `#3`,
`AB#38`). The script handles prefix stripping and tracker routing internally.

Pass `-Org`, `-Project`, or `-User` only if the user explicitly overrides them
for the ADO flow; otherwise the script reads from env vars.

## Step 3 — Report result

**GitHub flow** — tell the user:

- The issue title and state (warn if closed)
- The feature branch name that was created and pushed (`feature/gh-{N}-{slug}`)

**ADO flow** — tell the user:

- Whether the work item state was changed to Active (or was already Active)
- Whether the assignee was updated (or was already correct)
- The feature branch name that was created and pushed (`feature/AB{N}-{slug}`)

If the script errors, surface the full error message and do not retry silently.
