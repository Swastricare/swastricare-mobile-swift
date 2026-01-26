-- ============================================================================
-- AI MEDICAL INTERACTIONS TABLE
-- ============================================================================
-- Tracks all MedGemma medical AI interactions for safety, compliance, and analytics
-- Created: 2026-01-14

-- ============================================================================
-- AI MEDICAL INTERACTIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.ai_medical_interactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    health_profile_id UUID REFERENCES public.health_profiles(id) ON DELETE SET NULL,
    
    -- Query classification
    query_type VARCHAR(30) NOT NULL CHECK (query_type IN (
        'medical_chat',      -- MedGemma 27B text queries
        'image_analysis',    -- MedGemma 4B image analysis
        'symptom_check',     -- Symptom-related queries
        'medication_query',  -- Medication-related queries
        'lab_interpretation', -- Lab report interpretation
        'general_health'     -- General health questions routed to MedGemma
    )),
    
    -- Model information
    model_used VARCHAR(50) NOT NULL, -- medgemma-27b, medgemma-4b, gemini-medical
    
    -- Query details (sanitized - no PII)
    query_summary VARCHAR(500), -- Summarized/truncated query for analytics
    
    -- Context
    has_health_context BOOLEAN DEFAULT false,
    has_conversation_history BOOLEAN DEFAULT false,
    
    -- Image analysis specific
    image_type VARCHAR(30), -- prescription, lab_report, xray, etc.
    
    -- Response metadata
    response_length INT,
    processing_time_ms INT,
    
    -- Safety flags
    is_emergency_detected BOOLEAN DEFAULT false,
    emergency_type VARCHAR(50), -- chest_pain, stroke, etc.
    
    disclaimer_shown BOOLEAN DEFAULT true,
    user_acknowledged_disclaimer BOOLEAN DEFAULT false,
    
    -- Follow-up recommended
    professional_consultation_recommended BOOLEAN DEFAULT false,
    urgency_level VARCHAR(20) DEFAULT 'none' CHECK (urgency_level IN (
        'none', 'low', 'medium', 'high', 'emergency'
    )),
    
    -- Error tracking
    had_error BOOLEAN DEFAULT false,
    error_type VARCHAR(50),
    fallback_used BOOLEAN DEFAULT false, -- Did we fall back to Gemini?
    
    -- Additional metadata
    metadata JSONB,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- USER MEDICAL CONSENT TABLE
-- ============================================================================
-- Tracks user acknowledgment of medical AI disclaimers
CREATE TABLE IF NOT EXISTS public.ai_medical_consent (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    
    -- Consent type
    consent_type VARCHAR(30) NOT NULL CHECK (consent_type IN (
        'initial_disclaimer',    -- First-time medical AI usage
        'image_analysis',        -- Consent for image analysis
        'data_processing'        -- Consent for health data processing
    )),
    
    -- Consent details
    consent_version VARCHAR(20) NOT NULL DEFAULT '1.0',
    acknowledged_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Device info
    device_type VARCHAR(20), -- ios, android, web
    app_version VARCHAR(20),
    
    -- IP for compliance (hashed)
    ip_hash VARCHAR(64),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(user_id, consent_type, consent_version)
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_ai_medical_interactions_user 
    ON public.ai_medical_interactions(user_id);
CREATE INDEX IF NOT EXISTS idx_ai_medical_interactions_profile 
    ON public.ai_medical_interactions(health_profile_id);
CREATE INDEX IF NOT EXISTS idx_ai_medical_interactions_type 
    ON public.ai_medical_interactions(query_type);
CREATE INDEX IF NOT EXISTS idx_ai_medical_interactions_model 
    ON public.ai_medical_interactions(model_used);
CREATE INDEX IF NOT EXISTS idx_ai_medical_interactions_created 
    ON public.ai_medical_interactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_medical_interactions_emergency 
    ON public.ai_medical_interactions(user_id) WHERE is_emergency_detected = true;

CREATE INDEX IF NOT EXISTS idx_ai_medical_consent_user 
    ON public.ai_medical_consent(user_id);

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE public.ai_medical_interactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_medical_consent ENABLE ROW LEVEL SECURITY;

-- Users can only see their own medical interactions
CREATE POLICY "Users can view own medical interactions" 
    ON public.ai_medical_interactions FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own medical interactions" 
    ON public.ai_medical_interactions FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- Users can manage their own consent records
CREATE POLICY "Users can view own consent records" 
    ON public.ai_medical_consent FOR SELECT 
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own consent records" 
    ON public.ai_medical_consent FOR INSERT 
    WITH CHECK (auth.uid() = user_id);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE public.ai_medical_interactions IS 
    'Tracks all MedGemma medical AI interactions for safety, compliance, and analytics';

COMMENT ON TABLE public.ai_medical_consent IS 
    'Stores user acknowledgment of medical AI disclaimers for compliance';

COMMENT ON COLUMN public.ai_medical_interactions.query_summary IS 
    'Sanitized/truncated query summary - should not contain PII';

COMMENT ON COLUMN public.ai_medical_interactions.is_emergency_detected IS 
    'True if emergency keywords were detected in the query';

COMMENT ON COLUMN public.ai_medical_interactions.fallback_used IS 
    'True if MedGemma was unavailable and Gemini was used instead';
