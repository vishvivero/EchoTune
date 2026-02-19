# EchoTune — Polar Tier Strategy & Implementation Plan

**Last Updated:** Feb 19, 2026 02:00 UTC  
**Status:** Strategy finalized, awaiting pricing approval + implementation

---

## The Three-Tier Narrative

Each tier tells a user story. They're not just price points—they're milestones on the user's transcription journey.

### Tier 1: Solo ($20/year or lifetime)
**The "Just Starting" Tier**
- Perfect for: Individual creatives, side hustlers, students
- Pitch: "Your thoughts, transcribed. Beautifully."
- Max devices: 1
- Features:
  - Unlimited local transcriptions (WhisperKit)
  - AI text enhancement (polish your thoughts)
  - Trigger words + Power Modes
  - Lifetime updates
  - ✨ No cloud API required (full privacy)

**Polar SKU:** `solo` | Price: `$20/year` (currently $29.99 — needs adjustment)

---

### Tier 2: Duet ($35/year or lifetime)
**The "I'm Serious" Tier**
- Perfect for: Podcasters, content creators, professionals
- Pitch: "Record once, transcribe everywhere. Cloud-powered."
- Max devices: 3
- Everything in Solo, PLUS:
  - ⚡ Cloud transcription (Groq Whisper Large-v3, 30+ languages)
  - 📊 Transcription analytics & word count
  - 🎯 Batch transcription (upload files, queue processing)
  - 🌍 Multilingual transcription + auto-detect
  - 🔗 Smart linking (reference previous transcriptions)
  - Priority support (email)

**Polar SKU:** `duet` | Price: `$35/year` | **Status: NEEDS CREATING**

---

### Tier 3: Chorus ($49/year or lifetime)
**The "Professional" Tier**
- Perfect for: Studios, teams, production houses, SaaS integrations
- Pitch: "Transcription that scales. Your AI co-pilot for audio."
- Max devices: Unlimited
- Everything in Duet, PLUS:
  - 🤖 Siri Shortcuts integration (workflow automation)
  - 🔌 Webhook support (stream transcripts to your tools)
  - 📁 Custom output templates (JSON, SRT, markdown, VTT)
  - ⚙️ API access (build on EchoTune)
  - 🚀 Early access to new models + features
  - 👥 Team access (share account across team)
  - 24/7 priority support

**Polar SKU:** `chorus` | Price: `$49/year` | **Status: NEEDS CREATING**

---

## Current Code State

**File:** `EchoTune/Models/LicenseInfo.swift`

```swift
enum LicenseTier: String, Codable {
    case solo = "Solo"  // ← Only tier implemented
    
    var maxDevices: Int {
        return 1
    }
    
    var price: String {
        return "$29.99"  // ← Incorrect price
    }
}
```

**Issues:**
1. ❌ Only `solo` case defined (missing `duet`, `chorus`)
2. ❌ Solo price is $29.99 (plan says $20)
3. ❌ No feature flags to gate Duet/Chorus features
4. ❌ No maxDevices variance by tier

---

## Implementation Roadmap

### Phase 1: Tier Model & Feature Flags (1 hour)
**In `LicenseInfo.swift`:**

```swift
enum LicenseTier: String, Codable {
    case solo = "Solo"
    case duet = "Duet"
    case chorus = "Chorus"
    
    var maxDevices: Int {
        switch self {
        case .solo: return 1
        case .duet: return 3
        case .chorus: return .max
        }
    }
    
    var price: String {
        switch self {
        case .solo: return "$20"
        case .duet: return "$35"
        case .chorus: return "$49"
        }
    }
    
    var features: [Feature] {
        // Common to all
        var all: [Feature] = [
            .unlimitedTranscriptions,
            .aiTextEnhancement,
            .triggerWords,
            .lifetimeUpdates
        ]
        
        if self >= .duet {
            all.append(contentsOf: [
                .cloudTranscription,
                .multilingualSupport,
                .batchTranscription,
                .transcriptionAnalytics,
                .prioritySupport
            ])
        }
        
        if self == .chorus {
            all.append(contentsOf: [
                .siritShortcuts,
                .webhookSupport,
                .customOutputTemplates,
                .apiAccess,
                .earlyFeatureAccess,
                .teamAccess
            ])
        }
        
        return all
    }
}

enum Feature: String, Codable {
    // Core
    case unlimitedTranscriptions
    case aiTextEnhancement
    case triggerWords
    case lifetimeUpdates
    // Duet+
    case cloudTranscription
    case multilingualSupport
    case batchTranscription
    case transcriptionAnalytics
    case prioritySupport
    // Chorus only
    case siritShortcuts
    case webhookSupport
    case customOutputTemplates
    case apiAccess
    case earlyFeatureAccess
    case teamAccess
}
```

**Requires:** Vish approval on pricing

---

### Phase 2: Polar SKU Creation (30 min)
**On Polar.sh Dashboard** `https://polar.sh/dashboard/helixnotus/products`

1. Create **Duet** product
   - Pricing: $35 USD/year (or other currencies)
   - Checkout: `https://buy.polar.sh/[checkout_link_for_duet]`
   
2. Create **Chorus** product
   - Pricing: $49 USD/year
   - Checkout: `https://buy.polar.sh/[checkout_link_for_chorus]`

3. Document SKU IDs in EchoTune `Secrets.swift` or `Constants.swift`

**Requires:** Vish access to Polar dashboard

---

### Phase 3: Feature Gating (2-3 hours)
**Locations that need tier checks:**

| Feature | File | Line | Action |
|---------|------|------|--------|
| Cloud Transcription | `AIEnhancementEngine.swift` | ~150 | Add `guard license.tier >= .duet` |
| Multilingual Picker | `AudioManager.swift` | ~200 | Gate language selector |
| Batch Upload | `MainDashboardView.swift` | TBD | Hide batch button for Solo |
| Webhooks | `WebhookService.swift` (NEW) | — | Chorus only |
| API Access | `APIGateway.swift` (NEW) | — | Chorus only, rate-limit by tier |
| Siri Shortcuts | `ShortcutsManager.swift` (NEW) | — | Chorus only |

**Requires:** Engineering time (Ali or Vish)

---

### Phase 4: Pricing Page Update (1 hour)
**Files:** `PricingView.swift` (new, if public-facing) or in-app tier display

Visual comparison table:

```
┌─────────────────┬──────────┬──────────┬──────────┐
│                 │ Solo     │ Duet     │ Chorus   │
├─────────────────┼──────────┼──────────┼──────────┤
│ Price           │ $20/yr   │ $35/yr   │ $49/yr   │
│ Devices         │ 1        │ 3        │ ∞        │
│ Local Transcr.  │ ✓        │ ✓        │ ✓        │
│ Cloud Transcr.  │ —        │ ✓        │ ✓        │
│ Multilingual    │ —        │ ✓        │ ✓        │
│ API Access      │ —        │ —        │ ✓        │
└─────────────────┴──────────┴──────────┴──────────┘
```

---

## Blockers & Dependencies

| Item | Owner | Status | Unblocks |
|------|-------|--------|----------|
| Pricing approval | Vish | ⏳ Pending | Phase 1 implementation |
| Polar Duet/Chorus SKU creation | Vish | ⏳ Pending | Phase 2 checkout links |
| Feature gating code | Ali/Vish | ⏳ Backlog | Phase 3, launch readiness |
| Sentry integration (SPM) | Vish | ⏳ Blocked | Error monitoring for Chorus features |
| Supabase project | Vish | ⏳ Pending | Referral system for all tiers |

---

## Launch Readiness Checklist

- [ ] Pricing approved by Vish
- [ ] LicenseTier enum updated with all 3 tiers
- [ ] Duet & Chorus created on Polar.sh
- [ ] Feature gating implemented & tested
- [ ] Tier pricing correctly validated from Polar API
- [ ] In-app tier display updated
- [ ] Landing page shows tier comparison
- [ ] Beta funnel updated (direct to tier picker, not just Solo)
- [ ] Referral system wired to all tiers (pending Supabase)

---

## Why This Matters 🚀

The three-tier model does three critical things:

1. **Creates a growth path** — Users don't choose between buying or not. They choose which tier fits their needs. Solo → Duet → Chorus is a natural upgrade journey.

2. **Captures willingness to pay** — Some users will pay $20. Some will gladly pay $49 for cloud + API. We capture both.

3. **Differentiates from competitors** — VoiceInk and Whisper Transcription don't have a clear tier story. EchoTune's tiers tell a journey: privacy → cloud-power → pro automation.

---

**Next step:** Vish reviews pricing, approves, and we move to Phase 1 (1 hour of engineering time).
