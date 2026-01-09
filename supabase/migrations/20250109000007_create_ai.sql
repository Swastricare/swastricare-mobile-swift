-- ============================================================================
-- AI MODULE
-- ============================================================================
-- Tables: ai_conversations, ai_insights, ai_image_analysis, ai_usage_logs

-- ============================================================================
-- AI CONVERSATIONS TABLE
-- ============================================================================
CREATE TABLE public.ai_conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    
    -- Conversation metadata
    title VARCHAR(200),
    conversation_type VARCHAR(30) CHECK (conversation_type IN (
        'general_health', 'symptom_check', 'medication_query',
        'nutrition_advice', 'fitness_guidance', 'mental_health',
        'lab_results', 'follow_up', 'other'
    )),
    
    -- Messages stored as JSONB array
    messages JSONB NOT NULL DEFAULT '[]',
    -- Structure: [{role: "user"|"assistant", content: string, timestamp: string}]
    
    -- Context provided to AI
    context_data JSONB,
    
    -- Model info
    model_used VARCHAR(50),
    
    -- Summary
    ai_summary TEXT,
    key_points TEXT[],
    
    -- Follow-up
    follow_up_required BOOLEAN DEFAULT false,
    follow_up_actions TEXT[],
    
    -- Rating
    user_rating INT CHECK (user_rating BETWEEN 1 AND 5),
    user_feedback TEXT,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active', 'archived', 'flagged'
    )),
    
    -- Tokens used
    total_tokens_used INT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- AI INSIGHTS TABLE
-- ============================================================================
CREATE TABLE public.ai_insights (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Insight type
    insight_type VARCHAR(30) NOT NULL CHECK (insight_type IN (
        'health_trend', 'medication_reminder', 'lifestyle_suggestion',
        'risk_alert', 'achievement', 'correlation', 'prediction',
        'summary', 'recommendation', 'warning'
    )),
    
    -- Priority/severity
    priority VARCHAR(20) DEFAULT 'low' CHECK (priority IN (
        'low', 'medium', 'high', 'urgent'
    )),
    
    -- Content
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    detailed_analysis TEXT,
    
    -- Data source
    data_sources TEXT[], -- medications, vitals, activities, etc.
    data_range_start DATE,
    data_range_end DATE,
    
    -- Supporting data
    supporting_data JSONB,
    confidence_score DECIMAL(3,2), -- 0.00 to 1.00
    
    -- Actions
    suggested_actions TEXT[],
    action_taken BOOLEAN DEFAULT false,
    action_taken_at TIMESTAMPTZ,
    
    -- Dismissal
    is_dismissed BOOLEAN DEFAULT false,
    dismissed_at TIMESTAMPTZ,
    dismiss_reason TEXT,
    
    -- Display
    show_in_dashboard BOOLEAN DEFAULT true,
    expires_at TIMESTAMPTZ,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- AI IMAGE ANALYSIS TABLE
-- ============================================================================
CREATE TABLE public.ai_image_analysis (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id),
    
    -- Image details
    image_url TEXT NOT NULL,
    image_type VARCHAR(30) CHECK (image_type IN (
        'skin_condition', 'wound', 'rash', 'medication', 'food',
        'lab_report', 'prescription', 'medical_document', 'other'
    )),
    
    -- Analysis request
    user_query TEXT,
    analysis_context TEXT,
    
    -- Results
    analysis_result JSONB,
    primary_finding TEXT,
    confidence_score DECIMAL(3,2),
    
    -- Detailed findings
    findings TEXT[],
    concerns TEXT[],
    recommendations TEXT[],
    
    -- Medical disclaimer acknowledged
    disclaimer_acknowledged BOOLEAN DEFAULT false,
    
    -- Follow-up
    requires_medical_attention BOOLEAN DEFAULT false,
    urgency_level VARCHAR(20) CHECK (urgency_level IN (
        'none', 'low', 'medium', 'high', 'emergency'
    )),
    
    -- Model info
    model_used VARCHAR(50),
    processing_time_ms INT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- AI USAGE LOGS TABLE
-- ============================================================================
CREATE TABLE public.ai_usage_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    health_profile_id UUID REFERENCES public.health_profiles(id) ON DELETE SET NULL,
    
    -- Request type
    request_type VARCHAR(30) NOT NULL CHECK (request_type IN (
        'chat', 'image_analysis', 'text_generation', 'summarization',
        'translation', 'health_analysis', 'insight_generation', 'other'
    )),
    
    -- Model info
    model_name VARCHAR(50),
    model_provider VARCHAR(30), -- openai, anthropic, google, etc.
    
    -- Token usage
    prompt_tokens INT,
    completion_tokens INT,
    total_tokens INT,
    
    -- Cost (if applicable)
    estimated_cost DECIMAL(10,6),
    currency VARCHAR(3) DEFAULT 'USD',
    
    -- Performance
    latency_ms INT,
    
    -- Status
    status VARCHAR(20) CHECK (status IN (
        'success', 'error', 'timeout', 'rate_limited'
    )),
    error_message TEXT,
    
    -- Reference
    conversation_id UUID REFERENCES public.ai_conversations(id) ON DELETE SET NULL,
    image_analysis_id UUID REFERENCES public.ai_image_analysis(id) ON DELETE SET NULL,
    
    -- Request metadata
    request_metadata JSONB,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_ai_conversations_profile ON public.ai_conversations(health_profile_id);
CREATE INDEX idx_ai_conversations_user ON public.ai_conversations(user_id);
CREATE INDEX idx_ai_conversations_type ON public.ai_conversations(health_profile_id, conversation_type);
CREATE INDEX idx_ai_conversations_created ON public.ai_conversations(health_profile_id, created_at DESC);
CREATE INDEX idx_ai_insights_profile ON public.ai_insights(health_profile_id);
CREATE INDEX idx_ai_insights_type ON public.ai_insights(health_profile_id, insight_type);
CREATE INDEX idx_ai_insights_priority ON public.ai_insights(health_profile_id, priority) WHERE is_dismissed = false;
CREATE INDEX idx_ai_insights_dashboard ON public.ai_insights(health_profile_id) WHERE show_in_dashboard = true AND is_dismissed = false;
CREATE INDEX idx_ai_image_analysis_profile ON public.ai_image_analysis(health_profile_id);
CREATE INDEX idx_ai_image_analysis_type ON public.ai_image_analysis(health_profile_id, image_type);
CREATE INDEX idx_ai_usage_logs_user ON public.ai_usage_logs(user_id);
CREATE INDEX idx_ai_usage_logs_created ON public.ai_usage_logs(user_id, created_at DESC);

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER ai_conversations_updated_at
    BEFORE UPDATE ON public.ai_conversations
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
