# SwasthiCare Future Modules Architecture

## Core Design Principle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         HEALTH_PROFILE_ID                                    │
│                    (The Universal Foreign Key)                               │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
        ┌───────────────────────────┼───────────────────────────┐
        │                           │                           │
        ▼                           ▼                           ▼
   ┌─────────┐                ┌─────────┐                ┌─────────┐
   │ Current │                │ Future  │                │ Future  │
   │ Modules │                │Module A │                │Module B │
   └─────────┘                └─────────┘                └─────────┘

EVERY new module connects via health_profile_id
This allows:
✅ Family access automatically works
✅ RLS policies automatically apply
✅ Data stays connected to the person
✅ Works for dependents too
```

---

## Current Base Schema (v2.0)

```
CORE FOUNDATION
├── users
├── user_settings  
├── health_profiles        ◄── CENTRAL HUB
├── family_groups
└── family_members

CURRENT MODULES (Connected to health_profile_id)
├── Medications Module
│   ├── medications
│   ├── medication_schedules
│   └── medication_logs
│
├── Health Metrics Module
│   ├── daily_health_metrics
│   ├── vital_signs
│   ├── activity_logs
│   ├── hydration_logs
│   └── nutrition_logs
│
├── Medical Records Module
│   ├── document_folders
│   ├── medical_documents
│   ├── healthcare_providers
│   ├── appointments
│   └── appointment_notes
│
├── Conditions Module
│   ├── chronic_conditions
│   ├── allergies
│   └── emergency_contacts
│
├── AI Module
│   ├── ai_conversations
│   ├── ai_insights
│   ├── ai_image_analysis
│   └── ai_usage_logs
│
└── Engagement Module
    ├── reminders
    ├── reminder_logs
    ├── notifications
    ├── user_streaks
    └── achievements
```

---

## Future Module Stacking

### Module 1: Lab Reports & Diagnostics (Enhanced)

```sql
-- ============================================================================
-- LAB REPORTS MODULE (Stacks on medical_documents)
-- ============================================================================

-- Lab test catalog (master list of tests)
CREATE TABLE public.lab_test_catalog (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    test_code VARCHAR(50) UNIQUE,          -- e.g., "CBC", "HBA1C", "TSH"
    test_name VARCHAR(200) NOT NULL,
    category VARCHAR(50),                   -- hematology, biochemistry, etc.
    description TEXT,
    unit VARCHAR(50),                       -- mg/dL, mmol/L, etc.
    normal_range_min DECIMAL(10,4),
    normal_range_max DECIMAL(10,4),
    normal_range_text VARCHAR(100),         -- For non-numeric ranges
    critical_low DECIMAL(10,4),
    critical_high DECIMAL(10,4),
    fasting_required BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Lab reports (linked to medical_documents)
CREATE TABLE public.lab_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    document_id UUID REFERENCES public.medical_documents(id),  -- Link to uploaded PDF
    
    -- Report details
    report_date DATE NOT NULL,
    lab_name VARCHAR(200),
    lab_accreditation VARCHAR(100),        -- NABL, CAP, etc.
    ordering_doctor VARCHAR(100),
    
    -- Sample info
    sample_type VARCHAR(50),               -- blood, urine, stool, etc.
    sample_collected_at TIMESTAMPTZ,
    sample_received_at TIMESTAMPTZ,
    report_generated_at TIMESTAMPTZ,
    
    -- Status
    status VARCHAR(20) DEFAULT 'completed',
    
    -- AI analysis
    ai_summary TEXT,
    ai_concerns TEXT[],
    ai_recommendations TEXT[],
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Individual test results within a report
CREATE TABLE public.lab_test_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lab_report_id UUID NOT NULL REFERENCES public.lab_reports(id) ON DELETE CASCADE,
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id),
    
    -- Test info
    test_catalog_id UUID REFERENCES public.lab_test_catalog(id),
    test_name VARCHAR(200) NOT NULL,       -- Stored separately for flexibility
    test_code VARCHAR(50),
    
    -- Result
    value_numeric DECIMAL(15,4),
    value_text VARCHAR(200),               -- For non-numeric results
    unit VARCHAR(50),
    
    -- Reference ranges (from report, may differ from catalog)
    reference_min DECIMAL(10,4),
    reference_max DECIMAL(10,4),
    reference_text VARCHAR(100),
    
    -- Interpretation
    status VARCHAR(20) CHECK (status IN (
        'normal', 'low', 'high', 'critical_low', 'critical_high', 'abnormal'
    )),
    
    -- Trend (compared to last test)
    previous_value DECIMAL(15,4),
    trend VARCHAR(20) CHECK (trend IN ('improving', 'stable', 'worsening', 'new')),
    
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Lab report sharing (for second opinions)
CREATE TABLE public.lab_report_shares (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    lab_report_id UUID NOT NULL REFERENCES public.lab_reports(id) ON DELETE CASCADE,
    shared_by UUID NOT NULL REFERENCES public.users(id),
    shared_with_email VARCHAR(255),
    shared_with_doctor_id UUID REFERENCES public.healthcare_providers(id),
    
    access_code VARCHAR(20),               -- For link-based sharing
    expires_at TIMESTAMPTZ,
    accessed_at TIMESTAMPTZ,
    access_count INT DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_lab_reports_profile_date ON public.lab_reports(health_profile_id, report_date DESC);
CREATE INDEX idx_lab_results_test ON public.lab_test_results(health_profile_id, test_code, created_at DESC);
```

**How it stacks:**
```
medical_documents (existing)
        │
        ▼
lab_reports ──────► lab_test_results
        │                   │
        │                   ▼
        │           lab_test_catalog (master)
        ▼
lab_report_shares
```

---

### Module 2: Doctor & Clinic Management (Enhanced)

```sql
-- ============================================================================
-- DOCTORS MODULE (Enhances healthcare_providers)
-- ============================================================================

-- Doctor specializations catalog
CREATE TABLE public.medical_specializations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50),                  -- primary, specialist, surgical, etc.
    description TEXT,
    common_conditions TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Hospitals/Clinics
CREATE TABLE public.healthcare_facilities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(200) NOT NULL,
    facility_type VARCHAR(50) CHECK (facility_type IN (
        'hospital', 'clinic', 'diagnostic_center', 'pharmacy', 
        'nursing_home', 'specialty_center', 'telemedicine'
    )),
    
    -- Location
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(100),
    pincode VARCHAR(10),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    
    -- Contact
    phone VARCHAR(20),
    email VARCHAR(255),
    website VARCHAR(255),
    
    -- Details
    accreditations TEXT[],                 -- NABH, JCI, etc.
    specialties TEXT[],
    emergency_services BOOLEAN DEFAULT false,
    
    -- Operating hours
    operating_hours JSONB,                 -- {"monday": {"open": "09:00", "close": "21:00"}}
    
    -- Ratings (aggregated)
    avg_rating DECIMAL(2,1),
    total_reviews INT DEFAULT 0,
    
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enhanced doctors table (extends healthcare_providers)
CREATE TABLE public.doctors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Basic info
    name VARCHAR(100) NOT NULL,
    gender VARCHAR(20),
    photo_url TEXT,
    
    -- Professional
    registration_number VARCHAR(50),       -- Medical council registration
    registration_council VARCHAR(100),     -- e.g., "Tamil Nadu Medical Council"
    specialization_id UUID REFERENCES public.medical_specializations(id),
    specialization_name VARCHAR(100),
    sub_specialization VARCHAR(100),
    
    -- Qualifications
    qualifications TEXT[],                 -- MBBS, MD, DM, etc.
    experience_years INT,
    
    -- Languages
    languages TEXT[],
    
    -- Consultation
    consultation_fee DECIMAL(10,2),
    video_consultation_fee DECIMAL(10,2),
    consultation_duration_mins INT DEFAULT 15,
    
    -- Contact
    phone VARCHAR(20),
    email VARCHAR(255),
    
    -- Online presence
    website VARCHAR(255),
    practo_profile VARCHAR(255),
    
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Doctor-Facility associations (a doctor can work at multiple places)
CREATE TABLE public.doctor_facilities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doctor_id UUID NOT NULL REFERENCES public.doctors(id) ON DELETE CASCADE,
    facility_id UUID NOT NULL REFERENCES public.healthcare_facilities(id) ON DELETE CASCADE,
    
    -- Schedule at this facility
    available_days INT[],                  -- [1,2,3,4,5] for weekdays
    slot_duration_mins INT DEFAULT 15,
    slots_per_day INT,
    
    -- Timing
    morning_start TIME,
    morning_end TIME,
    evening_start TIME,
    evening_end TIME,
    
    consultation_fee_override DECIMAL(10,2),
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(doctor_id, facility_id)
);

-- User's doctors (their personal list, links to health_profile)
CREATE TABLE public.my_doctors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Can link to verified doctor OR custom entry
    doctor_id UUID REFERENCES public.doctors(id),
    
    -- Custom entry (if doctor not in system)
    custom_name VARCHAR(100),
    custom_specialization VARCHAR(100),
    custom_phone VARCHAR(20),
    custom_clinic VARCHAR(200),
    custom_address TEXT,
    
    -- User's notes
    relationship VARCHAR(50),              -- "my cardiologist", "family doctor"
    notes TEXT,
    
    is_primary BOOLEAN DEFAULT false,
    last_visit_date DATE,
    next_visit_date DATE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(health_profile_id, doctor_id)
);

-- Doctor reviews (by users)
CREATE TABLE public.doctor_reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doctor_id UUID NOT NULL REFERENCES public.doctors(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id),
    
    rating INT CHECK (rating BETWEEN 1 AND 5),
    review_text TEXT,
    
    -- Specific ratings
    wait_time_rating INT CHECK (wait_time_rating BETWEEN 1 AND 5),
    bedside_manner_rating INT CHECK (bedside_manner_rating BETWEEN 1 AND 5),
    
    is_verified_visit BOOLEAN DEFAULT false,
    appointment_id UUID REFERENCES public.appointments(id),
    
    is_public BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(doctor_id, user_id)
);
```

**How it stacks:**
```
healthcare_providers (existing - user's simple list)
        │
        ├──────────────────────────────┐
        ▼                              ▼
   my_doctors ◄───────────────► doctors (verified database)
        │                              │
        │                              ├──► doctor_facilities
        │                              │           │
        │                              │           ▼
        │                              │   healthcare_facilities
        │                              │
        │                              ▼
        │                      doctor_reviews
        │
        ▼
   appointments (existing)
```

---

### Module 3: Prescriptions & Pharmacy

```sql
-- ============================================================================
-- PRESCRIPTIONS MODULE
-- ============================================================================

-- Prescriptions (from doctor visits)
CREATE TABLE public.prescriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Source
    appointment_id UUID REFERENCES public.appointments(id),
    doctor_id UUID REFERENCES public.doctors(id),
    document_id UUID REFERENCES public.medical_documents(id),  -- Scanned prescription
    
    -- Details
    prescription_date DATE NOT NULL,
    diagnosis TEXT,
    notes TEXT,
    
    -- Validity
    valid_until DATE,
    refills_allowed INT DEFAULT 0,
    refills_used INT DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active', 'completed', 'expired', 'cancelled'
    )),
    
    -- Digital signature (for e-prescriptions)
    is_digital BOOLEAN DEFAULT false,
    digital_signature TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Prescription items (medicines in a prescription)
CREATE TABLE public.prescription_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prescription_id UUID NOT NULL REFERENCES public.prescriptions(id) ON DELETE CASCADE,
    
    -- Medicine
    medication_id UUID REFERENCES public.medications(id),  -- Links to user's medication
    medicine_name VARCHAR(200) NOT NULL,
    generic_name VARCHAR(200),
    
    -- Dosage
    dosage VARCHAR(50),
    frequency VARCHAR(50),
    duration_days INT,
    quantity INT,
    
    -- Instructions
    instructions TEXT,
    before_food BOOLEAN,
    
    -- Substitution
    substitution_allowed BOOLEAN DEFAULT true,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pharmacies
CREATE TABLE public.pharmacies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(200) NOT NULL,
    license_number VARCHAR(50),
    
    -- Location
    address TEXT,
    city VARCHAR(100),
    pincode VARCHAR(10),
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    
    -- Contact
    phone VARCHAR(20),
    whatsapp VARCHAR(20),
    email VARCHAR(255),
    
    -- Services
    delivery_available BOOLEAN DEFAULT false,
    delivery_radius_km DECIMAL(5,2),
    min_order_amount DECIMAL(10,2),
    
    -- Hours
    operating_hours JSONB,
    is_24x7 BOOLEAN DEFAULT false,
    
    -- Online
    website VARCHAR(255),
    app_available BOOLEAN DEFAULT false,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Medicine orders
CREATE TABLE public.medicine_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    prescription_id UUID REFERENCES public.prescriptions(id),
    pharmacy_id UUID REFERENCES public.pharmacies(id),
    
    -- Order details
    order_number VARCHAR(50),
    order_date TIMESTAMPTZ DEFAULT NOW(),
    
    -- Items (JSON for flexibility)
    items JSONB NOT NULL,                  -- [{medicine, qty, price}]
    
    -- Pricing
    subtotal DECIMAL(10,2),
    discount DECIMAL(10,2) DEFAULT 0,
    delivery_charge DECIMAL(10,2) DEFAULT 0,
    total DECIMAL(10,2),
    
    -- Delivery
    delivery_address TEXT,
    delivery_type VARCHAR(20) CHECK (delivery_type IN ('pickup', 'delivery')),
    expected_delivery TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending', 'confirmed', 'processing', 'ready', 
        'out_for_delivery', 'delivered', 'cancelled'
    )),
    
    -- Payment
    payment_status VARCHAR(20) DEFAULT 'pending',
    payment_method VARCHAR(30),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- User's preferred pharmacies
CREATE TABLE public.my_pharmacies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    pharmacy_id UUID REFERENCES public.pharmacies(id),
    
    -- Custom pharmacy (if not in system)
    custom_name VARCHAR(200),
    custom_phone VARCHAR(20),
    custom_address TEXT,
    
    is_preferred BOOLEAN DEFAULT false,
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(health_profile_id, pharmacy_id)
);
```

---

### Module 4: Insurance & Billing

```sql
-- ============================================================================
-- INSURANCE MODULE
-- ============================================================================

-- Insurance providers
CREATE TABLE public.insurance_providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(200) NOT NULL,
    short_name VARCHAR(50),
    logo_url TEXT,
    
    provider_type VARCHAR(30) CHECK (provider_type IN (
        'health', 'life', 'accident', 'critical_illness', 'government'
    )),
    
    -- Contact
    customer_care VARCHAR(20),
    email VARCHAR(255),
    website VARCHAR(255),
    claim_portal VARCHAR(255),
    
    -- Network
    network_hospitals_count INT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User's insurance policies
CREATE TABLE public.insurance_policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES public.insurance_providers(id),
    
    -- Policy details
    policy_number VARCHAR(50) NOT NULL,
    policy_name VARCHAR(200),
    policy_type VARCHAR(50),               -- individual, family floater, group
    
    -- Coverage
    sum_insured DECIMAL(15,2),
    remaining_sum DECIMAL(15,2),
    
    -- Dates
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    renewal_date DATE,
    
    -- Premium
    premium_amount DECIMAL(10,2),
    premium_frequency VARCHAR(20),         -- monthly, quarterly, yearly
    next_premium_date DATE,
    
    -- Document
    document_id UUID REFERENCES public.medical_documents(id),
    policy_document_url TEXT,
    card_url TEXT,                         -- Insurance card image
    
    -- Contacts
    tpa_name VARCHAR(200),                 -- Third Party Administrator
    tpa_contact VARCHAR(20),
    
    -- Family members covered
    covered_members UUID[],                -- Array of health_profile_ids
    
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active', 'expired', 'lapsed', 'cancelled'
    )),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insurance claims
CREATE TABLE public.insurance_claims (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    policy_id UUID NOT NULL REFERENCES public.insurance_policies(id),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id),
    
    -- Claim details
    claim_number VARCHAR(50),
    claim_type VARCHAR(30) CHECK (claim_type IN (
        'cashless', 'reimbursement', 'pre_auth'
    )),
    
    -- Treatment
    hospital_id UUID REFERENCES public.healthcare_facilities(id),
    hospital_name VARCHAR(200),
    admission_date DATE,
    discharge_date DATE,
    diagnosis TEXT,
    treatment TEXT,
    
    -- Amounts
    total_bill_amount DECIMAL(15,2),
    claimed_amount DECIMAL(15,2),
    approved_amount DECIMAL(15,2),
    deduction_amount DECIMAL(15,2),
    settled_amount DECIMAL(15,2),
    
    -- Status
    status VARCHAR(20) DEFAULT 'submitted' CHECK (status IN (
        'draft', 'submitted', 'under_review', 'approved', 
        'partially_approved', 'rejected', 'settled', 'appealed'
    )),
    
    -- Documents
    documents UUID[],                      -- Array of medical_document ids
    
    -- Dates
    submitted_at TIMESTAMPTZ,
    processed_at TIMESTAMPTZ,
    settled_at TIMESTAMPTZ,
    
    rejection_reason TEXT,
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Medical bills/expenses tracking
CREATE TABLE public.medical_expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Categorization
    expense_type VARCHAR(30) NOT NULL CHECK (expense_type IN (
        'consultation', 'lab_test', 'medication', 'procedure',
        'hospitalization', 'therapy', 'equipment', 'other'
    )),
    
    -- Details
    description VARCHAR(200),
    provider_name VARCHAR(200),
    
    -- Amount
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'INR',
    
    -- Payment
    payment_method VARCHAR(30),
    payment_date DATE,
    
    -- Insurance
    is_insured BOOLEAN DEFAULT false,
    claim_id UUID REFERENCES public.insurance_claims(id),
    insurance_covered DECIMAL(10,2),
    out_of_pocket DECIMAL(10,2),
    
    -- Links
    appointment_id UUID REFERENCES public.appointments(id),
    prescription_id UUID REFERENCES public.prescriptions(id),
    document_id UUID REFERENCES public.medical_documents(id),  -- Receipt/bill
    
    expense_date DATE NOT NULL,
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

### Module 5: Telemedicine

```sql
-- ============================================================================
-- TELEMEDICINE MODULE
-- ============================================================================

-- Video consultations
CREATE TABLE public.video_consultations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    appointment_id UUID REFERENCES public.appointments(id),
    doctor_id UUID REFERENCES public.doctors(id),
    
    -- Session
    session_id VARCHAR(100),               -- Video platform session ID
    platform VARCHAR(30),                  -- zoom, meet, custom, etc.
    
    -- Timing
    scheduled_at TIMESTAMPTZ NOT NULL,
    duration_mins INT DEFAULT 15,
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    actual_duration_mins INT,
    
    -- URLs
    patient_join_url TEXT,
    doctor_join_url TEXT,
    recording_url TEXT,
    
    -- Status
    status VARCHAR(20) DEFAULT 'scheduled' CHECK (status IN (
        'scheduled', 'waiting', 'in_progress', 'completed', 
        'cancelled', 'no_show_patient', 'no_show_doctor'
    )),
    
    -- Outcome
    prescription_id UUID REFERENCES public.prescriptions(id),
    follow_up_required BOOLEAN,
    follow_up_date DATE,
    
    -- Payment
    fee DECIMAL(10,2),
    payment_status VARCHAR(20),
    
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chat consultations (async)
CREATE TABLE public.chat_consultations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    doctor_id UUID REFERENCES public.doctors(id),
    
    -- Session
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active', 'closed', 'expired'
    )),
    
    started_at TIMESTAMPTZ DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    
    -- Outcome
    prescription_id UUID REFERENCES public.prescriptions(id),
    
    fee DECIMAL(10,2),
    payment_status VARCHAR(20),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Chat messages
CREATE TABLE public.chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    consultation_id UUID NOT NULL REFERENCES public.chat_consultations(id) ON DELETE CASCADE,
    
    sender_type VARCHAR(20) NOT NULL CHECK (sender_type IN ('patient', 'doctor', 'system')),
    sender_id UUID,
    
    message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN (
        'text', 'image', 'document', 'prescription', 'audio'
    )),
    content TEXT,
    media_url TEXT,
    
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

### Module 6: Wearables & Devices

```sql
-- ============================================================================
-- WEARABLES & DEVICES MODULE
-- ============================================================================

-- Connected devices
CREATE TABLE public.connected_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    device_type VARCHAR(30) NOT NULL CHECK (device_type IN (
        'smartwatch', 'fitness_band', 'glucometer', 'bp_monitor',
        'pulse_oximeter', 'smart_scale', 'thermometer', 'cgm', 'other'
    )),
    
    -- Device info
    brand VARCHAR(100),
    model VARCHAR(100),
    device_id VARCHAR(200),                -- Unique device identifier
    
    -- Connection
    connection_type VARCHAR(30) CHECK (connection_type IN (
        'bluetooth', 'wifi', 'healthkit', 'google_fit', 'api', 'manual'
    )),
    
    -- Status
    is_connected BOOLEAN DEFAULT true,
    last_sync_at TIMESTAMPTZ,
    battery_level INT,
    
    -- Settings
    sync_enabled BOOLEAN DEFAULT true,
    sync_frequency_mins INT DEFAULT 60,
    metrics_to_sync TEXT[],                -- ['heart_rate', 'steps', 'sleep']
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Device readings (raw data from devices)
CREATE TABLE public.device_readings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    device_id UUID NOT NULL REFERENCES public.connected_devices(id) ON DELETE CASCADE,
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id),
    
    reading_type VARCHAR(30) NOT NULL,     -- heart_rate, blood_glucose, etc.
    
    -- Value
    value_primary DECIMAL(15,4) NOT NULL,
    value_secondary DECIMAL(15,4),
    unit VARCHAR(30),
    
    -- Context
    context JSONB,                         -- Additional metadata from device
    
    recorded_at TIMESTAMPTZ NOT NULL,
    synced_at TIMESTAMPTZ DEFAULT NOW()
);

-- Partition by month for performance
-- CREATE TABLE device_readings_2025_01 PARTITION OF device_readings
-- FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');

CREATE INDEX idx_device_readings_profile_type_time 
ON public.device_readings(health_profile_id, reading_type, recorded_at DESC);
```

---

### Module 7: Health Goals & Programs

```sql
-- ============================================================================
-- HEALTH GOALS MODULE
-- ============================================================================

-- Health goals
CREATE TABLE public.health_goals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    goal_type VARCHAR(30) NOT NULL CHECK (goal_type IN (
        'weight_loss', 'weight_gain', 'fitness', 'sleep', 'hydration',
        'medication_adherence', 'blood_sugar', 'blood_pressure',
        'cholesterol', 'steps', 'exercise', 'nutrition', 'custom'
    )),
    
    title VARCHAR(200) NOT NULL,
    description TEXT,
    
    -- Target
    target_value DECIMAL(10,2),
    target_unit VARCHAR(30),
    current_value DECIMAL(10,2),
    start_value DECIMAL(10,2),
    
    -- Timeline
    start_date DATE NOT NULL,
    target_date DATE,
    
    -- Progress
    progress_percentage DECIMAL(5,2) DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active', 'completed', 'paused', 'abandoned'
    )),
    
    completed_at TIMESTAMPTZ,
    
    -- AI coaching
    ai_recommendations TEXT[],
    last_ai_review TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Goal milestones
CREATE TABLE public.goal_milestones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    goal_id UUID NOT NULL REFERENCES public.health_goals(id) ON DELETE CASCADE,
    
    title VARCHAR(100),
    target_value DECIMAL(10,2),
    target_date DATE,
    
    achieved BOOLEAN DEFAULT false,
    achieved_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Health programs (structured wellness programs)
CREATE TABLE public.health_programs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    name VARCHAR(200) NOT NULL,
    description TEXT,
    program_type VARCHAR(30),              -- weight_loss, diabetes_management, etc.
    
    duration_days INT,
    difficulty VARCHAR(20),
    
    -- Content
    overview TEXT,
    benefits TEXT[],
    requirements TEXT[],
    
    -- Media
    thumbnail_url TEXT,
    
    is_premium BOOLEAN DEFAULT false,
    price DECIMAL(10,2),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User enrolled programs
CREATE TABLE public.user_programs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    program_id UUID NOT NULL REFERENCES public.health_programs(id),
    
    -- Progress
    enrolled_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    current_day INT DEFAULT 1,
    
    status VARCHAR(20) DEFAULT 'enrolled' CHECK (status IN (
        'enrolled', 'active', 'paused', 'completed', 'dropped'
    )),
    
    completed_at TIMESTAMPTZ,
    
    UNIQUE(health_profile_id, program_id)
);
```

---

### Module 8: Women's Health

```sql
-- ============================================================================
-- WOMEN'S HEALTH MODULE
-- ============================================================================

-- Menstrual cycle tracking
CREATE TABLE public.menstrual_cycles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Period
    period_start DATE NOT NULL,
    period_end DATE,
    cycle_length INT,                      -- Days until next period
    period_length INT,                     -- Days of period
    
    -- Flow
    flow_intensity VARCHAR(20) CHECK (flow_intensity IN (
        'spotting', 'light', 'medium', 'heavy'
    )),
    
    -- Symptoms
    symptoms TEXT[],
    pain_level INT CHECK (pain_level BETWEEN 0 AND 10),
    mood TEXT[],
    
    -- Fertility (optional)
    ovulation_date DATE,
    fertile_window_start DATE,
    fertile_window_end DATE,
    
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pregnancy tracking
CREATE TABLE public.pregnancy_tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Dates
    conception_date DATE,
    due_date DATE,
    last_menstrual_period DATE,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active', 'delivered', 'ended'
    )),
    
    -- Outcome
    delivery_date DATE,
    delivery_type VARCHAR(30),             -- vaginal, c_section, etc.
    
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pregnancy weekly logs
CREATE TABLE public.pregnancy_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pregnancy_id UUID NOT NULL REFERENCES public.pregnancy_tracking(id) ON DELETE CASCADE,
    
    log_date DATE NOT NULL,
    week_number INT,
    
    -- Vitals
    weight_kg DECIMAL(5,2),
    blood_pressure_systolic INT,
    blood_pressure_diastolic INT,
    
    -- Baby
    baby_movement VARCHAR(20),
    baby_heartbeat INT,
    
    -- Symptoms
    symptoms TEXT[],
    mood TEXT[],
    energy_level INT CHECK (energy_level BETWEEN 1 AND 5),
    sleep_quality INT CHECK (sleep_quality BETWEEN 1 AND 5),
    
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## Module Dependency Graph

```
                              ┌──────────────────┐
                              │  health_profiles │
                              └────────┬─────────┘
                                       │
         ┌─────────────────────────────┼─────────────────────────────┐
         │                             │                             │
         ▼                             ▼                             ▼
    ┌─────────┐                  ┌─────────┐                   ┌─────────┐
    │ BASE    │                  │ MEDICAL │                   │ ENGAGE  │
    │ MODULES │                  │ MODULES │                   │ MODULES │
    └────┬────┘                  └────┬────┘                   └────┬────┘
         │                            │                             │
    ┌────┴────┐              ┌────────┼────────┐              ┌─────┴─────┐
    │         │              │        │        │              │           │
    ▼         ▼              ▼        ▼        ▼              ▼           ▼
┌───────┐ ┌───────┐    ┌───────┐ ┌───────┐ ┌───────┐    ┌───────┐   ┌───────┐
│Metrics│ │Medica-│    │Lab    │ │Doctors│ │Prescrip│   │Goals  │   │Programs│
│       │ │tions  │    │Reports│ │       │ │tions   │   │       │   │        │
└───┬───┘ └───┬───┘    └───┬───┘ └───┬───┘ └───┬────┘   └───────┘   └────────┘
    │         │            │         │         │
    │         │            │         │         │
    │         └────────────┼─────────┼─────────┘
    │                      │         │
    ▼                      ▼         ▼
┌───────────────────────────────────────────────┐
│              FUTURE MODULES                    │
├───────────────────────────────────────────────┤
│  Insurance  │  Telemedicine  │  Wearables     │
│  Pharmacy   │  Women's Health│  Mental Health │
│  Fitness    │  Nutrition AI  │  Genetic Data  │
└───────────────────────────────────────────────┘
```

---

## Adding New Modules Checklist

When adding any new module:

1. **Connect to health_profile_id**
   ```sql
   health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE
   ```

2. **Enable RLS**
   ```sql
   ALTER TABLE public.new_table ENABLE ROW LEVEL SECURITY;
   ```

3. **Add family access policy**
   ```sql
   CREATE POLICY "Family access" ON public.new_table
       FOR SELECT USING (public.has_family_access(health_profile_id, 'view'));
   ```

4. **Create appropriate indexes**
   ```sql
   CREATE INDEX idx_new_table_profile ON public.new_table(health_profile_id);
   CREATE INDEX idx_new_table_date ON public.new_table(health_profile_id, created_at DESC);
   ```

5. **Add to audit logging** (for sensitive data)
   ```sql
   CREATE TRIGGER audit_new_table
   AFTER INSERT OR UPDATE OR DELETE ON public.new_table
   FOR EACH ROW EXECUTE FUNCTION public.audit_log_trigger();
   ```

---

## Summary

| Module | Tables | Status | Dependency |
|--------|--------|--------|------------|
| Core Users | 2 | ✅ Included | Base |
| Family Access | 3 | ✅ Included | Base |
| Health Profile | 4 | ✅ Included | Base |
| Medications | 4 | ✅ Included | Base |
| Health Metrics | 5 | ✅ Included | Base |
| Medical Records | 4 | ✅ Included | Base |
| AI Features | 4 | ✅ Included | Base |
| Engagement | 5 | ✅ Included | Base |
| Lab Reports | 4 | 📋 Ready | Medical Records |
| Doctors Enhanced | 5 | 📋 Ready | Medical Records |
| Prescriptions | 4 | 📋 Ready | Medications + Doctors |
| Insurance | 4 | 📋 Ready | Medical Records |
| Telemedicine | 3 | 📋 Ready | Doctors + Appointments |
| Wearables | 2 | 📋 Ready | Health Metrics |
| Health Goals | 4 | 📋 Ready | Base |
| Women's Health | 3 | 📋 Ready | Base |

**Total: 31 base + 29 future = 60 tables**

All designed to stack cleanly on the `health_profile_id` foundation!
