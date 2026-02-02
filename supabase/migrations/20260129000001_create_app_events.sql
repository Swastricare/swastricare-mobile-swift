-- ============================================================================
-- APP EVENTS (Analytics)
-- ============================================================================
-- Stores all in-app events for analysis: login/logout, hydration, medication,
-- button taps, screen views, errors. Respect user_settings.analytics_enabled on client.

CREATE TABLE public.app_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- User (null when anonymous / pre-login)
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,

    -- Event identity
    event_name VARCHAR(100) NOT NULL,
    event_type VARCHAR(50) NOT NULL CHECK (event_type IN (
        'navigation', 'action', 'error', 'count', 'feature_usage', 'auth', 'screen'
    )),

    -- Flexible payload: counts, screen name, error message, feature key, etc.
    properties JSONB DEFAULT '{}',

    -- Optional: app version, OS, device model
    device_info JSONB DEFAULT '{}',

    -- Optional: group events per session
    session_id UUID
);

-- ============================================================================
-- RLS
-- ============================================================================
ALTER TABLE public.app_events ENABLE ROW LEVEL SECURITY;

-- Users can insert their own events (user_id = auth.uid()) or anonymous (user_id is null)
CREATE POLICY app_events_insert_policy ON public.app_events
    FOR INSERT
    WITH CHECK (
        user_id IS NULL OR user_id = auth.uid()
    );

-- Users can read only their own events (for debugging / export)
CREATE POLICY app_events_select_policy ON public.app_events
    FOR SELECT
    USING (user_id IS NULL OR user_id = auth.uid());

-- No UPDATE/DELETE from client (analytics are append-only)
-- Service role can do anything for dashboards.

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_app_events_user_created ON public.app_events(user_id, created_at DESC);
CREATE INDEX idx_app_events_name_created ON public.app_events(event_name, created_at DESC);
CREATE INDEX idx_app_events_session ON public.app_events(session_id) WHERE session_id IS NOT NULL;
