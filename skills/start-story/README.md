# start-story

Activates a work item or issue and creates the feature branch in one step.
Supports **ADO work items** and **GitHub issues**, selected via the `ISSUE_TRACKER`
config setting.

## Prerequisites

- [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell) (`pwsh`)

**GitHub flow:**

- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated (`gh auth login`)

**ADO flow:**

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az`)
- Logged in to Azure: `az login`
- ADO access to the target organisation and project

## Setup

Add `ISSUE_TRACKER` to the `env` block in `~/.claude/settings.json`:

**GitHub:**

```json
{
  "env": {
    "ISSUE_TRACKER": "github"
  }
}
```

**ADO:**

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

> **Fallback:** If `ISSUE_TRACKER` is not set but `ADO_ORG` is present, the skill
> behaves as `ISSUE_TRACKER=ado` with no error — existing ADO users require no
> migration.

## Install

```bash
npx skills@latest add craigspaterson/agent-skills/skills/start-story
```

## Usage

Say any of the following after identifying a work item or issue to start:

```text
start story 42
start working on AB#42
begin #3
kick off GH#3
start issue 3
```

The skill accepts any of these ID formats and strips prefixes automatically —
routing is driven by `ISSUE_TRACKER`, not the prefix.

## What it does

**GitHub flow:**

1. Checks `gh` CLI is authenticated.
2. Fetches the issue title (warns if the issue is closed, then continues).
3. Creates and pushes `feature/gh-{N}-{slug}`.

**ADO flow:**

1. Authenticates with Azure.
2. Fetches the work item title, state, and assignee.
3. Sets state to **Active** and assigns to `ADO_USER` if not already set.
4. Creates and pushes `feature/AB{N}-{slug}`.

Both flows check whether the branch already exists locally or on origin before
creating it, and exit with a clear message if it does.

## Branch naming

| Tracker | Example branch |
|---------|---------------|
| GitHub  | `feature/gh-3-add-rate-limiting-to-api` |
| ADO     | `feature/AB42-add-rate-limiting-to-api` |

Slug rules: lowercase, non-alphanumeric characters removed, spaces collapsed to
hyphens, capped at 40 characters.
