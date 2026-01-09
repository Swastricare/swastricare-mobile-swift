-- ============================================================================
-- PRESCRIPTIONS & PHARMACY MODULE
-- ============================================================================
-- Tables: prescriptions, prescription_items, pharmacies, medicine_orders, my_pharmacies

-- ============================================================================
-- PRESCRIPTIONS TABLE
-- ============================================================================
CREATE TABLE public.prescriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Source
    appointment_id UUID REFERENCES public.appointments(id),
    doctor_id UUID REFERENCES public.doctors(id),
    provider_id UUID REFERENCES public.healthcare_providers(id),
    document_id UUID REFERENCES public.medical_documents(id),
    
    -- Prescription details
    prescription_number VARCHAR(50),
    prescription_date DATE NOT NULL,
    
    -- Diagnosis
    diagnosis TEXT,
    symptoms TEXT[],
    icd_codes TEXT[],
    
    -- Notes
    notes TEXT,
    special_instructions TEXT,
    
    -- Validity
    valid_until DATE,
    refills_allowed INT DEFAULT 0,
    refills_used INT DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active', 'completed', 'expired', 'cancelled', 'on_hold'
    )),
    
    -- Digital prescription
    is_digital BOOLEAN DEFAULT false,
    digital_signature TEXT,
    qr_code TEXT,
    
    -- Follow-up
    follow_up_required BOOLEAN DEFAULT false,
    follow_up_date DATE,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- PRESCRIPTION ITEMS TABLE
-- ============================================================================
CREATE TABLE public.prescription_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prescription_id UUID NOT NULL REFERENCES public.prescriptions(id) ON DELETE CASCADE,
    
    -- Link to user's medication
    medication_id UUID REFERENCES public.medications(id),
    
    -- Medicine details
    medicine_name VARCHAR(200) NOT NULL,
    generic_name VARCHAR(200),
    brand_name VARCHAR(100),
    
    -- Dosage
    dosage VARCHAR(50),
    dosage_unit VARCHAR(30),
    strength VARCHAR(50),
    form VARCHAR(30),
    
    -- Frequency
    frequency VARCHAR(50),
    frequency_per_day INT,
    timing TEXT[],
    
    -- Duration
    duration_days INT,
    duration_text VARCHAR(50),
    
    -- Quantity
    quantity INT,
    quantity_unit VARCHAR(30),
    
    -- Instructions
    instructions TEXT,
    before_food BOOLEAN,
    
    -- Substitution
    substitution_allowed BOOLEAN DEFAULT true,
    
    -- Route
    route VARCHAR(30),
    
    -- Order in prescription
    sort_order INT DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- PHARMACIES TABLE
-- ============================================================================
CREATE TABLE public.pharmacies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Basic info
    name VARCHAR(200) NOT NULL,
    license_number VARCHAR(50),
    
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
    whatsapp VARCHAR(20),
    email VARCHAR(255),
    
    -- Services
    delivery_available BOOLEAN DEFAULT false,
    delivery_radius_km DECIMAL(5,2),
    min_order_amount DECIMAL(10,2),
    delivery_fee DECIMAL(10,2),
    free_delivery_above DECIMAL(10,2),
    
    -- Hours
    operating_hours JSONB,
    is_24x7 BOOLEAN DEFAULT false,
    
    -- Online
    website VARCHAR(255),
    app_available BOOLEAN DEFAULT false,
    online_ordering BOOLEAN DEFAULT false,
    
    -- Payment
    accepts_insurance BOOLEAN DEFAULT false,
    insurance_providers TEXT[],
    payment_methods TEXT[],
    
    -- Ratings
    avg_rating DECIMAL(2,1),
    total_reviews INT DEFAULT 0,
    
    -- Verification
    is_verified BOOLEAN DEFAULT false,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- MEDICINE ORDERS TABLE
-- ============================================================================
CREATE TABLE public.medicine_orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    prescription_id UUID REFERENCES public.prescriptions(id),
    pharmacy_id UUID REFERENCES public.pharmacies(id),
    
    -- Order details
    order_number VARCHAR(50),
    order_date TIMESTAMPTZ DEFAULT NOW(),
    
    -- Items (JSONB for flexibility)
    items JSONB NOT NULL,
    -- Structure: [{medicine_name, quantity, unit_price, total_price, prescription_item_id}]
    
    -- Pricing
    subtotal DECIMAL(10,2),
    discount_amount DECIMAL(10,2) DEFAULT 0,
    discount_code VARCHAR(50),
    tax_amount DECIMAL(10,2) DEFAULT 0,
    delivery_charge DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(10,2),
    
    -- Delivery
    delivery_type VARCHAR(20) CHECK (delivery_type IN ('pickup', 'delivery')),
    delivery_address TEXT,
    delivery_city VARCHAR(100),
    delivery_pincode VARCHAR(10),
    delivery_instructions TEXT,
    
    -- Timing
    expected_delivery TIMESTAMPTZ,
    actual_delivery TIMESTAMPTZ,
    
    -- Status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending', 'confirmed', 'processing', 'ready',
        'out_for_delivery', 'delivered', 'cancelled', 'returned'
    )),
    status_history JSONB DEFAULT '[]',
    
    -- Payment
    payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN (
        'pending', 'paid', 'failed', 'refunded', 'partial_refund'
    )),
    payment_method VARCHAR(30),
    payment_reference VARCHAR(100),
    
    -- Cancellation
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- MY PHARMACIES TABLE
-- ============================================================================
CREATE TABLE public.my_pharmacies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Link to verified pharmacy (optional)
    pharmacy_id UUID REFERENCES public.pharmacies(id),
    
    -- Custom entry
    custom_name VARCHAR(200),
    custom_phone VARCHAR(20),
    custom_address TEXT,
    custom_city VARCHAR(100),
    
    -- Preferences
    is_preferred BOOLEAN DEFAULT false,
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(health_profile_id, pharmacy_id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_prescriptions_profile ON public.prescriptions(health_profile_id);
CREATE INDEX idx_prescriptions_date ON public.prescriptions(health_profile_id, prescription_date DESC);
CREATE INDEX idx_prescriptions_status ON public.prescriptions(health_profile_id, status);
CREATE INDEX idx_prescriptions_doctor ON public.prescriptions(doctor_id);
CREATE INDEX idx_prescription_items_prescription ON public.prescription_items(prescription_id);
CREATE INDEX idx_pharmacies_city ON public.pharmacies(city);
CREATE INDEX idx_pharmacies_location ON public.pharmacies(latitude, longitude);
CREATE INDEX idx_medicine_orders_profile ON public.medicine_orders(health_profile_id);
CREATE INDEX idx_medicine_orders_status ON public.medicine_orders(health_profile_id, status);
CREATE INDEX idx_medicine_orders_date ON public.medicine_orders(health_profile_id, order_date DESC);
CREATE INDEX idx_my_pharmacies_profile ON public.my_pharmacies(health_profile_id);

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER prescriptions_updated_at
    BEFORE UPDATE ON public.prescriptions
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER pharmacies_updated_at
    BEFORE UPDATE ON public.pharmacies
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER medicine_orders_updated_at
    BEFORE UPDATE ON public.medicine_orders
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER my_pharmacies_updated_at
    BEFORE UPDATE ON public.my_pharmacies
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
