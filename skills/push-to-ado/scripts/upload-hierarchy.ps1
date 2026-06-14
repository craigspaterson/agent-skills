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

function New-WorkItem {
    param(
        [string]$Type,
        [string]$Title,
        [string]$Description,
        [string]$AcceptanceCriteria = "",
        [int]$StoryPoints = 0,
        [string]$Priority = "Medium",
        [int]$ParentId = 0,
        [string]$Tags = ""
    )

    $ops = [System.Collections.Generic.List[hashtable]]::new()
    $ops.Add(@{ op = "add"; path = "/fields/System.Title";                      value = $Title })
    $ops.Add(@{ op = "add"; path = "/fields/System.Description";                value = $Description })
    $ops.Add(@{ op = "add"; path = "/multilineFieldsFormat/System.Description"; value = "Markdown" })
    $ops.Add(@{ op = "add"; path = "/fields/Microsoft.VSTS.Common.Priority";    value = $priorityMap[$Priority] })

    if ($AcceptanceCriteria) {
        $ops.Add(@{ op = "add"; path = "/fields/Microsoft.VSTS.Common.AcceptanceCriteria";                        value = $AcceptanceCriteria })
        $ops.Add(@{ op = "add"; path = "/multilineFieldsFormat/Microsoft.VSTS.Common.AcceptanceCriteria";         value = "Markdown" })
    }
    if ($StoryPoints -gt 0) {
        $ops.Add(@{ op = "add"; path = "/fields/Microsoft.VSTS.Scheduling.StoryPoints"; value = $StoryPoints })
    }
    if ($Tags) {
        $ops.Add(@{ op = "add"; path = "/fields/System.Tags"; value = $Tags })
    }
    if ($ParentId -gt 0) {
        $ops.Add(@{
            op    = "add"
            path  = "/relations/-"
            value = @{
                rel        = "System.LinkTypes.Hierarchy-Reverse"
                url        = "$baseUrl/_apis/wit/workItems/$ParentId"
                attributes = @{ comment = "" }
            }
        })
    }

    $encodedType = [Uri]::EscapeDataString($Type)
    $url         = "$baseUrl/_apis/wit/workItems/`$$encodedType`?api-version=7.1"
    $body        = $ops | ConvertTo-Json -Depth 6

    Write-Host "  [$Type] $Title"
    $r   = Invoke-RestMethod -Method Patch -Uri $url -Headers $headers -Body $body -ContentType "application/json-patch+json"
    $id  = $r.id
    Write-Host "    -> AB#$id  $baseUrl/_workitems/edit/$id"
    return $id
}

# ────────────────────────────────────────────────────────────
# EPIC 1  Lead Generation & Conversion
# ────────────────────────────────────────────────────────────
$e1 = New-WorkItem -Type "Epic" -Priority "High" `
    -Title "Lead Generation & Conversion" `
    -Description "Improve the site's ability to generate and capture leads. The contact section currently shows only static contact information — address, phone, email. Converting it to an active, tracked form is the most direct revenue lever."

  $f1_1 = New-WorkItem -Type "Feature" -Priority "High" -ParentId $e1 `
      -Title "Contact Form" `
      -Description "Replace the static contact footer with an interactive form backed by an Azure Functions endpoint. Includes spam protection, email delivery, and GA4 conversion tracking."

    New-WorkItem -Type "User Story" -Priority "High" -ParentId $f1_1 -StoryPoints 3 `
        -Title "Submit an inquiry via web form" `
        -Description "As a potential client, I want to fill out a form on the site so I can send an inquiry without leaving the browser to open my email client." `
        -AcceptanceCriteria "- Name, email, and message fields are present with a submit button`n- Client-side validation highlights missing or invalid fields before submission`n- Form renders correctly on mobile and desktop"

    New-WorkItem -Type "User Story" -Priority "High" -ParentId $f1_1 -StoryPoints 2 `
        -Title "Receive confirmation after form submission" `
        -Description "As a site visitor, I want to see a success message after submitting so I know my message was received." `
        -AcceptanceCriteria "- Inline confirmation state is shown after successful submission (no page reload)`n- Error state is displayed if the submission fails`n- Confirmation message is readable by screen readers"

    New-WorkItem -Type "User Story" -Priority "High" -ParentId $f1_1 -StoryPoints 5 -Tags "Technical" `
        -Title "Implement form backend via Azure Static Web Apps managed function" `
        -Description "Wire the contact form POST to an Azure Functions HTTP trigger deployed alongside the SWA. Forward submissions to info@blackhawkstudios.com via SendGrid or Azure Communication Services." `
        -AcceptanceCriteria "- POST to /api/contact returns 200 on success and 4xx on validation failure`n- Email is delivered to info@blackhawkstudios.com within 60 seconds of form submission`n- Function deploys successfully via the existing GitHub Actions workflow"

    New-WorkItem -Type "User Story" -Priority "Medium" -ParentId $f1_1 -StoryPoints 2 -Tags "Technical" `
        -Title "Add spam protection to contact form" `
        -Description "Add a honeypot hidden field and rate-limit the function endpoint (1 submission / 60 s per IP) to prevent abuse before going live." `
        -AcceptanceCriteria "- Honeypot field is hidden from sighted users but present in the DOM`n- Bot submissions that fill the honeypot are silently rejected (200 returned, no email sent)`n- More than 1 submission per 60 s from the same IP returns HTTP 429"

    New-WorkItem -Type "User Story" -Priority "Medium" -ParentId $f1_1 -StoryPoints 1 -Tags "Technical" `
        -Title "Track form submissions in GA4" `
        -Description "Fire a generate_lead GA4 event on successful form submission so conversions appear in Google Analytics (GA4 tag G-43LEH4LYTK)." `
        -AcceptanceCriteria "- generate_lead event appears in GA4 DebugView on form submission`n- Event fires only on confirmed success, not on validation errors`n- Event is visible in the GA4 Conversions report"

# ────────────────────────────────────────────────────────────
# EPIC 2  Search Engine Optimization
# ────────────────────────────────────────────────────────────
$e2 = New-WorkItem -Type "Epic" -Priority "High" `
    -Title "Search Engine Optimization" `
    -Description "Improve the site's organic search visibility. Current SEO is minimal: a title tag, one meta description, sitemap.xml, and robots.txt. Several high-value signals — Open Graph tags, JSON-LD structured data, canonical URLs, and local SEO — are absent."

  $f2_1 = New-WorkItem -Type "Feature" -Priority "High" -ParentId $e2 `
      -Title "On-Page & Technical SEO" `
      -Description "Add structured metadata, improve page title and description copy, fix canonical URL handling, and automate the sitemap lastmod timestamp."

    New-WorkItem -Type "User Story" -Priority "High" -ParentId $f2_1 -StoryPoints 2 -Tags "Technical" `
        -Title "Add Open Graph and Twitter Card meta tags" `
        -Description "Add og:title, og:description, og:image, og:url, twitter:card, and twitter:image to the HTML head so link previews render correctly on LinkedIn, Slack, and X when the URL is shared." `
        -AcceptanceCriteria "- All six OG and Twitter meta tags are present in the page <head>`n- og:image points to a correctly sized image (1200x630 px recommended)`n- Preview validates correctly in the LinkedIn Post Inspector and Twitter Card Validator"

    New-WorkItem -Type "User Story" -Priority "High" -ParentId $f2_1 -StoryPoints 2 -Tags "Technical" `
        -Title "Add JSON-LD LocalBusiness structured data" `
        -Description "Embed a LocalBusiness schema.org block with name, address, telephone, url, and geo coordinates. Enables rich results and improves local pack eligibility." `
        -AcceptanceCriteria "- JSON-LD script tag with @type LocalBusiness is present in the page <head>`n- Passes Google Rich Results Test with no errors or warnings`n- Includes: name, address (streetAddress, addressLocality, addressRegion, postalCode, countryCode), telephone, url"

    New-WorkItem -Type "User Story" -Priority "Medium" -ParentId $f2_1 -StoryPoints 1 -Tags "Technical" `
        -Title "Add canonical URL and enforce www redirect" `
        -Description "Add <link rel='canonical' href='https://www.blackhawkstudios.com/'> and ensure the www vs non-www redirect is enforced in staticwebapp.config.json." `
        -AcceptanceCriteria "- Canonical link tag is present in the HTML <head>`n- http://blackhawkstudios.com and https://blackhawkstudios.com both 301-redirect to https://www.blackhawkstudios.com"

    New-WorkItem -Type "User Story" -Priority "Medium" -ParentId $f2_1 -StoryPoints 1 -Tags "Technical" `
        -Title "Improve title tag and meta description copy" `
        -Description "Rewrite the page title to lead with the primary keyword and sharpen the meta description to 150-160 chars with a call to action. Current title: 'Blackhawk Studios LLC — Technology Agency, San Francisco'." `
        -AcceptanceCriteria "- Page title is 50-60 chars and leads with primary keyword (e.g. 'San Francisco Mobile App & Web Development')`n- Meta description is 150-160 chars and includes a CTA`n- Validated in a browser tab and Google Search Console preview tool"

    New-WorkItem -Type "User Story" -Priority "Low" -ParentId $f2_1 -StoryPoints 2 -Tags "Technical" `
        -Title "Automate sitemap.xml lastmod date in CI/CD" `
        -Description "The sitemap lastmod is currently a static hardcoded date. Automate it in the GitHub Actions workflow so it reflects the actual last deploy date on every deployment." `
        -AcceptanceCriteria "- sitemap.xml lastmod updates automatically on each successful GitHub Actions deploy`n- Date format is ISO 8601 (YYYY-MM-DD)`n- No manual edits to sitemap.xml are required after each deploy"

  $f2_2 = New-WorkItem -Type "Feature" -Priority "Medium" -ParentId $e2 `
      -Title "Local SEO" `
      -Description "Target location-based search queries for San Francisco technology agency and mobile app developer searches. Ensure NAP (Name, Address, Phone) consistency across all channels."

    New-WorkItem -Type "User Story" -Priority "Medium" -ParentId $f2_2 -StoryPoints 3 `
        -Title "Appear in local SF tech agency search results" `
        -Description "As Blackhawk Studios, I want to rank for queries like 'SF technology agency' and 'San Francisco mobile app developer' so prospective clients find us organically." `
        -AcceptanceCriteria "- LocalBusiness structured data is live and validated in Google Rich Results Test`n- No structured data errors appear in Google Search Console`n- Site is submitted to Google Search Console with sitemap indexed"

    New-WorkItem -Type "User Story" -Priority "Low" -ParentId $f2_2 -StoryPoints 1 -Tags "Technical" `
        -Title "Add NAP consistency audit to release checklist" `
        -Description "Verify Name / Address / Phone in the HTML, JSON-LD, and any external directories (Google Business Profile, Yelp) are identical before each major content update." `
        -AcceptanceCriteria "- A NAP audit checklist item exists in the project PR template or release checklist`n- HTML, JSON-LD, and Google Business Profile NAP values all match exactly"

# ────────────────────────────────────────────────────────────
# EPIC 3  Performance & Core Web Vitals
# ────────────────────────────────────────────────────────────
$e3 = New-WorkItem -Type "Epic" -Priority "High" `
    -Title "Performance & Core Web Vitals" `
    -Description "Improve page load speed, Core Web Vitals scores, and asset delivery efficiency. Two large PNGs are the primary LCP risk. Google Fonts adds a render-blocking third-party request. Target: all Core Web Vitals in the green band."

  $f3_1 = New-WorkItem -Type "Feature" -Priority "High" -ParentId $e3 `
      -Title "Image Optimization" `
      -Description "Convert existing PNG images to modern formats (WebP/AVIF), add responsive srcset variants, and fix CLS-causing missing dimension attributes."

    New-WorkItem -Type "User Story" -Priority "High" -ParentId $f3_1 -StoryPoints 3 -Tags "Technical" `
        -Title "Convert hero and about PNGs to WebP/AVIF with picture fallback" `
        -Description "Replace the two Gemini-generated PNGs with WebP (primary) and AVIF (modern) variants. Use <picture><source> for format negotiation; keep PNG as the fallback <img>. Target: <= 150 KB per image." `
        -AcceptanceCriteria "- Both images are served as AVIF to browsers that support it, WebP otherwise, PNG as final fallback`n- Each image file is <= 150 KB`n- Visual quality is acceptable at 1x and 2x display densities`n- No broken images on any browser (Chrome, Firefox, Safari)"

    New-WorkItem -Type "User Story" -Priority "High" -ParentId $f3_1 -StoryPoints 2 -Tags "Technical" `
        -Title "Add srcset and sizes attributes for responsive image delivery" `
        -Description "Add 3 breakpoint variants per image (480w, 960w, 1440w) so mobile devices don't download desktop-resolution assets." `
        -AcceptanceCriteria "- Each <img> has a srcset with at least 3 width descriptors`n- sizes attribute correctly describes the image's rendered width at each breakpoint`n- Chrome DevTools Network shows mobile viewport loading the smallest appropriate variant"

    New-WorkItem -Type "User Story" -Priority "High" -ParentId $f3_1 -StoryPoints 1 -Tags "Technical" `
        -Title "Add explicit width and height attributes to all img tags" `
        -Description "Prevents Cumulative Layout Shift (CLS) score regression. Required for a passing Core Web Vitals audit." `
        -AcceptanceCriteria "- All <img> elements have numeric width and height attributes matching the intrinsic aspect ratio`n- Lighthouse CLS score is < 0.1 after the change"

    New-WorkItem -Type "User Story" -Priority "Medium" -ParentId $f3_1 -StoryPoints 1 -Tags "Technical" `
        -Title "Preload hero image to improve LCP" `
        -Description "Add <link rel='preload' as='image'> for the above-the-fold hero image to improve Largest Contentful Paint (LCP)." `
        -AcceptanceCriteria "- <link rel='preload'> for the hero image is in <head>`n- Lighthouse LCP improves or does not regress after the change`n- No duplicate image fetch appears in DevTools Network waterfall"

  $f3_2 = New-WorkItem -Type "Feature" -Priority "Medium" -ParentId $e3 `
      -Title "Asset & Font Performance" `
      -Description "Eliminate the render-blocking Google Fonts request by self-hosting, and reduce CSS payload by removing unused rules."

    New-WorkItem -Type "User Story" -Priority "Medium" -ParentId $f3_2 -StoryPoints 3 -Tags "Technical" `
        -Title "Self-host Google Fonts (Space Grotesk + Fira Code)" `
        -Description "Download and serve Space Grotesk and Fira Code font files from Azure SWA to eliminate the render-blocking third-party DNS lookup. Add font-display: swap to @font-face rules." `
        -AcceptanceCriteria "- No requests to fonts.googleapis.com or fonts.gstatic.com in DevTools Network`n- Font files are served from www.blackhawkstudios.com`n- @font-face declarations include font-display: swap`n- Site renders with correct fonts on first load with no invisible text (FOIT)"

    New-WorkItem -Type "User Story" -Priority "Low" -ParentId $f3_2 -StoryPoints 2 -Tags "Technical" `
        -Title "Audit and trim unused CSS in site.css" `
        -Description "Run PurgeCSS or a manual audit on site.css to remove dead rules. Target: <= 20 KB uncompressed." `
        -AcceptanceCriteria "- site.css file size is <= 20 KB uncompressed after cleanup`n- No visual regressions on any section (Hero, Services, About, Contact) or error pages (404, 500)`n- Mobile nav toggle still functions correctly after changes"

# ────────────────────────────────────────────────────────────
# EPIC 4  Accessibility & Quality Baseline
# ────────────────────────────────────────────────────────────
$e4 = New-WorkItem -Type "Epic" -Priority "Medium" `
    -Title "Accessibility & Quality Baseline" `
    -Description "Achieve WCAG 2.1 AA compliance and fill in missing web platform basics (skip links, PWA manifest, additional favicon sizes). Low effort with high protection against audit failures and assistive technology incompatibilities."

  $f4_1 = New-WorkItem -Type "Feature" -Priority "Medium" -ParentId $e4 `
      -Title "Accessibility (WCAG 2.1 AA)" `
      -Description "Ensure the site is keyboard navigable, screen reader accessible, and meets minimum color contrast requirements per WCAG 2.1 AA."

    New-WorkItem -Type "User Story" -Priority "Medium" -ParentId $f4_1 -StoryPoints 3 `
        -Title "Navigate the site efficiently with a screen reader" `
        -Description "As a screen reader user, I want landmark regions and descriptive link text so I can jump to sections without reading the whole page." `
        -AcceptanceCriteria "- Lighthouse a11y audit returns 0 critical violations`n- axe browser extension reports 0 violations`n- All interactive elements (nav links, CTA button, any form fields) are keyboard reachable via Tab`n- Page sections use appropriate ARIA landmark roles or HTML5 sectioning elements"

    New-WorkItem -Type "User Story" -Priority "Medium" -ParentId $f4_1 -StoryPoints 1 -Tags "Technical" `
        -Title "Add skip-to-main-content link" `
        -Description "Add a visually hidden <a href='#main'>Skip to content</a> as the first focusable element so keyboard users can bypass the nav." `
        -AcceptanceCriteria "- Skip link is the first focusable element in the DOM`n- Link is visually hidden until it receives focus`n- Activating the link moves focus to the main content landmark`n- Visible focus indicator is shown when the link receives keyboard focus"

    New-WorkItem -Type "User Story" -Priority "Medium" -ParentId $f4_1 -StoryPoints 2 -Tags "Technical" `
        -Title "Audit color contrast for green-on-dark text" `
        -Description "Verify #00e676 on #090c0f meets 4.5:1 for normal text and 3:1 for large text per WCAG 2.1 AA. Fix any instances that fail." `
        -AcceptanceCriteria "- All body/normal text passes 4.5:1 contrast ratio`n- All large text (18pt+ or 14pt+ bold) passes 3:1 contrast ratio`n- Verified using WebAIM Contrast Checker or browser DevTools`n- Any fixes remain within the brand palette (no purple, blue gradients, or rounded aesthetics)"

  $f4_2 = New-WorkItem -Type "Feature" -Priority "Low" -ParentId $e4 `
      -Title "Favicon & Web App Manifest" `
      -Description "Add missing favicon sizes for Apple devices and a minimal PWA manifest so the site is add-to-homescreen eligible."

    New-WorkItem -Type "User Story" -Priority "Low" -ParentId $f4_2 -StoryPoints 2 -Tags "Technical" `
        -Title "Add apple-touch-icon and multiple favicon sizes" `
        -Description "Add apple-touch-icon.png (180x180) and favicon-32x32.png / favicon-16x16.png. Current favicon.ico only covers basic browser tabs." `
        -AcceptanceCriteria "- apple-touch-icon.png (180x180) is served at /apple-touch-icon.png`n- favicon-32x32.png and favicon-16x16.png are served and linked in <head>`n- Icon appears correctly on iOS add-to-homescreen`n- No console errors related to missing icon resources"

    New-WorkItem -Type "User Story" -Priority "Low" -ParentId $f4_2 -StoryPoints 2 -Tags "Technical" `
        -Title "Add manifest.json for PWA installability" `
        -Description "Add a minimal web app manifest so the site is add-to-homescreen eligible. theme_color and background_color should match the brand (#090c0f)." `
        -AcceptanceCriteria "- /manifest.json is present and linked via <link rel='manifest'> in <head>`n- manifest.json includes: name, short_name, icons (192x192 and 512x512 minimum), theme_color: #090c0f, background_color: #090c0f, display: standalone`n- Lighthouse PWA audit shows manifest is valid`n- No manifest parse errors in Chrome DevTools Application panel"

Write-Host ""
Write-Host "==================================================="
Write-Host " All 23 work items created across 4 Epics / 7 Features"
Write-Host "==================================================="
