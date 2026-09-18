# create-pr

Creates or updates a GitHub pull request using the target repo's own
`.github/pull_request_template.md` as the body structure, with a
Conventional Commits-style title and the assignee resolved dynamically
(never hardcoded).

## Prerequisites

- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated
  (`gh auth login`)
- `git` with the branch you want to PR already pushed (or pushable) to origin

## Setup

No required configuration — the skill works out of the box for any repo
under a GitHub remote. One optional override:

| Variable        | Purpose                                                              | Default                          |
|------------------|-----------------------------------------------------------------------|-----------------------------------|
| `PR_ASSIGNEE`    | GitHub username to assign the PR to                                   | current `gh` user (`gh api user --jq .login`) |

Set it in the `env` block of `~/.claude/settings.json` if you want PRs
assigned to someone other than whoever is running the skill (e.g. a shared
review queue):

```json
{
  "env": {
    "PR_ASSIGNEE": "some-other-user"
  }
}
```

Most people won't need this — by default each teammate's PRs get assigned
to themselves.

## Install

```bash
npx skills@latest add craigspaterson/agent-skills/skills/create-pr
```

## Usage

Say any of the following once your branch is ready:

```text
create a PR
open a PR
make a pull request
update the PR
```

## What it does

1. Looks for `.github/pull_request_template.md` (or `PULL_REQUEST_TEMPLATE.md`)
   in the current repo. If none exists, falls back to a minimal
   Summary/Changes/Testing body instead of inventing sections.
2. Reads branch state (`git status`, diff and log against the default
   branch, push status) to fill the template from what actually changed —
   checklist items are only checked once genuinely verified, not by default.
3. Titles the PR using [Conventional Commits](https://www.conventionalcommits.org/)
   (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`).
4. Resolves the assignee (see Setup above) and runs `gh pr create` /
   `gh pr edit` accordingly.
5. Populates the "Related Work" section from an ADO `AB#NNNNN` or GitHub
   `#NNN` reference in the branch name or commits, if one is evident —
   never fabricates a link.

## Repo-specific quirks

- If a repo's `AGENTS.md` or `CLAUDE.md` documents PR conventions (e.g. a
  version-bump trailer or a required section), the skill follows those
  instead of guessing.
- Repos with no template get a plain Summary + Changes + Test plan body
  rather than another repo's template applied incorrectly.

## Notes

- Always re-reads the template fresh per repo/PR — templates can drift
  between repos, so it never assumes one from a previous run still applies.
