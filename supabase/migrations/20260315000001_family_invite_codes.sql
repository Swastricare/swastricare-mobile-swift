-- Ensure health_profiles has all required columns (our simplified version may be missing some)
ALTER TABLE public.health_profiles ADD COLUMN IF NOT EXISTS profile_type VARCHAR(20) DEFAULT 'self';
ALTER TABLE public.health_profiles ADD COLUMN IF NOT EXISTS relationship VARCHAR(50);
ALTER TABLE public.health_profiles ADD COLUMN IF NOT EXISTS is_primary BOOLEAN DEFAULT false;
ALTER TABLE public.health_profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
ALTER TABLE public.health_profiles ADD COLUMN IF NOT EXISTS full_name VARCHAR(100);
ALTER TABLE public.health_profiles ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Ensure family_groups has invite_code
ALTER TABLE public.family_groups ADD COLUMN IF NOT EXISTS invite_code VARCHAR(8) UNIQUE;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_family_groups_invite_code ON public.family_groups(invite_code) WHERE invite_code IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_family_groups_owner ON public.family_groups(owner_user_id);
CREATE INDEX IF NOT EXISTS idx_family_members_group ON public.family_members(family_group_id);
CREATE INDEX IF NOT EXISTS idx_family_members_profile ON public.family_members(health_profile_id);
CREATE INDEX IF NOT EXISTS idx_health_profiles_user ON public.health_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_health_profiles_primary ON public.health_profiles(user_id) WHERE is_primary = true;

-- RLS
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
