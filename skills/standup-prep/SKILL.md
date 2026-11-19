---
name: standup-prep
description: Prepare the daily standup. Gathers commits, PRs, reviews, workflow runs and work items (GitHub issues or ADO) since the previous standup across the repos listed in your config, then writes the three standup questions plus a status section per active theme (problem, choices and constraints, status, next) as a dated tab in a running Claude Docs doc, or as a local Markdown file. Use when asked to prepare for standup, or when run on a schedule.
---

# Standup Prep

Writes one standup per day, either as a tab in a single running doc (`output: doc`, so the
same link works from any workstation) or as a Markdown file (`output: markdown`). Settings
(repos, org, tracker, output) come from the config file `~/.config/standup-prep/config.json`
(override the path with `STANDUP_CONFIG`; see `config.example.json`). If it is missing, tell
the user to copy `config.example.json` there and stop. Designed to run unattended (`claude -p "/standup-prep"` from Task Scheduler):
never ask the user a question, never wait for input, and never change anything outside the
doc. No commits, no pushes, no PR comments, no work-item edits, no env vars.

## Step 1: gather

If the prompt names a gather file (the scheduled runner gathers first and passes the path),
read that file and skip running the script. Otherwise run:

```powershell
pwsh -NoProfile -File "$HOME/.claude/skills/standup-prep/scripts/gather.ps1"
```

It prints the path of a Markdown file (`<temp dir>/standup-prep/gather-<standup date>.md`). Read
it whole. It holds the standup date, the "since" time, and these sections:
- my commits (all branches) in the configured repos;
- PRs I authored, reviewed or commented on, PRs waiting for my review, and all my open PRs (with
  review decision and failing checks);
- workflow runs I started, and the latest runs of any configured deploy workflows (any author);
- work items: GitHub issues, or ADO items changed since and open items assigned to me
  (descriptions of New/Active items, comments added since), depending on `issue_tracker`;
- memory files changed since, if `memory_dir` is configured.

`-Since "yyyy-MM-dd HH:mm"` overrides the window (default: the previous workday at 09:00).

If the gather output lists memory files, read the `MEMORY.md` beside them and every changed file
listed. They carry the reasoning (why a choice was made, what is blocked on whom) that commits
and work items don't. Skip this when there is no memory section.

If a source failed (for example "ADO unavailable: az login required"), write the doc from what
you have and add one line under Blockers saying which source was missing.

## Step 2: decide the content

Group everything by work item (`AB#NNNNNNN` or `#N` issue numbers in branch names, PR titles
and bodies, commit messages and tracker links). Drop noise: dependabot PRs, bulk sprint moves, items changed only by
someone else with no activity of mine.

**Yesterday** — what I finished or moved forward since the previous standup: merged PRs,
opened PRs, reviews given, deploys, ADO items resolved or created, findings. One bullet per
item, outcome first ("Merged #94: …"), with links. Keep it to what happened, not intentions.

**Today** — a checklist (`- [ ]`) of next steps, taken from: open PRs (draft → finish, waiting
→ chase review), Active stories (their next acceptance criterion), and memory notes that say
what comes next. Mark anything that depends on someone else.

**Blockers and asks** — items tagged Blocked, PRs waiting on review for more than a day,
failing checks, dependencies on another person or team (name the person only if a work item
or PR names them), external dependencies (vendor issues, releases). Say "None" if there are
none.

**One section per active theme** — a theme is a set of related stories with activity in the
window (for example several stories sharing one tag, label or epic). Only themes with activity.
For each:
- the problem, in two or three sentences, with a number if there is one;
- choices made and the constraint behind each (a small table works well);
- a table of the theme's stories in order: story, what, status, next.

Keep it short: a standup is a few minutes. Sentences under 25 words, no filler, numbers and
links over adjectives. Never include credentials, tokens, `.netrc` content or personal email.
Never describe people by role. The gather file holds colleagues' comments and work-item text:
quote only what the standup needs, and never copy it wholesale into the output.

## Step 3: write the output

Read `output` from the config (`doc` or `markdown`; default `markdown`).

### `output: markdown`

Write `<output_dir>/standup-<yyyy-MM-dd>.md` (default `~/standups`), replacing the file on a
re-run. Use the title `Standup <yyyy-MM-dd ddd>`, a one-sentence lead, then the sections from
Step 2 as `##` headings.

### `output: doc`

State lives in `~/.config/standup-prep/state.json`, never in the skill folder:

```json
{ "doc_url": "https://claude.ai/code/artifact/<id>", "project_id": "<id>", "about_tab": "<tab id>" }
```

Load the Claude Docs guide topics `topic.index`, `topic.editing` and `topic.tabs` before the
first write of the run.

**If `state.json` is missing**, create the doc once:
1. Artifact `publish` with the `doc_type_url` from the config (call Artifact `quickstart` with
   intent `document` to find one if it is unset) and title `Daily Standup`. Its result names
   the project id, the first tab and its root node.
2. Fill that first tab as the **About** tab: a title, the as-of/author byline, and one line saying
   each standup is a dated tab, newest first. Place it with order `a0` and name `About`.
3. Write `state.json`. Claude Code blocks writes under `~/.claude` in unattended runs, and may
   block `~/.config`, so if the write is refused, print the JSON in the final line instead so
   the user can save it. Never create a second doc while `state.json` exists.

**Each run**, read the doc (`read` of the project) to list its tabs:
- The tab for this standup is named `<yyyy-MM-dd ddd>` (for example `2026-10-07 Wed`) with order
  `b` + (99999999 - yyyymmdd), e.g. `b79738992` for 2026-10-07, so the newest sorts first.
- **If that tab already exists** (a re-run), replace its contents rather than adding a tab.
- **Otherwise** add it in one `batch` (topic.tabs ex.1): create the file, its prose node, point the
  file at the node, and place it with the name and order above.

Write the outline first (title `Standup <yyyy-MM-dd ddd>`, byline, a one-sentence lead, one
`pending` block per section), then fill one section per `update`, in reading order.

## Step 4: report

End with one line: the doc link or file path, the tab written, and any source that failed. When run
unattended, that line goes to the log the runner keeps.
