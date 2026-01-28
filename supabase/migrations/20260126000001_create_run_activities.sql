-- ============================================================================
-- RUN ACTIVITIES MODULE
-- ============================================================================
-- Tables: run_activities, run_activity_routes, daily_activity_summaries, activity_goals
-- Supports GPS route tracking, HealthKit sync, and gamification points

-- ============================================================================
-- RUN ACTIVITIES TABLE
-- ============================================================================
-- Stores individual walking/running activities with full route data
CREATE TABLE public.run_activities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Activity identification
    external_id VARCHAR(255), -- HealthKit/Google Fit workout UUID
    source VARCHAR(50) NOT NULL DEFAULT 'app' CHECK (source IN (
        'app', 'apple_health', 'google_fit', 'garmin', 'fitbit', 'strava', 'manual'
    )),
    
    -- Activity type
    activity_type VARCHAR(30) NOT NULL DEFAULT 'walk' CHECK (activity_type IN (
        'walk', 'run', 'commute', 'hike', 'treadmill'
    )),
    activity_name VARCHAR(200),
    
    -- Timing
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ NOT NULL,
    duration_seconds INT NOT NULL DEFAULT 0,
    
    -- Distance & Movement
    distance_meters DECIMAL(10,2) NOT NULL DEFAULT 0,
    steps INT NOT NULL DEFAULT 0,
    
    -- Calories & Points
    calories_burned INT NOT NULL DEFAULT 0,
    active_calories INT DEFAULT 0,
    points_earned INT NOT NULL DEFAULT 0,
    
    -- Heart Rate Stats
    avg_heart_rate INT,
    max_heart_rate INT,
    min_heart_rate INT,
    
    -- Pace & Speed
    avg_pace_seconds_per_km INT, -- seconds per kilometer
    max_pace_seconds_per_km INT,
    avg_speed_kmh DECIMAL(5,2),
    max_speed_kmh DECIMAL(5,2),
    
    -- Elevation
    elevation_gain_meters DECIMAL(8,2) DEFAULT 0,
    elevation_loss_meters DECIMAL(8,2) DEFAULT 0,
    max_elevation_meters DECIMAL(8,2),
    min_elevation_meters DECIMAL(8,2),
    
    -- Cadence
    avg_cadence INT, -- steps per minute
    max_cadence INT,
    
    -- Weather conditions during activity
    weather_temp_celsius DECIMAL(4,1),
    weather_humidity_percent INT,
    weather_condition VARCHAR(50),
    
    -- Location summary
    start_location_name VARCHAR(200),
    end_location_name VARCHAR(200),
    start_latitude DECIMAL(10,8),
    start_longitude DECIMAL(11,8),
    end_latitude DECIMAL(10,8),
    end_longitude DECIMAL(11,8),
    
    -- Route data (stored as JSONB for flexibility)
    -- Format: [{"lat": 12.9716, "lng": 77.5946, "alt": 920.5, "ts": "2024-01-26T07:30:00Z"}]
    route_coordinates JSONB DEFAULT '[]'::jsonb,
    route_polyline TEXT, -- Encoded polyline for efficient storage
    
    -- Map snapshot
    map_snapshot_url TEXT,
    
    -- Indoor detection
    is_indoor BOOLEAN DEFAULT FALSE,
    
    -- Notes & Tags
    notes TEXT,
    tags TEXT[], -- e.g., ['morning', 'park', 'personal_best']
    
    -- Sync status
    synced_to_healthkit BOOLEAN DEFAULT FALSE,
    synced_at TIMESTAMPTZ,
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    deleted_at TIMESTAMPTZ, -- Soft delete
    
    -- Unique constraint to prevent duplicate imports
    UNIQUE(health_profile_id, external_id, source)
);

-- ============================================================================
-- DAILY ACTIVITY SUMMARIES TABLE
-- ============================================================================
-- Aggregated daily stats for quick retrieval
CREATE TABLE public.daily_activity_summaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Date
    summary_date DATE NOT NULL,
    
    -- Totals
    total_steps INT NOT NULL DEFAULT 0,
    total_distance_meters DECIMAL(12,2) NOT NULL DEFAULT 0,
    total_calories INT NOT NULL DEFAULT 0,
    total_points INT NOT NULL DEFAULT 0,
    total_duration_seconds INT NOT NULL DEFAULT 0,
    
    -- Activity counts
    walk_count INT DEFAULT 0,
    run_count INT DEFAULT 0,
    commute_count INT DEFAULT 0,
    
    -- Averages
    avg_heart_rate INT,
    avg_pace_seconds_per_km INT,
    avg_speed_kmh DECIMAL(5,2),
    
    -- Goals progress (percentage 0-100+)
    steps_goal_progress INT DEFAULT 0,
    distance_goal_progress INT DEFAULT 0,
    calories_goal_progress INT DEFAULT 0,
    
    -- Best performance of the day
    best_pace_seconds_per_km INT,
    longest_activity_meters DECIMAL(10,2),
    
    -- Sources
    data_sources TEXT[], -- ['apple_health', 'app']
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(health_profile_id, summary_date)
);

-- ============================================================================
-- ACTIVITY GOALS TABLE
-- ============================================================================
-- User-defined goals for gamification
CREATE TABLE public.activity_goals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Goal targets
    daily_steps_goal INT NOT NULL DEFAULT 10000,
    daily_distance_meters INT NOT NULL DEFAULT 8000, -- 8km
    daily_calories_goal INT NOT NULL DEFAULT 500,
    daily_active_minutes INT NOT NULL DEFAULT 30,
    
    -- Weekly goals
    weekly_steps_goal INT DEFAULT 70000,
    weekly_distance_meters INT DEFAULT 50000, -- 50km
    weekly_active_days INT DEFAULT 5,
    
    -- Points & Rewards
    points_per_1000_steps INT DEFAULT 10,
    points_per_km INT DEFAULT 20,
    points_per_calorie DECIMAL(3,2) DEFAULT 0.1,
    
    -- Streaks
    current_steps_streak INT DEFAULT 0,
    longest_steps_streak INT DEFAULT 0,
    current_active_streak INT DEFAULT 0,
    longest_active_streak INT DEFAULT 0,
    last_streak_date DATE,
    
    -- Level & XP for gamification
    level INT DEFAULT 1,
    total_xp INT DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(health_profile_id)
);

-- ============================================================================
-- WEEKLY COMPARISONS VIEW
-- ============================================================================
-- For quick retrieval of week-over-week stats
CREATE VIEW public.weekly_activity_comparison AS
SELECT 
    health_profile_id,
    DATE_TRUNC('week', summary_date) AS week_start,
    SUM(total_steps) AS total_steps,
    SUM(total_distance_meters) AS total_distance,
    SUM(total_calories) AS total_calories,
    SUM(total_points) AS total_points,
    AVG(total_steps) AS avg_daily_steps,
    AVG(total_distance_meters) AS avg_daily_distance,
    COUNT(*) AS active_days
FROM public.daily_activity_summaries
WHERE summary_date >= CURRENT_DATE - INTERVAL '4 weeks'
GROUP BY health_profile_id, DATE_TRUNC('week', summary_date)
ORDER BY week_start DESC;

-- ============================================================================
-- INDEXES
-- ============================================================================
-- Run activities indexes
CREATE INDEX idx_run_activities_profile_date ON public.run_activities(health_profile_id, started_at DESC);
CREATE INDEX idx_run_activities_type ON public.run_activities(health_profile_id, activity_type, started_at DESC);
CREATE INDEX idx_run_activities_source ON public.run_activities(health_profile_id, source);
CREATE INDEX idx_run_activities_external ON public.run_activities(external_id, source) WHERE external_id IS NOT NULL;
CREATE INDEX idx_run_activities_not_deleted ON public.run_activities(health_profile_id, started_at DESC) WHERE deleted_at IS NULL;

-- Daily summaries indexes
CREATE INDEX idx_daily_summaries_profile_date ON public.daily_activity_summaries(health_profile_id, summary_date DESC);
CREATE INDEX idx_daily_summaries_recent ON public.daily_activity_summaries(health_profile_id, summary_date DESC) 
    WHERE summary_date >= CURRENT_DATE - INTERVAL '30 days';

-- Activity goals index
CREATE INDEX idx_activity_goals_profile ON public.activity_goals(health_profile_id);

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE public.run_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_activity_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_goals ENABLE ROW LEVEL SECURITY;

-- Run activities policies
CREATE POLICY "Users can view own run activities" ON public.run_activities
    FOR SELECT USING (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create own run activities" ON public.run_activities
    FOR INSERT WITH CHECK (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update own run activities" ON public.run_activities
    FOR UPDATE USING (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete own run activities" ON public.run_activities
    FOR DELETE USING (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

-- Daily summaries policies
CREATE POLICY "Users can view own daily summaries" ON public.daily_activity_summaries
    FOR SELECT USING (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can manage own daily summaries" ON public.daily_activity_summaries
    FOR ALL USING (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

-- Activity goals policies
CREATE POLICY "Users can view own activity goals" ON public.activity_goals
    FOR SELECT USING (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can manage own activity goals" ON public.activity_goals
    FOR ALL USING (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

-- ============================================================================
-- TRIGGERS
-- ============================================================================
-- Update timestamps
CREATE TRIGGER run_activities_updated_at
    BEFORE UPDATE ON public.run_activities
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER daily_activity_summaries_updated_at
    BEFORE UPDATE ON public.daily_activity_summaries
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER activity_goals_updated_at
    BEFORE UPDATE ON public.activity_goals
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to calculate points for an activity
CREATE OR REPLACE FUNCTION public.calculate_activity_points(
    p_steps INT,
    p_distance_meters DECIMAL,
    p_calories INT,
    p_health_profile_id UUID
) RETURNS INT AS $$
DECLARE
    v_goals activity_goals%ROWTYPE;
    v_points INT := 0;
BEGIN
    -- Get user's goals settings
    SELECT * INTO v_goals FROM public.activity_goals 
    WHERE health_profile_id = p_health_profile_id;
    
    -- Use defaults if no goals set
    IF v_goals IS NULL THEN
        v_points := (p_steps / 1000 * 10) + 
                   (p_distance_meters / 1000 * 20) + 
                   (p_calories * 0.1)::INT;
    ELSE
        v_points := (p_steps / 1000 * v_goals.points_per_1000_steps) + 
                   (p_distance_meters / 1000 * v_goals.points_per_km) + 
                   (p_calories * v_goals.points_per_calorie)::INT;
    END IF;
    
    RETURN v_points;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update daily summary after activity insert/update
CREATE OR REPLACE FUNCTION public.update_daily_activity_summary()
RETURNS TRIGGER AS $$
DECLARE
    v_date DATE;
    v_summary_exists BOOLEAN;
BEGIN
    -- Get the date of the activity
    v_date := DATE(NEW.started_at);
    
    -- Check if summary exists
    SELECT EXISTS(
        SELECT 1 FROM public.daily_activity_summaries 
        WHERE health_profile_id = NEW.health_profile_id 
        AND summary_date = v_date
    ) INTO v_summary_exists;
    
    IF v_summary_exists THEN
        -- Update existing summary
        UPDATE public.daily_activity_summaries
        SET 
            total_steps = (
                SELECT COALESCE(SUM(steps), 0) FROM public.run_activities 
                WHERE health_profile_id = NEW.health_profile_id 
                AND DATE(started_at) = v_date AND deleted_at IS NULL
            ),
            total_distance_meters = (
                SELECT COALESCE(SUM(distance_meters), 0) FROM public.run_activities 
                WHERE health_profile_id = NEW.health_profile_id 
                AND DATE(started_at) = v_date AND deleted_at IS NULL
            ),
            total_calories = (
                SELECT COALESCE(SUM(calories_burned), 0) FROM public.run_activities 
                WHERE health_profile_id = NEW.health_profile_id 
                AND DATE(started_at) = v_date AND deleted_at IS NULL
            ),
            total_points = (
                SELECT COALESCE(SUM(points_earned), 0) FROM public.run_activities 
                WHERE health_profile_id = NEW.health_profile_id 
                AND DATE(started_at) = v_date AND deleted_at IS NULL
            ),
            total_duration_seconds = (
                SELECT COALESCE(SUM(duration_seconds), 0) FROM public.run_activities 
                WHERE health_profile_id = NEW.health_profile_id 
                AND DATE(started_at) = v_date AND deleted_at IS NULL
            ),
            walk_count = (
                SELECT COUNT(*) FROM public.run_activities 
                WHERE health_profile_id = NEW.health_profile_id 
                AND DATE(started_at) = v_date AND activity_type = 'walk' AND deleted_at IS NULL
            ),
            run_count = (
                SELECT COUNT(*) FROM public.run_activities 
                WHERE health_profile_id = NEW.health_profile_id 
                AND DATE(started_at) = v_date AND activity_type = 'run' AND deleted_at IS NULL
            ),
            commute_count = (
                SELECT COUNT(*) FROM public.run_activities 
                WHERE health_profile_id = NEW.health_profile_id 
                AND DATE(started_at) = v_date AND activity_type = 'commute' AND deleted_at IS NULL
            ),
            updated_at = NOW()
        WHERE health_profile_id = NEW.health_profile_id AND summary_date = v_date;
    ELSE
        -- Insert new summary
        INSERT INTO public.daily_activity_summaries (
            health_profile_id, summary_date, total_steps, total_distance_meters,
            total_calories, total_points, total_duration_seconds,
            walk_count, run_count, commute_count
        ) VALUES (
            NEW.health_profile_id, v_date, NEW.steps, NEW.distance_meters,
            NEW.calories_burned, NEW.points_earned, NEW.duration_seconds,
            CASE WHEN NEW.activity_type = 'walk' THEN 1 ELSE 0 END,
            CASE WHEN NEW.activity_type = 'run' THEN 1 ELSE 0 END,
            CASE WHEN NEW.activity_type = 'commute' THEN 1 ELSE 0 END
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-update daily summary
CREATE TRIGGER update_daily_summary_on_activity
    AFTER INSERT OR UPDATE ON public.run_activities
    FOR EACH ROW EXECUTE FUNCTION public.update_daily_activity_summary();
