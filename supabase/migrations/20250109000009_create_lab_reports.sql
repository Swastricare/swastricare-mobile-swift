-- ============================================================================
-- LAB REPORTS MODULE
-- ============================================================================
-- Tables: lab_test_catalog, lab_reports, lab_test_results, lab_report_shares

-- ============================================================================
-- LAB TEST CATALOG TABLE (Master list)
-- ============================================================================
CREATE TABLE public.lab_test_catalog (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Test identification
    test_code VARCHAR(50) UNIQUE,
    test_name VARCHAR(200) NOT NULL,
    
    -- Categorization
    category VARCHAR(50) CHECK (category IN (
        'hematology', 'biochemistry', 'immunology', 'microbiology',
        'endocrinology', 'cardiology', 'hepatology', 'renal',
        'lipid', 'thyroid', 'diabetes', 'vitamins', 'tumor_markers',
        'coagulation', 'urinalysis', 'other'
    )),
    sub_category VARCHAR(50),
    
    -- Description
    description TEXT,
    also_known_as TEXT[],
    
    -- Units and ranges
    unit VARCHAR(50),
    normal_range_min DECIMAL(10,4),
    normal_range_max DECIMAL(10,4),
    normal_range_text VARCHAR(100),
    
    -- Critical values
    critical_low DECIMAL(10,4),
    critical_high DECIMAL(10,4),
    
    -- Gender-specific ranges
    male_range_min DECIMAL(10,4),
    male_range_max DECIMAL(10,4),
    female_range_min DECIMAL(10,4),
    female_range_max DECIMAL(10,4),
    
    -- Age-specific ranges (as JSONB for flexibility)
    age_specific_ranges JSONB,
    
    -- Test requirements
    fasting_required BOOLEAN DEFAULT false,
    fasting_hours INT,
    special_instructions TEXT,
    
    -- Sample info
    sample_type VARCHAR(50),
    sample_volume_ml DECIMAL(5,2),
    
    -- Common conditions tested for
    conditions_tested TEXT[],
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- LAB REPORTS TABLE
-- ============================================================================
CREATE TABLE public.lab_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    document_id UUID REFERENCES public.medical_documents(id),
    
    -- Report details
    report_number VARCHAR(50),
    report_date DATE NOT NULL,
    
    -- Lab info
    lab_name VARCHAR(200),
    lab_address TEXT,
    lab_accreditation VARCHAR(100),
    lab_contact VARCHAR(50),
    
    -- Doctor info
    ordering_doctor VARCHAR(100),
    referring_doctor VARCHAR(100),
    
    -- Sample info
    sample_type VARCHAR(50),
    sample_id VARCHAR(50),
    sample_collected_at TIMESTAMPTZ,
    sample_received_at TIMESTAMPTZ,
    report_generated_at TIMESTAMPTZ,
    
    -- Report status
    status VARCHAR(20) DEFAULT 'completed' CHECK (status IN (
        'pending', 'processing', 'completed', 'requires_repeat'
    )),
    
    -- AI analysis
    ai_summary TEXT,
    ai_concerns TEXT[],
    ai_recommendations TEXT[],
    overall_status VARCHAR(20) CHECK (overall_status IN (
        'all_normal', 'some_abnormal', 'review_required', 'urgent'
    )),
    
    -- Notes
    lab_notes TEXT,
    doctor_notes TEXT,
    personal_notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- LAB TEST RESULTS TABLE
-- ============================================================================
CREATE TABLE public.lab_test_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lab_report_id UUID NOT NULL REFERENCES public.lab_reports(id) ON DELETE CASCADE,
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Test info
    test_catalog_id UUID REFERENCES public.lab_test_catalog(id),
    test_name VARCHAR(200) NOT NULL,
    test_code VARCHAR(50),
    
    -- Result
    value_numeric DECIMAL(15,4),
    value_text VARCHAR(200),
    unit VARCHAR(50),
    
    -- Reference ranges (from this specific report)
    reference_min DECIMAL(10,4),
    reference_max DECIMAL(10,4),
    reference_text VARCHAR(100),
    
    -- Interpretation
    status VARCHAR(20) CHECK (status IN (
        'normal', 'low', 'high', 'critical_low', 'critical_high', 'abnormal'
    )),
    interpretation TEXT,
    
    -- Trend analysis
    previous_value DECIMAL(15,4),
    previous_date DATE,
    trend VARCHAR(20) CHECK (trend IN (
        'improving', 'stable', 'worsening', 'new', 'fluctuating'
    )),
    percent_change DECIMAL(6,2),
    
    -- Flags
    is_flagged BOOLEAN DEFAULT false,
    flag_reason TEXT,
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- LAB REPORT SHARES TABLE
-- ============================================================================
CREATE TABLE public.lab_report_shares (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lab_report_id UUID NOT NULL REFERENCES public.lab_reports(id) ON DELETE CASCADE,
    shared_by UUID NOT NULL REFERENCES public.users(id),
    
    -- Share with
    shared_with_email VARCHAR(255),
    shared_with_phone VARCHAR(20),
    shared_with_doctor_id UUID REFERENCES public.healthcare_providers(id),
    
    -- Access control
    access_code VARCHAR(20),
    access_link TEXT,
    
    -- Permissions
    can_download BOOLEAN DEFAULT true,
    can_print BOOLEAN DEFAULT true,
    
    -- Validity
    expires_at TIMESTAMPTZ,
    max_access_count INT,
    
    -- Tracking
    access_count INT DEFAULT 0,
    first_accessed_at TIMESTAMPTZ,
    last_accessed_at TIMESTAMPTZ,
    
    -- Status
    is_revoked BOOLEAN DEFAULT false,
    revoked_at TIMESTAMPTZ,
    
    -- Message
    share_message TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_lab_test_catalog_code ON public.lab_test_catalog(test_code);
CREATE INDEX idx_lab_test_catalog_category ON public.lab_test_catalog(category);
CREATE INDEX idx_lab_reports_profile ON public.lab_reports(health_profile_id);
CREATE INDEX idx_lab_reports_date ON public.lab_reports(health_profile_id, report_date DESC);
CREATE INDEX idx_lab_reports_status ON public.lab_reports(health_profile_id, overall_status);
CREATE INDEX idx_lab_test_results_report ON public.lab_test_results(lab_report_id);
CREATE INDEX idx_lab_test_results_profile ON public.lab_test_results(health_profile_id);
CREATE INDEX idx_lab_test_results_test ON public.lab_test_results(health_profile_id, test_code, created_at DESC);
CREATE INDEX idx_lab_test_results_status ON public.lab_test_results(health_profile_id, status) WHERE status != 'normal';
CREATE INDEX idx_lab_report_shares_report ON public.lab_report_shares(lab_report_id);
CREATE INDEX idx_lab_report_shares_code ON public.lab_report_shares(access_code) WHERE is_revoked = false;

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER lab_reports_updated_at
    BEFORE UPDATE ON public.lab_reports
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
