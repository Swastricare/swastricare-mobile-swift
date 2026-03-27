-- Referral system for AI access gating
-- Each user gets a unique referral_code on their users row.
-- When a referred user signs up, referrals row is completed and referrer's ai_unlocked flips to true.

-- Add columns to users table
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS ai_unlocked BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS referral_code VARCHAR(8) UNIQUE;

-- Referrals tracking table
CREATE TABLE IF NOT EXISTS public.referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    referred_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    referral_code VARCHAR(8) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON public.referrals(referrer_user_id);
CREATE INDEX IF NOT EXISTS idx_referrals_code ON public.referrals(referral_code);
CREATE INDEX IF NOT EXISTS idx_referrals_referred ON public.referrals(referred_user_id);
CREATE INDEX IF NOT EXISTS idx_users_referral_code ON public.users(referral_code) WHERE referral_code IS NOT NULL;

-- Trigger for updated_at
CREATE TRIGGER referrals_updated_at
    BEFORE UPDATE ON public.referrals
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- RLS
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

-- Users can read their own referrals (as referrer)
CREATE POLICY "Users can read own referrals"
    ON public.referrals FOR SELECT
    USING (auth.uid() = referrer_user_id);

-- Users can insert referrals they sent
CREATE POLICY "Users can create own referrals"
    ON public.referrals FOR INSERT
    WITH CHECK (auth.uid() = referrer_user_id);

-- Server function to complete a referral (called during signup)
CREATE OR REPLACE FUNCTION public.complete_referral(p_referral_code VARCHAR, p_referred_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_referrer_id UUID;
BEGIN
    -- Find the referrer by code
    SELECT id INTO v_referrer_id
    FROM public.users
    WHERE referral_code = p_referral_code;

    IF v_referrer_id IS NULL THEN
        RETURN false;
    END IF;

    -- Prevent self-referral
    IF v_referrer_id = p_referred_user_id THEN
        RETURN false;
    END IF;

    -- Check if this referred user already completed a referral for this referrer (idempotent)
    IF EXISTS (
        SELECT 1 FROM public.referrals
        WHERE referrer_user_id = v_referrer_id
        AND referred_user_id = p_referred_user_id
        AND status = 'completed'
    ) THEN
        RETURN true;
    END IF;

    -- Insert the referral
    INSERT INTO public.referrals (referrer_user_id, referred_user_id, referral_code, status, completed_at)
    VALUES (v_referrer_id, p_referred_user_id, p_referral_code, 'completed', NOW())
    ON CONFLICT DO NOTHING;

    -- Unlock AI for both the referrer and the referred user
    UPDATE public.users SET ai_unlocked = true WHERE id = v_referrer_id;
    UPDATE public.users SET ai_unlocked = true WHERE id = p_referred_user_id;

    RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate a unique referral code for a user
CREATE OR REPLACE FUNCTION public.generate_referral_code(p_user_id UUID)
RETURNS VARCHAR AS $$
DECLARE
    v_name VARCHAR;
    v_prefix VARCHAR(3);
    v_code VARCHAR(8);
    v_attempts INT := 0;
BEGIN
    -- Check if user already has a code
    SELECT referral_code INTO v_code FROM public.users WHERE id = p_user_id;
    IF v_code IS NOT NULL THEN
        RETURN v_code;
    END IF;

    -- Get user's name for prefix
    SELECT COALESCE(full_name, 'USR') INTO v_name FROM public.users WHERE id = p_user_id;
    v_prefix := UPPER(LEFT(REGEXP_REPLACE(v_name, '[^a-zA-Z]', '', 'g'), 3));
    IF LENGTH(v_prefix) < 3 THEN
        v_prefix := RPAD(v_prefix, 3, 'X');
    END IF;

    -- Generate code with retries
    LOOP
        v_code := v_prefix || UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 3));
        BEGIN
            UPDATE public.users SET referral_code = v_code WHERE id = p_user_id;
            RETURN v_code;
        EXCEPTION WHEN unique_violation THEN
            v_attempts := v_attempts + 1;
            IF v_attempts >= 5 THEN
                v_code := v_prefix || UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 5));
                UPDATE public.users SET referral_code = v_code WHERE id = p_user_id;
                RETURN v_code;
            END IF;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
