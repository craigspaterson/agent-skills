# agent-skills

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A shared library of agent skill definitions. Skills teach your agent consistent output formats, writing guidelines, and worked examples so every team member gets the same quality of output without having to re-explain conventions in every conversation.

---

## What Is a Skill?

A skill is a `SKILL.md` file that is loaded into the agent's context before a task. It defines:

- **Output format** — the exact structure the agent should produce
- **Writing guidelines** — naming conventions, tone, and rules
- **Acceptance criteria checklists** — coverage prompts for common concerns
- **Worked examples** — minimal input → full output pairs
- **Behavior rules** — how the agent should handle edge cases and ambiguity

---

## Available Skills

| Skill | Path | Purpose |
|---|---|---|
| `user-story` | `skills/user-story/SKILL.md` | Jira-formatted User Stories with AC — for human-facing features, UI, and user journeys |
| `technical-story` | `skills/technical-story/SKILL.md` | Jira-formatted Technical Stories with AC — for IaC, CI/CD, IAM, Cloud Run, Pub/Sub, and backend logic |
| `terraform-docs-inject` | `skills/terraform-docs-inject/SKILL.md` | Regenerate and inject Terraform documentation into `terraform/README.md` using `terraform-docs` |
| `push-to-ado` | `skills/push-to-ado/SKILL.md` | Upload a drafted User Story or Technical Story to Azure DevOps as a work item via `upload.ps1` |
| `start-story` | `skills/start-story/SKILL.md` | Activate an ADO work item (set state to Active, assign to self) and create + push the feature branch |

---

## Install

Install skills in Claude Code, GitHub Copilot, Cursor, and more using [skills.sh](https://skills.sh).

### All Skills

```bash
npx skills add craigspaterson/agent-skills
```

### Individual Skills

```bash
# User Story skill
npx skills add craigspaterson/agent-skills/skills/user-story

# Technical Story skill
npx skills add craigspaterson/agent-skills/skills/technical-story

# Terraform Docs Inject skill
npx skills add craigspaterson/agent-skills/skills/terraform-docs-inject

# Push to ADO skill
npx skills add craigspaterson/agent-skills/skills/push-to-ado

# Start Story skill
npx skills add craigspaterson/agent-skills/skills/start-story
```

Once installed, the agent activates a skill automatically when your request matches its description.

---

## How to Use

### Option 1 — Manual paste

1. Open a new conversation with your agent.
2. Copy the contents of the relevant `SKILL.md` file.
3. Paste it at the start of your message, followed by your request.

Example:

```
[paste contents of skills/technical-story/SKILL.md]

Write a story for developing the cache-invalidation Cloud Run service in OpenTofu for the XYZ Platform.
```

### Option 2 — Agent instructions file (recommended)

Most agent tools load an instructions file automatically at the start of every session (`AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `.github/copilot-instructions.md`, etc.).

1. Clone this repo locally:
   ```bash
   git clone git@github.com:<your-org>/agent-skills.git
   ```
2. In your agent instructions file, reference the skill:
   ```
   Before writing any user story, read skills/user-story/SKILL.md.
   Before writing any technical story, read skills/technical-story/SKILL.md.
   ```
3. The agent will load the skill automatically when triggered.

### Option 3 — Project knowledge (Team / Enterprise)

Many agent platforms support uploading files as shared project knowledge, making them available to all team members automatically.

1. Create a project or workspace for your team.
2. Upload the relevant `SKILL.md` files as project knowledge.
3. All team members will have the skills available automatically in every conversation.

---

## Contributing

To add or update a skill:

1. Branch from `main`.
2. Add or edit the `SKILL.md` under `skills/<skill-name>/`.
3. Update the table in this README.
4. Open a PR for review — skills affect output quality for the whole team, so a second pair of eyes is worthwhile.

Skill files follow a standard frontmatter block at the top:

```
---
name: skill-name
description: One-sentence trigger description used by the agent to decide when to load this skill.
---
```

---

## Questions

Reach out to the team or raise a GitHub issue in this repo.
