-- ============================================================================
-- CONDITIONS MODULE
-- ============================================================================
-- Tables: chronic_conditions, allergies, emergency_contacts

-- ============================================================================
-- CHRONIC CONDITIONS TABLE
-- ============================================================================
CREATE TABLE public.chronic_conditions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Condition details
    condition_name VARCHAR(200) NOT NULL,
    icd_code VARCHAR(20), -- International Classification of Diseases code
    
    -- Category
    category VARCHAR(50) CHECK (category IN (
        'cardiovascular', 'respiratory', 'endocrine', 'neurological',
        'musculoskeletal', 'gastrointestinal', 'renal', 'mental_health',
        'autoimmune', 'cancer', 'infectious', 'genetic', 'other'
    )),
    
    -- Severity
    severity VARCHAR(20) CHECK (severity IN (
        'mild', 'moderate', 'severe', 'critical'
    )),
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active', 'managed', 'in_remission', 'resolved', 'monitoring'
    )),
    
    -- Dates
    diagnosed_date DATE,
    resolved_date DATE,
    
    -- Diagnosed by
    diagnosed_by VARCHAR(100),
    diagnosing_facility VARCHAR(200),
    
    -- Treatment
    current_treatment TEXT,
    medications_for_condition UUID[], -- Array of medication IDs
    
    -- Monitoring
    monitoring_frequency VARCHAR(30),
    last_checkup_date DATE,
    next_checkup_date DATE,
    
    -- Impact
    daily_life_impact TEXT,
    work_restrictions TEXT,
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- ALLERGIES TABLE
-- ============================================================================
CREATE TABLE public.allergies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Allergen details
    allergen_name VARCHAR(200) NOT NULL,
    
    -- Type
    allergy_type VARCHAR(30) NOT NULL CHECK (allergy_type IN (
        'food', 'medication', 'environmental', 'insect',
        'latex', 'animal', 'contact', 'other'
    )),
    
    -- Severity
    severity VARCHAR(20) NOT NULL CHECK (severity IN (
        'mild', 'moderate', 'severe', 'life_threatening'
    )),
    
    -- Reaction details
    reaction_description TEXT,
    symptoms TEXT[],
    
    -- Onset
    onset_type VARCHAR(20) CHECK (onset_type IN (
        'immediate', 'delayed', 'unknown'
    )),
    onset_time_minutes INT,
    
    -- First occurrence
    first_reaction_date DATE,
    
    -- Diagnosis
    confirmed_by VARCHAR(20) CHECK (confirmed_by IN (
        'self_reported', 'doctor_diagnosed', 'allergy_test', 'unknown'
    )),
    test_type VARCHAR(50), -- skin_prick, blood_test, etc.
    test_date DATE,
    
    -- Treatment
    emergency_treatment TEXT,
    carries_epipen BOOLEAN DEFAULT false,
    
    -- Cross-reactivity
    cross_reactive_allergens TEXT[],
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active', 'outgrown', 'under_treatment', 'resolved'
    )),
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- EMERGENCY CONTACTS TABLE
-- ============================================================================
CREATE TABLE public.emergency_contacts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Contact details
    name VARCHAR(100) NOT NULL,
    relationship VARCHAR(50) NOT NULL,
    
    -- Phone numbers
    phone_primary VARCHAR(20) NOT NULL,
    phone_secondary VARCHAR(20),
    
    -- Other contact
    email VARCHAR(255),
    
    -- Address
    address TEXT,
    city VARCHAR(100),
    
    -- Priority
    priority INT DEFAULT 1, -- 1 = primary, 2 = secondary, etc.
    
    -- Permissions
    can_make_medical_decisions BOOLEAN DEFAULT false,
    has_medical_power_of_attorney BOOLEAN DEFAULT false,
    
    -- Availability
    best_time_to_call VARCHAR(50),
    languages TEXT[],
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_chronic_conditions_profile ON public.chronic_conditions(health_profile_id);
CREATE INDEX idx_chronic_conditions_status ON public.chronic_conditions(health_profile_id, status);
CREATE INDEX idx_chronic_conditions_category ON public.chronic_conditions(health_profile_id, category);
CREATE INDEX idx_allergies_profile ON public.allergies(health_profile_id);
CREATE INDEX idx_allergies_type ON public.allergies(health_profile_id, allergy_type);
CREATE INDEX idx_allergies_severity ON public.allergies(health_profile_id, severity);
CREATE INDEX idx_emergency_contacts_profile ON public.emergency_contacts(health_profile_id);
CREATE INDEX idx_emergency_contacts_priority ON public.emergency_contacts(health_profile_id, priority);

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER chronic_conditions_updated_at
    BEFORE UPDATE ON public.chronic_conditions
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER allergies_updated_at
    BEFORE UPDATE ON public.allergies
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER emergency_contacts_updated_at
    BEFORE UPDATE ON public.emergency_contacts
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
