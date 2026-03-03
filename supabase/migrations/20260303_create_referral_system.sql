-- Referral System Tables for EchoTune
-- Created: March 3, 2026

-- Beta Users table: track all beta program signups
CREATE TABLE IF NOT EXISTS beta_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) NOT NULL UNIQUE,
  polar_customer_id VARCHAR(255) UNIQUE,
  referral_code VARCHAR(12) UNIQUE NOT NULL,
  license_type VARCHAR(50) DEFAULT 'beta', -- 'beta', 'free', 'pro'
  license_expires_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '1 year',
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Referrals table: track who referred whom
CREATE TABLE IF NOT EXISTS referrals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id UUID NOT NULL REFERENCES beta_users(id) ON DELETE CASCADE,
  referred_user_id UUID REFERENCES beta_users(id) ON DELETE SET NULL,
  referred_email VARCHAR(255) NOT NULL, -- capture email even if signup not yet created
  referred_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  signup_completed_at TIMESTAMP WITH TIME ZONE,
  rewarded_at TIMESTAMP WITH TIME ZONE,
  referrer_bonus_days INTEGER DEFAULT 30, -- 1 month per referral
  referred_bonus_days INTEGER DEFAULT 90, -- 3 months for new user
  status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'completed', 'rewarded'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX idx_beta_users_polar_customer_id ON beta_users(polar_customer_id);
CREATE INDEX idx_beta_users_referral_code ON beta_users(referral_code);
CREATE INDEX idx_referrals_referrer_id ON referrals(referrer_id);
CREATE INDEX idx_referrals_referred_user_id ON referrals(referred_user_id);
CREATE INDEX idx_referrals_status ON referrals(status);
CREATE INDEX idx_referrals_created_at ON referrals(created_at);

-- Enable RLS (Row Level Security)
ALTER TABLE beta_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;

-- RLS Policies: Users can view their own data and referral stats
CREATE POLICY "Users can view their own profile" ON beta_users
  FOR SELECT USING (auth.uid()::text = id::text);

CREATE POLICY "Users can view referrals they initiated" ON referrals
  FOR SELECT USING (auth.uid()::text = referrer_id::text);

-- Function to generate unique referral code
CREATE OR REPLACE FUNCTION generate_referral_code()
RETURNS VARCHAR(12) AS $$
DECLARE
  code VARCHAR(12);
  exists BOOLEAN;
BEGIN
  LOOP
    code := 'ECHO' || UPPER(SUBSTRING(MD5(RANDOM()::TEXT), 1, 8));
    SELECT EXISTS(SELECT 1 FROM beta_users WHERE referral_code = code) INTO exists;
    EXIT WHEN NOT exists;
  END LOOP;
  RETURN code;
END;
$$ LANGUAGE plpgsql;

-- Function to add a referral
CREATE OR REPLACE FUNCTION add_referral(
  referrer_email VARCHAR,
  referred_email VARCHAR
)
RETURNS TABLE (
  referral_id UUID,
  referrer_id UUID,
  referrer_referral_code VARCHAR,
  status VARCHAR,
  message VARCHAR
) AS $$
DECLARE
  v_referrer_id UUID;
  v_referred_user_id UUID;
  v_existing_referral UUID;
BEGIN
  -- Find referrer
  SELECT id INTO v_referrer_id FROM beta_users WHERE email = referrer_email;
  IF v_referrer_id IS NULL THEN
    RETURN QUERY SELECT NULL, NULL, NULL, 'error'::VARCHAR, 'Referrer not found'::VARCHAR;
    RETURN;
  END IF;

  -- Check if referred email already exists as beta user
  SELECT id INTO v_referred_user_id FROM beta_users WHERE email = referred_email;

  -- Check for duplicate referral
  SELECT id INTO v_existing_referral FROM referrals 
  WHERE referrer_id = v_referrer_id AND referred_email = referred_email;
  
  IF v_existing_referral IS NOT NULL THEN
    RETURN QUERY SELECT 
      v_existing_referral, 
      v_referrer_id, 
      (SELECT referral_code FROM beta_users WHERE id = v_referrer_id),
      'duplicate'::VARCHAR, 
      'This referral already exists'::VARCHAR;
    RETURN;
  END IF;

  -- Insert referral
  INSERT INTO referrals (referrer_id, referred_user_id, referred_email, status)
  VALUES (v_referrer_id, v_referred_user_id, referred_email, 
    CASE WHEN v_referred_user_id IS NOT NULL THEN 'completed' ELSE 'pending' END)
  RETURNING 
    referrals.id,
    referrals.referrer_id,
    (SELECT referral_code FROM beta_users WHERE id = v_referrer_id),
    referrals.status,
    'Referral created successfully'::VARCHAR
  INTO referral_id, referrer_id, referrer_referral_code, status, message;

  RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- Function to complete referral when new user signs up
CREATE OR REPLACE FUNCTION complete_referral(
  referral_code VARCHAR,
  new_user_email VARCHAR,
  polar_customer_id VARCHAR
)
RETURNS TABLE (
  success BOOLEAN,
  message VARCHAR,
  referrer_bonus_days INTEGER,
  referred_bonus_days INTEGER
) AS $$
DECLARE
  v_referrer_id UUID;
  v_referral_id UUID;
  v_new_user_id UUID;
BEGIN
  -- Find referrer by code
  SELECT id INTO v_referrer_id FROM beta_users WHERE referral_code = referral_code;
  IF v_referrer_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Invalid referral code'::VARCHAR, 0, 0;
    RETURN;
  END IF;

  -- Create new user in beta_users table
  INSERT INTO beta_users (email, polar_customer_id, referral_code, license_expires_at)
  VALUES (
    new_user_email,
    polar_customer_id,
    generate_referral_code(),
    NOW() + INTERVAL '3 months' -- 3-month starter bonus for referred user
  )
  RETURNING beta_users.id INTO v_new_user_id;

  -- Find and complete the referral
  UPDATE referrals
  SET 
    referred_user_id = v_new_user_id,
    signup_completed_at = NOW(),
    status = 'completed',
    updated_at = NOW()
  WHERE referrer_id = v_referrer_id 
    AND referred_email = new_user_email
    AND status IN ('pending', 'completed')
  RETURNING id INTO v_referral_id;

  IF v_referral_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Referral record not found'::VARCHAR, 0, 0;
    RETURN;
  END IF;

  -- Extend referrer's license by 1 month (30 days)
  UPDATE beta_users
  SET license_expires_at = license_expires_at + INTERVAL '30 days'
  WHERE id = v_referrer_id;

  RETURN QUERY SELECT TRUE, 'Referral completed and bonuses applied'::VARCHAR, 30, 90;
END;
$$ LANGUAGE plpgsql;

-- Function to get referral stats
CREATE OR REPLACE FUNCTION get_referral_stats(user_email VARCHAR)
RETURNS TABLE (
  total_referrals BIGINT,
  completed_referrals BIGINT,
  pending_referrals BIGINT,
  bonus_days_earned INTEGER,
  free_year_unlocked BOOLEAN
) AS $$
DECLARE
  v_user_id UUID;
BEGIN
  SELECT id INTO v_user_id FROM beta_users WHERE email = user_email;
  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT 0, 0, 0, 0, FALSE;
    RETURN;
  END IF;

  RETURN QUERY SELECT
    COUNT(*)::BIGINT as total_referrals,
    COUNT(*) FILTER (WHERE status = 'completed')::BIGINT as completed_referrals,
    COUNT(*) FILTER (WHERE status = 'pending')::BIGINT as pending_referrals,
    COALESCE(COUNT(*) FILTER (WHERE status = 'completed')::INTEGER * 30, 0) as bonus_days_earned,
    (COUNT(*) FILTER (WHERE status = 'completed') >= 12)::BOOLEAN as free_year_unlocked
  FROM referrals
  WHERE referrer_id = v_user_id;
END;
$$ LANGUAGE plpgsql;

-- Audit log for referral rewards
CREATE TABLE IF NOT EXISTS referral_rewards_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES beta_users(id) ON DELETE CASCADE,
  reward_type VARCHAR(50), -- 'referral_bonus', 'free_year', 'manual_adjustment'
  days_added INTEGER,
  new_expiry TIMESTAMP WITH TIME ZONE,
  reason VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_referral_rewards_user_id ON referral_rewards_log(user_id);

-- Trigger to log license extensions
CREATE OR REPLACE FUNCTION log_license_extension()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.license_expires_at > OLD.license_expires_at THEN
    INSERT INTO referral_rewards_log (user_id, reward_type, days_added, new_expiry, reason)
    VALUES (
      NEW.id,
      'referral_bonus',
      EXTRACT(DAY FROM (NEW.license_expires_at - OLD.license_expires_at))::INTEGER,
      NEW.license_expires_at,
      'Automatic referral reward'
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_log_license_extension
AFTER UPDATE ON beta_users
FOR EACH ROW
EXECUTE FUNCTION log_license_extension();
