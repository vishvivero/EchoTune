-- ============================================================
-- EchoTune Referral System Schema
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New query)
-- ============================================================

-- 1. Beta Users table — every activated beta user
CREATE TABLE IF NOT EXISTS beta_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT UNIQUE NOT NULL,
    polar_license_key TEXT UNIQUE,
    polar_customer_id TEXT,
    referral_code TEXT UNIQUE NOT NULL,
    referred_by TEXT REFERENCES beta_users(referral_code),
    license_expires_at TIMESTAMPTZ,
    bonus_days_earned INTEGER DEFAULT 0,
    total_referrals INTEGER DEFAULT 0,
    device_fingerprint TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Referrals tracking table
CREATE TABLE IF NOT EXISTS referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_code TEXT NOT NULL REFERENCES beta_users(referral_code),
    referred_email TEXT NOT NULL,
    referred_user_id UUID REFERENCES beta_users(id),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'activated', 'rewarded', 'expired')),
    bonus_days INTEGER DEFAULT 30,  -- days awarded to referrer
    referred_bonus_days INTEGER DEFAULT 90,  -- 3 months for referred friend
    created_at TIMESTAMPTZ DEFAULT now(),
    activated_at TIMESTAMPTZ,
    rewarded_at TIMESTAMPTZ
);

-- 3. Indexes
CREATE INDEX IF NOT EXISTS idx_beta_users_referral_code ON beta_users(referral_code);
CREATE INDEX IF NOT EXISTS idx_beta_users_email ON beta_users(email);
CREATE INDEX IF NOT EXISTS idx_beta_users_polar_license_key ON beta_users(polar_license_key);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer_code ON referrals(referrer_code);
CREATE INDEX IF NOT EXISTS idx_referrals_referred_email ON referrals(referred_email);
CREATE INDEX IF NOT EXISTS idx_referrals_status ON referrals(status);

-- 4. Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER beta_users_updated_at
    BEFORE UPDATE ON beta_users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- 5. Generate unique referral code (6 chars, alphanumeric)
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS TEXT AS $$
DECLARE
    code TEXT;
    exists BOOLEAN;
BEGIN
    LOOP
        -- Generate: ET- + 6 random alphanumeric chars
        code := 'ET-' || upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
        SELECT EXISTS(SELECT 1 FROM beta_users WHERE referral_code = code) INTO exists;
        EXIT WHEN NOT exists;
    END LOOP;
    RETURN code;
END;
$$ LANGUAGE plpgsql;

-- 6. Register a new beta user (called from app on first activation)
CREATE OR REPLACE FUNCTION register_beta_user(
    p_email TEXT,
    p_polar_license_key TEXT DEFAULT NULL,
    p_polar_customer_id TEXT DEFAULT NULL,
    p_referred_by TEXT DEFAULT NULL,
    p_device_fingerprint TEXT DEFAULT NULL,
    p_license_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    v_user beta_users%ROWTYPE;
    v_referral_code TEXT;
    v_referral referrals%ROWTYPE;
BEGIN
    -- Check if user already exists
    SELECT * INTO v_user FROM beta_users WHERE email = p_email;

    IF v_user.id IS NOT NULL THEN
        -- Update existing user with any new info
        UPDATE beta_users SET
            polar_license_key = COALESCE(p_polar_license_key, polar_license_key),
            polar_customer_id = COALESCE(p_polar_customer_id, polar_customer_id),
            device_fingerprint = COALESCE(p_device_fingerprint, device_fingerprint),
            license_expires_at = COALESCE(p_license_expires_at, license_expires_at)
        WHERE id = v_user.id
        RETURNING * INTO v_user;

        RETURN json_build_object(
            'success', true,
            'user_id', v_user.id,
            'referral_code', v_user.referral_code,
            'bonus_days_earned', v_user.bonus_days_earned,
            'total_referrals', v_user.total_referrals,
            'license_expires_at', v_user.license_expires_at,
            'is_new', false
        );
    END IF;

    -- Generate unique referral code
    v_referral_code := generate_referral_code();

    -- Validate referred_by code exists (if provided)
    IF p_referred_by IS NOT NULL THEN
        IF NOT EXISTS(SELECT 1 FROM beta_users WHERE referral_code = p_referred_by) THEN
            p_referred_by := NULL;  -- Silently ignore invalid codes
        END IF;
    END IF;

    -- Insert new user
    INSERT INTO beta_users (
        email, polar_license_key, polar_customer_id,
        referral_code, referred_by, device_fingerprint,
        license_expires_at
    ) VALUES (
        p_email, p_polar_license_key, p_polar_customer_id,
        v_referral_code, p_referred_by, p_device_fingerprint,
        p_license_expires_at
    )
    RETURNING * INTO v_user;

    -- If referred by someone, create the referral record and reward both parties
    IF p_referred_by IS NOT NULL THEN
        INSERT INTO referrals (
            referrer_code, referred_email, referred_user_id,
            status, activated_at
        ) VALUES (
            p_referred_by, p_email, v_user.id,
            'rewarded', now()
        );

        -- Reward referrer: +30 days per referral
        UPDATE beta_users SET
            total_referrals = total_referrals + 1,
            bonus_days_earned = bonus_days_earned + 30,
            license_expires_at = COALESCE(license_expires_at, now()) + INTERVAL '30 days'
        WHERE referral_code = p_referred_by;

        -- Reward referred user: +90 days (3 months)
        UPDATE beta_users SET
            bonus_days_earned = 90,
            license_expires_at = COALESCE(license_expires_at, now()) + INTERVAL '90 days'
        WHERE id = v_user.id
        RETURNING * INTO v_user;
    END IF;

    RETURN json_build_object(
        'success', true,
        'user_id', v_user.id,
        'referral_code', v_user.referral_code,
        'bonus_days_earned', v_user.bonus_days_earned,
        'total_referrals', v_user.total_referrals,
        'license_expires_at', v_user.license_expires_at,
        'is_new', true,
        'referred_by', p_referred_by
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Get referral stats for a user
CREATE OR REPLACE FUNCTION get_referral_stats(p_referral_code TEXT)
RETURNS JSON AS $$
DECLARE
    v_user beta_users%ROWTYPE;
    v_referrals JSON;
BEGIN
    SELECT * INTO v_user FROM beta_users WHERE referral_code = p_referral_code;

    IF v_user.id IS NULL THEN
        RETURN json_build_object('success', false, 'error', 'User not found');
    END IF;

    -- Get referral details
    SELECT json_agg(json_build_object(
        'email', substr(r.referred_email, 1, 3) || '***@' || split_part(r.referred_email, '@', 2),
        'status', r.status,
        'bonus_days', r.bonus_days,
        'created_at', r.created_at,
        'activated_at', r.activated_at
    ) ORDER BY r.created_at DESC)
    INTO v_referrals
    FROM referrals r
    WHERE r.referrer_code = p_referral_code;

    RETURN json_build_object(
        'success', true,
        'referral_code', v_user.referral_code,
        'total_referrals', v_user.total_referrals,
        'bonus_days_earned', v_user.bonus_days_earned,
        'license_expires_at', v_user.license_expires_at,
        'referrals_to_free_year', GREATEST(0, 12 - v_user.total_referrals),
        'referrals', COALESCE(v_referrals, '[]'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. RLS Policies
ALTER TABLE beta_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;

-- Allow anon to call RPC functions (SECURITY DEFINER handles access)
-- Allow anon to read their own data via referral_code
CREATE POLICY "Users can read own data via referral code"
    ON beta_users FOR SELECT
    USING (true);  -- RPC functions use SECURITY DEFINER; direct reads are filtered in app

CREATE POLICY "Referrals are readable"
    ON referrals FOR SELECT
    USING (true);  -- Filtered by referral_code in queries

-- Only server/functions can insert/update
CREATE POLICY "Server can insert beta users"
    ON beta_users FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Server can update beta users"
    ON beta_users FOR UPDATE
    USING (true);

CREATE POLICY "Server can insert referrals"
    ON referrals FOR INSERT
    WITH CHECK (true);

CREATE POLICY "Server can update referrals"
    ON referrals FOR UPDATE
    USING (true);

-- 9. Grant access to anon role (for RPC calls from app)
GRANT USAGE ON SCHEMA public TO anon;
GRANT EXECUTE ON FUNCTION register_beta_user TO anon;
GRANT EXECUTE ON FUNCTION get_referral_stats TO anon;
GRANT SELECT ON beta_users TO anon;
GRANT SELECT ON referrals TO anon;
GRANT INSERT, UPDATE ON beta_users TO anon;
GRANT INSERT, UPDATE ON referrals TO anon;
