-- ============================================================================
-- HEALTH METRICS MODULE
-- ============================================================================
-- Tables: daily_health_metrics, vital_signs, activity_logs, hydration_logs, nutrition_logs

-- ============================================================================
-- DAILY HEALTH METRICS TABLE
-- ============================================================================
CREATE TABLE public.daily_health_metrics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Date (one record per day)
    metric_date DATE NOT NULL,
    
    -- Weight
    weight_kg DECIMAL(5,2),
    
    -- Sleep
    sleep_hours DECIMAL(4,2),
    sleep_quality INT CHECK (sleep_quality BETWEEN 1 AND 5),
    bedtime TIME,
    wake_time TIME,
    
    -- Energy & Mood
    energy_level INT CHECK (energy_level BETWEEN 1 AND 5),
    mood VARCHAR(20) CHECK (mood IN (
        'excellent', 'good', 'okay', 'low', 'bad'
    )),
    stress_level INT CHECK (stress_level BETWEEN 1 AND 10),
    
    -- Summary stats (aggregated)
    total_steps INT,
    total_calories_burned INT,
    total_active_minutes INT,
    total_water_ml INT,
    total_calories_consumed INT,
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(health_profile_id, metric_date)
);

-- ============================================================================
-- VITAL SIGNS TABLE
-- ============================================================================
CREATE TABLE public.vital_signs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Measurement time
    measured_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Blood pressure
    blood_pressure_systolic INT,
    blood_pressure_diastolic INT,
    blood_pressure_position VARCHAR(20), -- sitting, standing, lying
    
    -- Heart
    heart_rate INT,
    heart_rate_variability DECIMAL(5,2),
    resting_heart_rate INT,
    
    -- Respiratory
    respiratory_rate INT,
    oxygen_saturation DECIMAL(4,1),
    peak_flow DECIMAL(6,2),
    
    -- Temperature
    temperature_celsius DECIMAL(4,2),
    temperature_location VARCHAR(20), -- oral, ear, forehead, armpit
    
    -- Blood sugar
    blood_glucose DECIMAL(6,2),
    blood_glucose_unit VARCHAR(10) DEFAULT 'mg/dL',
    blood_glucose_type VARCHAR(20) CHECK (blood_glucose_type IN (
        'fasting', 'pre_meal', 'post_meal', 'random', 'bedtime'
    )),
    
    -- Context
    measurement_context VARCHAR(30), -- at_rest, after_exercise, after_meal
    device_used VARCHAR(100),
    
    -- Notes
    notes TEXT,
    
    -- Who recorded
    recorded_by UUID REFERENCES public.users(id),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- ACTIVITY LOGS TABLE
-- ============================================================================
CREATE TABLE public.activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Activity details
    activity_type VARCHAR(50) NOT NULL,
    activity_name VARCHAR(100),
    
    -- Duration and timing
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    duration_minutes INT,
    
    -- Metrics
    distance_km DECIMAL(8,3),
    steps INT,
    calories_burned INT,
    
    -- Heart rate during activity
    avg_heart_rate INT,
    max_heart_rate INT,
    min_heart_rate INT,
    
    -- Intensity
    intensity VARCHAR(20) CHECK (intensity IN (
        'light', 'moderate', 'vigorous', 'very_vigorous'
    )),
    
    -- Location
    location_name VARCHAR(200),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    
    -- Source
    source VARCHAR(50), -- manual, apple_health, google_fit, device
    source_id VARCHAR(100),
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- HYDRATION LOGS TABLE
-- ============================================================================
CREATE TABLE public.hydration_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- What was consumed
    beverage_type VARCHAR(30) DEFAULT 'water' CHECK (beverage_type IN (
        'water', 'tea', 'coffee', 'juice', 'milk', 'sports_drink',
        'smoothie', 'soda', 'alcohol', 'other'
    )),
    
    -- Amount
    amount_ml INT NOT NULL,
    
    -- Timing
    consumed_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Context
    container_type VARCHAR(30), -- glass, bottle, cup
    temperature VARCHAR(20), -- cold, room_temp, warm, hot
    
    -- Hydration value (water = 1.0, coffee = 0.8, alcohol = negative)
    hydration_factor DECIMAL(3,2) DEFAULT 1.0,
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- NUTRITION LOGS TABLE
-- ============================================================================
CREATE TABLE public.nutrition_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Meal info
    meal_type VARCHAR(20) NOT NULL CHECK (meal_type IN (
        'breakfast', 'lunch', 'dinner', 'snack', 'beverage'
    )),
    meal_time TIMESTAMPTZ DEFAULT NOW(),
    
    -- Food details
    food_name VARCHAR(200) NOT NULL,
    description TEXT,
    serving_size VARCHAR(50),
    servings DECIMAL(4,2) DEFAULT 1,
    
    -- Calories
    calories INT,
    
    -- Macros (in grams)
    protein_g DECIMAL(6,2),
    carbs_g DECIMAL(6,2),
    fat_g DECIMAL(6,2),
    fiber_g DECIMAL(6,2),
    sugar_g DECIMAL(6,2),
    
    -- Micros
    sodium_mg DECIMAL(8,2),
    potassium_mg DECIMAL(8,2),
    cholesterol_mg DECIMAL(8,2),
    
    -- Vitamins (as percentage of daily value)
    vitamin_a_pct DECIMAL(5,2),
    vitamin_c_pct DECIMAL(5,2),
    vitamin_d_pct DECIMAL(5,2),
    calcium_pct DECIMAL(5,2),
    iron_pct DECIMAL(5,2),
    
    -- Image
    image_url TEXT,
    
    -- Source
    source VARCHAR(50), -- manual, barcode, ai_detected
    barcode VARCHAR(50),
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_daily_metrics_profile_date ON public.daily_health_metrics(health_profile_id, metric_date DESC);
CREATE INDEX idx_vital_signs_profile_date ON public.vital_signs(health_profile_id, measured_at DESC);
CREATE INDEX idx_vital_signs_glucose ON public.vital_signs(health_profile_id, measured_at DESC) WHERE blood_glucose IS NOT NULL;
CREATE INDEX idx_activity_logs_profile_date ON public.activity_logs(health_profile_id, started_at DESC);
CREATE INDEX idx_activity_logs_type ON public.activity_logs(health_profile_id, activity_type);
CREATE INDEX idx_hydration_logs_profile_date ON public.hydration_logs(health_profile_id, consumed_at DESC);
CREATE INDEX idx_nutrition_logs_profile_date ON public.nutrition_logs(health_profile_id, meal_time DESC);
CREATE INDEX idx_nutrition_logs_meal_type ON public.nutrition_logs(health_profile_id, meal_type, meal_time DESC);

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER daily_health_metrics_updated_at
    BEFORE UPDATE ON public.daily_health_metrics
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
