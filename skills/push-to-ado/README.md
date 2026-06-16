# push-to-ado

Uploads and updates work items in Azure DevOps. Supports three modes:

- **Single story** — push one drafted User Story or Technical Story via `upload.ps1`
- **Full hierarchy** — create a complete Epic → Feature → Story backlog in one pass via `upload-hierarchy.ps1`
- **Bulk update** — patch Title, Description, AC, Story Points, Priority, and Tags on existing items via `update-work-items.ps1`

## Prerequisites

- [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell) (`pwsh`)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az`)
- Logged in to Azure: `az login`
- ADO access to the target organisation and project

## Setup

Set environment variables to avoid being prompted on every run:

```bash
# ~/.claude/settings.json env block, or your shell profile
export ADO_ORG=myorg
export ADO_PROJECT=myproject
```

Or pass them directly as script parameters (`-Org` / `-Project`) for `upload.ps1`.

## Install

```bash
npx skills add craigspaterson/agent-skills/skills/push-to-ado
```

## Usage — single story

After drafting a story with `/user-story` or `/technical-story`, say:

```text
push to ADO
```

The agent extracts the title, description, acceptance criteria, story points, and priority from the story in context, then calls `scripts/upload.ps1` to create the work item. It will ask for a parent feature ID if one wasn't provided.

## Usage — full hierarchy

When you have a structured backlog with Epics, Features, and Stories, say:

```text
push this backlog to ADO
```

The agent writes a tailored call to `scripts/upload-hierarchy.ps1`, which creates all items in the correct parent–child order. Technical stories are created as `User Story` type with the tag `Technical`.

## Usage — bulk update

When you have existing ADO items with content that needs replacing (e.g. after re-drafting through `/user-story` or `/technical-story`), say:

```text
update those ADO items
```

The agent populates `scripts/update-work-items.ps1` with one `Update-WorkItem` call per item using the known ADO IDs, then runs it to PATCH all items in a single pass.

## Output

On success the agent reports each item created or updated:

```text
  [Epic] My Epic
    -> AB#101  https://dev.azure.com/myorg/myproject/_workitems/edit/101
  [Feature] My Feature
    -> AB#102  https://dev.azure.com/myorg/myproject/_workitems/edit/102
  AB#103  My Story
    -> Updated
```
