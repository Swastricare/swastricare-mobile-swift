-- Create family_groups table with invite_code
CREATE TABLE IF NOT EXISTS public.family_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL DEFAULT 'My Family',
    description TEXT,
    invite_code VARCHAR(8) UNIQUE,
    allow_member_invites BOOLEAN DEFAULT false,
    require_approval BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create health_profiles if not exists (needed as FK target)
CREATE TABLE IF NOT EXISTS public.health_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name VARCHAR(100),
    avatar_url TEXT,
    date_of_birth DATE,
    gender VARCHAR(20),
    height_cm INTEGER,
    weight_kg DECIMAL(5,2),
    blood_type VARCHAR(5),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create family_members table
CREATE TABLE IF NOT EXISTS public.family_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_group_id UUID NOT NULL REFERENCES public.family_groups(id) ON DELETE CASCADE,
    health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
    added_by_user_id UUID REFERENCES auth.users(id),
    role VARCHAR(20) DEFAULT 'viewer' CHECK (role IN ('owner', 'caregiver', 'viewer', 'limited')),
    can_view BOOLEAN DEFAULT true,
    can_edit BOOLEAN DEFAULT false,
    can_add_medications BOOLEAN DEFAULT false,
    can_add_appointments BOOLEAN DEFAULT false,
    can_view_medical_documents BOOLEAN DEFAULT true,
    can_manage_members BOOLEAN DEFAULT false,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('pending', 'active', 'suspended', 'removed')),
    relationship VARCHAR(50),
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(family_group_id, health_profile_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_family_groups_invite_code ON public.family_groups(invite_code) WHERE invite_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_family_groups_owner ON public.family_groups(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_family_members_group ON public.family_members(family_group_id);
CREATE INDEX IF NOT EXISTS idx_family_members_profile ON public.family_members(health_profile_id);
CREATE INDEX IF NOT EXISTS idx_health_profiles_user ON public.health_profiles(user_id);

-- Enable RLS
ALTER TABLE public.family_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.health_profiles ENABLE ROW LEVEL SECURITY;

-- health_profiles RLS
DROP POLICY IF EXISTS "Users can view own health profiles" ON public.health_profiles;
CREATE POLICY "Users can view own health profiles" ON public.health_profiles FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS "Users can insert own health profiles" ON public.health_profiles;
CREATE POLICY "Users can insert own health profiles" ON public.health_profiles FOR INSERT WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS "Users can update own health profiles" ON public.health_profiles;
CREATE POLICY "Users can update own health profiles" ON public.health_profiles FOR UPDATE USING (user_id = auth.uid());

-- family_groups RLS
DROP POLICY IF EXISTS "family_groups_select" ON public.family_groups;
CREATE POLICY "family_groups_select" ON public.family_groups FOR SELECT USING (owner_user_id = auth.uid() OR invite_code IS NOT NULL);
DROP POLICY IF EXISTS "family_groups_insert" ON public.family_groups;
CREATE POLICY "family_groups_insert" ON public.family_groups FOR INSERT WITH CHECK (owner_user_id = auth.uid());
DROP POLICY IF EXISTS "family_groups_update" ON public.family_groups;
CREATE POLICY "family_groups_update" ON public.family_groups FOR UPDATE USING (owner_user_id = auth.uid());
DROP POLICY IF EXISTS "family_groups_delete" ON public.family_groups;
CREATE POLICY "family_groups_delete" ON public.family_groups FOR DELETE USING (owner_user_id = auth.uid());

-- family_members RLS
DROP POLICY IF EXISTS "family_members_insert" ON public.family_members;
CREATE POLICY "family_members_insert" ON public.family_members FOR INSERT WITH CHECK (
    health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
    AND added_by_user_id = auth.uid()
);
DROP POLICY IF EXISTS "family_members_select" ON public.family_members;
CREATE POLICY "family_members_select" ON public.family_members FOR SELECT USING (
    family_group_id IN (SELECT id FROM public.family_groups WHERE owner_user_id = auth.uid())
    OR family_group_id IN (
        SELECT fm.family_group_id FROM public.family_members fm
        JOIN public.health_profiles hp ON fm.health_profile_id = hp.id
        WHERE hp.user_id = auth.uid() AND fm.status = 'active'
    )
);
DROP POLICY IF EXISTS "family_members_delete" ON public.family_members;
CREATE POLICY "family_members_delete" ON public.family_members FOR DELETE USING (
    health_profile_id IN (SELECT id FROM public.health_profiles WHERE user_id = auth.uid())
    OR family_group_id IN (SELECT id FROM public.family_groups WHERE owner_user_id = auth.uid())
);
DROP POLICY IF EXISTS "family_members_update" ON public.family_members;
CREATE POLICY "family_members_update" ON public.family_members FOR UPDATE
    USING (family_group_id IN (SELECT id FROM public.family_groups WHERE owner_user_id = auth.uid()))
    WITH CHECK (family_group_id IN (SELECT id FROM public.family_groups WHERE owner_user_id = auth.uid()));
