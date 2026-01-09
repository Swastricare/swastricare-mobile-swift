-- ============================================================================
-- MEDICAL RECORDS MODULE
-- ============================================================================
-- Tables: document_folders, medical_documents, healthcare_providers, appointments, appointment_notes

-- ============================================================================
-- DOCUMENT FOLDERS TABLE
-- ============================================================================
CREATE TABLE public.document_folders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Folder info
    name VARCHAR(100) NOT NULL,
    description TEXT,
    color VARCHAR(20),
    icon VARCHAR(50),
    
    -- Hierarchy
    parent_folder_id UUID REFERENCES public.document_folders(id) ON DELETE CASCADE,
    
    -- Order
    sort_order INT DEFAULT 0,
    
    -- System folders
    is_system_folder BOOLEAN DEFAULT false,
    folder_type VARCHAR(30), -- lab_reports, prescriptions, insurance, imaging, etc.
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- MEDICAL DOCUMENTS TABLE
-- ============================================================================
CREATE TABLE public.medical_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    folder_id UUID REFERENCES public.document_folders(id) ON DELETE SET NULL,
    
    -- Document info
    title VARCHAR(200) NOT NULL,
    description TEXT,
    
    -- File details
    file_url TEXT NOT NULL,
    file_name VARCHAR(255),
    file_type VARCHAR(50), -- pdf, image, dicom
    file_size_bytes BIGINT,
    mime_type VARCHAR(100),
    
    -- Thumbnail
    thumbnail_url TEXT,
    
    -- Document type
    document_type VARCHAR(30) CHECK (document_type IN (
        'lab_report', 'prescription', 'imaging', 'discharge_summary',
        'insurance', 'vaccination', 'certificate', 'invoice', 'other'
    )),
    
    -- Document date (different from upload date)
    document_date DATE,
    
    -- Related entities
    provider_id UUID, -- Will reference healthcare_providers
    appointment_id UUID, -- Will reference appointments
    
    -- Tags
    tags TEXT[],
    
    -- AI processing
    ocr_text TEXT,
    ai_summary TEXT,
    ai_extracted_data JSONB,
    
    -- Security
    is_sensitive BOOLEAN DEFAULT false,
    is_encrypted BOOLEAN DEFAULT false,
    
    -- Sharing
    is_shared BOOLEAN DEFAULT false,
    share_expires_at TIMESTAMPTZ,
    
    -- Uploaded by
    uploaded_by UUID REFERENCES public.users(id),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- HEALTHCARE PROVIDERS TABLE
-- ============================================================================
CREATE TABLE public.healthcare_providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Provider details
    name VARCHAR(100) NOT NULL,
    provider_type VARCHAR(30) CHECK (provider_type IN (
        'doctor', 'dentist', 'therapist', 'specialist', 'hospital',
        'clinic', 'pharmacy', 'lab', 'other'
    )),
    
    -- Specialization
    specialization VARCHAR(100),
    sub_specialization VARCHAR(100),
    
    -- Contact
    phone VARCHAR(20),
    alternate_phone VARCHAR(20),
    email VARCHAR(255),
    
    -- Address
    address_line1 VARCHAR(200),
    address_line2 VARCHAR(200),
    city VARCHAR(100),
    state VARCHAR(100),
    pincode VARCHAR(10),
    country VARCHAR(50) DEFAULT 'India',
    
    -- Location
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    
    -- Consultation
    consultation_fee DECIMAL(10,2),
    
    -- Hours
    working_hours JSONB,
    
    -- Notes
    notes TEXT,
    
    -- Favorites
    is_favorite BOOLEAN DEFAULT false,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- APPOINTMENTS TABLE
-- ============================================================================
CREATE TABLE public.appointments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    provider_id UUID REFERENCES public.healthcare_providers(id) ON DELETE SET NULL,
    
    -- Appointment type
    appointment_type VARCHAR(30) CHECK (appointment_type IN (
        'checkup', 'follow_up', 'consultation', 'procedure',
        'lab_test', 'imaging', 'therapy', 'vaccination', 'other'
    )),
    
    -- Title and description
    title VARCHAR(200) NOT NULL,
    description TEXT,
    
    -- Timing
    scheduled_at TIMESTAMPTZ NOT NULL,
    duration_minutes INT DEFAULT 30,
    end_time TIMESTAMPTZ,
    
    -- Location
    location VARCHAR(200),
    is_video_consultation BOOLEAN DEFAULT false,
    video_link TEXT,
    
    -- Status
    status VARCHAR(20) DEFAULT 'scheduled' CHECK (status IN (
        'scheduled', 'confirmed', 'in_progress', 'completed',
        'cancelled', 'no_show', 'rescheduled'
    )),
    
    -- Reminder
    reminder_enabled BOOLEAN DEFAULT true,
    reminder_minutes_before INT DEFAULT 60,
    
    -- Preparation
    preparation_instructions TEXT,
    fasting_required BOOLEAN DEFAULT false,
    
    -- Outcome
    actual_start_time TIMESTAMPTZ,
    actual_end_time TIMESTAMPTZ,
    
    -- Reason
    reason_for_visit TEXT,
    symptoms TEXT[],
    
    -- Follow up
    follow_up_required BOOLEAN DEFAULT false,
    follow_up_date DATE,
    
    -- Cost
    estimated_cost DECIMAL(10,2),
    actual_cost DECIMAL(10,2),
    
    -- Notes
    notes TEXT,
    
    -- Created by
    created_by UUID REFERENCES public.users(id),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- APPOINTMENT NOTES TABLE
-- ============================================================================
CREATE TABLE public.appointment_notes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    appointment_id UUID NOT NULL REFERENCES public.appointments(id) ON DELETE CASCADE,
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Note content
    note_type VARCHAR(20) CHECK (note_type IN (
        'pre_visit', 'during_visit', 'post_visit', 'follow_up'
    )),
    content TEXT NOT NULL,
    
    -- Doctor's notes (if any)
    diagnosis TEXT,
    treatment_plan TEXT,
    
    -- Vitals recorded
    vitals_recorded JSONB,
    
    -- Attachments
    attachment_ids UUID[],
    
    -- Created by
    created_by UUID REFERENCES public.users(id),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- ADD FOREIGN KEY REFERENCES
-- ============================================================================
ALTER TABLE public.medical_documents 
    ADD CONSTRAINT fk_documents_provider 
    FOREIGN KEY (provider_id) REFERENCES public.healthcare_providers(id) ON DELETE SET NULL;

ALTER TABLE public.medical_documents 
    ADD CONSTRAINT fk_documents_appointment 
    FOREIGN KEY (appointment_id) REFERENCES public.appointments(id) ON DELETE SET NULL;

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_document_folders_profile ON public.document_folders(health_profile_id);
CREATE INDEX idx_document_folders_parent ON public.document_folders(parent_folder_id);
CREATE INDEX idx_medical_documents_profile ON public.medical_documents(health_profile_id);
CREATE INDEX idx_medical_documents_folder ON public.medical_documents(folder_id);
CREATE INDEX idx_medical_documents_type ON public.medical_documents(health_profile_id, document_type);
CREATE INDEX idx_medical_documents_date ON public.medical_documents(health_profile_id, document_date DESC);
CREATE INDEX idx_healthcare_providers_profile ON public.healthcare_providers(health_profile_id);
CREATE INDEX idx_healthcare_providers_type ON public.healthcare_providers(health_profile_id, provider_type);
CREATE INDEX idx_appointments_profile ON public.appointments(health_profile_id);
CREATE INDEX idx_appointments_scheduled ON public.appointments(health_profile_id, scheduled_at DESC);
CREATE INDEX idx_appointments_status ON public.appointments(health_profile_id, status);
CREATE INDEX idx_appointments_provider ON public.appointments(provider_id);
CREATE INDEX idx_appointment_notes_appointment ON public.appointment_notes(appointment_id);

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER document_folders_updated_at
    BEFORE UPDATE ON public.document_folders
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER medical_documents_updated_at
    BEFORE UPDATE ON public.medical_documents
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER healthcare_providers_updated_at
    BEFORE UPDATE ON public.healthcare_providers
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER appointments_updated_at
    BEFORE UPDATE ON public.appointments
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER appointment_notes_updated_at
    BEFORE UPDATE ON public.appointment_notes
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
