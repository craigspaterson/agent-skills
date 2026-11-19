# standup-prep

Prepares your daily standup. Gathers commits, PRs, reviews, workflow runs and work items
(GitHub issues or Azure DevOps) since the previous standup, then writes **Yesterday / Today /
Blockers** plus a short status section per active theme, either as a dated tab in a running
Claude Docs doc or as a Markdown file.

## Prerequisites

- [PowerShell 7+](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell) (`pwsh`)
- [GitHub CLI](https://cli.github.com/) (`gh`), authenticated: `gh auth login`
- `git`, with your repos cloned under one root folder
- ADO tracker only: [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) (`az`), logged in: `az login`
- `output: doc` only: the Claude Docs connector in Claude

## Install

```bash
npx skills@latest add craigspaterson/agent-skills/skills/standup-prep
```

## Setup

Copy `config.example.json` to `~/.config/standup-prep/config.json` (or point `STANDUP_CONFIG`
at another path) and edit it:

| Key | Meaning |
|---|---|
| `github_owner` | GitHub org or user that owns the repos |
| `repos_root`, `repos` | Folder holding your clones, and the repo names to cover |
| `git_email` | Author email for your commits (default: `git config user.email`) |
| `issue_tracker` | `github`, `ado` or `none` |
| `ado` | `org`, `project`, `user` (ADO only; `ADO_ORG`, `ADO_PROJECT`, `ADO_USER` env vars also work) |
| `deploy_workflows` | Optional list of `{repo, workflow, label}`; shows the latest runs from any author |
| `memory_dir` | Optional folder of Claude memory files to read for reasoning and blockers |
| `output` | `markdown` (default) or `doc` |
| `output_dir` | Where Markdown files go (default `~/standups`) |
| `doc_type_url` | Optional Claude Docs artifact type for the first `doc` run |
| `workday_start` | Start of the standup window on the previous workday, `HH:mm` |

The config and `state.json` (the running doc's link) live outside the repo and must not be
committed.

## Usage

Ask Claude to "prepare for standup", or run `/standup-prep`. To override the window, run the
gather script with `-Since "yyyy-MM-dd HH:mm"`.

### Scheduling

`scripts/run-standup.ps1` gathers, runs `claude -p "/standup-prep"` with a minimal tool
allowlist, deletes the gather file and rotates logs. Schedule it on weekday mornings:

- **Windows:** Task Scheduler, action `pwsh -NoProfile -File <path>\run-standup.ps1`
- **macOS:** a launchd agent, or cron: `30 8 * * 1-5 pwsh -NoProfile -File ~/.claude/skills/standup-prep/scripts/run-standup.ps1`
- **Linux:** cron, as above

## Privacy

The gather file contains commit messages, PR text and colleagues' work-item comments. It is
written to the OS temp folder, read once, and deleted by the scheduled runner. The skill only
reads: it never commits, pushes, comments or edits work items.
