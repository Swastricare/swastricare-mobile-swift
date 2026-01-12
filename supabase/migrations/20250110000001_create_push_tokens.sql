-- ============================================================================
-- PUSH TOKENS TABLE
-- ============================================================================
-- Stores device push notification tokens for sending remote notifications
-- Also includes app_version for tracking which version users are on

-- ============================================================================
-- PUSH TOKENS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.push_tokens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    
    -- Device Token (unique per device)
    device_token TEXT NOT NULL,
    
    -- Device Information
    device_name TEXT,
    device_model TEXT,
    os_version TEXT,
    app_version TEXT,
    
    -- Platform
    platform TEXT DEFAULT 'ios' CHECK (platform IN ('ios', 'android', 'web')),
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    last_used_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Unique constraint: one token per device per user
    UNIQUE(user_id, device_token)
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_push_tokens_user ON public.push_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_push_tokens_device ON public.push_tokens(device_token);
CREATE INDEX IF NOT EXISTS idx_push_tokens_active ON public.push_tokens(user_id) WHERE is_active = true;

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER push_tokens_updated_at
    BEFORE UPDATE ON public.push_tokens
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

-- Users can only see their own push tokens
CREATE POLICY "Users can view own push tokens" ON public.push_tokens
    FOR SELECT USING (auth.uid() = user_id);

-- Users can insert their own push tokens
CREATE POLICY "Users can insert own push tokens" ON public.push_tokens
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own push tokens
CREATE POLICY "Users can update own push tokens" ON public.push_tokens
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can delete their own push tokens
CREATE POLICY "Users can delete own push tokens" ON public.push_tokens
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================================
-- UPSERT FUNCTION
-- ============================================================================
-- Function to upsert push tokens (insert or update on conflict)
CREATE OR REPLACE FUNCTION public.upsert_push_token(
    p_user_id UUID,
    p_device_token TEXT,
    p_device_name TEXT DEFAULT NULL,
    p_device_model TEXT DEFAULT NULL,
    p_os_version TEXT DEFAULT NULL,
    p_app_version TEXT DEFAULT NULL,
    p_platform TEXT DEFAULT 'ios'
)
RETURNS UUID AS $$
DECLARE
    v_id UUID;
BEGIN
    INSERT INTO public.push_tokens (
        user_id, device_token, device_name, device_model, 
        os_version, app_version, platform, is_active, last_used_at
    )
    VALUES (
        p_user_id, p_device_token, p_device_name, p_device_model,
        p_os_version, p_app_version, p_platform, true, NOW()
    )
    ON CONFLICT (user_id, device_token) 
    DO UPDATE SET
        device_name = COALESCE(EXCLUDED.device_name, push_tokens.device_name),
        device_model = COALESCE(EXCLUDED.device_model, push_tokens.device_model),
        os_version = COALESCE(EXCLUDED.os_version, push_tokens.os_version),
        app_version = COALESCE(EXCLUDED.app_version, push_tokens.app_version),
        platform = COALESCE(EXCLUDED.platform, push_tokens.platform),
        is_active = true,
        last_used_at = NOW(),
        updated_at = NOW()
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
