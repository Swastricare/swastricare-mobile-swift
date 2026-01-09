-- ============================================================================
-- INSURANCE & BILLING MODULE
-- ============================================================================
-- Tables: insurance_providers, insurance_policies, insurance_claims, medical_expenses

-- ============================================================================
-- INSURANCE PROVIDERS TABLE (Catalog)
-- ============================================================================
CREATE TABLE public.insurance_providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Basic info
    name VARCHAR(200) NOT NULL,
    short_name VARCHAR(50),
    logo_url TEXT,
    
    -- Type
    provider_type VARCHAR(30) CHECK (provider_type IN (
        'health', 'life', 'accident', 'critical_illness', 'government', 'corporate'
    )),
    
    -- Contact
    customer_care VARCHAR(20),
    alternate_phone VARCHAR(20),
    email VARCHAR(255),
    website VARCHAR(255),
    claim_portal VARCHAR(255),
    
    -- TPA info
    tpa_name VARCHAR(200),
    tpa_contact VARCHAR(20),
    
    -- Network
    network_hospitals_count INT,
    
    -- App
    app_available BOOLEAN DEFAULT false,
    app_url VARCHAR(255),
    
    -- Ratings
    claim_settlement_ratio DECIMAL(5,2),
    avg_rating DECIMAL(2,1),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INSURANCE POLICIES TABLE
-- ============================================================================
CREATE TABLE public.insurance_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES public.insurance_providers(id),
    
    -- Policy details
    policy_number VARCHAR(50) NOT NULL,
    policy_name VARCHAR(200),
    policy_type VARCHAR(50) CHECK (policy_type IN (
        'individual', 'family_floater', 'group', 'senior_citizen',
        'maternity', 'critical_illness', 'personal_accident', 'top_up'
    )),
    
    -- Coverage
    sum_insured DECIMAL(15,2),
    remaining_sum DECIMAL(15,2),
    
    -- Dates
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    purchase_date DATE,
    renewal_date DATE,
    
    -- Premium
    premium_amount DECIMAL(10,2),
    premium_frequency VARCHAR(20) CHECK (premium_frequency IN (
        'monthly', 'quarterly', 'half_yearly', 'yearly', 'single'
    )),
    next_premium_date DATE,
    premium_paid_until DATE,
    
    -- Documents
    document_id UUID REFERENCES public.medical_documents(id),
    policy_document_url TEXT,
    card_url TEXT,
    card_number VARCHAR(50),
    
    -- Contacts
    tpa_name VARCHAR(200),
    tpa_contact VARCHAR(20),
    agent_name VARCHAR(100),
    agent_contact VARCHAR(20),
    
    -- Coverage details
    room_rent_limit DECIMAL(10,2),
    icu_limit DECIMAL(10,2),
    copay_percentage DECIMAL(5,2),
    deductible_amount DECIMAL(10,2),
    waiting_period_days INT,
    pre_existing_waiting_months INT,
    
    -- Family members covered
    covered_members UUID[],
    
    -- Benefits
    benefits JSONB,
    exclusions TEXT[],
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active', 'expired', 'lapsed', 'cancelled', 'pending_renewal'
    )),
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INSURANCE CLAIMS TABLE
-- ============================================================================
CREATE TABLE public.insurance_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    policy_id UUID NOT NULL REFERENCES public.insurance_policies(id),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id),
    
    -- Claim details
    claim_number VARCHAR(50),
    claim_type VARCHAR(30) CHECK (claim_type IN (
        'cashless', 'reimbursement', 'pre_auth'
    )),
    
    -- Treatment details
    hospital_id UUID REFERENCES public.healthcare_facilities(id),
    hospital_name VARCHAR(200),
    admission_date DATE,
    discharge_date DATE,
    
    -- Medical
    diagnosis TEXT,
    treatment TEXT,
    procedure_codes TEXT[],
    
    -- Amounts
    total_bill_amount DECIMAL(15,2),
    claimed_amount DECIMAL(15,2),
    approved_amount DECIMAL(15,2),
    deduction_amount DECIMAL(15,2),
    settled_amount DECIMAL(15,2),
    patient_liability DECIMAL(15,2),
    
    -- Deduction breakdown
    deduction_reasons JSONB,
    
    -- Status
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN (
        'draft', 'submitted', 'under_review', 'query_raised',
        'approved', 'partially_approved', 'rejected', 'settled', 'appealed'
    )),
    status_history JSONB DEFAULT '[]',
    
    -- Documents
    documents UUID[],
    
    -- Dates
    submitted_at TIMESTAMPTZ,
    query_raised_at TIMESTAMPTZ,
    processed_at TIMESTAMPTZ,
    settled_at TIMESTAMPTZ,
    
    -- Query/rejection
    query_details TEXT,
    rejection_reason TEXT,
    appeal_details TEXT,
    
    -- Payment
    payment_mode VARCHAR(30),
    payment_reference VARCHAR(100),
    payment_date DATE,
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- MEDICAL EXPENSES TABLE
-- ============================================================================
CREATE TABLE public.medical_expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Categorization
    expense_type VARCHAR(30) NOT NULL CHECK (expense_type IN (
        'consultation', 'lab_test', 'medication', 'procedure',
        'hospitalization', 'therapy', 'equipment', 'ambulance',
        'nursing', 'rehabilitation', 'dental', 'vision', 'other'
    )),
    
    -- Details
    description VARCHAR(200),
    provider_name VARCHAR(200),
    provider_type VARCHAR(30),
    
    -- Amount
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'INR',
    
    -- Payment
    payment_method VARCHAR(30) CHECK (payment_method IN (
        'cash', 'card', 'upi', 'netbanking', 'wallet', 'insurance', 'other'
    )),
    payment_date DATE,
    payment_reference VARCHAR(100),
    
    -- Insurance
    is_insured BOOLEAN DEFAULT false,
    claim_id UUID REFERENCES public.insurance_claims(id),
    insurance_covered DECIMAL(10,2),
    out_of_pocket DECIMAL(10,2),
    
    -- Related entities
    appointment_id UUID REFERENCES public.appointments(id),
    prescription_id UUID REFERENCES public.prescriptions(id),
    document_id UUID REFERENCES public.medical_documents(id),
    lab_report_id UUID REFERENCES public.lab_reports(id),
    
    -- Date
    expense_date DATE NOT NULL,
    
    -- Tax
    is_tax_deductible BOOLEAN DEFAULT true,
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_insurance_providers_type ON public.insurance_providers(provider_type);
CREATE INDEX idx_insurance_policies_profile ON public.insurance_policies(health_profile_id);
CREATE INDEX idx_insurance_policies_status ON public.insurance_policies(health_profile_id, status);
CREATE INDEX idx_insurance_policies_expiry ON public.insurance_policies(end_date) WHERE status = 'active';
CREATE INDEX idx_insurance_claims_policy ON public.insurance_claims(policy_id);
CREATE INDEX idx_insurance_claims_profile ON public.insurance_claims(health_profile_id);
CREATE INDEX idx_insurance_claims_status ON public.insurance_claims(health_profile_id, status);
CREATE INDEX idx_medical_expenses_profile ON public.medical_expenses(health_profile_id);
CREATE INDEX idx_medical_expenses_date ON public.medical_expenses(health_profile_id, expense_date DESC);
CREATE INDEX idx_medical_expenses_type ON public.medical_expenses(health_profile_id, expense_type);
CREATE INDEX idx_medical_expenses_year ON public.medical_expenses(health_profile_id, expense_date) WHERE is_tax_deductible = true;

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER insurance_providers_updated_at
    BEFORE UPDATE ON public.insurance_providers
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER insurance_policies_updated_at
    BEFORE UPDATE ON public.insurance_policies
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER insurance_claims_updated_at
    BEFORE UPDATE ON public.insurance_claims
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER medical_expenses_updated_at
    BEFORE UPDATE ON public.medical_expenses
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
