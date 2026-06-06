---
name: user-story
description: Draft Jira-formatted User Stories with Acceptance Criteria. Use this skill whenever the user wants to write, create, draft, refine, or improve a user story, epic, ticket, or feature request — especially when they mention Jira, acceptance criteria, agile, scrum, sprints, or backlog items. Trigger even for casual phrasing like "write a story for...", "create a ticket for...", "help me describe this feature", or "I need a Jira issue for...". Also trigger when the user pastes a rough feature idea and wants it turned into a structured story.
---

# User Story Skill

Draft polished, Jira-ready User Stories with Acceptance Criteria following agile best practices.

---

## Output Format

Every user story must follow this exact structure:

```
**Title:** [Short, imperative-phrased summary — max 10 words]

**Type:** Story  
**Priority:** [Critical / High / Medium / Low]  
**Story Points:** [1 / 2 / 3 / 5 / 8 / 13 — Fibonacci scale]

---

**User Story**

As a [persona/role],  
I want to [action/goal],  
So that [benefit/value].

---

**Acceptance Criteria**

---

**AC1 - [Criterion Name]**

Given [precondition],
When [action],
Then [expected outcome].

---

**AC2 - [Criterion Name]**

Given [precondition],
When [action],
Then [expected outcome].

---

[Add as many AC[N] - Name blocks as needed — minimum 3, maximum 8]

---

**Out of Scope**
- [What is explicitly NOT included in this story]

**Dependencies**
- [Any blockers, related tickets, or prerequisites — or "None"]

**Notes**
[Optional: edge cases, open questions, design links, or context for the dev team]
```

---

## Writing Guidelines

### Title
- Imperative verb ("Add", "Enable", "Display", "Allow", "Support")
- Never start with "As a user..."
- Specific enough to distinguish from other tickets at a glance

### Persona
- Be specific: prefer "logged-in customer", "admin user", "guest visitor" over generic "user"
- Match the persona to the system context if provided

### Story Statement (the "As a / I want / So that")
- "I want" = the feature action, not the business outcome
- "So that" = the *why* — business value, not just a restatement of I want
- Avoid technical implementation details in the story statement

### Acceptance Criteria (AC[N] - Name / Given/When/Then)
- Each criterion is labeled **AC[N] - Name** on its own line, where N is a sequential number and Name is a short descriptive title for the criterion
- The label is separated from the Given/When/Then block by a blank line
- Each criterion tests ONE behavior
- Given, When, and Then are each on their own line
- "Given" = system state or precondition
- "When" = the user action or event
- "Then" = the observable, verifiable outcome
- Use concrete, testable language — avoid vague words like "fast", "easy", "properly"
- Cover happy path first, then edge cases and error states
- Include at least one negative/error case (e.g., invalid input, missing permission)
- Separate each AC block with a horizontal rule (`---`) for markdown readability

### Story Points
Default guidance (adjust to context if user specifies team conventions):
- **1** — Trivial change, < 2 hours
- **2** — Simple, well-understood, < half a day
- **3** — Small feature, some unknowns, ~1 day
- **5** — Medium complexity, a few days
- **8** — Complex, multiple components, ~1 week
- **13** — Very large, consider splitting

### Priority
- **Critical** — Blocker, production issue, or must-have for launch
- **High** — Important for the current sprint goal
- **Medium** — Valuable, but not blocking
- **Low** — Nice-to-have, future consideration

---

## Behavior Rules

1. **Always produce a complete story** — never leave placeholders like "[describe here]". Make reasonable assumptions and note them in the Notes section.
2. **Ask before assuming** only if the user's input is genuinely too vague to produce any meaningful story. Otherwise, draft first and offer to refine.
3. **Split large features** — if the request describes multiple independent user journeys, produce multiple stories and flag that they should be separate Jira tickets.
4. **Match the user's domain** — use their terminology (e.g., "merchant", "patient", "student") rather than generic words.
5. **Never include implementation details** in the story statement. They belong in Notes or a separate technical task ticket.
6. **Markdown formatting** — output should be clean Markdown that renders well in Jira's description field. Use `**bold**` for section headers.

---

## Examples

### Minimal Input → Full Story

**Input:** "User login with Google"

**Output:**
```
**Title:** Add Google OAuth Single Sign-On for Users

**Type:** Story  
**Priority:** High  
**Story Points:** 5

---

**User Story**

As a new or returning user,  
I want to sign in using my Google account,  
So that I can access the platform without creating a separate password.

---

**Acceptance Criteria**

---

**AC1 - OAuth Redirect**

Given I am on the login page,
When I click "Continue with Google",
Then I am redirected to Google's OAuth consent screen.

---

**AC2 - Successful Sign-In**

Given I have approved OAuth permissions on Google,
When Google redirects me back to the app,
Then I am signed in and land on my dashboard.

---

**AC3 - Existing Account Linking**

Given my Google account email matches an existing account,
When I complete Google sign-in,
Then my existing account is linked and my data is preserved.

---

**AC4 - Denied Permissions**

Given I deny permissions on the Google consent screen,
When Google redirects me back,
Then I see an error message and remain on the login page.

---

**AC5 - Expired Session**

Given my session has expired,
When I attempt to access a protected page,
Then I am redirected to the login page and prompted to sign in again.

---

**Out of Scope**
- Sign-in with other OAuth providers (Apple, GitHub, Facebook)
- Admin-level SSO / SAML configuration

**Dependencies**
- Google Cloud project with OAuth 2.0 credentials configured
- Auth service integration layer

**Notes**
Assumed standard web OAuth 2.0 flow. Mobile deep-link handling should be a separate story. Confirm whether new Google users should auto-create an account or see a registration step.
```

---

## Refinement Flow

After producing a story, offer these follow-up options if appropriate:
- "Would you like me to split this into smaller stories?"
- "Should I add more edge case criteria?"
- "Want me to draft the linked technical task ticket?"
- "Need me to adjust story points or priority?"
