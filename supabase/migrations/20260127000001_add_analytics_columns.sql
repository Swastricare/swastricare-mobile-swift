-- ============================================================================
-- RUN ACTIVITY ANALYTICS COLUMNS MIGRATION
-- ============================================================================
-- Adds columns for storing detailed analytics data:
-- - splits: Per-kilometer breakdown
-- - pace_samples: Pace data points for graphing
-- - heart_rate_samples: HR data points for graphing

-- ============================================================================
-- ADD SPLITS COLUMN
-- ============================================================================
-- Stores per-kilometer split data as JSONB array
-- Format: [{id: 1, distanceMeters: 1000, durationSeconds: 360, paceSecondsPerKm: 360, 
--           elevationGain: 15, elevationLoss: 5, avgHeartRate: 150, startTime: "ISO8601", endTime: "ISO8601"}]
ALTER TABLE public.run_activities 
ADD COLUMN IF NOT EXISTS splits JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.run_activities.splits IS 'Per-kilometer split breakdown with pace, time, and elevation data';

-- ============================================================================
-- ADD PACE SAMPLES COLUMN
-- ============================================================================
-- Stores pace samples for graphing pace over distance
-- Format: [{distanceKm: 0.5, paceSecondsPerKm: 360, timestamp: "ISO8601", speedKmh: 10.0}]
ALTER TABLE public.run_activities 
ADD COLUMN IF NOT EXISTS pace_samples JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.run_activities.pace_samples IS 'Pace samples for graphing pace variation over distance';

-- ============================================================================
-- ADD HEART RATE SAMPLES COLUMN
-- ============================================================================
-- Stores heart rate samples for detailed HR graphing
-- Format: [{bpm: 145, timestamp: "ISO8601", distanceKm: 2.5}]
ALTER TABLE public.run_activities 
ADD COLUMN IF NOT EXISTS heart_rate_samples JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.run_activities.heart_rate_samples IS 'Heart rate samples for graphing HR over time';

-- ============================================================================
-- ADD HEART RATE ZONE DISTRIBUTION COLUMN
-- ============================================================================
-- Stores time spent in each heart rate zone (in seconds)
-- Format: {recovery: 120, fatBurn: 300, cardio: 600, peak: 480, maximum: 60}
ALTER TABLE public.run_activities 
ADD COLUMN IF NOT EXISTS hr_zone_distribution JSONB DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.run_activities.hr_zone_distribution IS 'Time spent in each heart rate zone (seconds)';

-- ============================================================================
-- ADD BEST/WORST SPLIT INDEXES
-- ============================================================================
ALTER TABLE public.run_activities 
ADD COLUMN IF NOT EXISTS best_split_index INT;

ALTER TABLE public.run_activities 
ADD COLUMN IF NOT EXISTS worst_split_index INT;

COMMENT ON COLUMN public.run_activities.best_split_index IS 'Index of the fastest split (0-based)';
COMMENT ON COLUMN public.run_activities.worst_split_index IS 'Index of the slowest split (0-based)';

-- ============================================================================
-- ADD COMPUTED PACE STATS
-- ============================================================================
ALTER TABLE public.run_activities 
ADD COLUMN IF NOT EXISTS best_pace_seconds_per_km INT;

COMMENT ON COLUMN public.run_activities.best_pace_seconds_per_km IS 'Fastest pace achieved during activity (seconds/km)';

-- ============================================================================
-- ADD INDEX FOR ANALYTICS QUERIES
-- ============================================================================
-- Index for querying activities by date for calendar views
CREATE INDEX IF NOT EXISTS idx_run_activities_date 
ON public.run_activities(health_profile_id, DATE(started_at))
WHERE deleted_at IS NULL;

-- ============================================================================
-- FUNCTION TO CALCULATE SPLITS FROM ROUTE COORDINATES
-- ============================================================================
-- This function can be called to recalculate splits server-side if needed
CREATE OR REPLACE FUNCTION public.calculate_activity_splits(
    p_activity_id UUID
) RETURNS JSONB AS $$
DECLARE
    v_route JSONB;
    v_splits JSONB := '[]'::jsonb;
    v_current_split JSONB;
    v_total_distance DECIMAL := 0;
    v_split_distance DECIMAL := 0;
    v_split_start_idx INT := 0;
    v_split_number INT := 1;
    v_coord JSONB;
    v_prev_coord JSONB;
    v_distance DECIMAL;
    v_i INT;
BEGIN
    -- Get route coordinates
    SELECT route_coordinates INTO v_route
    FROM public.run_activities
    WHERE id = p_activity_id;
    
    IF v_route IS NULL OR jsonb_array_length(v_route) < 2 THEN
        RETURN '[]'::jsonb;
    END IF;
    
    -- Note: This is a placeholder - actual distance calculation would need
    -- to use the Haversine formula, which is complex in pure SQL
    -- In practice, splits should be calculated client-side or in an Edge Function
    
    RETURN v_splits;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- TRIGGER TO UPDATE BEST PACE ON INSERT/UPDATE
-- ============================================================================
CREATE OR REPLACE FUNCTION public.update_activity_best_pace()
RETURNS TRIGGER AS $$
BEGIN
    -- Calculate best pace from splits if available
    IF NEW.splits IS NOT NULL AND jsonb_array_length(NEW.splits) > 0 THEN
        SELECT MIN((elem->>'paceSecondsPerKm')::INT)
        INTO NEW.best_pace_seconds_per_km
        FROM jsonb_array_elements(NEW.splits) AS elem
        WHERE (elem->>'paceSecondsPerKm')::INT > 0;
        
        -- Find best split index
        SELECT idx - 1
        INTO NEW.best_split_index
        FROM (
            SELECT ROW_NUMBER() OVER () AS idx, elem
            FROM jsonb_array_elements(NEW.splits) AS elem
        ) AS indexed
        WHERE (elem->>'paceSecondsPerKm')::INT = NEW.best_pace_seconds_per_km
        LIMIT 1;
        
        -- Find worst split index
        SELECT idx - 1
        INTO NEW.worst_split_index
        FROM (
            SELECT ROW_NUMBER() OVER () AS idx, elem
            FROM jsonb_array_elements(NEW.splits) AS elem
        ) AS indexed
        WHERE (elem->>'paceSecondsPerKm')::INT = (
            SELECT MAX((e->>'paceSecondsPerKm')::INT)
            FROM jsonb_array_elements(NEW.splits) AS e
            WHERE (e->>'paceSecondsPerKm')::INT > 0
        )
        LIMIT 1;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger if it doesn't exist
DROP TRIGGER IF EXISTS update_best_pace_trigger ON public.run_activities;
CREATE TRIGGER update_best_pace_trigger
    BEFORE INSERT OR UPDATE OF splits ON public.run_activities
    FOR EACH ROW
    EXECUTE FUNCTION public.update_activity_best_pace();

-- ============================================================================
-- SAMPLE DATA VALIDATION FUNCTION
-- ============================================================================
-- Function to validate the structure of splits data
CREATE OR REPLACE FUNCTION public.validate_splits_structure(splits JSONB)
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if it's an array
    IF jsonb_typeof(splits) != 'array' THEN
        RETURN FALSE;
    END IF;
    
    -- Check each element has required fields
    IF EXISTS (
        SELECT 1 
        FROM jsonb_array_elements(splits) AS elem
        WHERE NOT (
            elem ? 'id' AND
            elem ? 'distanceMeters' AND
            elem ? 'durationSeconds' AND
            elem ? 'paceSecondsPerKm'
        )
    ) THEN
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
