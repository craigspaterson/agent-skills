---
name: technical-story
description: Draft Jira-formatted Technical Stories (Infrastructure and Application sub-types) with Acceptance Criteria, for backlog items that describe a system or engineering concern rather than a user experience. Use this skill whenever the user wants to write, create, draft, refine, or improve a technical story, enabler story, engineering story, infra story, or any PBI describing IaC provisioning, GitHub Actions / CI-CD workflows, Cloud Run or other cloud resource deployment, IAM / service-account configuration, Artifact Registry publishing, or backend service/function logic. Trigger even for casual phrasing like "write a story for provisioning a Cloud Run service", "create a ticket for the OpenTofu apply workflow", "story for the IAM bindings", or "turn this infra task into a story". Use the user-story skill instead when the PBI describes a human-facing feature, UI, or classic user experience. If unsure which kind of story applies, this skill includes guidance to decide.
---

# Technical Story Skill

Draft polished, Jira-ready Technical Stories with Acceptance Criteria, for backlog
items that describe system or engineering concerns rather than a human user experience.

This skill complements the `user-story` skill. A User Story centres on a human persona
and the value they get; a Technical Story centres on the **system or platform** and the
technical outcome (reliability, security, consistency, observability, testability). The
consumer of the capability is the platform itself, so the story statement names the
system, not a human role.

---

## Step 1 — Confirm This Is a Technical Story

Use this skill when the PBI describes an engineering concern with no direct human actor.
If the item describes a human-facing feature, UI, or classic experience, use the
`user-story` skill instead.

| Signal in the request | Story type |
|---|---|
| IaC resource provisioning (Cloud Run, GCS, Pub/Sub, LB) | **Technical** |
| IAM / service account / Workload Identity configuration | **Technical** |
| GitHub Actions / CI-CD / OpenTofu apply / deploy workflow | **Technical** |
| Artifact Registry publish, prune, or versioning | **Technical** |
| Backend handler, function logic, message processing | **Technical** |
| API endpoint a human directly calls in a journey | User Story |
| Dashboard, screen, form, or UI feature | User Story |
| Auth flow described from the user's perspective | User Story |

If genuinely mixed (e.g. "let users export a report" where the export job is the work),
split it: a User Story for the experience and a Technical Story for the enabling job,
linked as dependencies.

---

## Step 2 — Choose the Sub-Type

Every Technical Story is one of two sub-types. Pick based on the primary concern:

- **Infrastructure** — provisioning, configuration, access, pipelines. The deliverable
  is a resource, binding, or workflow that exists and behaves correctly. Owners are
  typically platform/infra engineers. Definition of Done is verified in the cloud
  console, the IaC plan, or the pipeline run.
- **Application** — logic that runs *on* the infrastructure. The deliverable is correct
  behaviour: inputs handled, outputs produced, failures managed, logs emitted. Owners
  are typically application engineers. Definition of Done is verified by tests and
  observed runtime behaviour.

A single capability often needs **both**: one Infrastructure story to provision the
Cloud Run service, one Application story for its handler logic. When that is the case,
produce both and link them — the Infrastructure story typically blocks the Application
story's integration testing.

---

## Output Format

Use this exact structure. It mirrors the `user-story` skill's format so the two sit
side by side, with two differences: the `Type` line names the sub-type, and the story
statement names the **system/platform**, not a persona.

```
**Title:** [Short, imperative-phrased summary — max 10 words]

**Type:** Technical Story — [Infrastructure / Application]
**Priority:** [Critical / High / Medium / Low]
**Story Points:** [1 / 2 / 3 / 5 / 8 / 13 — Fibonacci scale]

---

**Technical Story**

As the [platform / service / system name],
I need [capability or resource],
So that [technical outcome — reliability, security, consistency, observability].

---

**Acceptance Criteria**

---

**AC1 - [Criterion Name]**

Given [system state or precondition],
When [action, trigger, or event],
Then [observable, verifiable outcome].

---

**AC2 - [Criterion Name]**

Given [system state or precondition],
When [action, trigger, or event],
Then [observable, verifiable outcome].

---

[Add as many AC[N] - Name blocks as needed — minimum 3, maximum 8]

---

**Out of Scope**
- [What resource, logic, concern, or environment is explicitly excluded]

**Dependencies**
- [Prerequisite APIs, modules, service accounts, linked stories — or "None"]

**Notes**
[Naming conventions, error-handling decisions, open questions, per-environment split.]
```

---

## Writing Guidelines

### Title
- Imperative verb ("Provision", "Implement", "Configure", "Publish", "Enable").
- Specific enough to distinguish from other tickets at a glance.
- Name the resource or workflow ("Provision Cloud Run Service via OpenTofu for X").

### Story Statement (the "As the / I need / So that")
- "As the…" names the **system or platform** consuming the capability — e.g.
  "As the CEP AEM platform", "As the `content-processor` service". Never a human persona.
- "I need" = the capability or resource, stated at outcome level, not the implementation.
- "So that" = the technical *why* — reliability, security, consistency, auditability,
  observability, testability. Not a restatement of "I need".

### Acceptance Criteria (AC[N] - Name / Given/When/Then)
- Each criterion is labelled **AC[N] - Name** on its own line, separated from the
  Given/When/Then block by a blank line.
- Given, When, and Then are each on their own line.
- "Given" = system state or precondition. "When" = the trigger, operation, or event.
  "Then" = the observable, verifiable outcome.
- Each criterion tests ONE behaviour. Use concrete, testable language — avoid vague
  words like "fast", "secure", "properly". Prefer checkable facts ("plan shows zero
  changes", "IAM binding is exactly these two roles", "log entry has severity ERROR").
- Cover the happy path first, then failure and edge cases. Always include at least one
  failure/negative case.
- Separate each AC block with a horizontal rule (`---`).

### Story Points
- **1** — Trivial, < 2 hours · **2** — Simple, < half a day · **3** — Small, ~1 day
- **5** — Medium, a few days · **8** — Complex, ~1 week · **13** — Very large, split it

### Priority
- **Critical** — Blocker or production issue · **High** — Current sprint goal
- **Medium** — Valuable, not blocking · **Low** — Nice-to-have

---

## AC Coverage Checklists

Use the checklist matching the sub-type to make sure no common concern is missed. Not
every item must appear in every story — they are prompts, not mandatory fields.

### Infrastructure
- Provisioning success — resource exists with expected name/region/config.
- IAM / service account — least-privilege bindings, no broad project-level grants.
- Authentication — Workload Identity Federation, no static service-account keys.
- Environment parity — names follow convention, all values sourced from variables,
  no hardcoded environment references.
- Secret handling — credentials from Secret Manager, no plaintext in config.
- Idempotency / drift — re-apply produces zero unintended changes.
- Failure handling — non-zero exits surface clearly, no silent partial state.

### Application
- Happy path — well-formed input processed, expected action completes.
- Malformed / invalid input — rejected gracefully, logged, no crash.
- Downstream failure — retries or fails cleanly per policy, error logged.
- Structured logging — JSON with severity, messageId/traceId, timestamp.
- Auth / security — unauthenticated or unauthorised access rejected.
- Unit / integration test coverage — happy path plus error cases pass in CI.

---

## Behavior Rules

1. **Always produce a complete story** — never leave placeholders. Make reasonable
   assumptions and record them in Notes.
2. **Default to the user's domain terminology** — match their resource names,
   environment suffixes, and conventions rather than generic placeholders.
3. **Split when a capability spans infrastructure and application** — produce both
   stories and link them as dependencies, with the infra story typically blocking the
   application story's integration testing.
4. **Prefer environment-agnostic stories** when the user works across multiple
   environments — one story with environment as a variable, unless the user asks for
   per-environment stories (e.g. gamma and prod as separate child stories).
5. **Keep implementation specifics in Notes or AC**, not in the story statement.
6. **Clean Markdown** that renders well in Jira's description field; `**bold**` headers.

---

## Examples

### Infrastructure — Minimal Input → Full Story

**Input:** "Story for provisioning a Cloud Run service in OpenTofu"

**Output:**
```
**Title:** Provision Cloud Run Service via OpenTofu for content-processor

**Type:** Technical Story — Infrastructure
**Priority:** High
**Story Points:** 5

---

**Technical Story**

As the platform,
I need a Cloud Run service for content-processor provisioned via OpenTofu,
So that the service is deployed consistently across environments with least-privilege
IAM, correct scaling behaviour, and auditable infrastructure state.

---

**Acceptance Criteria**

---

**AC1 - Resource Provisioned via OpenTofu**

Given a valid OpenTofu workspace targeting the product project,
When `tofu apply` is executed against the Cloud Run module,
Then the service is created and visible in the GCP console with the expected name,
region, and container image reference.

---

**AC2 - Least-Privilege Service Account**

Given the service requires Secret Manager and Pub/Sub access,
When the module is applied,
Then a dedicated service account is created with only the required roles and no
broader project-level bindings.

---

**AC3 - Scaling Constraints from Variables**

Given the service must not exhaust container quota under burst load,
When the module is applied,
Then min/max instances, memory, and CPU are set from the services variable and
reflected in the deployed revision.

---

**AC4 - Plan Produces No Drift**

Given the service is already deployed,
When `tofu plan` runs against an unchanged variable file,
Then the plan shows zero add/change/destroy operations.

---

**Out of Scope**
- Application logic running inside the container (linked Application story)
- CI/CD pipeline triggering the apply (separate workflow story)

**Dependencies**
- GCP APIs bootstrapped (run, secretmanager)
- Workload Identity Federation configured for the deploy service account

**Notes**
Environment suffix convention assumed (a/b/g/p). Treat gamma and prod as separate
child stories if the team follows per-environment granularity.
```

### Application — Minimal Input → Full Story

**Input:** "Story for the content-processor function logic"

**Output:**
```
**Title:** Implement content-processor Cloud Run Handler Logic

**Type:** Technical Story — Application
**Priority:** High
**Story Points:** 5

---

**Technical Story**

As the content-processor service,
I need to consume, transform, and forward content events,
So that events are processed reliably with observable outcomes and graceful failure
handling.

---

**Acceptance Criteria**

---

**AC1 - Trigger Handling**

Given the service is deployed and running,
When a Pub/Sub push message is delivered,
Then the handler parses the envelope, extracts the payload, and acknowledges with 200.

---

**AC2 - Happy Path Processing**

Given a well-formed content event payload,
When the handler processes the message,
Then the expected transformation completes and a structured log confirms the outcome.

---

**AC3 - Malformed Payload Handling**

Given a message with an invalid payload structure,
When the handler attempts to parse it,
Then the message is acknowledged to prevent redelivery and a WARNING log captures the
message ID and reason.

---

**AC4 - Downstream Failure Handling**

Given the downstream target is unavailable,
When the handler attempts the operation,
Then it returns 500, does not acknowledge the message, and logs an ERROR with the
cause so the subscription retries per its backoff policy.

---

**Out of Scope**
- Infrastructure provisioning for the service (linked Infrastructure story)
- Changes to Pub/Sub topic or subscription configuration

**Dependencies**
- Linked Infrastructure story: Provision Cloud Run Service for content-processor
- Pub/Sub topic and subscription exist in the target environment

**Notes**
Acknowledge-on-bad-message is a deliberate dead-letter-avoidance pattern — confirm it
matches the error-handling policy before finalising.
```

---

## Refinement Flow

After producing a story, offer relevant follow-ups:
- "Want me to draft the linked Infrastructure (or Application) story so the pair is complete?"
- "Should I split this per-environment (e.g. gamma and prod as separate stories)?"
- "Want more failure/edge-case criteria added?"
- "Need me to adjust story points or priority?"
