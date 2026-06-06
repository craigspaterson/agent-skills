# Claude Instructions

This file is read automatically by Claude Code at the start of every session. It tells Claude which skills to load and provides project-specific context.

---

## Skills

Before writing any user story (human-facing feature, UI, user journey), read:
`<path-to-claude-skills>/skills/user-story/SKILL.md`

Before writing any technical story (IaC provisioning, GitHub Actions workflow, IAM binding, Cloud Run, Pub/Sub, backend handler logic), read:
`<path-to-claude-skills>/skills/technical-story/SKILL.md`

If unsure which story type applies, read both and use the decision table in `technical-story/SKILL.md` to choose. If a capability spans both, produce one of each and link them as dependencies.

---

## Project Context

<!-- Replace the placeholders below with your project's specifics -->

**Project:** `<project-name>`
**Platform:** `<e.g. GCP / AWS / Azure>`
**IaC:** `<e.g. OpenTofu / Terraform>`
**CI/CD:** `<e.g. GitHub Actions / Cloud Build>`
**Environments:** `<e.g. alpha (dev) → beta (test) → gamma (uat) → prod>`
**Repo(s):** `<list the repos in scope>`

---

## Conventions

<!-- Document team-specific conventions Claude should follow -->

- Story granularity: `<e.g. one story per environment, or environment-agnostic with env as a variable>`
- AC format: `AC[N] - Name` label on its own line, Given/When/Then each on separate lines, `---` dividers between blocks
- Priority defaults: `<e.g. all infra provisioning stories default to High>`
- Naming: `<e.g. environment suffixes -a/-b/-g/-p, resource naming pattern>`

---

## Out of Scope

<!-- Things Claude should not do in this repo without being explicitly asked -->

- Do not modify IaC files directly unless asked
- Do not commit or push changes
