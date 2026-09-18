# EchoTune PRD-5 summary and next steps

**Date:** 18 September 2026  
**Reviewed baseline:** `main` at `947ef12b444c6ca93ab9efd98a8a4472bc91c3bf` (7.4.7)

## What the five-PRD review produced

| PRD | Deliverable | Result |
|---|---|---|
| 1 - Codebase audit | `docs/audit-report.md` | 27 findings: 0 critical, 8 high, 13 medium, 6 low. No broad auto-fixes. |
| 2 - Organic growth | `docs/growth-strategy.md` | Live SEO audit, 14 ethical opportunities, 3 unsent disclosed community templates, 10 content gaps. |
| 3 - Pricing | `docs/pricing-analysis.md` | Current billing audit plus A/B/C comparison. Recommends freemium + lifetime, awaiting owner choice before implementation. |
| 4 - Email | `docs/email-deliverability.md` | Confirmed no product transactional sender. Domain mail routing/authentication is absent; no unjustified provider/DNS mutation. |
| 5 - Synthesis | this document | Prioritized owner decisions and execution sequence. |

All deliverables are in separate open pull requests. Nothing has been merged. No outbound email, forum post, social post, directory submission or editorial pitch was sent.

## Recommended execution order

### P0 - Trust, privacy and conversion blockers

1. **Remove transcript bodies from release logging.** Full dictated text currently reaches macOS Unified Logging in several local/cloud/streaming paths.
2. **Fix every dead commercial/legal link.** Make onboarding Buy use one canonical storefront; publish/route working Privacy and Terms pages.
3. **Correct privacy claims and permission copy.** Distinguish local mode from cloud transcription/AI cleanup and disclose that screen context can include app name, window title and browser URL.
4. **Secure transcript-derived persistence.** Move histories, notes, commitments and diagnostics out of plain preferences into protected storage with retention, export and full erase.
5. **Make licensing claims true.** If 1/3-device limits are sold, use Polar device activations and remote deactivation; make Keychain persistence failures explicit.

These come before promotion or monetization changes. Sending traffic to broken checkout/legal paths or stronger privacy claims would compound trust damage.

### P1 - Product/release correctness

6. Pick one trial rule: seven days, 50 uses or a clearly displayed combination. Start it at the promised point and test migration.
7. Add `PrivacyInfo.xcprivacy` based on actual required-reason APIs/data flows.
8. Align macOS minimum version, pricing, referral terms, retention claims and purchase routes across app, website and docs.
9. Add UI tests for onboarding, model setup, dictation, history, settings, purchase and permission-denied states; add external-link and privacy/logging checks to CI.
10. Fix referral configuration/disclosure or hide the feature until the backend is truly configured.

### P2 - Pricing decision and implementation

11. Choose:
   - A subscription;
   - B lifetime only;
   - C freemium + lifetime (recommended).
12. Approve the exact free/paid capability boundary and whether signed auto-updates are free.
13. Preserve all existing paid/lifetime users.
14. Implement one centralized capability/entitlement model only after the decision, then configure Polar/StoreKit and staged migration tests.

Recommended validation price/shape:

- Community: useful unlimited basic local dictation;
- Solo: £29 one-time, one Mac;
- Pro: £49 one-time, up to three Macs.

### P3 - Growth foundation, then outreach

15. Put website source/deployment under version control.
16. Publish a precise privacy architecture page and reproducible local-vs-cloud benchmark.
17. Expand sitemap with useful legal, comparison, use-case, benchmark and guide pages.
18. Submit factual listings to AlternativeTo, MacUpdate and open-source Mac lists.
19. Run a founder-disclosed Product Hunt launch.
20. Pitch Mac/voice outlets only with a real hook and evidence; review every exact outbound message first.

### P4 - Domain communications

21. Decide whether `support@`, `hi@` and `security@echotune.app` should be real receiving addresses.
22. If yes, choose the mailbox provider, publish its exact MX, verify receipt and assign monitoring ownership.
23. If sending as the domain, add provider-issued SPF/DKIM and staged DMARC.
24. Add product transactional email only when a real auth/notification flow exists. Do not create a provider simply to satisfy an outdated assumption.

## Decisions only the owner can make

| Decision | Recommended default | Why it needs the owner |
|---|---|---|
| Pricing model A/B/C | C - freemium + lifetime | Revenue model and feature boundary are business choices. |
| Free/paid capability boundary | Keep privacy, deletion, security and basic local dictation free | Product positioning and support economics. |
| Existing users | Grandfather every paid/lifetime entitlement | Changing access is a customer promise. |
| Device limits | Enforce the marketed 1/3 limits or remove the claim | Commercial policy, not merely code. |
| Website claim | “Local mode keeps audio on your Mac; optional cloud modes send to your selected provider.” | Brand promise must match actual data flow. |
| Domain mailbox provider/owners | Configure real monitored inboxes or remove addresses | Requires account, cost and ongoing responsibility. |
| Outreach text/timing | Review every exact pitch/post | External representation. |

## Dependencies that matter

- **Pricing depends on PRD-1 licensing fixes.** A paid tier cannot ship cleanly while device allocation, checkout, legal links and trial semantics are inconsistent.
- **Growth depends on PRD-1 trust fixes.** Directory/editorial traffic should not land on broken purchase/legal URLs or absolute privacy claims contradicted by optional cloud behavior.
- **Email PRD is not a product-email migration.** EchoTune has no user auth or transactional sender. Domain mailbox setup is an operational prerequisite for the support addresses already advertised.
- **Freemium supports growth.** A genuinely useful free local tier makes open-source listings, reviews and community recommendations more credible.
- **Website source ownership blocks safe direct SEO fixes.** The app repo can document issues, but production web changes need the actual deployed source/release path.

## Suggested review bundle

Review the PRs in order and comment before any merge:

1. PRD-1 audit - PR #4
2. PRD-2 growth - PR #5
3. PRD-3 pricing - PR #6
4. PRD-4 email - PR #7
5. PRD-5 synthesis - the PR containing this file

After the review, merge documentation in order or request edits. Then create separate small fix PRs for each approved P0 item. Do not combine privacy logging, checkout/legal, storage and licensing work into one change.

## Definition of the next milestone

EchoTune is ready for growth/pricing rollout when:

- no transcript content enters release logs;
- privacy/data-flow text matches every local/cloud path;
- checkout, privacy and terms URLs are live and CI-checked;
- local sensitive data has a documented retention/export/erase model;
- the approved trial/pricing/device rules are enforced and tested;
- support addresses receive mail or are removed;
- top-level UI smoke tests run in CI;
- owner-approved outreach assets are ready, with nothing sent automatically.
