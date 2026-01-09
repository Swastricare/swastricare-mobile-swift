-- ============================================================================
-- ENGAGEMENT MODULE
-- ============================================================================
-- Tables: reminders, reminder_logs, notifications, user_streaks, achievements

-- ============================================================================
-- REMINDERS TABLE
-- ============================================================================
CREATE TABLE public.reminders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    
    -- Reminder type
    reminder_type VARCHAR(30) NOT NULL CHECK (reminder_type IN (
        'medication', 'appointment', 'hydration', 'exercise',
        'measurement', 'meal', 'sleep', 'custom'
    )),
    
    -- Related entity
    related_entity_type VARCHAR(30),
    related_entity_id UUID,
    
    -- Content
    title VARCHAR(200) NOT NULL,
    message TEXT,
    
    -- Schedule
    scheduled_time TIME NOT NULL,
    timezone VARCHAR(50) DEFAULT 'UTC',
    
    -- Recurrence
    is_recurring BOOLEAN DEFAULT true,
    recurrence_type VARCHAR(20) CHECK (recurrence_type IN (
        'daily', 'weekly', 'monthly', 'custom'
    )),
    recurrence_days INT[], -- 0-6 for weekly, 1-31 for monthly
    recurrence_interval INT DEFAULT 1,
    
    -- Date range
    start_date DATE NOT NULL,
    end_date DATE,
    
    -- Notification settings
    notification_enabled BOOLEAN DEFAULT true,
    notification_sound VARCHAR(50),
    notification_vibrate BOOLEAN DEFAULT true,
    
    -- Snooze settings
    snooze_enabled BOOLEAN DEFAULT true,
    snooze_duration_minutes INT DEFAULT 10,
    max_snooze_count INT DEFAULT 3,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- REMINDER LOGS TABLE
-- ============================================================================
CREATE TABLE public.reminder_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reminder_id UUID NOT NULL REFERENCES public.reminders(id) ON DELETE CASCADE,
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Scheduled time for this instance
    scheduled_at TIMESTAMPTZ NOT NULL,
    
    -- Delivery status
    delivered_at TIMESTAMPTZ,
    delivery_status VARCHAR(20) CHECK (delivery_status IN (
        'pending', 'delivered', 'failed', 'skipped'
    )),
    delivery_channel VARCHAR(20), -- push, email, sms
    
    -- User action
    user_action VARCHAR(20) CHECK (user_action IN (
        'acknowledged', 'snoozed', 'dismissed', 'completed', 'ignored'
    )),
    actioned_at TIMESTAMPTZ,
    
    -- Snooze tracking
    snooze_count INT DEFAULT 0,
    snoozed_until TIMESTAMPTZ,
    
    -- Notes
    notes TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- NOTIFICATIONS TABLE
-- ============================================================================
CREATE TABLE public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    health_profile_id UUID REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Notification type
    notification_type VARCHAR(30) NOT NULL CHECK (notification_type IN (
        'reminder', 'alert', 'insight', 'achievement', 'system',
        'appointment', 'medication', 'family', 'promotion', 'other'
    )),
    
    -- Priority
    priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN (
        'low', 'normal', 'high', 'urgent'
    )),
    
    -- Content
    title VARCHAR(200) NOT NULL,
    body TEXT NOT NULL,
    
    -- Deep link
    action_url TEXT,
    action_type VARCHAR(30),
    action_data JSONB,
    
    -- Visual
    icon VARCHAR(50),
    image_url TEXT,
    
    -- Status
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMPTZ,
    
    -- Delivery
    channels TEXT[] DEFAULT ARRAY['push'],
    delivered_via TEXT[],
    delivered_at TIMESTAMPTZ,
    
    -- Expiry
    expires_at TIMESTAMPTZ,
    
    -- Grouping
    group_key VARCHAR(100),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- USER STREAKS TABLE
-- ============================================================================
CREATE TABLE public.user_streaks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Streak type
    streak_type VARCHAR(30) NOT NULL CHECK (streak_type IN (
        'medication_adherence', 'hydration', 'exercise', 'sleep',
        'logging', 'app_usage', 'steps', 'meditation', 'custom'
    )),
    
    -- Current streak
    current_streak INT DEFAULT 0,
    current_streak_start DATE,
    
    -- Best streak
    longest_streak INT DEFAULT 0,
    longest_streak_start DATE,
    longest_streak_end DATE,
    
    -- Last activity
    last_activity_date DATE,
    last_activity_at TIMESTAMPTZ,
    
    -- Streak requirements
    daily_target DECIMAL(10,2),
    target_unit VARCHAR(30),
    
    -- Statistics
    total_days_completed INT DEFAULT 0,
    total_days_missed INT DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(health_profile_id, streak_type)
);

-- ============================================================================
-- ACHIEVEMENTS TABLE
-- ============================================================================
CREATE TABLE public.achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Achievement type
    achievement_type VARCHAR(50) NOT NULL,
    achievement_key VARCHAR(50) NOT NULL, -- unique identifier like 'first_medication', '7_day_streak'
    
    -- Display
    title VARCHAR(100) NOT NULL,
    description TEXT,
    icon VARCHAR(50),
    badge_url TEXT,
    
    -- Category
    category VARCHAR(30) CHECK (category IN (
        'medication', 'fitness', 'nutrition', 'hydration', 'sleep',
        'streak', 'milestone', 'social', 'special'
    )),
    
    -- Points/XP
    points_awarded INT DEFAULT 0,
    xp_awarded INT DEFAULT 0,
    
    -- Progress (for multi-step achievements)
    progress_current INT DEFAULT 0,
    progress_required INT DEFAULT 1,
    progress_percentage DECIMAL(5,2) DEFAULT 0,
    
    -- Status
    is_unlocked BOOLEAN DEFAULT false,
    unlocked_at TIMESTAMPTZ,
    
    -- Sharing
    is_shared BOOLEAN DEFAULT false,
    shared_at TIMESTAMPTZ,
    
    -- Rarity
    rarity VARCHAR(20) CHECK (rarity IN (
        'common', 'uncommon', 'rare', 'epic', 'legendary'
    )),
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(health_profile_id, achievement_key)
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_reminders_profile ON public.reminders(health_profile_id);
CREATE INDEX idx_reminders_user ON public.reminders(user_id);
CREATE INDEX idx_reminders_active ON public.reminders(health_profile_id) WHERE is_active = true;
CREATE INDEX idx_reminders_type ON public.reminders(health_profile_id, reminder_type);
CREATE INDEX idx_reminder_logs_reminder ON public.reminder_logs(reminder_id);
CREATE INDEX idx_reminder_logs_profile_date ON public.reminder_logs(health_profile_id, scheduled_at DESC);
CREATE INDEX idx_notifications_user ON public.notifications(user_id);
CREATE INDEX idx_notifications_unread ON public.notifications(user_id) WHERE is_read = false;
CREATE INDEX idx_notifications_created ON public.notifications(user_id, created_at DESC);
CREATE INDEX idx_user_streaks_profile ON public.user_streaks(health_profile_id);
CREATE INDEX idx_user_streaks_type ON public.user_streaks(health_profile_id, streak_type);
CREATE INDEX idx_achievements_profile ON public.achievements(health_profile_id);
CREATE INDEX idx_achievements_unlocked ON public.achievements(health_profile_id) WHERE is_unlocked = true;
CREATE INDEX idx_achievements_category ON public.achievements(health_profile_id, category);

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER reminders_updated_at
    BEFORE UPDATE ON public.reminders
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER user_streaks_updated_at
    BEFORE UPDATE ON public.user_streaks
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER achievements_updated_at
    BEFORE UPDATE ON public.achievements
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
