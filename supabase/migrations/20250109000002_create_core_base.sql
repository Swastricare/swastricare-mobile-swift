-- ============================================================================
-- CORE BASE MODULE
-- ============================================================================
-- Foundation tables: users, user_settings, health_profiles, family_groups, family_members

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- USERS TABLE
-- ============================================================================
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255),
    phone VARCHAR(20),
    
    -- Profile
    full_name VARCHAR(100),
    avatar_url TEXT,
    
    -- Preferences
    language VARCHAR(10) DEFAULT 'en',
    timezone VARCHAR(50) DEFAULT 'UTC',
    
    -- Status
    onboarding_completed BOOLEAN DEFAULT false,
    is_premium BOOLEAN DEFAULT false,
    premium_until TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ
);

-- ============================================================================
-- HEALTH PROFILES TABLE
-- ============================================================================
CREATE TABLE public.health_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    
    -- Basic Info
    full_name VARCHAR(100) NOT NULL,
    date_of_birth DATE,
    gender VARCHAR(20) CHECK (gender IN ('male', 'female', 'other', 'prefer_not_to_say')),
    blood_type VARCHAR(5) CHECK (blood_type IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
    
    -- Physical
    height_cm DECIMAL(5,2),
    weight_kg DECIMAL(5,2),
    
    -- Profile type
    profile_type VARCHAR(20) DEFAULT 'self' CHECK (profile_type IN ('self', 'dependent', 'family_member')),
    relationship VARCHAR(50),
    
    -- Avatar
    avatar_url TEXT,
    
    -- Status
    is_primary BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- USER SETTINGS TABLE
-- ============================================================================
CREATE TABLE public.user_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    
    -- Notification preferences
    notifications_enabled BOOLEAN DEFAULT true,
    email_notifications BOOLEAN DEFAULT true,
    push_notifications BOOLEAN DEFAULT true,
    sms_notifications BOOLEAN DEFAULT false,
    
    -- Notification timing
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    
    -- App preferences
    theme VARCHAR(20) DEFAULT 'system' CHECK (theme IN ('light', 'dark', 'system')),
    font_size VARCHAR(20) DEFAULT 'medium' CHECK (font_size IN ('small', 'medium', 'large')),
    haptics_enabled BOOLEAN DEFAULT true,
    
    -- Privacy
    analytics_enabled BOOLEAN DEFAULT true,
    data_sharing_enabled BOOLEAN DEFAULT false,
    
    -- Health data
    default_health_profile_id UUID REFERENCES public.health_profiles(id),
    unit_system VARCHAR(20) DEFAULT 'metric' CHECK (unit_system IN ('metric', 'imperial')),
    
    -- Biometric security
    biometric_enabled BOOLEAN DEFAULT false,
    auto_lock_minutes INT DEFAULT 5,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(user_id)
);

-- ============================================================================
-- FAMILY GROUPS TABLE
-- ============================================================================
CREATE TABLE public.family_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    
    name VARCHAR(100) NOT NULL DEFAULT 'My Family',
    description TEXT,
    
    -- Settings
    allow_member_invites BOOLEAN DEFAULT false,
    require_approval BOOLEAN DEFAULT true,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- FAMILY MEMBERS TABLE
-- ============================================================================
CREATE TABLE public.family_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    family_group_id UUID NOT NULL REFERENCES public.family_groups(id) ON DELETE CASCADE,
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    
    -- Who added this member
    added_by_user_id UUID REFERENCES public.users(id),
    
    -- Access control
    role VARCHAR(20) DEFAULT 'viewer' CHECK (role IN ('owner', 'caregiver', 'viewer', 'limited')),
    
    -- Permissions
    can_view BOOLEAN DEFAULT true,
    can_edit BOOLEAN DEFAULT false,
    can_add_medications BOOLEAN DEFAULT false,
    can_add_appointments BOOLEAN DEFAULT false,
    can_view_medical_documents BOOLEAN DEFAULT true,
    can_manage_members BOOLEAN DEFAULT false,
    
    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('pending', 'active', 'suspended', 'removed')),
    
    -- Relationship
    relationship VARCHAR(50),
    
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(family_group_id, health_profile_id)
);

-- ============================================================================
-- INDEXES
-- ============================================================================
CREATE INDEX idx_users_email ON public.users(email);
CREATE INDEX idx_health_profiles_user ON public.health_profiles(user_id);
CREATE INDEX idx_health_profiles_primary ON public.health_profiles(user_id) WHERE is_primary = true;
CREATE INDEX idx_user_settings_user ON public.user_settings(user_id);
CREATE INDEX idx_family_groups_owner ON public.family_groups(owner_user_id);
CREATE INDEX idx_family_members_group ON public.family_members(family_group_id);
CREATE INDEX idx_family_members_profile ON public.family_members(health_profile_id);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Auto-update updated_at timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Check family access
CREATE OR REPLACE FUNCTION public.has_family_access(
    profile_id UUID,
    required_permission TEXT DEFAULT 'view'
)
RETURNS BOOLEAN AS $$
DECLARE
    user_uuid UUID;
BEGIN
    user_uuid := auth.uid();
    
    IF user_uuid IS NULL THEN
        RETURN false;
    END IF;
    
    -- Check if user owns the profile directly
    IF EXISTS (
        SELECT 1 FROM public.health_profiles hp
        WHERE hp.id = profile_id AND hp.user_id = user_uuid
    ) THEN
        RETURN true;
    END IF;
    
    -- Check family access
    IF required_permission = 'view' THEN
        RETURN EXISTS (
            SELECT 1 FROM public.family_members fm
            JOIN public.family_groups fg ON fm.family_group_id = fg.id
            WHERE fm.health_profile_id = profile_id
            AND fg.owner_user_id = user_uuid
            AND fm.status = 'active'
            AND fm.can_view = true
        );
    ELSIF required_permission = 'edit' THEN
        RETURN EXISTS (
            SELECT 1 FROM public.family_members fm
            JOIN public.family_groups fg ON fm.family_group_id = fg.id
            WHERE fm.health_profile_id = profile_id
            AND fg.owner_user_id = user_uuid
            AND fm.status = 'active'
            AND fm.can_edit = true
        );
    END IF;
    
    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- TRIGGERS
-- ============================================================================
CREATE TRIGGER users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER health_profiles_updated_at
    BEFORE UPDATE ON public.health_profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER user_settings_updated_at
    BEFORE UPDATE ON public.user_settings
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER family_groups_updated_at
    BEFORE UPDATE ON public.family_groups
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER family_members_updated_at
    BEFORE UPDATE ON public.family_members
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
