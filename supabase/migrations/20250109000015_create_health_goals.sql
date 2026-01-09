-- ============================================================================
-- HEALTH GOALS & PROGRAMS MODULE
-- ============================================================================
-- Tables: health_goals, goal_milestones, health_programs, user_programs

-- ============================================================================
-- HEALTH GOALS TABLE
-- ============================================================================
CREATE TABLE public.health_goals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Goal type
    goal_type VARCHAR(30) NOT NULL CHECK (goal_type IN (
        'weight_loss', 'weight_gain', 'weight_maintain',
        'fitness', 'strength', 'endurance', 'flexibility',
        'sleep', 'hydration', 'nutrition',
        'medication_adherence', 'blood_sugar', 'blood_pressure',
        'cholesterol', 'steps', 'exercise', 'meditation',
        'quit_smoking', 'reduce_alcohol', 'stress_management',
        'custom'
    )),
    
    -- Goal details
    title VARCHAR(200) NOT NULL,
    description TEXT,
    motivation TEXT,
    
    -- Target
    target_value DECIMAL(10,2),
    target_unit VARCHAR(30),
    target_direction VARCHAR(20) CHECK (target_direction IN (
        'increase', 'decrease', 'maintain', 'reach'
    )),
    
    -- Current progress
    start_value DECIMAL(10,2),
    current_value DECIMAL(10,2),
    
    -- Timeline
    start_date DATE NOT NULL,
    target_date DATE,
    
    -- Frequency
    frequency VARCHAR(20) CHECK (frequency IN (
        'daily', 'weekly', 'monthly', 'one_time'
    )),
    daily_target DECIMAL(10,2),
    weekly_target DECIMAL(10,2),
    
    -- Progress
    progress_percentage DECIMAL(5,2) DEFAULT 0,
    days_completed INT DEFAULT 0,
    days_missed INT DEFAULT 0,
    current_streak INT DEFAULT 0,
    best_streak INT DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active', 'completed', 'paused', 'abandoned', 'expired'
    )),
    completed_at TIMESTAMPTZ,
    
    -- AI coaching
    ai_recommendations TEXT[],
    ai_insights TEXT[],
    last_ai_review TIMESTAMPTZ,
    
    -- Reminders
    reminder_enabled BOOLEAN DEFAULT true,
    reminder_time TIME,
    reminder_days INT[],
    
    -- Sharing
    is_shared BOOLEAN DEFAULT false,
    shared_with UUID[],
    
    -- Priority
    priority VARCHAR(20) DEFAULT 'medium' CHECK (priority IN (
        'low', 'medium', 'high'
    )),
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- GOAL MILESTONES TABLE
-- ============================================================================
CREATE TABLE public.goal_milestones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    goal_id UUID NOT NULL REFERENCES public.health_goals(id) ON DELETE CASCADE,
    
    -- Milestone details
    title VARCHAR(100) NOT NULL,
    description TEXT,
    
    -- Target
    target_value DECIMAL(10,2),
    target_percentage DECIMAL(5,2),
    target_date DATE,
    
    -- Order
    milestone_order INT DEFAULT 0,
    
    -- Status
    achieved BOOLEAN DEFAULT false,
    achieved_at TIMESTAMPTZ,
    achieved_value DECIMAL(10,2),
    
    -- Reward
    reward_type VARCHAR(30),
    reward_points INT,
    reward_badge VARCHAR(50),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- HEALTH PROGRAMS TABLE (Catalog)
-- ============================================================================
CREATE TABLE public.health_programs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Program info
    name VARCHAR(200) NOT NULL,
    slug VARCHAR(100) UNIQUE,
    description TEXT,
    
    -- Type
    program_type VARCHAR(30) CHECK (program_type IN (
        'weight_loss', 'weight_gain', 'fitness', 'diabetes_management',
        'heart_health', 'mental_wellness', 'sleep_improvement',
        'nutrition', 'stress_management', 'smoking_cessation',
        'pregnancy', 'post_pregnancy', 'senior_health', 'custom'
    )),
    
    -- Duration
    duration_days INT,
    duration_weeks INT,
    
    -- Difficulty
    difficulty VARCHAR(20) CHECK (difficulty IN (
        'beginner', 'intermediate', 'advanced'
    )),
    
    -- Content
    overview TEXT,
    what_you_learn TEXT[],
    benefits TEXT[],
    requirements TEXT[],
    
    -- Structure
    total_modules INT,
    total_activities INT,
    daily_time_mins INT,
    
    -- Media
    thumbnail_url TEXT,
    banner_url TEXT,
    intro_video_url TEXT,
    
    -- Pricing
    is_premium BOOLEAN DEFAULT false,
    price DECIMAL(10,2),
    currency VARCHAR(3) DEFAULT 'INR',
    
    -- Ratings
    avg_rating DECIMAL(2,1),
    total_ratings INT DEFAULT 0,
    total_completions INT DEFAULT 0,
    completion_rate DECIMAL(5,2),
    
    -- Author
    author_name VARCHAR(100),
    author_credentials TEXT,
    author_photo_url TEXT,
    
    -- Tags
    tags TEXT[],
    
    -- Visibility
    is_published BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- USER PROGRAMS TABLE
-- ============================================================================
CREATE TABLE public.user_programs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    program_id UUID NOT NULL REFERENCES public.health_programs(id),
    
    -- Enrollment
    enrolled_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    
    -- Progress
    current_day INT DEFAULT 1,
    current_module INT DEFAULT 1,
    current_activity INT DEFAULT 1,
    
    -- Completion
    days_completed INT DEFAULT 0,
    modules_completed INT DEFAULT 0,
    activities_completed INT DEFAULT 0,
    
    -- Progress tracking
    progress_percentage DECIMAL(5,2) DEFAULT 0,
    progress_data JSONB DEFAULT '{}',
    
    -- Status
    status VARCHAR(20) DEFAULT 'enrolled' CHECK (status IN (
        'enrolled', 'active', 'paused', 'completed', 'dropped'
    )),
    
    -- Dates
    last_activity_at TIMESTAMPTZ,
    paused_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    dropped_at TIMESTAMPTZ,
    
    -- Expected completion
    expected_completion_date DATE,
    
    -- Streaks
    current_streak INT DEFAULT 0,
    longest_streak INT DEFAULT 0,
    
    -- Rating
    user_rating INT CHECK (user_rating BETWEEN 1 AND 5),
    user_review TEXT,
    
    -- Certificate
    certificate_url TEXT,
    certificate_issued_at TIMESTAMPTZ,
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(health_profile_id, program_id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_health_goals_profile ON public.health_goals(health_profile_id);
CREATE INDEX idx_health_goals_type ON public.health_goals(health_profile_id, goal_type);
CREATE INDEX idx_health_goals_status ON public.health_goals(health_profile_id, status);
CREATE INDEX idx_health_goals_active ON public.health_goals(health_profile_id) WHERE status = 'active';
CREATE INDEX idx_goal_milestones_goal ON public.goal_milestones(goal_id);
CREATE INDEX idx_goal_milestones_pending ON public.goal_milestones(goal_id) WHERE achieved = false;
CREATE INDEX idx_health_programs_type ON public.health_programs(program_type);
CREATE INDEX idx_health_programs_published ON public.health_programs(is_published) WHERE is_published = true;
CREATE INDEX idx_health_programs_featured ON public.health_programs(is_featured) WHERE is_featured = true;
CREATE INDEX idx_user_programs_profile ON public.user_programs(health_profile_id);
CREATE INDEX idx_user_programs_status ON public.user_programs(health_profile_id, status);
CREATE INDEX idx_user_programs_active ON public.user_programs(health_profile_id) WHERE status = 'active';

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER health_goals_updated_at
    BEFORE UPDATE ON public.health_goals
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER health_programs_updated_at
    BEFORE UPDATE ON public.health_programs
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER user_programs_updated_at
    BEFORE UPDATE ON public.user_programs
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
