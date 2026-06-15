#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Org     = $env:ADO_ORG
$Project = $env:ADO_PROJECT
if (-not $Org)     { Write-Error "ADO_ORG not set"; exit 1 }
if (-not $Project) { Write-Error "ADO_PROJECT not set"; exit 1 }

$baseUrl     = "https://dev.azure.com/$Org/$([Uri]::EscapeDataString($Project))"
$priorityMap = @{ Critical = 1; High = 2; Medium = 3; Low = 4 }

Write-Host "Authenticating with Azure..."
$token = az account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --query accessToken -o tsv
if (-not $token) { Write-Error "az login required"; exit 1 }
$headers = @{ Authorization = "Bearer $token" }

function Update-WorkItem {
    param(
        [int]$Id,
        [string]$Title,
        [string]$Description,
        [string]$AcceptanceCriteria = "",
        [int]$StoryPoints,
        [string]$Priority,
        [string]$Tags = ""
    )
    $ops = [System.Collections.Generic.List[hashtable]]::new()
    $ops.Add(@{ op = "add"; path = "/fields/System.Title";                      value = $Title })
    $ops.Add(@{ op = "add"; path = "/fields/System.Description";                value = $Description })
    $ops.Add(@{ op = "add"; path = "/multilineFieldsFormat/System.Description"; value = "Markdown" })
    if ($AcceptanceCriteria) {
        $ops.Add(@{ op = "add"; path = "/fields/Microsoft.VSTS.Common.AcceptanceCriteria";                value = $AcceptanceCriteria })
        $ops.Add(@{ op = "add"; path = "/multilineFieldsFormat/Microsoft.VSTS.Common.AcceptanceCriteria"; value = "Markdown" })
    }
    $ops.Add(@{ op = "add"; path = "/fields/Microsoft.VSTS.Scheduling.StoryPoints"; value = $StoryPoints })
    $ops.Add(@{ op = "add"; path = "/fields/Microsoft.VSTS.Common.Priority";        value = $priorityMap[$Priority] })
    if ($Tags) {
        $ops.Add(@{ op = "add"; path = "/fields/System.Tags"; value = $Tags })
    }
    $url  = "$baseUrl/_apis/wit/workItems/$Id`?api-version=7.1"
    $body = $ops | ConvertTo-Json -Depth 6
    Write-Host "  AB#$Id  $Title"
    Invoke-RestMethod -Method Patch -Uri $url -Headers $headers -Body $body -ContentType "application/json-patch+json" | Out-Null
    Write-Host "    -> Updated"
}

# ─────────────────────────────────────────────
# USER STORIES
# ─────────────────────────────────────────────

# AB#30
$desc = @'
**User Story**

As a potential client visiting the Blackhawk Studios website,
I want to submit a project inquiry directly from the contact section,
So that I can reach the team without leaving the browser to open my email client.

---

**Out of Scope**
- Backend email delivery or function logic (covered by AB#32)
- Spam protection and rate limiting (covered by AB#33)
- GA4 event tracking on submission (covered by AB#34)
- File or attachment uploads

**Dependencies**
- AB#32 — Form backend must be deployed for end-to-end validation

**Notes**
Form should match brand: dark charcoal background (#090c0f), neon green (#00e676) accent on focus states and submit button. Confirm whether the static contact info (address, phone, email) is retained alongside the form or replaced entirely.
'@
$ac = @'
**AC1 - Form Fields Present**

Given I scroll to the Contact section of the page,
When the section loads,
Then I see labeled input fields for Name, Email, and Message, plus a Submit button.

---

**AC2 - Successful Submission**

Given I have filled in Name, Email, and Message with valid values,
When I click Submit,
Then the form is submitted and I see a confirmation state with no page reload.

---

**AC3 - Client-Side Validation — Empty Fields**

Given I have left one or more required fields blank,
When I click Submit,
Then the form does not submit and each empty field is highlighted with an inline error message identifying what is missing.

---

**AC4 - Invalid Email Format**

Given I have entered a value in the Email field that is not a valid email address,
When I click Submit,
Then the form does not submit and the Email field displays an inline error message indicating the format is invalid.

---

**AC5 - Mobile Rendering**

Given I am viewing the site on a mobile viewport (375px wide or narrower),
When I scroll to the Contact section,
Then the form fields and Submit button are full-width, legible, and usable without horizontal scrolling.
'@
Update-WorkItem -Id 30 -Priority "High" -StoryPoints 3 `
    -Title "Submit Project Inquiry via Contact Form" `
    -Description $desc -AcceptanceCriteria $ac

# AB#31
$desc = @'
**User Story**

As a site visitor who has just submitted the contact form,
I want to see an immediate on-page confirmation that my message was received,
So that I know the inquiry went through and do not submit it again.

---

**Out of Scope**
- Email confirmation sent to the submitter
- Toast or banner notifications outside the contact section
- Backend retry logic on failure

**Dependencies**
- AB#30 — Contact form UI must exist
- AB#32 — Backend function must return a deterministic success or error response

**Notes**
The Submit button should enter a loading/disabled state between submission and response to prevent double-taps on mobile. Confirm wording of success and error messages before implementation.
'@
$ac = @'
**AC1 - Success State Displayed**

Given I have submitted the contact form with valid data and the backend returns a success response,
When the submission completes,
Then the form is replaced by a confirmation message (e.g. "Thanks — we'll be in touch soon") with no page reload.

---

**AC2 - Confirmation Is Accessible**

Given the success confirmation message appears,
When a screen reader user is focused in the form area,
Then the confirmation message is announced by the screen reader via an ARIA live region or focus shift to the message element.

---

**AC3 - Error State Displayed**

Given I have submitted the form and the backend returns an error response,
When the submission fails,
Then an error message is displayed in the form area instructing me to try again, and the form fields retain my previously entered values.

---

**AC4 - No Duplicate Submission on Refresh**

Given the success confirmation is showing,
When I refresh the page,
Then the form returns to its default empty state and no duplicate submission is made.
'@
Update-WorkItem -Id 31 -Priority "High" -StoryPoints 2 `
    -Title "See Confirmation After Submitting Contact Form" `
    -Description $desc -AcceptanceCriteria $ac

# AB#43
$desc = @'
**User Story**

As the Blackhawk Studios LLC team,
I want the website to appear in search results for queries like "SF technology agency" and "San Francisco mobile app developer",
So that prospective clients can discover the business through organic search without relying solely on direct referrals.

---

**Out of Scope**
- Paid search or Google Ads campaigns
- Google Business Profile creation or management
- Ongoing SEO content strategy or blog posts
- Ranking position guarantees (this story covers technical prerequisites, not outcome)

**Dependencies**
- AB#38 — JSON-LD LocalBusiness structured data must be implemented
- Access to Google Search Console for the blackhawkstudios.com property

**Notes**
Google Search Console access must be verified (DNS TXT record or HTML file method). This story is satisfied when the technical prerequisites are in place — actual ranking improvement follows over time.
'@
$ac = @'
**AC1 - LocalBusiness Schema Live**

Given the updated index.html has been deployed to production,
When the URL is submitted to the Google Rich Results Test,
Then the tool reports a valid LocalBusiness structured data block with no errors or warnings.

---

**AC2 - Schema Contains Required NAP Fields**

Given the LocalBusiness JSON-LD block is present in the page,
When the schema is inspected,
Then it includes: name ("Blackhawk Studios LLC"), streetAddress ("388 Market Street"), addressLocality ("San Francisco"), addressRegion ("CA"), postalCode ("94111"), telephone, and url fields.

---

**AC3 - Site Submitted to Google Search Console**

Given the site is deployed and the sitemap is accessible at https://www.blackhawkstudios.com/sitemap.xml,
When Google Search Console is checked,
Then the sitemap has been submitted and shows as "Success" with at least 1 URL indexed.

---

**AC4 - No Structured Data Errors in Search Console**

Given the LocalBusiness schema has been live for at least 24 hours,
When the Search Console Enhancements report is reviewed,
Then zero structured data errors are recorded for the site.
'@
Update-WorkItem -Id 43 -Priority "Medium" -StoryPoints 3 `
    -Title "Rank for Local San Francisco Tech Agency Searches" `
    -Description $desc -AcceptanceCriteria $ac

# AB#56
$desc = @'
**User Story**

As a screen reader user visiting the Blackhawk Studios website,
I want to navigate directly to page sections (Services, About, Contact) without listening to the entire page,
So that I can find the information I need as efficiently as a sighted visitor using the visual navigation.

---

**Out of Scope**
- WCAG AAA conformance
- Screen reader compatibility beyond VoiceOver (macOS/iOS) and NVDA (Windows)
- Color contrast audit (covered by AB#58)
- Mobile screen reader gestures (TalkBack / VoiceOver on iOS)

**Dependencies**
- AB#57 — Skip-to-main-content link Technical Story
- AB#30/AB#31 — If the contact form is live before this story, form fields must be included in the keyboard navigation audit

**Notes**
The site uses HTML5 sectioning elements which provide implicit ARIA landmark roles — confirm before closing. If existing markup uses div containers, explicit role attributes or landmark refactoring will be needed.
'@
$ac = @'
**AC1 - Skip-to-Content Link Available**

Given I arrive on the page and my focus is at the top of the document,
When I press Tab once,
Then a "Skip to main content" link becomes visible and receives focus before any nav element.

---

**AC2 - Skip Link Functions**

Given the "Skip to main content" link has focus,
When I activate it (press Enter or Space),
Then focus moves to the main content landmark, bypassing the navigation.

---

**AC3 - Landmark Regions Announced**

Given I am navigating the page with a screen reader's landmark shortcut,
When I list available landmarks,
Then I can identify at minimum: navigation, main (or equivalent section landmarks), and contentinfo (footer/contact).

---

**AC4 - Zero Critical Violations — Lighthouse**

Given the production URL is audited with a Lighthouse accessibility scan,
When the report is reviewed,
Then the accessibility score shows zero critical violations.

---

**AC5 - Zero Violations — axe**

Given the axe browser extension is run against the production page,
When the scan completes,
Then zero violations are reported (needs-review items are acceptable; violations are not).

---

**AC6 - All Interactive Elements Keyboard Reachable**

Given I am navigating using Tab only,
When I cycle through all focusable elements on the page,
Then every interactive element (nav links, CTA button, contact links, and any form fields) receives a visible focus indicator and can be activated via keyboard.
'@
Update-WorkItem -Id 56 -Priority "Medium" -StoryPoints 3 `
    -Title "Navigate Site Sections Efficiently with a Screen Reader" `
    -Description $desc -AcceptanceCriteria $ac

# ─────────────────────────────────────────────
# TECHNICAL STORIES — EPIC 1: Lead Generation
# ─────────────────────────────────────────────

# AB#32
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need an Azure Functions HTTP trigger at /api/contact that validates form input and delivers email,
So that contact form submissions are reliably processed and routed to info@blackhawkstudios.com with observable outcomes and graceful failure handling.

---

**Out of Scope**
- Spam protection and rate limiting (covered by AB#33)
- GA4 event tracking (covered by AB#34)
- Admin portal or dashboard for viewing submissions
- Email reply threading or CRM integration

**Dependencies**
- AB#30 — Contact form UI must exist and POST to /api/contact
- SendGrid or Azure Communication Services account and API key configured as a SWA application setting
- Azure Static Web Apps managed functions enabled for the SWA resource

**Notes**
SWA managed functions use an api/ directory at the repo root. Confirm preferred language (Node.js / Python / C#) before starting. API key for the email service must be stored in SWA application settings — never committed to the repo.
'@
$ac = @'
**AC1 - Happy Path Email Delivery**

Given a POST request to /api/contact with valid name, email, and message fields,
When the function executes,
Then a confirmation email is delivered to info@blackhawkstudios.com within 60 seconds and the function returns HTTP 200.

---

**AC2 - Missing Field Validation**

Given a POST request to /api/contact with one or more required fields absent or empty,
When the function executes,
Then the function returns HTTP 400 with a JSON body identifying the missing fields and no email is sent.

---

**AC3 - Invalid Email Rejection**

Given a POST request where the email field is not a valid email address format,
When the function executes,
Then the function returns HTTP 400 and no email is sent.

---

**AC4 - Downstream Email Failure Handling**

Given the email delivery service is unavailable,
When the function attempts to send the email,
Then the function returns HTTP 500, logs an ERROR entry with the error details, and does not silently discard the submission.

---

**AC5 - Function Co-Deploys with SWA**

Given a push to the main branch triggers the GitHub Actions workflow,
When the SWA deploy step completes,
Then the /api/contact endpoint is reachable at https://www.blackhawkstudios.com/api/contact.
'@
Update-WorkItem -Id 32 -Priority "High" -StoryPoints 5 `
    -Title "Implement /api/contact HTTP Trigger for SWA Contact Form" `
    -Description $desc -AcceptanceCriteria $ac

# AB#33
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need honeypot-based bot detection and per-IP rate limiting on the /api/contact endpoint,
So that automated spam submissions are rejected before consuming email quota and without exposing CAPTCHA friction to legitimate visitors.

---

**Out of Scope**
- CAPTCHA or reCAPTCHA integration
- IP blocklist / allowlist management
- Persistent rate-limit storage across function cold starts (in-memory is acceptable)

**Dependencies**
- AB#32 — /api/contact function must exist before spam protection can be layered on
- AB#30 — Contact form HTML must include the hidden honeypot field

**Notes**
In-memory rate limiting resets on function cold starts, which is acceptable for low-traffic SWA. The honeypot field name should be generic (e.g. "website") to appear plausible to bots.
'@
$ac = @'
**AC1 - Honeypot Field Rejected**

Given a POST request to /api/contact that includes a non-empty value in the honeypot field,
When the function executes,
Then the function returns HTTP 200 (to avoid tipping off bots) and no email is sent.

---

**AC2 - Rate Limit Enforced**

Given a single IP address has already submitted one request to /api/contact within the last 60 seconds,
When a second request arrives from the same IP within that window,
Then the function returns HTTP 429 and no email is sent.

---

**AC3 - Legitimate Submission Not Blocked**

Given a POST request from a human visitor with the honeypot field empty and no prior submission within 60 seconds,
When the function executes,
Then the request is processed normally.

---

**AC4 - Honeypot Field Hidden from Sighted Users**

Given the contact form is rendered in index.html,
When the page is inspected in a browser,
Then the honeypot input field is not visible and is not reachable via Tab.
'@
Update-WorkItem -Id 33 -Priority "Medium" -StoryPoints 2 `
    -Title "Add Honeypot Field and Rate Limit to /api/contact" `
    -Description $desc -AcceptanceCriteria $ac

# AB#34
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need a GA4 generate_lead event fired on every successful contact form submission,
So that lead volume is measurable in Google Analytics and the conversion rate of the contact section can be tracked over time.

---

**Out of Scope**
- Tracking form field interaction events (focus, blur, input)
- Custom event parameters beyond the standard generate_lead payload
- GA4 Conversion API (server-side tracking)

**Dependencies**
- AB#30 — Contact form UI must exist with a deterministic success callback
- AB#32 — /api/contact function must return a clear HTTP 200 on success
- GA4 property G-43LEH4LYTK already configured in index.html

**Notes**
Use the existing gtag("event", "generate_lead") call pattern — the GA4 tag is already initialised on page load. Mark generate_lead as a Conversion in GA4 property settings after the event is verified in DebugView.
'@
$ac = @'
**AC1 - Event Fires on Success Only**

Given a visitor has submitted the contact form and the /api/contact endpoint returns HTTP 200,
When the success confirmation state is shown,
Then a GA4 event named generate_lead is dispatched via gtag() using measurement ID G-43LEH4LYTK.

---

**AC2 - Event Does Not Fire on Failure**

Given a visitor submits the contact form and the /api/contact endpoint returns a non-200 response,
When the error state is displayed,
Then no generate_lead event is dispatched.

---

**AC3 - Event Visible in GA4 DebugView**

Given the page is loaded with GA4 DebugView enabled,
When a test form submission succeeds,
Then the generate_lead event appears in the GA4 DebugView panel within 30 seconds.

---

**AC4 - Event Visible in GA4 Conversions Report**

Given the generate_lead event has been marked as a conversion in GA4,
When at least one successful submission has occurred,
Then the event appears in the GA4 Conversions report.
'@
Update-WorkItem -Id 34 -Priority "Medium" -StoryPoints 1 `
    -Title "Fire generate_lead GA4 Event on Successful Form Submission" `
    -Description $desc -AcceptanceCriteria $ac

# ─────────────────────────────────────────────
# TECHNICAL STORIES — EPIC 2: SEO
# ─────────────────────────────────────────────

# AB#37
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need Open Graph and Twitter Card meta tags in the HTML head,
So that shared links to the site render rich previews on LinkedIn, Slack, X, and other social platforms, increasing click-through from shares.

---

**Out of Scope**
- Open Graph tags for subpages (site is single-page)
- Dynamic OG image generation
- Facebook pixel or social SDK integration

**Dependencies**
- A 1200x630 OG image asset must be created or cropped from the existing hero image

**Notes**
The og:image asset can be a cropped/resized version of the existing hero PNG (or its WebP equivalent after AB#47 lands). Use an absolute URL for og:image — relative paths are not supported by crawlers. og:type should be "website".
'@
$ac = @'
**AC1 - Required OG Tags Present**

Given the updated index.html is deployed to production,
When the page source is inspected,
Then the following tags are present in <head>: og:title, og:description, og:image, og:url, og:type.

---

**AC2 - Required Twitter Card Tags Present**

Given the updated index.html is deployed to production,
When the page source is inspected,
Then the following tags are present in <head>: twitter:card (value "summary_large_image"), twitter:title, twitter:description, twitter:image.

---

**AC3 - OG Image Dimensions Correct**

Given the og:image meta tag references a static image asset,
When that image is inspected,
Then its dimensions are at least 1200x630 pixels and it is served from www.blackhawkstudios.com.

---

**AC4 - LinkedIn Preview Validates**

Given the production URL is submitted to the LinkedIn Post Inspector,
When the inspection completes,
Then a preview card is shown with the correct title, description, and image.

---

**AC5 - Twitter Card Validates**

Given the production URL is submitted to the Twitter Card Validator,
When the validation completes,
Then a summary_large_image card is rendered with the correct title, description, and image.
'@
Update-WorkItem -Id 37 -Priority "High" -StoryPoints 2 `
    -Title "Add Open Graph and Twitter Card Meta Tags to index.html" `
    -Description $desc -AcceptanceCriteria $ac

# AB#38
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need a LocalBusiness JSON-LD structured data block embedded in the HTML head,
So that Google can surface rich results and local pack entries for relevant SF technology agency searches, and the site's NAP data is machine-readable.

---

**Out of Scope**
- Schema types beyond LocalBusiness (e.g. Product, Article, FAQ)
- Review or rating structured data
- Multiple location schema (single office only)

**Dependencies**
- AB#43 — Google Search Console access must be established to verify AC4

**Notes**
Consider using "@type": ["LocalBusiness", "ProfessionalService"] for more precision. Include geo coordinates (latitude: 37.7924, longitude: -122.3994) for 388 Market St to strengthen local pack signals. Validate the JSON block in a linter before deploying.
'@
$ac = @'
**AC1 - Schema Block Present in Head**

Given the updated index.html is deployed to production,
When the page source is inspected,
Then a <script type="application/ld+json"> block with "@type": "LocalBusiness" is present inside <head>.

---

**AC2 - Required Fields Populated**

Given the JSON-LD block is present,
When the schema is parsed,
Then it includes: name ("Blackhawk Studios LLC"), streetAddress ("388 Market Street"), addressLocality ("San Francisco"), addressRegion ("CA"), postalCode ("94111"), addressCountry ("US"), telephone, and url ("https://www.blackhawkstudios.com").

---

**AC3 - Passes Google Rich Results Test**

Given the production URL is submitted to the Google Rich Results Test,
When the test completes,
Then the tool reports the LocalBusiness structured data as valid with zero errors and zero warnings.

---

**AC4 - No Search Console Errors**

Given the schema has been live for at least 24 hours,
When the Google Search Console Enhancements report is reviewed,
Then zero structured data errors are recorded for the site.
'@
Update-WorkItem -Id 38 -Priority "High" -StoryPoints 2 `
    -Title "Embed JSON-LD LocalBusiness Schema in index.html" `
    -Description $desc -AcceptanceCriteria $ac

# AB#39
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need a canonical URL meta tag in the HTML head and a www-redirect rule in staticwebapp.config.json,
So that all traffic consolidates on a single canonical origin (https://www.blackhawkstudios.com), preventing duplicate content signals from splitting search ranking authority.

---

**Out of Scope**
- Redirect rules for legacy subdomains or vanity URLs
- HSTS header configuration (managed by Azure SWA platform)

**Dependencies**
- None — staticwebapp.config.json already exists in the repo

**Notes**
Verify the custom domain configuration in the Azure Portal has both blackhawkstudios.com and www.blackhawkstudios.com bound to the SWA resource before testing redirects.
'@
$ac = @'
**AC1 - Canonical Tag Present**

Given the updated index.html is deployed to production,
When the page source is inspected,
Then <link rel="canonical" href="https://www.blackhawkstudios.com/"> is present inside <head>.

---

**AC2 - Non-www HTTP Redirects to www HTTPS**

Given a request is made to http://blackhawkstudios.com,
When the Azure SWA routing rules are applied,
Then the client receives a 301 redirect to https://www.blackhawkstudios.com/.

---

**AC3 - Non-www HTTPS Redirects to www HTTPS**

Given a request is made to https://blackhawkstudios.com,
When the Azure SWA routing rules are applied,
Then the client receives a 301 redirect to https://www.blackhawkstudios.com/.

---

**AC4 - www HTTPS Serves Normally**

Given a request is made to https://www.blackhawkstudios.com,
When the SWA routing rules are evaluated,
Then no redirect occurs and the page is served with HTTP 200.
'@
Update-WorkItem -Id 39 -Priority "Medium" -StoryPoints 1 `
    -Title "Add Canonical Tag and Enforce www Redirect via SWA Config" `
    -Description $desc -AcceptanceCriteria $ac

# AB#40
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need an optimised page title and meta description that lead with the primary search keyword,
So that the site's click-through rate from search result pages improves and relevance signals for "San Francisco mobile app development" queries are strengthened.

---

**Out of Scope**
- Keyword research or SEO content strategy
- Title/description optimisation for routes beyond root (site is single-page)
- A/B testing of copy variants

**Dependencies**
- None

**Notes**
Proposed title (56 chars): "San Francisco Mobile App & Web Development — Blackhawk Studios". Proposed description (~155 chars): "Blackhawk Studios LLC builds mobile apps and web platforms for modern businesses in San Francisco. iOS, Android, web development, and tech consulting. Get in touch." Adjust to taste before merging.
'@
$ac = @'
**AC1 - Title Tag Length and Keyword Order**

Given the updated index.html is deployed to production,
When the page source is inspected,
Then the <title> tag is between 50 and 60 characters and begins with a primary keyword phrase such as "San Francisco Mobile App & Web Development".

---

**AC2 - Meta Description Length and CTA**

Given the updated index.html is deployed to production,
When the page source is inspected,
Then the meta description is between 150 and 160 characters and includes a call to action.

---

**AC3 - Title Matches Browser Tab**

Given the page is open in a browser,
When the tab is inspected,
Then the tab title reflects the updated <title> tag value.

---

**AC4 - Google Search Console Preview Valid**

Given the updated title and description are deployed,
When the URL is inspected using the Google Search Console URL Inspection tool,
Then the rendered title and description match the values in the HTML source without truncation.
'@
Update-WorkItem -Id 40 -Priority "Medium" -StoryPoints 1 `
    -Title "Rewrite Title Tag and Meta Description for Primary Keyword" `
    -Description $desc -AcceptanceCriteria $ac

# AB#41
$desc = @'
**Technical Story**

As the blackhawkstudios.com CI/CD pipeline,
I need the sitemap.xml lastmod date updated automatically to the current date on every deployment,
So that Google Search Console always receives an accurate last-modified signal without requiring manual edits to sitemap.xml.

---

**Out of Scope**
- Per-URL lastmod tracking (site is single-page; one URL in the sitemap)
- Sitemap index files or multi-sitemap configuration
- Sitemap re-submission to Google via Search Console API

**Dependencies**
- GitHub Actions workflow: .github/workflows/azure-static-web-apps-ambitious-mushroom-06a8b221e.yml

**Notes**
Simplest implementation: use sed in a run step before the SWA deploy action. Replace the existing date value: sed -i "s/<lastmod>[0-9-]*<\/lastmod>/<lastmod>$(date -u +%Y-%m-%d)<\/lastmod>/" sitemap.xml. Alternatively, use a placeholder token (LASTMOD_PLACEHOLDER) in the source file.
'@
$ac = @'
**AC1 - lastmod Updated on Deploy**

Given the GitHub Actions workflow runs on a push to main,
When the SWA deploy step completes,
Then the deployed sitemap.xml contains a <lastmod> value equal to the UTC date of that workflow run (format: YYYY-MM-DD).

---

**AC2 - Hardcoded Date Removed from Source**

Given the sitemap.xml file in the repository,
When the file is inspected on the main branch,
Then the <lastmod> value is a placeholder token or the date injection occurs in the workflow — not a static hardcoded date.

---

**AC3 - Workflow Step Does Not Fail on Clean Run**

Given the GitHub Actions workflow runs with no other changes,
When the date-injection step executes,
Then the step exits with code 0 and the workflow proceeds to the SWA deploy action.

---

**AC4 - Date Format is ISO 8601**

Given the sitemap.xml is deployed,
When it is fetched from https://www.blackhawkstudios.com/sitemap.xml,
Then the <lastmod> value matches the pattern YYYY-MM-DD.
'@
Update-WorkItem -Id 41 -Priority "Low" -StoryPoints 2 `
    -Title "Automate sitemap.xml lastmod Date in GitHub Actions Deploy" `
    -Description $desc -AcceptanceCriteria $ac

# AB#44
$desc = @'
**Technical Story**

As the blackhawkstudios.com development process,
I need a NAP (Name, Address, Phone) consistency checklist in the GitHub pull request template,
So that any change to contact information in the HTML or JSON-LD is flagged for cross-channel verification before merging, preventing citation inconsistencies that harm local SEO.

---

**Out of Scope**
- Automated NAP consistency validation (linting/CI check)
- External directory update automation
- Any changes to the NAP values themselves

**Dependencies**
- AB#38 — JSON-LD LocalBusiness schema must exist before the checklist can reference it meaningfully

**Notes**
If a .github/pull_request_template.md already exists, append the NAP section rather than replacing it. A future automation story could add a CI lint step that diffs NAP values between HTML and JSON-LD.
'@
$ac = @'
**AC1 - PR Template File Exists**

Given the repository,
When .github/pull_request_template.md is inspected,
Then the file exists and contains a NAP consistency checklist section.

---

**AC2 - Checklist Items Cover All Sources**

Given the PR template NAP section,
When the checklist is reviewed,
Then it includes checkbox items for: HTML contact section, JSON-LD LocalBusiness schema, Google Business Profile, and any other external directories (e.g. Yelp).

---

**AC3 - Template Appears on New PRs**

Given a contributor opens a new pull request via the GitHub UI,
When the PR description field loads,
Then the NAP checklist is pre-populated in the description body.
'@
Update-WorkItem -Id 44 -Priority "Low" -StoryPoints 1 `
    -Title "Add NAP Consistency Checklist to GitHub PR Template" `
    -Description $desc -AcceptanceCriteria $ac

# ─────────────────────────────────────────────
# TECHNICAL STORIES — EPIC 3: Performance
# ─────────────────────────────────────────────

# AB#47
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need the two hero/about PNG images replaced with AVIF and WebP variants served via the HTML picture element,
So that modern browsers receive smaller, faster-loading image formats while legacy browsers retain PNG fallback, reducing LCP and bandwidth cost.

---

**Out of Scope**
- Srcset/responsive size variants (covered by AB#48)
- Preload hint for the hero image (covered by AB#50)
- Automated image conversion in CI (manual conversion is acceptable for this story)

**Dependencies**
- None — replaces existing static assets

**Notes**
Use squoosh.app, libvips, or sharp (Node.js) for conversion. Target quality: AVIF 60-70, WebP 80. Keep the original PNGs in the repo as source-of-truth assets even after conversion. Images: Gemini_Generated_Image_ma0umvma0umvma0u (hero + about) and Gemini_Generated_Image_fna5tofna5tofna5.
'@
$ac = @'
**AC1 - AVIF and WebP Variants Exist**

Given the image conversion is complete,
When the /images/ directory is inspected,
Then AVIF and WebP variants exist for both source images, each <= 150 KB.

---

**AC2 - picture Element Used in index.html**

Given the updated index.html is deployed,
When the page source is inspected,
Then each image is wrapped in a <picture> element with a <source type="image/avif">, a <source type="image/webp">, and an <img> fallback pointing to the original PNG.

---

**AC3 - AVIF Served to Chrome**

Given the page is loaded in Chrome (which supports AVIF),
When the DevTools Network tab is inspected,
Then the AVIF variant is the file downloaded for each image.

---

**AC4 - PNG Fallback Served to Legacy Browsers**

Given the page is loaded in a browser that does not support AVIF or WebP (simulated via DevTools Accept header override),
When the image request resolves,
Then the PNG file is served and the image renders correctly.

---

**AC5 - No Visual Regression**

Given the updated page is rendered at 1x and 2x display density,
When the hero and about sections are compared against the previous design,
Then the images are visually equivalent with no quality degradation visible to the naked eye.
'@
Update-WorkItem -Id 47 -Priority "High" -StoryPoints 3 `
    -Title "Convert Site PNGs to WebP/AVIF with picture Element Fallback" `
    -Description $desc -AcceptanceCriteria $ac

# AB#48
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need srcset and sizes attributes on the hero and about images with breakpoint-specific width variants,
So that mobile and tablet viewports download appropriately sized image files rather than full desktop-resolution assets, reducing unnecessary bandwidth consumption.

---

**Out of Scope**
- Art-direction crops (different image content at different breakpoints)
- Image variants beyond the three specified breakpoints

**Dependencies**
- AB#47 — WebP/AVIF base images must exist before responsive variants can be generated

**Notes**
Generate responsive variants from the WebP source, not the PNG, to maintain format quality. The sizes attribute values must be verified against the actual rendered CSS layout widths — measure with DevTools at each breakpoint before committing.
'@
$ac = @'
**AC1 - Three Width Variants Exist Per Image**

Given the responsive variants are generated,
When the /images/ directory is inspected,
Then WebP (and AVIF) variants exist at 480w, 960w, and 1440w for each of the two site images.

---

**AC2 - srcset Populated on picture Sources**

Given the updated index.html is deployed,
When the page source is inspected,
Then each <source> element inside the <picture> block has a srcset attribute listing all three width descriptors (480w, 960w, 1440w).

---

**AC3 - sizes Attribute Reflects Layout**

Given the updated index.html is deployed,
When the sizes attribute is inspected on each image,
Then it describes the image's rendered width at each breakpoint, matching the actual CSS layout.

---

**AC4 - Mobile Loads Smallest Variant**

Given the page is loaded with DevTools set to a 375px mobile viewport,
When the Network tab is inspected after the page loads,
Then the 480w image variant is the file downloaded, not the 960w or 1440w variant.
'@
Update-WorkItem -Id 48 -Priority "High" -StoryPoints 2 `
    -Title "Add srcset and sizes Attributes for Responsive Image Delivery" `
    -Description $desc -AcceptanceCriteria $ac

# AB#49
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need explicit width and height attributes on all img elements matching each image's intrinsic aspect ratio,
So that browsers reserve the correct layout space before images load, eliminating Cumulative Layout Shift (CLS) and maintaining a Lighthouse CLS score below 0.1.

---

**Out of Scope**
- CSS aspect-ratio property changes (width/height attributes are sufficient)
- Images inside 404.html or 500.html error pages unless they contribute to CLS

**Dependencies**
- AB#47 — final image dimensions must be known before width/height can be set accurately

**Notes**
Set width and height to the largest display size used (the 1440w variant dimensions), and let CSS control the actual rendered size. Do not set width="100%" in the HTML attribute — use CSS for responsive scaling.
'@
$ac = @'
**AC1 - width and height Present on All img Tags**

Given the updated index.html is deployed,
When the page source is inspected,
Then every <img> element has both a width and a height attribute with numeric pixel values.

---

**AC2 - Attributes Match Intrinsic Aspect Ratio**

Given the width and height attributes on an img element,
When the ratio width/height is calculated,
Then it matches the intrinsic aspect ratio of the image file (within 1% tolerance).

---

**AC3 - Lighthouse CLS Score Below 0.1**

Given the updated page is audited with Lighthouse (mobile preset),
When the CLS metric is reported,
Then the score is less than 0.1 (green band).

---

**AC4 - No Layout Change on Image Load**

Given the page is loaded on a throttled connection (DevTools "Slow 4G" preset),
When images load progressively,
Then no visible content shift occurs in the hero or about sections as each image finishes loading.
'@
Update-WorkItem -Id 49 -Priority "High" -StoryPoints 1 `
    -Title "Add Explicit width and height Attributes to All img Elements" `
    -Description $desc -AcceptanceCriteria $ac

# AB#50
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need a <link rel="preload"> hint for the hero image in the HTML head,
So that the browser begins fetching the above-the-fold image earlier in the loading waterfall, improving the Largest Contentful Paint (LCP) score.

---

**Out of Scope**
- Preloading the about section image (below the fold; preloading would waste bandwidth)
- Preloading font files (covered by AB#52)

**Dependencies**
- AB#47 — hero image must be converted to WebP/AVIF before the preload can reference the modern format

**Notes**
If using srcset variants (AB#48), the preload tag should use imagesrcset and imagesizes attributes to match the picture element exactly, so the browser selects the same variant it would render.
'@
$ac = @'
**AC1 - Preload Link Present in Head**

Given the updated index.html is deployed,
When the page source is inspected,
Then a <link rel="preload" as="image"> tag referencing the hero image is present inside <head>, appearing before the stylesheet link.

---

**AC2 - Preload References Correct Format**

Given AB#47 is complete and the hero is served as AVIF/WebP,
When the preload link is inspected,
Then it references the WebP or AVIF hero image URL and includes the correct type attribute.

---

**AC3 - No Duplicate Image Fetch**

Given the page is loaded in Chrome,
When the DevTools Network tab is inspected,
Then the hero image is fetched exactly once — the preload fetch and the picture element request resolve to the same cached resource.

---

**AC4 - LCP Does Not Regress**

Given a Lighthouse (mobile) audit is run before and after this change,
When the LCP scores are compared,
Then the LCP score after the change is equal to or better than before.
'@
Update-WorkItem -Id 50 -Priority "Medium" -StoryPoints 1 `
    -Title "Add Preload Link for Hero Image to Improve LCP" `
    -Description $desc -AcceptanceCriteria $ac

# AB#52
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need Space Grotesk and Fira Code font files downloaded and served from the SWA origin,
So that the render-blocking DNS lookup to fonts.googleapis.com and fonts.gstatic.com is eliminated, improving LCP and removing a third-party dependency from the critical rendering path.

---

**Out of Scope**
- Variable font format (static woff2 per weight is acceptable)
- Font subsetting beyond what Google Fonts currently provides
- Preloading specific font files

**Dependencies**
- None — replaces the existing Google Fonts CSS link in index.html

**Notes**
Use google-webfonts-helper to download the exact woff2 subsets. Only download the weights actively used in site.css — Space Grotesk (300, 400, 500, 600, 700) and Fira Code (400, 500). Remove the <link rel="preconnect"> tags for Google Fonts after switching.
'@
$ac = @'
**AC1 - No Third-Party Font Requests**

Given the updated site is loaded in a browser,
When the DevTools Network tab is filtered to font requests,
Then zero requests are made to fonts.googleapis.com or fonts.gstatic.com.

---

**AC2 - Font Files Served from Origin**

Given the page has loaded,
When the Network tab is inspected for font file requests,
Then all woff2 files are served from www.blackhawkstudios.com with HTTP 200 and appropriate cache headers.

---

**AC3 - @font-face Declarations Include font-display: swap**

Given the updated site.css is deployed,
When the @font-face rules are inspected,
Then every @font-face declaration for Space Grotesk and Fira Code includes font-display: swap.

---

**AC4 - No Flash of Invisible Text**

Given the page is loaded on a throttled connection (DevTools "Slow 4G"),
When fonts are loading,
Then fallback system fonts are displayed immediately (no blank/invisible text period) before the custom fonts swap in.

---

**AC5 - All Font Weights Render Correctly**

Given the page is loaded with self-hosted fonts active,
When each section is inspected visually,
Then Space Grotesk renders correctly in all used weights (300, 400, 500, 600, 700) and Fira Code in used weights (400, 500), matching the previous appearance.
'@
Update-WorkItem -Id 52 -Priority "Medium" -StoryPoints 3 `
    -Title "Self-Host Google Fonts to Eliminate Third-Party Font Request" `
    -Description $desc -AcceptanceCriteria $ac

# AB#53
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need unused CSS rules removed from site.css,
So that the stylesheet payload is reduced, parse time is minimised, and the codebase contains only rules that are actively applied to the rendered page.

---

**Out of Scope**
- CSS minification or bundling (gzip via Azure SWA is sufficient)
- Refactoring the CSS architecture or methodology
- Removing CSS custom properties (variables) unless confirmed unused

**Dependencies**
- None — site.css is the sole stylesheet with no build step

**Notes**
Run PurgeCSS against index.html, 404.html, and 500.html as content sources. Any dynamically added class names (e.g. "open", "scrolled" added via JavaScript) must be added to the PurgeCSS safelist — check the inline script in index.html for classList.toggle and classList.add calls before running the audit.
'@
$ac = @'
**AC1 - File Size at or Below Target**

Given the trimmed site.css is deployed,
When the file size is measured (uncompressed),
Then it is <= 20 KB.

---

**AC2 - No Visual Regressions — Main Page**

Given the trimmed stylesheet is applied,
When all four sections of index.html (Hero, Services, About, Contact) are reviewed at mobile (375px), tablet (768px), and desktop (1440px) viewports,
Then no layout, colour, typography, or animation differences are visible compared to the baseline.

---

**AC3 - No Visual Regressions — Error Pages**

Given the trimmed stylesheet is applied,
When 404.html and 500.html are loaded in a browser,
Then both pages render correctly with no missing styles.

---

**AC4 - Mobile Nav Still Functions**

Given the trimmed stylesheet is applied,
When the hamburger toggle is activated on a mobile viewport,
Then the nav menu opens and closes correctly with the expected transition.
'@
Update-WorkItem -Id 53 -Priority "Low" -StoryPoints 2 `
    -Title "Audit and Remove Unused Rules from site.css" `
    -Description $desc -AcceptanceCriteria $ac

# ─────────────────────────────────────────────
# TECHNICAL STORIES — EPIC 4: Accessibility
# ─────────────────────────────────────────────

# AB#57
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need a skip-to-main-content link as the first focusable element in the page,
So that keyboard and screen reader users can bypass the navigation and reach the main content directly, satisfying WCAG 2.1 Success Criterion 2.4.1 (Bypass Blocks).

---

**Out of Scope**
- Skip links to individual sections beyond main content (one skip link is sufficient)
- Changes to ARIA landmark structure (covered by AB#56 user story)

**Dependencies**
- The target anchor (id="main" on the hero section or a main landmark element) must exist in index.html

**Notes**
Common implementation: position the link absolutely off-screen (left: -9999px) and bring it back on :focus. Ensure the focus style uses brand green (#00e676) outline to remain consistent with other focus indicators.
'@
$ac = @'
**AC1 - Skip Link is First Focusable Element**

Given the page has loaded,
When a keyboard user presses Tab once from the browser chrome,
Then the skip link is the first element to receive focus — before any nav link or other interactive element.

---

**AC2 - Link is Visually Hidden Until Focused**

Given the skip link is not focused,
When the page is inspected visually,
Then the link is not visible in the rendered layout and does not occupy visible space.

---

**AC3 - Link Becomes Visible on Focus**

Given a keyboard user tabs to the skip link,
When the link receives focus,
Then it becomes visible with a legible label ("Skip to main content"), a visible focus indicator, and sufficient color contrast against its background.

---

**AC4 - Activation Moves Focus to Main Content**

Given the skip link has focus,
When the user activates it (presses Enter),
Then keyboard focus moves to the main content landmark, bypassing the navigation.

---

**AC5 - Link Has Descriptive Text**

Given the link is inspected by a screen reader,
When it receives focus,
Then the announced text is "Skip to main content" or equivalent.
'@
Update-WorkItem -Id 57 -Priority "Medium" -StoryPoints 1 `
    -Title "Add Visually Hidden Skip-to-Main-Content Link" `
    -Description $desc -AcceptanceCriteria $ac

# AB#58
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need all text and interactive element color combinations audited against WCAG 2.1 AA contrast ratios, with any failures corrected,
So that the site is accessible to users with low vision or color perception differences without violating the existing brand palette.

---

**Out of Scope**
- WCAG AAA contrast ratios (7:1 for normal text, 4.5:1 for large text)
- Rebranding or palette changes beyond minimum necessary fixes

**Dependencies**
- None — standalone audit and fix story

**Notes**
The primary combination #00e676 on #090c0f has a calculated contrast ratio of approximately 13.5:1 — passes AA and AAA. Likely failure candidates are secondary text colors, placeholder text, or muted label text. Run axe first to identify actual failures before making any changes.
'@
$ac = @'
**AC1 - Normal Text Passes 4.5:1**

Given all text rendered on the page at font sizes below 18pt (or 14pt bold),
When the foreground and background color combination is measured using the WebAIM Contrast Checker,
Then every instance returns a contrast ratio of at least 4.5:1.

---

**AC2 - Large Text Passes 3:1**

Given all text rendered at 18pt or larger (or 14pt bold or larger),
When the contrast ratio is measured,
Then every instance returns a contrast ratio of at least 3:1.

---

**AC3 - Interactive Element Focus Indicators Pass 3:1**

Given the focus indicator color (#00e676) is applied to focused elements against the page background (#090c0f),
When the contrast ratio is measured,
Then it meets at least 3:1 per WCAG 2.1 SC 1.4.11 Non-text Contrast.

---

**AC4 - No Brand Palette Violations**

Given any contrast fix is applied,
When the updated site is reviewed visually,
Then no purple, blue gradients, or rounded aesthetics have been introduced — all fixes remain within the dark charcoal (#090c0f) and neon green (#00e676) palette.

---

**AC5 - Axe Reports Zero Contrast Violations**

Given the production page is scanned with the axe browser extension,
When the scan completes,
Then zero color-contrast violations are reported.
'@
Update-WorkItem -Id 58 -Priority "Medium" -StoryPoints 2 `
    -Title "Audit and Fix Color Contrast for WCAG 2.1 AA Compliance" `
    -Description $desc -AcceptanceCriteria $ac

# AB#60
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need apple-touch-icon.png and additional favicon size variants linked in the HTML head,
So that the site icon renders correctly when added to an iOS home screen and in browser tabs that request specific favicon sizes, eliminating 404s for missing icon assets.

---

**Out of Scope**
- PWA manifest icons (covered by AB#61)
- Windows tile icons (mstile) or Safari pinned tab SVG
- Favicon animation

**Dependencies**
- Existing favicon.ico and brand hawk image assets in the /images/ directory

**Notes**
Generate the 180x180, 32x32, and 16x16 PNGs from the existing hawk favicon source. Place all new icon files in the root directory to match convention (same level as favicon.ico).
'@
$ac = @'
**AC1 - apple-touch-icon Served at Correct Path**

Given the updated site is deployed,
When a GET request is made to https://www.blackhawkstudios.com/apple-touch-icon.png,
Then the server responds with HTTP 200 and a PNG image of exactly 180x180 pixels.

---

**AC2 - favicon-32x32 and favicon-16x16 Present**

Given the updated site is deployed,
When GET requests are made to /favicon-32x32.png and /favicon-16x16.png,
Then both respond with HTTP 200 and PNG images at their respective dimensions.

---

**AC3 - Link Tags Present in Head**

Given the updated index.html is deployed,
When the page source is inspected,
Then <link> tags for apple-touch-icon (180x180), favicon-32x32, and favicon-16x16 are present inside <head>.

---

**AC4 - No Console Errors for Icon Resources**

Given the page is loaded in Chrome with DevTools Network tab open,
When the page finishes loading,
Then no 404 errors appear for favicon or apple-touch-icon requests.

---

**AC5 - iOS Home Screen Icon Renders Correctly**

Given the site is visited in Safari on iOS and "Add to Home Screen" is selected,
When the home screen is viewed,
Then the Blackhawk Studios hawk icon appears at the expected size without pixelation.
'@
Update-WorkItem -Id 60 -Priority "Low" -StoryPoints 2 `
    -Title "Add Apple Touch Icon and Multi-Size Favicon Assets" `
    -Description $desc -AcceptanceCriteria $ac

# AB#61
$desc = @'
**Technical Story**

As the blackhawkstudios.com platform,
I need a web app manifest linked from index.html,
So that the site is eligible for "Add to Home Screen" prompts on Android and browsers that support PWA installation, and brand colors are applied to the browser chrome when launched as a standalone app.

---

**Out of Scope**
- Service worker or offline caching (full PWA offline support is not in scope)
- Push notifications
- Background sync

**Dependencies**
- AB#60 — 192x192 and 512x512 icon variants must exist before the manifest can reference them

**Notes**
Generate the 192x192 and 512x512 PNG icons from the same hawk brand source used for AB#60. Set purpose: "any maskable" on at least one icon entry so Android adaptive icon templates render correctly.
'@
$ac = @'
**AC1 - manifest.json Served at Root**

Given the updated site is deployed,
When a GET request is made to https://www.blackhawkstudios.com/manifest.json,
Then the server responds with HTTP 200 and a valid JSON document with Content-Type: application/manifest+json.

---

**AC2 - Required Fields Present**

Given the manifest.json is fetched,
When the JSON is parsed,
Then it contains: name ("Blackhawk Studios LLC"), short_name ("Blackhawk"), start_url ("/"), display ("standalone"), theme_color ("#090c0f"), background_color ("#090c0f"), and an icons array with entries for at least 192x192 and 512x512 PNG icons.

---

**AC3 - Link Tag Present in Head**

Given the updated index.html is deployed,
When the page source is inspected,
Then <link rel="manifest" href="/manifest.json"> is present inside <head>.

---

**AC4 - Lighthouse PWA Manifest Check Passes**

Given the production URL is audited with Lighthouse (PWA category),
When the manifest-related checks are evaluated,
Then all manifest checklist items pass with no errors.

---

**AC5 - No Manifest Parse Errors in DevTools**

Given the page is loaded in Chrome with DevTools open on the Application > Manifest panel,
When the manifest is parsed,
Then the panel displays the manifest fields correctly with no parse errors or warnings.
'@
Update-WorkItem -Id 61 -Priority "Low" -StoryPoints 2 `
    -Title "Add Web App Manifest for PWA Installability" `
    -Description $desc -AcceptanceCriteria $ac

Write-Host ""
Write-Host "==================================================="
Write-Host " All 23 work items updated"
Write-Host "==================================================="
