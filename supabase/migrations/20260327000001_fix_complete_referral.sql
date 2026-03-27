-- Fix: complete_referral should unlock AI for BOTH referrer and referred user
-- Previously only the referrer was unlocked, causing the referred user's apply to appear failed.

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
