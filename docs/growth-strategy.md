# EchoTune PRD-2 organic growth strategy

**Date:** 18 September 2026  
**Rule:** white-hat, disclosed, value-first activity only. No outreach or posting was sent during this PRD.

## Executive summary

EchoTune has a solid single-page technical SEO base: a unique title/description, canonical, Open Graph/Twitter cards, `SoftwareApplication` JSON-LD, responsive layout, HTTPS, `robots.txt`, and `sitemap.xml`. The main weakness is not metadata. It is a very thin indexable footprint: the sitemap contains only the homepage, the site has no crawlable docs/comparison/use-case pages, and three user-critical URLs are 404s. Fix those trust gaps first, then earn links through open-source/Mac app listings and specific editorial pitches built around EchoTune's strongest angle: open-source, local-first macOS dictation with optional bring-your-own-key cloud engines.

## On-page SEO audit

| Area | Current state | Action |
|---|---|---|
| Title and description | Good unique homepage title and description. | Keep; test a clearer intent phrase such as “Private voice dictation for Mac” in future Search Console experiments. |
| Canonical/social metadata | Canonical, Open Graph and Twitter card are present. | Keep and validate image dimensions on each release. |
| Header hierarchy | One clear hero H1 and structured section headings on the live homepage. | Keep one H1 per future page. |
| Image accessibility | The primary social image has alt metadata; decorative assets are mostly CSS/SVG. | Add contextual alt text to any future screenshots; leave decorative graphics empty. |
| Structured data | `SoftwareApplication` JSON-LD includes OS and GBP offers. | Add `softwareVersion`, `downloadUrl`, `license`, `applicationSubCategory`, and aggregate rating only if real review data exists. Do not fabricate ratings. |
| Mobile | Responsive CSS and viewport metadata are present. | Add mobile visual regression checks to release CI. |
| Speed | Static HTML/CSS is favorable, but no field/Core Web Vitals evidence is in the repo. | Connect Search Console and PageSpeed monitoring; optimize the large hero/OG assets only if field data shows a problem. |
| Sitemap | Valid but contains only `https://echotune.app/`. | Expand after real, useful pages exist: privacy, terms, download/release notes, comparison, use cases and guides. |
| Robots | Live and permissive; points to sitemap. | Keep. |
| Trust/conversion links | `/checkout`, `/privacy`, `/terms` return 404. | Publish legal pages and make every purchase CTA point to the canonical Polar storefront. This is a prerequisite for outreach. |
| Claim consistency | Homepage says “Your voice never leaves your Mac,” while optional cloud engines send audio/text. | Make the hero claim precise: local mode stays on-device; cloud modes send data to the selected provider. Trust matters more than an absolute slogan. |
| Repository/site ownership | Website source is not in this repository, so safe direct site fixes cannot be made here. | Put the site source under version control and add a link checker/deploy preview before changing production. |

### Direct fixes in this PRD

None. The live website source is not present in `vishvivero/EchoTune`, and production changes without its source/deployment path would be unsafe. The exact fixes are specified above for an owner-approved website change.

## Backlink and discovery opportunities

Authority scores are intentionally omitted. Third-party “DA” numbers are proprietary estimates, not ground truth. Relevance, editorial standards and an accessible submission route are better prioritization signals.

| Priority | Opportunity | Why it fits | Needed action | Source |
|---:|---|---|---|---|
| 1 | Product Hunt | Credible launch/discovery page with founder attribution. | Prepare a transparent maker launch after the broken purchase/legal links are fixed. | https://www.producthunt.com/launch |
| 2 | AlternativeTo | High-intent users compare alternatives to MacWhisper, Superwhisper and Wispr Flow. | Submit EchoTune as the maker; use accurate open-source/local-first attributes and comparison screenshots. | https://alternativeto.net/faq/ |
| 3 | MacUpdate | Established Mac software catalog with explicit submission guidance. | Submit signed/notarized build, homepage, version details and support contact. | https://www.macupdate.com/help/submit-app |
| 4 | awesome-mac | Curated open-source Mac software list, native fit. | Open a small PR following its contribution format; describe EchoTune without marketing copy. | https://github.com/jaywcjlove/awesome-mac |
| 5 | Indie Goodies open-source Mac apps | Exact open-source Mac app audience. | Request inclusion with GPL repo, screenshots and privacy architecture. | https://indiegoodies.com/awesome-open-source-mac-apps |
| 6 | Mac Apps Library | Dedicated Mac app directory with a submission route. | Submit only after canonical download/legal pages are live. | https://www.macappslibrary.com/submit |
| 7 | Discover Mac Apps | Dedicated discovery catalog and direct form. | Submit concise product facts, current compatibility and notarized download. | https://discovermacapps.com/submit |
| 8 | TryMacApps | Mac app discovery with direct submission. | Submit a founder-labeled listing and link to release notes. | https://www.trymacapps.com/submit |
| 9 | SaaSHub | Comparison/discovery profile useful for “alternatives” searches. | Create one accurate product profile, not duplicate/spam variants. | https://www.saashub.com/services/submit |
| 10 | 9to5Mac tips | Editorial opportunity if there is a genuine release story. | Pitch one newsworthy angle: open-source/private dictation and a measurable local-vs-cloud benchmark. Do not ask for a backlink. | https://9to5mac.com/contact/ |
| 11 | MacStories | Strong fit for a polished Mac-native workflow story. | Pitch a concise founder note around menu-bar UX, accessibility insertion and local-first architecture after a major release. | https://www.macstories.net/about/ |
| 12 | Voice Tech Podcast | Domain-relevant voice technology audience. | Pitch a technical founder conversation: reliable on-device streaming transcription on consumer Macs. | https://voicetechpodcast.com/ |
| 13 | Everyday AI guest pitch | Explicit guest/use-case submission route. | Pitch a real workflow and benchmarks, clearly identifying Vishnu as EchoTune's founder. | https://www.youreverydayai.com/pitch/ai-use-case/ |
| 14 | PCMag speech-to-text roundup | High-intent editorial comparison. | Send a short review offer with signed build, privacy matrix, pricing and test methodology. No claims of entitlement to inclusion. | https://www.pcmag.com/picks/best-speech-to-text-apps-and-tools |

### Outreach order

1. Fix trust/conversion 404s and privacy wording.
2. Publish two durable resources: a transparent privacy architecture page and a reproducible local dictation benchmark.
3. Submit factual directory listings (AlternativeTo, MacUpdate, open-source lists).
4. Launch on Product Hunt with founder disclosure.
5. Pitch editorial/podcast outlets only when there is a genuine hook or data asset.

## Draft community templates - do not send without review

### Helpful answer about private Mac dictation

> Founder of EchoTune here, so take the recommendation with that context. If privacy is the main requirement, the useful distinction is not “AI vs no AI,” but where inference runs. Apple Dictation, MacWhisper-style local tools and cloud-first tools make different tradeoffs. Check whether audio leaves the Mac, whether transcript history is retained, and whether a cloud model can be disabled completely. I built EchoTune to make the local path explicit and open-source, but the same checklist is useful whichever app you choose: test your own microphone/accent, inspect the privacy controls, and verify offline behavior before paying.

### Useful answer about building a local voice workflow

> I build an open-source macOS dictation app, and the biggest reliability lesson has been that model accuracy is only half the problem. The workflow also needs a predictable hotkey, a safe clipboard fallback when Accessibility insertion fails, visible model/privacy state, and recoverable history. For anyone evaluating tools, I would test all four rather than comparing demo transcripts alone. If useful, I can share the test script I use. Affiliation: EchoTune founder.

### Release/showcase post

> I built EchoTune, an open-source macOS menu-bar dictation app. Local models keep audio on the Mac; optional cloud engines are clearly separated and use the user's own provider key. I have published the source and a reproducible benchmark because “private” and “fast” should be testable claims. I would value feedback on setup friction and accuracy across accents more than launch upvotes. [link only where community rules allow]

These should be posted only in threads where they answer the actual question, with affiliation visible and each community's self-promotion rules checked first.

## Content gaps worth building

1. **Private voice dictation on Mac: a data-flow checklist** - linkable privacy architecture with diagrams for local and cloud modes.
2. **Mac dictation benchmark: Apple Dictation vs WhisperKit vs Groq/Deepgram** - reproducible audio set, word error rate, latency and hardware.
3. **How to use local Whisper dictation offline on macOS** - intent match plus setup guide.
4. **Best dictation workflow for developers on Mac** - code vocabulary, terminal/editor insertion and correction patterns.
5. **Voice typing for ADHD and repetitive strain** - accessibility-led workflows, reviewed by practitioners rather than medical claims.
6. **Meeting transcription without a meeting bot** - explain system/mic capture, consent and local processing.
7. **How much RAM does each local speech model need on Apple Silicon?** - model/hardware matrix.
8. **Bring-your-own-key voice transcription: cost and privacy tradeoffs** - current provider costs with update date and calculators.
9. **Open-source alternatives to cloud-first Mac dictation apps** - fair comparison methodology and explicit founder disclosure.
10. **Multilingual Mac dictation guide** - tested languages, auto-detect limits and per-language model recommendations.

Every comparison page should publish methodology, date-stamp prices/results, disclose the founder relationship, and link to competitors fairly.

## Measurement

Track monthly rather than chasing raw submission counts:

- non-brand organic clicks and impressions by landing page;
- referring domains that send engaged visits;
- directory/editorial conversion to notarized downloads;
- activation rate after download;
- ranking and click-through for “private dictation mac,” “offline voice to text mac,” and use-case pages;
- broken external links and sitemap coverage in CI.

## Sources

Official submission and editorial pages were preferred over backlink-list blogs:

- https://www.producthunt.com/launch
- https://alternativeto.net/faq/
- https://www.saashub.com/services/submit
- https://www.macupdate.com/help/submit-app
- https://www.macappslibrary.com/submit
- https://discovermacapps.com/submit
- https://www.trymacapps.com/submit
- https://github.com/jaywcjlove/awesome-mac
- https://indiegoodies.com/awesome-open-source-mac-apps
- https://9to5mac.com/contact/
- https://www.macstories.net/about/
- https://voicetechpodcast.com/
- https://www.youreverydayai.com/pitch/ai-use-case/
- https://www.pcmag.com/picks/best-speech-to-text-apps-and-tools
- https://echotune.app/
- https://echotune.app/robots.txt
- https://echotune.app/sitemap.xml

**Outbound action confirmation:** no directory submission, email, community post, social post or editorial pitch was sent.
