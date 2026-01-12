-- ============================================================================
-- APP VERSIONS TABLE
-- ============================================================================
-- Manages app version requirements for force updates and version checks
-- Supports multiple platforms (ios, android) and channels (production, testflight, staging)

-- ============================================================================
-- APP VERSIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.app_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Platform and Channel
    platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    channel TEXT NOT NULL DEFAULT 'production' CHECK (channel IN ('production', 'testflight', 'staging', 'beta')),
    
    -- Version Requirements
    min_supported_version TEXT,     -- Minimum version required (force update if below)
    min_supported_build INTEGER,    -- Minimum build number required
    latest_version TEXT,            -- Latest available version
    latest_build INTEGER,           -- Latest available build number
    
    -- Update Configuration
    force_update BOOLEAN NOT NULL DEFAULT false,  -- Force all users to update
    rollout_percentage INTEGER NOT NULL DEFAULT 100 CHECK (rollout_percentage >= 0 AND rollout_percentage <= 100),
    
    -- Update Dialog Content
    update_title TEXT,              -- Title for update dialog
    update_message TEXT,            -- Message for update dialog
    update_url TEXT,                -- App Store / Play Store URL
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT true,
    
    -- Timestamps
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Unique constraint: one active config per platform/channel
    UNIQUE(platform, channel)
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_app_versions_platform ON public.app_versions(platform);
CREATE INDEX IF NOT EXISTS idx_app_versions_channel ON public.app_versions(channel);
CREATE INDEX IF NOT EXISTS idx_app_versions_active ON public.app_versions(platform, channel) WHERE is_active = true;

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER app_versions_updated_at
    BEFORE UPDATE ON public.app_versions
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE public.app_versions ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read app versions (needed for version check before login)
CREATE POLICY "Anyone can read app versions" ON public.app_versions
    FOR SELECT USING (true);

-- Only service role can modify (via admin dashboard or server)
-- INSERT, UPDATE, DELETE are restricted to service role only (no user policies needed)

-- ============================================================================
-- SEED DATA
-- ============================================================================
-- Insert default version configs for iOS channels
INSERT INTO public.app_versions (platform, channel, min_supported_version, min_supported_build, latest_version, latest_build, force_update, rollout_percentage, update_title, update_message, update_url, is_active)
VALUES 
    ('ios', 'production', '1.0.0', 1, '1.0.0', 1, false, 100, 'Update Available', 'A new version of Swastricare is available with improvements and bug fixes.', 'https://apps.apple.com/app/swastricare/id123456789', true),
    ('ios', 'testflight', '1.0.0', 1, '1.0.0', 1, false, 100, 'Beta Update', 'A new beta version is available for testing.', null, true),
    ('ios', 'staging', '1.0.0', 1, '1.0.0', 1, false, 100, 'Dev Update', 'Development build update available.', null, true)
ON CONFLICT (platform, channel) DO NOTHING;

-- ============================================================================
-- HELPER FUNCTION: Check if app needs update
-- ============================================================================
CREATE OR REPLACE FUNCTION public.check_app_version(
    p_platform TEXT,
    p_channel TEXT,
    p_current_version TEXT,
    p_current_build INTEGER
)
RETURNS TABLE (
    needs_force_update BOOLEAN,
    has_update_available BOOLEAN,
    latest_version TEXT,
    update_title TEXT,
    update_message TEXT,
    update_url TEXT
) AS $$
DECLARE
    v_record RECORD;
    v_needs_force BOOLEAN := false;
    v_has_update BOOLEAN := false;
BEGIN
    -- Get the active version config
    SELECT * INTO v_record
    FROM public.app_versions
    WHERE platform = p_platform 
      AND channel = p_channel 
      AND is_active = true
    LIMIT 1;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, false, NULL::TEXT, NULL::TEXT, NULL::TEXT, NULL::TEXT;
        RETURN;
    END IF;
    
    -- Check if force update is required
    IF v_record.force_update THEN
        v_needs_force := true;
    ELSIF v_record.min_supported_build IS NOT NULL AND p_current_build < v_record.min_supported_build THEN
        v_needs_force := true;
    END IF;
    
    -- Check if update is available
    IF v_record.latest_build IS NOT NULL AND p_current_build < v_record.latest_build THEN
        v_has_update := true;
    END IF;
    
    RETURN QUERY SELECT 
        v_needs_force,
        v_has_update,
        v_record.latest_version,
        v_record.update_title,
        v_record.update_message,
        v_record.update_url;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
