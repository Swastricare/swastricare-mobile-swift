-- ============================================================================
-- MENSTRUAL CYCLE: DAILY LOGS & SETTINGS TABLES
-- ============================================================================
-- These tables support the Android/iOS cycle tracker for daily logging
-- and per-user cycle preferences. They complement the existing
-- menstrual_cycles table created in 20250109000016.

-- ============================================================================
-- MENSTRUAL DAILY LOGS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.menstrual_daily_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cycle_id UUID NOT NULL REFERENCES public.menstrual_cycles(id) ON DELETE CASCADE,
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,

    date DATE NOT NULL,
    flow_level VARCHAR(20) DEFAULT 'none' CHECK (flow_level IN (
        'none', 'light', 'medium', 'heavy', 'very_heavy'
    )),
    symptoms TEXT DEFAULT '',          -- comma-separated symptom keys
    mood VARCHAR(20),                  -- happy, calm, energetic, anxious, sad, irritable, tired, neutral
    notes TEXT,
    pain_level INT DEFAULT 0 CHECK (pain_level BETWEEN 0 AND 10),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_menstrual_daily_logs_profile
    ON public.menstrual_daily_logs(health_profile_id);
CREATE INDEX IF NOT EXISTS idx_menstrual_daily_logs_cycle
    ON public.menstrual_daily_logs(cycle_id);
CREATE INDEX IF NOT EXISTS idx_menstrual_daily_logs_date
    ON public.menstrual_daily_logs(health_profile_id, date);

-- Auto-update updated_at
CREATE TRIGGER set_menstrual_daily_logs_updated_at
    BEFORE UPDATE ON public.menstrual_daily_logs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================================
-- MENSTRUAL SETTINGS TABLE (one row per user)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.menstrual_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,

    average_cycle_length INT DEFAULT 28 CHECK (average_cycle_length BETWEEN 21 AND 45),
    average_period_length INT DEFAULT 5 CHECK (average_period_length BETWEEN 2 AND 10),
    reminder_enabled BOOLEAN DEFAULT true,
    reminder_time TIME DEFAULT '09:00:00',

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- One settings row per profile
    UNIQUE(health_profile_id)
);

CREATE INDEX IF NOT EXISTS idx_menstrual_settings_profile
    ON public.menstrual_settings(health_profile_id);

-- Auto-update updated_at
CREATE TRIGGER set_menstrual_settings_updated_at
    BEFORE UPDATE ON public.menstrual_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================================================
-- ROW LEVEL SECURITY — menstrual_daily_logs
-- ============================================================================
ALTER TABLE public.menstrual_daily_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own menstrual daily logs" ON public.menstrual_daily_logs
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

CREATE POLICY "Users can insert own menstrual daily logs" ON public.menstrual_daily_logs
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

CREATE POLICY "Users can update own menstrual daily logs" ON public.menstrual_daily_logs
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

CREATE POLICY "Users can delete own menstrual daily logs" ON public.menstrual_daily_logs
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

-- ============================================================================
-- ROW LEVEL SECURITY — menstrual_settings
-- ============================================================================
ALTER TABLE public.menstrual_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own menstrual settings" ON public.menstrual_settings
    FOR SELECT USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_view'::text)
    );

CREATE POLICY "Users can insert own menstrual settings" ON public.menstrual_settings
    FOR INSERT WITH CHECK (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

CREATE POLICY "Users can update own menstrual settings" ON public.menstrual_settings
    FOR UPDATE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );

CREATE POLICY "Users can delete own menstrual settings" ON public.menstrual_settings
    FOR DELETE USING (
        health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
        OR has_family_access(health_profile_id, 'can_edit'::text)
    );
