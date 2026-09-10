# resolve-copilot-review

Triages GitHub Copilot's automated PR review comments, fixes the confirmed
issues, replies on each thread, and marks the review threads resolved.

## Prerequisites

- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated (`gh auth login`)
- `gh` account with write access to the repo (replying to and resolving review
  threads both require it)
- A local checkout of the PR's branch, so fixes can be committed and pushed

## Install

```bash
npx skills@latest add craigspaterson/agent-skills/skills/resolve-copilot-review
```

## Usage

Say any of the following on a branch that has an open PR, or name a PR explicitly:

```text
resolve the Copilot review comments
address Copilot's feedback on this PR
are Copilot's findings on PR 42 valid?
clear the Copilot review threads
```

## What it does

1. **Identify the PR** — the one you named, or the open PR for the current branch.
2. **Fetch Copilot's review threads** via the GraphQL `reviewThreads` API (REST
   carries neither thread-resolution state nor a resolvable thread id), filtered
   to unresolved threads authored by Copilot.
3. **Triage every finding first** — reads each referenced file at the flagged
   line and reports a per-finding verdict (**valid** / **not applicable**) with a
   reason, before any code changes. This is the "tell me if they're valid" step.
4. **Fix, reply, resolve** — applies each valid fix, replies on every thread
   naming what changed (or why no change was needed), and resolves the thread.
5. **Commit and push** — commits the fixes and pushes to the PR branch so the
   diff Copilot reviewed reflects them.

## Notes

- GraphQL node ids (used to resolve a thread) and REST database ids (used to post
  a reply) are different id spaces for the same comment — the skill keeps them
  separate.
- Copilot's exact bot login has varied, so threads are matched on a
  case-insensitive `copilot` substring.
- If there are no open Copilot threads, the skill says so and stops.
