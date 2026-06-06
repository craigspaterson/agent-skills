---
name: terraform-docs-inject
description: "Generate Terraform docs and inject them into terraform/README.md using terraform-docs markdown table output-mode inject. Use when the user asks to refresh, regenerate, or update Terraform documentation or README."
---

# Terraform Docs Inject

## Quick start

From the repository root:

```bash
cd terraform
terraform-docs markdown table --output-file README.md --output-mode inject .
```

## Workflow

1. Confirm a `terraform/` directory exists in the repository root — stop and report if not.
2. Check that `terraform-docs` is installed (`terraform-docs --version`). If not installed, stop and ask the user to install it before proceeding.
3. Run the command above exactly as written — do not change any arguments.
4. Report whether `terraform/README.md` was updated or was already up to date.

## Notes

- Injects content between existing `terraform-docs` markers in `terraform/README.md` — does not replace the whole file.
- Always run from the repository root so the relative path resolves correctly.
