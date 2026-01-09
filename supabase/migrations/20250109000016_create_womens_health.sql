-- ============================================================================
-- WOMEN'S HEALTH MODULE
-- ============================================================================
-- Tables: menstrual_cycles, pregnancy_tracking, pregnancy_logs

-- ============================================================================
-- MENSTRUAL CYCLES TABLE
-- ============================================================================
CREATE TABLE public.menstrual_cycles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Period dates
    period_start DATE NOT NULL,
    period_end DATE,
    
    -- Cycle info
    cycle_length INT,
    period_length INT,
    
    -- Flow
    flow_intensity VARCHAR(20) CHECK (flow_intensity IN (
        'spotting', 'light', 'medium', 'heavy', 'very_heavy'
    )),
    
    -- Flow by day (JSONB for flexibility)
    daily_flow JSONB,
    -- Structure: [{day: 1, intensity: 'medium', notes: ''}]
    
    -- Symptoms
    symptoms TEXT[],
    symptom_severity JSONB,
    -- Structure: {cramps: 3, headache: 2, bloating: 4} (1-5 scale)
    
    -- Pain
    pain_level INT CHECK (pain_level BETWEEN 0 AND 10),
    pain_location TEXT[],
    pain_relief_used TEXT[],
    
    -- Mood
    mood TEXT[],
    mood_notes TEXT,
    
    -- Energy and sleep
    energy_level INT CHECK (energy_level BETWEEN 1 AND 5),
    sleep_quality INT CHECK (sleep_quality BETWEEN 1 AND 5),
    
    -- Fertility tracking (optional)
    ovulation_date DATE,
    ovulation_confirmed BOOLEAN DEFAULT false,
    ovulation_symptoms TEXT[],
    
    -- Fertile window
    fertile_window_start DATE,
    fertile_window_end DATE,
    
    -- BBT tracking
    basal_body_temp DECIMAL(4,2),
    
    -- Cervical mucus
    cervical_mucus VARCHAR(30) CHECK (cervical_mucus IN (
        'dry', 'sticky', 'creamy', 'watery', 'egg_white', 'none'
    )),
    
    -- Intimacy (optional)
    intimacy_logged BOOLEAN DEFAULT false,
    protection_used BOOLEAN,
    protection_type VARCHAR(30),
    
    -- Predictions
    predicted_period_start DATE,
    predicted_ovulation DATE,
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- PREGNANCY TRACKING TABLE
-- ============================================================================
CREATE TABLE public.pregnancy_tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Key dates
    last_menstrual_period DATE,
    conception_date DATE,
    due_date DATE NOT NULL,
    
    -- Current status
    current_week INT,
    current_trimester INT,
    
    -- Baby info
    baby_name VARCHAR(100),
    baby_gender VARCHAR(20),
    is_multiple BOOLEAN DEFAULT false,
    number_of_babies INT DEFAULT 1,
    
    -- Healthcare
    obgyn_name VARCHAR(100),
    obgyn_contact VARCHAR(20),
    hospital_name VARCHAR(200),
    hospital_contact VARCHAR(20),
    
    -- Birth plan
    birth_plan_type VARCHAR(30) CHECK (birth_plan_type IN (
        'vaginal', 'c_section_planned', 'vbac', 'water_birth',
        'home_birth', 'undecided'
    )),
    birth_plan_notes TEXT,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active', 'delivered', 'miscarriage', 'ectopic', 'ended'
    )),
    
    -- Delivery
    delivery_date DATE,
    delivery_type VARCHAR(30),
    delivery_location VARCHAR(200),
    
    -- Baby at birth
    baby_weight_kg DECIMAL(4,3),
    baby_height_cm DECIMAL(5,2),
    apgar_score_1min INT,
    apgar_score_5min INT,
    
    -- Complications
    complications TEXT[],
    high_risk BOOLEAN DEFAULT false,
    high_risk_factors TEXT[],
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- PREGNANCY LOGS TABLE
-- ============================================================================
CREATE TABLE public.pregnancy_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pregnancy_id UUID NOT NULL REFERENCES public.pregnancy_tracking(id) ON DELETE CASCADE,
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Log date
    log_date DATE NOT NULL,
    week_number INT,
    day_of_week INT,
    
    -- Weight tracking
    weight_kg DECIMAL(5,2),
    weight_change_kg DECIMAL(4,2),
    
    -- Vitals
    blood_pressure_systolic INT,
    blood_pressure_diastolic INT,
    heart_rate INT,
    temperature_celsius DECIMAL(4,2),
    
    -- Baby movement
    baby_movement VARCHAR(20) CHECK (baby_movement IN (
        'none', 'light', 'moderate', 'active', 'very_active'
    )),
    kick_count INT,
    first_kick_time TIME,
    kick_session_duration_mins INT,
    
    -- Baby heartbeat
    baby_heartbeat INT,
    heartbeat_recorded_at TIMESTAMPTZ,
    
    -- Symptoms
    symptoms TEXT[],
    symptom_severity JSONB,
    
    -- Common pregnancy symptoms
    nausea_level INT CHECK (nausea_level BETWEEN 0 AND 5),
    fatigue_level INT CHECK (fatigue_level BETWEEN 0 AND 5),
    back_pain_level INT CHECK (back_pain_level BETWEEN 0 AND 5),
    swelling_level INT CHECK (swelling_level BETWEEN 0 AND 5),
    
    -- Contractions
    contractions_count INT,
    contractions_notes TEXT,
    braxton_hicks BOOLEAN DEFAULT false,
    
    -- Mood and energy
    mood TEXT[],
    energy_level INT CHECK (energy_level BETWEEN 1 AND 5),
    anxiety_level INT CHECK (anxiety_level BETWEEN 0 AND 5),
    
    -- Sleep
    sleep_hours DECIMAL(4,2),
    sleep_quality INT CHECK (sleep_quality BETWEEN 1 AND 5),
    sleep_position VARCHAR(20),
    
    -- Nutrition
    water_intake_ml INT,
    prenatal_vitamin_taken BOOLEAN,
    meals_logged INT,
    
    -- Exercise
    exercise_type VARCHAR(50),
    exercise_duration_mins INT,
    
    -- Appointments
    appointment_notes TEXT,
    ultrasound_notes TEXT,
    
    -- Medical
    medications_taken TEXT[],
    concerns TEXT[],
    questions_for_doctor TEXT[],
    
    -- Photos
    bump_photo_url TEXT,
    ultrasound_photo_url TEXT,
    
    -- Notes
    notes TEXT,
    journal_entry TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(pregnancy_id, log_date)
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_menstrual_cycles_profile ON public.menstrual_cycles(health_profile_id);
CREATE INDEX idx_menstrual_cycles_date ON public.menstrual_cycles(health_profile_id, period_start DESC);
CREATE INDEX idx_menstrual_cycles_ovulation ON public.menstrual_cycles(health_profile_id, ovulation_date) 
    WHERE ovulation_date IS NOT NULL;
CREATE INDEX idx_pregnancy_tracking_profile ON public.pregnancy_tracking(health_profile_id);
CREATE INDEX idx_pregnancy_tracking_active ON public.pregnancy_tracking(health_profile_id) WHERE status = 'active';
CREATE INDEX idx_pregnancy_logs_pregnancy ON public.pregnancy_logs(pregnancy_id);
CREATE INDEX idx_pregnancy_logs_date ON public.pregnancy_logs(pregnancy_id, log_date DESC);
CREATE INDEX idx_pregnancy_logs_week ON public.pregnancy_logs(pregnancy_id, week_number);

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER menstrual_cycles_updated_at
    BEFORE UPDATE ON public.menstrual_cycles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER pregnancy_tracking_updated_at
    BEFORE UPDATE ON public.pregnancy_tracking
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER pregnancy_logs_updated_at
    BEFORE UPDATE ON public.pregnancy_logs
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
