---
name: create-pr
description: Create or update a GitHub pull request using the repo's own .github/pull_request_template.md as the body structure, with a Conventional Commits-style title and the assignee set to the current gh user (or $PR_ASSIGNEE if set). Use when the user asks to "create a PR", "open a PR", "make a pull request", or similar, in any repo under this workspace.
---

# Create PR

## Quick start

1. Find the template: `.github/pull_request_template.md` or `.github/PULL_REQUEST_TEMPLATE.md` (case varies by repo). If none exists, fall back to a minimal Summary/Changes/Testing body — don't invent sections.
2. Gather branch state: `git status`, `git diff main...HEAD` (or the repo's default branch), `git log main..HEAD`, and whether the branch is pushed/tracks a remote.
3. Fill in the template's sections from the actual diff and commit history — don't leave checklist items unchecked by default; check the ones genuinely true (e.g. "I verified no sensitive data is included" once you've looked).
4. Title: Conventional Commits format (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`).
5. Resolve the assignee: use `$PR_ASSIGNEE` if set in the environment, otherwise the currently authenticated GitHub user (`gh api user --jq .login`). Never hardcode a specific username — this skill is shared across the team, and the assignee should default to whoever is running it.
6. Create with:
   ```
   assignee="${PR_ASSIGNEE:-$(gh api user --jq .login)}"
   gh pr create --title "<type>: <summary>" --body "$(cat <<'EOF'
   <filled template>
   EOF
   )" --assignee "$assignee"
   ```
7. If updating an existing PR instead, use `gh pr edit <number> --body "..." --add-assignee "$assignee"` (only add the assignee if not already set).

## Template quirks by repo

- If a repo's `AGENTS.md` or `CLAUDE.md` documents PR conventions (e.g. a Version Bump section, a required trailer, a non-standard checklist), follow those over guessing.
- If a repo has no template, use a plain Summary + Changes + Test plan body — do not apply another repo's template.

## Related Work section

If the branch name or commits reference a work item (ADO `AB#NNNNN` or GitHub issue `#NNN`), populate the "Related Work" / "Issue" line with it. Don't fabricate a link if none is evident.

## Notes

- Always re-read the template fresh per repo/PR rather than assuming it matches a previous run — templates can drift between repos.
