# push-to-ado

Uploads a drafted User Story or Technical Story to Azure DevOps as a work item.

## Prerequisites

- [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell) (`pwsh`)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az`)
- Logged in to Azure: `az login`
- ADO access to the target organisation and project

## Setup

Set environment variables to avoid being prompted on every run:

```bash
# ~/.claude/settings.json or your shell profile
export ADO_ORG=myorg
export ADO_PROJECT=myproject
```

Or pass them directly as script parameters (`-Org` / `-Project`).

## Install

```bash
npx skills add craigspaterson/agent-skills/skills/push-to-ado
```

## Usage

After drafting a story with `/user-story` or `/technical-story`, say:

```
push to ADO
```

The agent extracts the title, description, acceptance criteria, story points, and priority from the story in context, then calls `scripts/upload.ps1` to create the work item. It will ask for a parent feature ID if one wasn't provided.

## Output

On success the agent returns the work item URL:

```
Work item created: AB#12345
https://dev.azure.com/myorg/myproject/_workitems/edit/12345
```
