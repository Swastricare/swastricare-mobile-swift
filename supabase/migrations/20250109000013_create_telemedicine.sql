-- ============================================================================
-- TELEMEDICINE MODULE
-- ============================================================================
-- Tables: video_consultations, chat_consultations, chat_messages

-- ============================================================================
-- VIDEO CONSULTATIONS TABLE
-- ============================================================================
CREATE TABLE public.video_consultations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    appointment_id UUID REFERENCES public.appointments(id),
    doctor_id UUID REFERENCES public.doctors(id),
    provider_id UUID REFERENCES public.healthcare_providers(id),
    
    -- Session info
    session_id VARCHAR(100),
    platform VARCHAR(30) CHECK (platform IN (
        'in_app', 'zoom', 'google_meet', 'teams', 'custom', 'other'
    )),
    
    -- Timing
    scheduled_at TIMESTAMPTZ NOT NULL,
    duration_mins INT DEFAULT 15,
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    actual_duration_mins INT,
    
    -- URLs
    patient_join_url TEXT,
    doctor_join_url TEXT,
    
    -- Recording
    recording_enabled BOOLEAN DEFAULT false,
    recording_url TEXT,
    recording_consent BOOLEAN DEFAULT false,
    
    -- Status
    status VARCHAR(20) DEFAULT 'scheduled' CHECK (status IN (
        'scheduled', 'confirmed', 'waiting_room', 'in_progress',
        'completed', 'cancelled', 'no_show_patient', 'no_show_doctor',
        'technical_issue', 'rescheduled'
    )),
    status_history JSONB DEFAULT '[]',
    
    -- Technical quality
    video_quality VARCHAR(20),
    audio_quality VARCHAR(20),
    connection_issues TEXT[],
    
    -- Outcome
    prescription_id UUID REFERENCES public.prescriptions(id),
    
    -- Follow-up
    follow_up_required BOOLEAN DEFAULT false,
    follow_up_type VARCHAR(20),
    follow_up_date DATE,
    
    -- Payment
    fee DECIMAL(10,2),
    discount DECIMAL(10,2) DEFAULT 0,
    total_fee DECIMAL(10,2),
    payment_status VARCHAR(20) CHECK (payment_status IN (
        'pending', 'paid', 'refunded', 'failed'
    )),
    payment_method VARCHAR(30),
    payment_reference VARCHAR(100),
    
    -- Cancellation
    cancelled_by VARCHAR(20),
    cancellation_reason TEXT,
    refund_amount DECIMAL(10,2),
    
    -- Notes
    chief_complaint TEXT,
    consultation_notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- CHAT CONSULTATIONS TABLE
-- ============================================================================
CREATE TABLE public.chat_consultations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    doctor_id UUID REFERENCES public.doctors(id),
    provider_id UUID REFERENCES public.healthcare_providers(id),
    
    -- Session type
    consultation_type VARCHAR(30) DEFAULT 'general' CHECK (consultation_type IN (
        'general', 'follow_up', 'second_opinion', 'prescription_renewal',
        'lab_review', 'symptom_check'
    )),
    
    -- Topic
    topic VARCHAR(200),
    chief_complaint TEXT,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active', 'waiting_response', 'resolved', 'closed', 'expired'
    )),
    
    -- Timing
    started_at TIMESTAMPTZ DEFAULT NOW(),
    last_message_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    
    -- Response time
    response_time_mins INT,
    
    -- Message counts
    total_messages INT DEFAULT 0,
    patient_messages INT DEFAULT 0,
    doctor_messages INT DEFAULT 0,
    
    -- Outcome
    prescription_id UUID REFERENCES public.prescriptions(id),
    resolution_summary TEXT,
    
    -- Follow-up
    follow_up_required BOOLEAN DEFAULT false,
    follow_up_type VARCHAR(20),
    
    -- Payment
    fee DECIMAL(10,2),
    payment_status VARCHAR(20) CHECK (payment_status IN (
        'pending', 'paid', 'refunded', 'failed'
    )),
    payment_method VARCHAR(30),
    
    -- Rating
    patient_rating INT CHECK (patient_rating BETWEEN 1 AND 5),
    patient_feedback TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- CHAT MESSAGES TABLE
-- ============================================================================
CREATE TABLE public.chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    consultation_id UUID NOT NULL REFERENCES public.chat_consultations(id) ON DELETE CASCADE,
    
    -- Sender
    sender_type VARCHAR(20) NOT NULL CHECK (sender_type IN (
        'patient', 'doctor', 'system', 'ai_assistant'
    )),
    sender_id UUID,
    sender_name VARCHAR(100),
    
    -- Message content
    message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN (
        'text', 'image', 'document', 'prescription', 'audio',
        'video', 'lab_report', 'vital_signs', 'system_message'
    )),
    content TEXT,
    
    -- Media
    media_url TEXT,
    media_type VARCHAR(50),
    media_size_bytes BIGINT,
    thumbnail_url TEXT,
    
    -- Referenced entities
    prescription_id UUID REFERENCES public.prescriptions(id),
    document_id UUID REFERENCES public.medical_documents(id),
    lab_report_id UUID REFERENCES public.lab_reports(id),
    
    -- Read status
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMPTZ,
    
    -- Delivery
    delivered_at TIMESTAMPTZ,
    delivery_status VARCHAR(20) CHECK (delivery_status IN (
        'sending', 'sent', 'delivered', 'read', 'failed'
    )),
    
    -- Metadata
    metadata JSONB,
    
    -- Deletion
    is_deleted BOOLEAN DEFAULT false,
    deleted_at TIMESTAMPTZ,
    deleted_by UUID,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_video_consultations_profile ON public.video_consultations(health_profile_id);
CREATE INDEX idx_video_consultations_scheduled ON public.video_consultations(health_profile_id, scheduled_at DESC);
CREATE INDEX idx_video_consultations_status ON public.video_consultations(health_profile_id, status);
CREATE INDEX idx_video_consultations_doctor ON public.video_consultations(doctor_id);
CREATE INDEX idx_chat_consultations_profile ON public.chat_consultations(health_profile_id);
CREATE INDEX idx_chat_consultations_status ON public.chat_consultations(health_profile_id, status);
CREATE INDEX idx_chat_consultations_doctor ON public.chat_consultations(doctor_id);
CREATE INDEX idx_chat_messages_consultation ON public.chat_messages(consultation_id);
CREATE INDEX idx_chat_messages_created ON public.chat_messages(consultation_id, created_at DESC);
CREATE INDEX idx_chat_messages_unread ON public.chat_messages(consultation_id) WHERE is_read = false;

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER video_consultations_updated_at
    BEFORE UPDATE ON public.video_consultations
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER chat_consultations_updated_at
    BEFORE UPDATE ON public.chat_consultations
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
