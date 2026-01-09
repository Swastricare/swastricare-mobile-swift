-- ============================================================================
-- MEDICATIONS MODULE
-- ============================================================================
-- Tables: medications, medication_schedules, medication_logs

-- ============================================================================
-- MEDICATIONS TABLE
-- ============================================================================
CREATE TABLE public.medications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Medicine details
    name VARCHAR(200) NOT NULL,
    generic_name VARCHAR(200),
    brand VARCHAR(100),
    
    -- Dosage
    dosage VARCHAR(50),
    dosage_unit VARCHAR(30),
    strength VARCHAR(50),
    
    -- Form and route
    form VARCHAR(30) CHECK (form IN (
        'tablet', 'capsule', 'syrup', 'injection', 'drops', 'inhaler',
        'cream', 'ointment', 'patch', 'suppository', 'powder', 'other'
    )),
    route VARCHAR(30) CHECK (route IN (
        'oral', 'topical', 'injection', 'inhalation', 'sublingual',
        'rectal', 'nasal', 'ophthalmic', 'otic', 'other'
    )),
    
    -- Visual identification
    color VARCHAR(50),
    shape VARCHAR(50),
    imprint VARCHAR(50),
    image_url TEXT,
    
    -- Prescription info
    is_prescription BOOLEAN DEFAULT false,
    prescribed_by VARCHAR(100),
    prescription_date DATE,
    prescription_number VARCHAR(50),
    
    -- Instructions
    instructions TEXT,
    purpose TEXT,
    warnings TEXT,
    side_effects TEXT[],
    
    -- Inventory
    current_quantity INT DEFAULT 0,
    refill_threshold INT,
    refill_quantity INT,
    
    -- Duration
    start_date DATE,
    end_date DATE,
    is_ongoing BOOLEAN DEFAULT true,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active', 'paused', 'completed', 'discontinued'
    )),
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- MEDICATION SCHEDULES TABLE
-- ============================================================================
CREATE TABLE public.medication_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    medication_id UUID NOT NULL REFERENCES public.medications(id) ON DELETE CASCADE,
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Schedule type
    schedule_type VARCHAR(20) DEFAULT 'daily' CHECK (schedule_type IN (
        'daily', 'weekly', 'monthly', 'as_needed', 'custom'
    )),
    
    -- Timing
    time_of_day TIME NOT NULL,
    timezone VARCHAR(50) DEFAULT 'UTC',
    
    -- Frequency
    frequency_per_day INT DEFAULT 1,
    interval_hours INT,
    
    -- Weekly schedule
    days_of_week INT[], -- 0=Sunday, 1=Monday, etc.
    
    -- Monthly schedule
    days_of_month INT[],
    
    -- Dosage per intake
    dosage_amount DECIMAL(10,2) DEFAULT 1,
    
    -- Instructions
    take_with_food BOOLEAN,
    special_instructions TEXT,
    
    -- Reminders
    reminder_enabled BOOLEAN DEFAULT true,
    reminder_minutes_before INT DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- MEDICATION LOGS TABLE
-- ============================================================================
CREATE TABLE public.medication_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    medication_id UUID NOT NULL REFERENCES public.medications(id) ON DELETE CASCADE,
    schedule_id UUID REFERENCES public.medication_schedules(id) ON DELETE SET NULL,
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Scheduled vs actual
    scheduled_time TIMESTAMPTZ,
    taken_time TIMESTAMPTZ,
    
    -- Status
    status VARCHAR(20) NOT NULL CHECK (status IN (
        'taken', 'skipped', 'missed', 'late', 'early'
    )),
    
    -- Dosage
    dosage_taken DECIMAL(10,2),
    
    -- Context
    skip_reason TEXT,
    notes TEXT,
    
    -- Side effects reported
    side_effects_reported TEXT[],
    mood_after VARCHAR(20),
    
    -- Who logged it
    logged_by UUID REFERENCES public.users(id),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_medications_profile ON public.medications(health_profile_id);
CREATE INDEX idx_medications_status ON public.medications(health_profile_id, status);
CREATE INDEX idx_medication_schedules_medication ON public.medication_schedules(medication_id);
CREATE INDEX idx_medication_schedules_profile ON public.medication_schedules(health_profile_id);
CREATE INDEX idx_medication_schedules_active ON public.medication_schedules(health_profile_id) WHERE is_active = true;
CREATE INDEX idx_medication_logs_medication ON public.medication_logs(medication_id);
CREATE INDEX idx_medication_logs_profile_date ON public.medication_logs(health_profile_id, created_at DESC);
CREATE INDEX idx_medication_logs_scheduled ON public.medication_logs(scheduled_time);

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER medications_updated_at
    BEFORE UPDATE ON public.medications
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER medication_schedules_updated_at
    BEFORE UPDATE ON public.medication_schedules
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
