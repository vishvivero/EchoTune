# Supabase Referral System Setup

## 1. Run the Migration

Go to [Supabase Dashboard → SQL Editor](https://supabase.com/dashboard/project/mdcnmfbogxixjfwordxy/sql/new)

Paste and run: `migrations/001_referral_system.sql`

This creates:
- `beta_users` table (user profiles + referral codes)
- `referrals` table (tracking who referred whom)
- `register_beta_user()` RPC function
- `get_referral_stats()` RPC function
- RLS policies + grants

## 2. Get the Anon Key

Go to [Project Settings → API](https://supabase.com/dashboard/project/mdcnmfbogxixjfwordxy/settings/api)

Copy the **anon/public** key and update `ReferralManager.swift`:
```swift
private static let defaultAnonKey = "YOUR_ANON_KEY_HERE"
```

## 3. Deploy the Edge Function (Polar Webhook)

```bash
# Install Supabase CLI if needed
brew install supabase/tap/supabase

# Link to project
supabase link --project-ref mdcnmfbogxixjfwordxy

# Deploy
supabase functions deploy polar-webhook --project-ref mdcnmfbogxixjfwordxy
```

## 4. Set Up Polar Webhook

Go to [Polar Dashboard → Settings → Webhooks](https://dashboard.polar.sh)

- **URL:** `https://mdcnmfbogxixjfwordxy.supabase.co/functions/v1/polar-webhook`
- **Events:** `checkout.created`, `order.created`, `benefit.granted`
- **Secret:** (optional, set matching secret in Supabase)

## 5. Referral Flow

```
User A activates license → registers in Supabase → gets referral code ET-XXXXXX
User A shares: https://buy.polar.sh/...?metadata[referral_code]=ET-XXXXXX
User B clicks link → Polar checkout → webhook fires → register_beta_user(referred_by=ET-XXXXXX)
  → User B gets +90 days (3 months)
  → User A gets +30 days (1 month)
  → At 12 referrals, User A has earned 360 days (free year)
```

## 6. Testing

```sql
-- Check users
SELECT referral_code, email, total_referrals, bonus_days_earned, license_expires_at
FROM beta_users ORDER BY created_at DESC;

-- Check referrals
SELECT * FROM referrals ORDER BY created_at DESC;

-- Test registration manually
SELECT register_beta_user('test@example.com', NULL, NULL, NULL, NULL, NULL);
```
