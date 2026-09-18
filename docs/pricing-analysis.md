# EchoTune PRD-3 pricing analysis

**Date:** 18 September 2026  
**Status:** Analysis complete, awaiting the owner's decision on A/B/C. No billing code changed.

## Recommendation

Choose **C: a real free tier plus paid lifetime licenses**, keeping EchoTune's open-source/local-first position while making the signed-build value clear.

Recommended shape for validation:

- **Community - free:** unlimited basic local dictation with one efficient bundled/local model, clipboard fallback, core history, and build-from-source freedom.
- **Solo - £29 one-time:** all local models, AI cleanup/BYO-key providers, meeting mode, automations, advanced history/export, automatic updates and one Mac.
- **Pro - £49 one-time:** same product on up to three Macs, positioned for power users.

This is closest to the code and current live site, has the lowest migration risk, and creates a durable evaluation path. EchoTune cannot credibly monetize a seven-day hard stop while the same GPL code can be built free and while the Buy link is broken. A useful free tier makes the paid product about convenience, polish, updates and support rather than artificial lockout.

Before implementation, validate willingness to pay with download-to-activation data and 10-15 user interviews. Do not silently convert existing licensed users or remove access.

## Current state in code

### Distribution and entitlement paths

| Path | Current behavior | Risk |
|---|---|---|
| Direct signed build | `LicenseManager` validates Polar license keys through the public customer-portal endpoint; Keychain caches the key/metadata. | It validates but does not use device activations, so 1/3-device claims are not enforced. Onboarding purchase route is a live 404. |
| App Store build | Conditional `StoreKitManager` loads non-consumable product `com.echotune.EchoTune.pro` and verifies StoreKit transactions locally. | Product-load failures leave an indefinite spinner; `/privacy` and `/terms` links are live 404s. |
| Open source | GPL-3.0 repo and releases can be used/built free. | A hard paywall is easy to remove in self-built copies; paid value must be signed builds, updates, support and convenience. |
| Trial | `LicenseManager` has a seven-day Keychain anchor and a 50-use counter. Gating checks time only. | Trial starts at manager initialization rather than the promised post-onboarding transition; the 50-use counter is not enforced. |

### Current prices and contradictions

- Live site structured data and `LicenseInfo.swift` advertise **£29.99 Individual / £49.99 Pro** one-time.
- FAQ and user guide still say **$10 one-time**.
- App Store price is loaded from StoreKit and may differ by storefront.
- Settings describes a lifetime license; referral code describes time extensions, creating a mismatch between “lifetime” and bonus days.

PRD-1 already documents the necessary licensing, checkout, privacy and claim fixes. Pricing implementation should not start until those assumptions and the target model are approved.

## Options

| Option | Example shape | Advantages for EchoTune | Downsides | Build effort from PRD-1 |
|---|---|---|---|---|
| **A. Subscription** | Free trial; £7.99/mo or £69/yr Pro; optional team tier later | Recurring revenue funds ongoing model/OS work; familiar for cloud-heavy competitors; easier to add hosted features later. | Poor fit for a GPL/local-first product with low marginal cost; strongest user resistance in Mac utilities; requires subscription lifecycle, grace periods, cancellation, webhook state and existing-user policy. | **High.** Replace/extend Polar and StoreKit entitlement models, robust server state, offline grace, migration and restore tests. Must first fix device and privacy issues. |
| **B. Lifetime only** | £29 Solo / £49 Pro, seven-day full trial | Already reflected on live site and most code; simple promise; low ongoing billing complexity; strong fit with local/open-source positioning. | No recurring revenue; trial cliff limits organic adoption; revenue depends on continuous acquisition/upgrades; current device enforcement is incomplete. | **Low-medium.** Repair checkout, Polar activations, trial start/rule, legal URLs and product-copy consistency. |
| **C. Freemium + lifetime paid tier** | Basic local dictation free; Solo £29; Pro £49 | Best alignment with GPL and product-led growth; users can verify local performance/privacy before paying; creates review/community adoption; preserves simple lifetime purchase. | Requires a careful feature boundary; free tier must be useful but paid value obvious; entitlement checks need centralization; risk of support load from free users. | **Medium.** Define feature matrix, central entitlement service and migration; then reuse Polar/StoreKit lifetime products after PRD-1 fixes. |

## Competitive context

Prices below were checked against current official product/help pages on 18 September 2026. They are directional, not a reason to copy competitors.

| Product | Current public model | Relevance |
|---|---|---|
| MacWhisper | Free tier; Pro **€64 one-time** with lifetime updates. | Closest proof that free + lifetime can work for a local Mac transcription tool. https://www.macwhisper.com/ |
| VoiceInk | One-time Mac licenses displayed at **$25 / $39 / $49** for 1/2/3 devices on its official pricing page at check time. | Open-source/local-first and near-identical device-tier logic; EchoTune's live £29.99/£49.99 sits in range. https://tryvoiceink.com/pricing |
| Superwhisper | **$8.49/mo, $84.99/yr, $249.99 lifetime**, same paid features across billing frequencies. | Shows a premium hybrid model, justified by broad platform/cloud capability. https://superwhisper.com/docs/get-started/sw-pro |
| Wispr Flow | Free usage; Pro **$15/user/mo or $144/yr** in USD/GBP/EUR, with team/enterprise tiers. | Cloud-first recurring benchmark, but different costs/compliance and therefore not a direct price anchor. https://wisprflow.ai/pricing |
| Monologue | Monthly and annual billing for dictation/voice notes/meetings. | Supports subscription viability when cloud meeting services are central; EchoTune currently emphasizes local/BYO-key operation. https://www.monologue.to/pricing |

## Proposed feature boundary for option C

| Capability | Community | Solo / Pro |
|---|---:|---:|
| Basic push-to-talk local dictation | Yes, unlimited | Yes |
| One efficient local model | Yes | All supported local models |
| Clipboard fallback | Yes | Yes |
| Short searchable history | Yes | Full retention controls/export |
| Custom vocabulary | Limited | Full |
| BYO-key cloud transcription | No or limited trial | Yes |
| AI enhancement/custom prompts | No or limited trial | Yes |
| Meeting mode / structured notes | No | Yes |
| Power modes, triggers, advanced automations | No | Yes |
| Automatic signed updates | Optional strategic choice | Yes |
| Device count | One | Solo one / Pro three |

Keep privacy and correctness capabilities free. Do not paywall data deletion, security updates, accessibility fallback, or clear cloud disclosures.

## Implementation plan after approval

1. **Fix PRD-1 prerequisites:** canonical checkout/legal URLs, transcript logging, privacy copy, Keychain write errors, trial start/rule and Polar device activation.
2. **Create one entitlement model:** `community`, `trial`, `solo`, `pro`, with capability checks rather than scattered `isLicensed` booleans.
3. **Choose existing-user treatment:** preserve every paid/lifetime entitlement. Give existing free/trial users clear notice before changing limits.
4. **Configure Polar and StoreKit products:** server/store configuration is source of truth; do not hardcode stale displayed prices.
5. **Instrument privacy-safe funnel events:** download, onboarding complete, first successful dictation, paywall view, checkout open, activation; no transcript content.
6. **Test:** fresh install, offline launch, trial expiry, purchase/restore, refund/revocation, device limit, migration, checkout failure and App Store product-load failure.
7. **Release in stages:** beta cohort, measure conversion/support, then public rollout.

## Decision needed

Pick one:

- **A - subscription**
- **B - lifetime only**
- **C - freemium + lifetime** (recommended)

Also confirm the free/paid feature boundary and whether automatic signed updates remain available to Community users. These are business decisions, so implementation waits for explicit approval.
