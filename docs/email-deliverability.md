# EchoTune PRD-4 transactional email deliverability audit

**Date:** 18 September 2026  
**Outcome:** The stated password-reset/signup-email problem does not exist in this codebase because EchoTune has no user authentication or transactional email sender. No provider migration or DNS mutation was justified. Deliverability score: **not applicable (no message can be sent from the product).**

## Executive finding

EchoTune is a local macOS app licensed through Polar or StoreKit. The repository contains no signup/login system, password reset, email verification, SMTP client, email API SDK, server email function, or email templates. The only email-related app actions open the user's own mail client with `mailto:` links for support, feedback or referrals. Therefore there is no EchoTune-owned transactional stream to “get out of spam,” and changing to Postmark/SES/Resend would add unused infrastructure.

The live domain has a separate, serious communications gap: `echotune.app` currently publishes **no MX record and no SPF, DKIM or DMARC TXT records**, while the app/docs direct people to `support@echotune.app`, `hi@echotune.app` and `security@echotune.app`. Those addresses cannot be assumed to receive mail, and the domain is not ready to send authenticated mail.

## Current-state audit

| Area | Finding | Evidence |
|---|---|---|
| Product auth | None. EchoTune has local trial/license state; Polar and StoreKit own purchase identity. | Static search across all tracked source, server/config and workflow files. |
| Product-sent email | None. No SMTP/provider SDK/API, server send function or templates. | Static search for SMTP, Resend, Postmark, SES, SendGrid, Mailgun, verification/reset/signup terms. |
| User-initiated mail | `MainDashboardView`, `HelpFeedbackView` and `ReferralManager` create `mailto:` URLs. The user's configured mail provider sends these, not EchoTune. | `MainDashboardView.swift:358`, `HelpFeedbackView.swift:162`, `ReferralManager.swift:163-183`. |
| Public recipient addresses | Docs/code name `support@echotune.app`, `hi@echotune.app`, and `security@echotune.app`. | FAQ, guide, troubleshooting, legal/security docs and app views. |
| Domain mail routing | No MX record returned for `echotune.app`. | Live DNS query on audit date. |
| SPF | No apex TXT/SPF record returned. | Live DNS query. |
| DMARC | No TXT record returned at `_dmarc.echotune.app`. | Live DNS query. |
| DKIM | No selectors can be identified because no sending provider/config exists. Common-selector probes returned none; absence is expected until a provider supplies a selector. | Live DNS plus repository/provider audit. |
| Website host | Netlify. This says nothing about mail service. | Live HTTPS headers. |
| Reputation, bounces, complaints | No sending provider/account or sending stream exists to inspect. | Not applicable. |

## Root cause

There is no deliverability defect in application email code. There is **no application email code**.

If users report missing license receipts or keys, investigate the actual sender separately:

- Polar checkout/receipt/license delivery for direct purchases;
- Apple receipt and StoreKit purchase state for App Store purchases.

Those messages use provider-controlled sending domains and dashboards. The app repository and apex `echotune.app` DNS cannot establish their current bounce, complaint or authentication state.

## Fix applied

No email provider, DNS or product code change was applied because:

1. no EchoTune transactional sender exists;
2. the repository does not own the live domain DNS/deployment configuration;
3. selecting a provider and changing DNS creates cost, external state and operational responsibility;
4. sending a test message requires a real authorized sending account and recipient.

Inventing a sender just to satisfy this PRD would be the wrong fix.

## Required operational fix before publishing support addresses

This is separate from transactional deliverability and should be completed by the domain owner:

1. Choose a receiving mailbox/forwarding provider for `support@`, `hi@` and `security@`.
2. Publish that provider's MX records.
3. Verify inbound delivery to each published address and define who monitors it.
4. If staff will send as `@echotune.app`, publish the provider's exact SPF and DKIM records.
5. Publish DMARC gradually:
   - start with `p=none`, a dedicated aggregate-report mailbox and alignment review;
   - move to `quarantine`/`reject` only after every legitimate sender is authenticated.
6. Remove or replace public addresses until inbound receipt is proven.

Do not copy generic DNS values from this report. The exact MX/SPF/DKIM records come from the chosen provider and must be verified in its control panel.

## If product email is added later

Use a transactional provider only when a real product flow needs it. For low-volume auth/receipt notifications:

- **Postmark:** strong transactional focus and clear message streams; good when operational simplicity matters.
- **Resend:** straightforward developer API; good for a small web/backend stack.
- **Amazon SES:** low unit cost but more setup, monitoring and reputation work.

At that point:

- send from a dedicated subdomain such as `notify.echotune.app`;
- configure provider-issued DKIM, scoped SPF and aligned DMARC;
- send multipart HTML/plain text with stable From/Reply-To identities;
- process bounces and complaints;
- never send license keys, transcripts or sensitive context in logs;
- test actual signup/reset messages to controlled inboxes and a deliverability analyzer;
- record the analyzer URL/score and inbox placement before and after.

## Before/after deliverability test

| Metric | Before | After |
|---|---:|---:|
| Mail-tester-style score | N/A - no sender/message | N/A - no sender/message was created |
| Product transactional send | Not possible | Not changed |
| SPF/DKIM/DMARC | Absent/unconfigured | Not changed without provider/DNS authority |
| Inbound support delivery | Unverified; no MX | Unchanged; requires mailbox owner action |

A fabricated score would be misleading. A real score is possible only after there is an authorized sender and a real test message.

## Completion statement

**Root cause identified:** EchoTune has no transactional email system; the PRD's assumed signup/reset flow does not match the app. The domain also lacks inbound mail routing and email authentication despite publishing support addresses.  
**Fix applied:** none, because no safe or justified code/provider/DNS mutation exists in this repository.  
**Before/after score:** N/A / N/A.
