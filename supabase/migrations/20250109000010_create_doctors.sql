-- ============================================================================
-- ENHANCED DOCTORS MODULE
-- ============================================================================
-- Tables: medical_specializations, healthcare_facilities, doctors, doctor_facilities, my_doctors, doctor_reviews

-- ============================================================================
-- MEDICAL SPECIALIZATIONS TABLE (Catalog)
-- ============================================================================
CREATE TABLE public.medical_specializations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Specialization info
    name VARCHAR(100) NOT NULL,
    short_name VARCHAR(50),
    
    -- Category
    category VARCHAR(50) CHECK (category IN (
        'primary_care', 'internal_medicine', 'surgical', 'pediatric',
        'womens_health', 'mental_health', 'dental', 'eye', 'ent',
        'orthopedic', 'cardiology', 'neurology', 'oncology',
        'dermatology', 'alternative', 'other'
    )),
    
    -- Description
    description TEXT,
    
    -- Common conditions
    common_conditions TEXT[],
    
    -- Symptoms that indicate this specialty
    related_symptoms TEXT[],
    
    -- Icon
    icon VARCHAR(50),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- HEALTHCARE FACILITIES TABLE
-- ============================================================================
CREATE TABLE public.healthcare_facilities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Basic info
    name VARCHAR(200) NOT NULL,
    facility_type VARCHAR(50) CHECK (facility_type IN (
        'hospital', 'clinic', 'diagnostic_center', 'pharmacy',
        'nursing_home', 'specialty_center', 'telemedicine',
        'rehabilitation', 'dental_clinic', 'eye_center', 'other'
    )),
    
    -- Location
    address_line1 VARCHAR(200),
    address_line2 VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(100),
    pincode VARCHAR(10),
    country VARCHAR(50) DEFAULT 'India',
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    
    -- Contact
    phone VARCHAR(20),
    alternate_phone VARCHAR(20),
    email VARCHAR(255),
    website VARCHAR(255),
    
    -- Details
    accreditations TEXT[],
    specialties TEXT[],
    facilities_available TEXT[],
    
    -- Emergency
    emergency_services BOOLEAN DEFAULT false,
    ambulance_available BOOLEAN DEFAULT false,
    
    -- Operating hours
    operating_hours JSONB,
    is_24x7 BOOLEAN DEFAULT false,
    
    -- Beds (for hospitals)
    total_beds INT,
    icu_beds INT,
    
    -- Insurance
    insurance_accepted TEXT[],
    cashless_available BOOLEAN DEFAULT false,
    
    -- Ratings
    avg_rating DECIMAL(2,1),
    total_reviews INT DEFAULT 0,
    
    -- Images
    logo_url TEXT,
    photos TEXT[],
    
    -- Verification
    is_verified BOOLEAN DEFAULT false,
    verified_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- DOCTORS TABLE (Verified Database)
-- ============================================================================
CREATE TABLE public.doctors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Basic info
    name VARCHAR(100) NOT NULL,
    gender VARCHAR(20),
    photo_url TEXT,
    
    -- Professional registration
    registration_number VARCHAR(50),
    registration_council VARCHAR(100),
    registration_year INT,
    
    -- Specialization
    specialization_id UUID REFERENCES public.medical_specializations(id),
    specialization_name VARCHAR(100),
    sub_specialization VARCHAR(100),
    
    -- Qualifications
    qualifications TEXT[],
    degrees TEXT[],
    
    -- Experience
    experience_years INT,
    experience_since_year INT,
    
    -- Languages
    languages TEXT[],
    
    -- Consultation fees
    consultation_fee DECIMAL(10,2),
    video_consultation_fee DECIMAL(10,2),
    follow_up_fee DECIMAL(10,2),
    
    -- Consultation duration
    consultation_duration_mins INT DEFAULT 15,
    
    -- Contact
    phone VARCHAR(20),
    email VARCHAR(255),
    
    -- Online presence
    website VARCHAR(255),
    practo_profile VARCHAR(255),
    linkedin_profile VARCHAR(255),
    
    -- Bio
    bio TEXT,
    specializations_description TEXT,
    
    -- Awards and memberships
    awards TEXT[],
    memberships TEXT[],
    
    -- Publications
    publications TEXT[],
    
    -- Ratings
    avg_rating DECIMAL(2,1),
    total_reviews INT DEFAULT 0,
    
    -- Verification
    is_verified BOOLEAN DEFAULT false,
    verified_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- DOCTOR FACILITIES TABLE (Junction)
-- ============================================================================
CREATE TABLE public.doctor_facilities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doctor_id UUID NOT NULL REFERENCES public.doctors(id) ON DELETE CASCADE,
    facility_id UUID NOT NULL REFERENCES public.healthcare_facilities(id) ON DELETE CASCADE,
    
    -- Schedule
    available_days INT[],
    slot_duration_mins INT DEFAULT 15,
    slots_per_day INT,
    
    -- Timing
    morning_start TIME,
    morning_end TIME,
    afternoon_start TIME,
    afternoon_end TIME,
    evening_start TIME,
    evening_end TIME,
    
    -- Fee override
    consultation_fee_override DECIMAL(10,2),
    
    -- Room/chamber
    room_number VARCHAR(20),
    floor VARCHAR(20),
    
    -- Appointment booking
    booking_enabled BOOLEAN DEFAULT true,
    advance_booking_days INT DEFAULT 7,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(doctor_id, facility_id)
);

-- ============================================================================
-- MY DOCTORS TABLE (User's personal list)
-- ============================================================================
CREATE TABLE public.my_doctors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Link to verified doctor (optional)
    doctor_id UUID REFERENCES public.doctors(id),
    
    -- Custom entry (if doctor not in system)
    custom_name VARCHAR(100),
    custom_specialization VARCHAR(100),
    custom_phone VARCHAR(20),
    custom_email VARCHAR(255),
    custom_clinic VARCHAR(200),
    custom_address TEXT,
    custom_city VARCHAR(100),
    
    -- User's relationship
    relationship VARCHAR(50),
    nickname VARCHAR(50),
    
    -- Visit history
    is_primary BOOLEAN DEFAULT false,
    first_visit_date DATE,
    last_visit_date DATE,
    next_visit_date DATE,
    total_visits INT DEFAULT 0,
    
    -- Notes
    notes TEXT,
    
    -- Favorites
    is_favorite BOOLEAN DEFAULT false,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(health_profile_id, doctor_id)
);

-- ============================================================================
-- DOCTOR REVIEWS TABLE
-- ============================================================================
CREATE TABLE public.doctor_reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    doctor_id UUID NOT NULL REFERENCES public.doctors(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id),
    health_profile_id UUID REFERENCES public.health_profiles(id),
    
    -- Overall rating
    rating INT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    
    -- Detailed ratings
    wait_time_rating INT CHECK (wait_time_rating BETWEEN 1 AND 5),
    bedside_manner_rating INT CHECK (bedside_manner_rating BETWEEN 1 AND 5),
    explanation_rating INT CHECK (explanation_rating BETWEEN 1 AND 5),
    treatment_effectiveness_rating INT CHECK (treatment_effectiveness_rating BETWEEN 1 AND 5),
    
    -- Review content
    review_title VARCHAR(200),
    review_text TEXT,
    
    -- Visit details
    visit_date DATE,
    visit_type VARCHAR(30),
    appointment_id UUID REFERENCES public.appointments(id),
    
    -- Verification
    is_verified_visit BOOLEAN DEFAULT false,
    
    -- Helpfulness
    helpful_count INT DEFAULT 0,
    not_helpful_count INT DEFAULT 0,
    
    -- Visibility
    is_public BOOLEAN DEFAULT true,
    is_anonymous BOOLEAN DEFAULT false,
    
    -- Moderation
    is_approved BOOLEAN DEFAULT true,
    is_flagged BOOLEAN DEFAULT false,
    flag_reason TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(doctor_id, user_id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_medical_specializations_category ON public.medical_specializations(category);
CREATE INDEX idx_healthcare_facilities_type ON public.healthcare_facilities(facility_type);
CREATE INDEX idx_healthcare_facilities_city ON public.healthcare_facilities(city);
CREATE INDEX idx_healthcare_facilities_location ON public.healthcare_facilities(latitude, longitude);
CREATE INDEX idx_doctors_specialization ON public.doctors(specialization_id);
CREATE INDEX idx_doctors_name ON public.doctors(name);
CREATE INDEX idx_doctors_verified ON public.doctors(is_verified) WHERE is_verified = true;
CREATE INDEX idx_doctor_facilities_doctor ON public.doctor_facilities(doctor_id);
CREATE INDEX idx_doctor_facilities_facility ON public.doctor_facilities(facility_id);
CREATE INDEX idx_my_doctors_profile ON public.my_doctors(health_profile_id);
CREATE INDEX idx_my_doctors_doctor ON public.my_doctors(doctor_id);
CREATE INDEX idx_my_doctors_favorite ON public.my_doctors(health_profile_id) WHERE is_favorite = true;
CREATE INDEX idx_doctor_reviews_doctor ON public.doctor_reviews(doctor_id);
CREATE INDEX idx_doctor_reviews_rating ON public.doctor_reviews(doctor_id, rating);

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER healthcare_facilities_updated_at
    BEFORE UPDATE ON public.healthcare_facilities
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER doctors_updated_at
    BEFORE UPDATE ON public.doctors
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER doctor_facilities_updated_at
    BEFORE UPDATE ON public.doctor_facilities
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER my_doctors_updated_at
    BEFORE UPDATE ON public.my_doctors
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER doctor_reviews_updated_at
    BEFORE UPDATE ON public.doctor_reviews
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
