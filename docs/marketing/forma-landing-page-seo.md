# Forma Landing Page SEO/GEO Package

## Purpose

This document provides the full copy, metadata, keyword targeting, schema markup, FAQ, and implementation notes for a PolyphasicDevs landing page for **Forma** based on how the app works in the current codebase.

## Product Truths To Preserve

These points are based on the current app code and should not be overstated on the landing page:

- The primary free feature is **manual export**.
- Export formats currently supported are **CSV**, **Excel (.xlsx)**, and **JSON**.
- The exporter currently generates the **most recent 30 days** of supported Apple Health data, not full-history export.
- Users choose their own destination folder and exports stay in the location they select.
- Automatic midnight export is currently a **premium** feature.
- Premium also gates the in-app dashboard, insights, records/goals, and AI coach experience.
- The AI coach is live via a backend proxy and should be positioned as an advanced add-on, not the main reason to download.

If you want to rank aggressively for queries like `export all Apple Health data` or `Apple Health complete export to CSV`, the product should first support a wider or user-selectable export range.

## Research Snapshot

### What the SERP angle should be

The strongest search intent is not generic health app discovery. It is:

- `Apple Health export to CSV`
- `Apple Health export to Excel`
- `Apple Health export JSON`
- `export Apple Health data`
- `Apple Health data export app`
- `HealthKit export CSV`

### Why this angle is defensible

- Apple’s own export is still described as **XML format**, which creates a clean positioning gap for a simpler export experience.
- Existing competitors already lead with the same narrative: easier export, AI-ready files, and privacy/local processing.
- PolyphasicDevs already has working robots and sitemap coverage, so this page can slot cleanly into the current site structure.

### External references used

- Apple Support: [Share your health and fitness data in XML format](https://support.apple.com/et-ee/guide/ipod-touch/iph5ede58c3d/ios)
- AI Health Export competitor page: [AI Health Export](https://www.aihealthexport.com/)
- App Store competitor listing: [Health Auto Export - JSON+CSV](https://apps.apple.com/gb/app/health-auto-export-json-csv/id1115567069)
- Current site baseline: [Polyphasic Developers](https://polyphasicdevs.com/)
- Current robots: [polyphasicdevs.com/robots.txt](https://polyphasicdevs.com/robots.txt)
- Current sitemap: [polyphasicdevs.com/sitemap.xml](https://polyphasicdevs.com/sitemap.xml)

## Recommended URL Strategy

Primary landing page:

- `https://polyphasicdevs.com/forma/`

Optional support pages to improve topical authority later:

- `/forma/export-apple-health-to-csv/`
- `/forma/apple-health-export-vs-xml/`
- `/forma/apple-health-to-excel/`
- `/forma/apple-health-json-export/`

## Keyword Strategy

### Primary keyword

- `Apple Health export app`

### Primary secondary keywords

- `Apple Health export to CSV`
- `Apple Health export to Excel`
- `Apple Health JSON export`
- `export Apple Health data`
- `HealthKit export CSV`

### Supporting semantic terms

- Apple Health data export
- Apple Watch data export
- iPhone health data export
- private health data export
- on-device health export
- export Apple Health for spreadsheets
- export Apple Health for analysis

### Keywords to avoid pushing hard until product changes

- export all Apple Health data
- full Apple Health history export
- unlimited export range

## Recommended Metadata

### SEO Title

`Forma: Free Apple Health Export to CSV, Excel & JSON`

### Meta Description

`Export Apple Health data to CSV, Excel, or JSON with Forma. Free iPhone app with private local export, chosen folder saving, and premium AI coach for deeper analysis.`

### Canonical

`https://polyphasicdevs.com/forma/`

### Open Graph Title

`Forma | Free Apple Health Export to CSV, Excel & JSON`

### Open Graph Description

`A simple way to export Apple Health data from your iPhone to CSV, Excel, or JSON. Free export first. Premium AI coach and deeper analysis when you want more.`

### Suggested Social Image Copy

- Headline: `Export Apple Health Data For Free`
- Subhead: `CSV, Excel, JSON`
- Support line: `Private local export on iPhone`

### Suggested Image Path

- `https://polyphasicdevs.com/assets/images/forma/forma-og.jpg`

### Twitter Card

- `summary_large_image`

### Suggested meta block

```html
<script>
  window.PAGE_META = {
    title: "Forma: Free Apple Health Export to CSV, Excel & JSON",
    description: "Export Apple Health data to CSV, Excel, or JSON with Forma. Free iPhone app with private local export, chosen folder saving, and premium AI coach for deeper analysis.",
    canonical: "/forma/"
  };
</script>
```

## GEO Summary Block

This short answer-first block should appear high on the page, ideally directly under the hero.

> Forma is an iPhone app that lets you export Apple Health data to CSV, Excel, or JSON for free. It is built for people who want a cleaner, more usable export than Apple’s default XML export, while keeping their data private and saved to a folder they choose. Premium adds AI coaching, insights, and deeper analysis, but the free export is the core reason to use the app.

## Full Landing Page Copy

### Eyebrow

`Apple Health export app`

### H1

`Export Apple Health data to CSV, Excel, or JSON for free`

### Hero subheading

`Forma gives you a simple, private way to turn Apple Health data into files you can actually use. Choose a folder, pick a format, and export recent health data from your iPhone in a few taps.`

### Hero supporting bullets

- `Free export is the main feature`
- `CSV, Excel, and JSON output`
- `Saved to the folder you choose`
- `Premium adds AI coaching and deeper analysis`

### Primary CTA

`Download Forma`

### Secondary CTA

`See How Export Works`

## Section 1: The core value proposition

### H2

`Apple gives you XML. Forma gives you usable files.`

### Body

`If you have ever tried exporting health data from Apple Health, you already know the problem: the default export is not built for normal people. Forma focuses on the one thing most users actually want: a clean export they can open, inspect, share, or work with immediately.`

`With Forma, free users can export supported Apple Health data as CSV, Excel, or JSON directly from their iPhone. No account setup. No forced cloud dashboard. No making export the premium upsell.`

## Section 2: How it works

### H2

`How Forma works`

### Step 1 heading

`Connect Apple Health`

### Step 1 body

`Grant read access to the Apple Health categories and metrics Forma supports, including steps, distance, active energy, heart rate, resting heart rate, blood oxygen, respiratory rate, body measurements, sleep, mindful sessions, and workouts.`

### Step 2 heading

`Choose your export folder`

### Step 2 body

`Pick the folder where you want your export saved. Forma writes files to the location you choose, so you stay in control of where your data goes.`

### Step 3 heading

`Pick CSV, Excel, or JSON`

### Step 3 body

`Select the format that fits your workflow. CSV is ideal for spreadsheets and quick analysis. Excel gives you a structured workbook. JSON is useful when you want developer-friendly structured data.`

### Step 4 heading

`Export in a tap`

### Step 4 body

`Run the export manually for free whenever you need it. Premium users can also enable automatic midnight export for a hands-off workflow.`

## Section 3: Feature split

### H2

`Free first. Premium when you want more than export.`

### Free heading

`Free`

### Free body

- `Manual Apple Health export`
- `CSV, Excel, and JSON formats`
- `Folder-based local saving`
- `Simple private workflow with no account required`

### Premium heading

`Premium`

### Premium body

- `Automatic midnight export`
- `Dashboard views and trend analysis`
- `Insight cards and data summaries`
- `Records and goal tracking`
- `AI coach for tailored health and training guidance`

### Premium positioning paragraph

`Premium should be presented as the upgrade for people who want interpretation, context, and ongoing analysis. The export itself should remain the lead value proposition and the clearest reason to download.`

## Section 4: Why users download it

### H2

`Built for people who want their Apple Health data out`

### Body

`Forma is for people who do not want their health data trapped inside an app interface. Some want a spreadsheet. Some want a cleaner export for personal analysis. Some want structured files they can use in their own systems. Others want the export first and AI guidance second.`

`The app is especially relevant for:`

- `people who want Apple Health data in CSV instead of XML`
- `users moving health data into Excel or Numbers`
- `developers and analysts who want JSON output`
- `people who care about private, local-first export`
- `users who may later want AI coaching based on their recent health context`

## Section 5: Privacy angle

### H2

`Private by design`

### Body

`Forma reads from Apple Health only after you grant permission. It does not require an account to use the export feature. Exported files go to the folder you choose.`

`That matters because health export is a trust decision. The landing page should make that trust point explicit, early, and repeatedly.`

### Privacy bullets

- `No account required for export`
- `You choose where files are saved`
- `Built on Apple Health permissions`
- `Premium AI features are an add-on, not the default requirement`

## Section 6: Premium AI section

### H2

`Want more than a file export? Upgrade for coaching and analysis.`

### Body

`Forma Premium is for people who want help interpreting their data, not just exporting it. Premium unlocks deeper analysis, in-app trends, records, goals, and an AI coach grounded in your recent health context.`

`This should sit below the export sections so the page stays anchored on the main acquisition message: free export first, advanced insight second.`

## Section 7: Use cases

### H2

`What people use Forma for`

- `Export Apple Health data to CSV for spreadsheet analysis`
- `Create Excel files from recent Apple Health data`
- `Generate JSON exports for custom workflows or developer use`
- `Keep a recurring private export workflow on iPhone`
- `Get AI-guided interpretation after the export need is already solved`

## Section 8: FAQ

### H2

`Frequently asked questions`

### Q1

`Can I export Apple Health data to CSV for free?`

### A1

`Yes. Forma’s core free feature is manual export to CSV, Excel, or JSON.`

### Q2

`Is Forma an Apple Health export app or an AI coach app?`

### A2

`It should be positioned first as an Apple Health export app. The AI coach and deeper analysis are premium features for users who want more than export.`

### Q3

`Where are my files saved?`

### A3

`Forma saves exports to the folder you choose, so you control where your exported files live.`

### Q4

`Does Forma replace Apple Health?`

### A4

`No. Forma works with Apple Health by reading supported HealthKit data and turning it into more usable exports and premium analysis features.`

### Q5

`What formats does Forma support?`

### A5

`Forma supports CSV, Excel, and JSON export formats.`

### Q6

`Is the export feature the main reason to download Forma?`

### A6

`Yes. The export feature should be the lead message on the landing page because it is the clearest free value and the main driver for download intent.`

### Q7

`Does Forma export all Apple Health history?`

### A7

`Not in the current build. The exporter currently generates a recent 30-day export window for supported data types. If broader history becomes available later, this answer and the page copy should be updated at the same time.`

## Recommended On-Page SEO Structure

- One H1 only.
- Use the exact phrase `Apple Health export` in the H1, intro paragraph, at least one H2, and FAQ.
- Mention `CSV`, `Excel`, and `JSON` in visible body copy, not just metadata.
- Put the answer-first GEO block near the top.
- Keep paragraphs short and scannable.
- Include a visual comparison block: `Apple XML export` vs `Forma CSV / Excel / JSON export`.

## Suggested Comparison Block Copy

### H2

`Forma vs Apple’s default export`

| Topic | Apple Health export | Forma |
|---|---|---|
| Output | XML | CSV, Excel, JSON |
| Usability | Technical and hard to work with | Ready for spreadsheets and structured use |
| Workflow | Generic export | Export-focused experience |
| File destination | Share/export flow | Saved to folder you choose |
| Analysis layer | None | Premium insights and AI coach |

## JSON-LD Schema

### SoftwareApplication schema

```json
{
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "SoftwareApplication",
      "@id": "https://polyphasicdevs.com/forma/#app",
      "name": "Forma",
      "applicationCategory": "HealthApplication",
      "operatingSystem": "iOS",
      "description": "Forma is an iPhone app that lets users export Apple Health data to CSV, Excel, or JSON and upgrade for AI coaching and deeper analysis.",
      "url": "https://polyphasicdevs.com/forma/",
      "publisher": {
        "@type": "Organization",
        "name": "Polyphasic Developers",
        "url": "https://polyphasicdevs.com/"
      },
      "featureList": [
        "Free Apple Health export",
        "CSV export",
        "Excel export",
        "JSON export",
        "Folder-based saving",
        "Premium AI coach",
        "Premium insights",
        "Automatic midnight export"
      ]
    },
    {
      "@type": "WebPage",
      "@id": "https://polyphasicdevs.com/forma/#webpage",
      "url": "https://polyphasicdevs.com/forma/",
      "name": "Forma: Free Apple Health Export to CSV, Excel & JSON",
      "description": "Export Apple Health data to CSV, Excel, or JSON with Forma. Free export first, with premium AI coach and deeper analysis available when needed.",
      "isPartOf": {
        "@id": "https://polyphasicdevs.com/#website"
      },
      "about": {
        "@id": "https://polyphasicdevs.com/forma/#app"
      }
    }
  ]
}
```

### FAQPage schema

```json
{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
    {
      "@type": "Question",
      "name": "Can I export Apple Health data to CSV for free?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Yes. Forma’s core free feature is manual export to CSV, Excel, or JSON."
      }
    },
    {
      "@type": "Question",
      "name": "What formats does Forma support?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Forma supports CSV, Excel, and JSON export formats."
      }
    },
    {
      "@type": "Question",
      "name": "Where are my files saved?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Forma saves exports to the folder you choose, so you control where your exported files live."
      }
    },
    {
      "@type": "Question",
      "name": "Does Forma export all Apple Health history?",
      "acceptedAnswer": {
        "@type": "Answer",
        "text": "Not in the current build. The exporter currently generates a recent 30-day export window for supported data types."
      }
    }
  ]
}
```

## Suggested Internal Links

Add links from:

- homepage or work page to `/forma/`
- privacy policy to the Forma page
- Forma page to the app privacy policy
- Forma page to App Store download

Recommended anchor text variations:

- `Apple Health export app`
- `export Apple Health to CSV`
- `Forma health data export`
- `Apple Health export for iPhone`

## Technical Implementation Notes For PolyphasicDevs

- The site already uses a `window.PAGE_META` pattern. Reuse it for this page.
- The site already serves a valid `robots.txt` and `sitemap.xml`.
- Because the current `robots.txt` uses `User-agent: *` with `Allow: /`, AI crawlers should already be permitted unless blocked elsewhere.
- Include the page in the sitemap as soon as it ships.
- Add the JSON-LD directly in the HTML head or server-rendered page output.
- Use a descriptive static OG image instead of relying on a generic site-wide image.

## Recommended CTA Copy Variants

- `Download Forma`
- `Get the free export app`
- `Export Apple Health data now`

## Copy To Avoid

Do not publish claims like these until the product supports them:

- `Export your full Apple Health history`
- `Unlimited export range on free`
- `Export everything Apple Health stores`
- `Free AI coach`
- `No premium gating for analysis`

## Recommended Next SEO Moves After Launch

1. Publish a supporting article targeting `Apple Health XML export vs CSV`.
2. Publish a supporting article targeting `How to export Apple Health data to Excel on iPhone`.
3. Add screenshots that show the export format picker and chosen-folder workflow.
4. Add an FAQ-rich section high on the page to improve AI and rich-result pickup.
5. If the app later supports broader export ranges, immediately expand the page and supporting articles to target `export all Apple Health data`.

## Final Recommended Hero Version

Use this if you want the cleanest above-the-fold version:

### H1

`Export Apple Health data to CSV, Excel, or JSON for free`

### Subhead

`Forma is the simple iPhone app for people who want a usable Apple Health export instead of a messy XML file. Save recent health data to the folder you choose, then upgrade only if you want AI coaching and deeper analysis.`

### CTA row

- `Download Forma`
- `Learn About Premium`
