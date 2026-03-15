-- ============================================================================
-- FAMILY INVITE CODES + RLS POLICY FIXES
-- Adds invite_code column to family_groups and updates RLS policies
-- to support the join-by-code flow from both iOS and Android apps.
-- ============================================================================

-- 1. Add invite_code column to family_groups
ALTER TABLE public.family_groups
    ADD COLUMN IF NOT EXISTS invite_code VARCHAR(8) UNIQUE;

-- 2. Add index on invite_code for fast lookups
CREATE INDEX IF NOT EXISTS idx_family_groups_invite_code
    ON public.family_groups(invite_code)
    WHERE invite_code IS NOT NULL;

-- 3. Allow ANY authenticated user to SELECT family_groups by invite_code
--    (needed for join-by-code flow — user doesn't own the group yet)
DROP POLICY IF EXISTS "Anyone can find groups by invite code" ON public.family_groups;
CREATE POLICY "Anyone can find groups by invite code" ON public.family_groups
    FOR SELECT
    USING (
        -- Owner can always see their groups
        owner_user_id = auth.uid()
        -- OR anyone can look up a group by invite code (for joining)
        OR invite_code IS NOT NULL
    );

-- 4. Allow authenticated users to INSERT themselves into family_members
--    (needed for join-by-code flow — user adds themselves as a viewer)
DROP POLICY IF EXISTS "Users can join family groups" ON public.family_members;
CREATE POLICY "Users can join family groups" ON public.family_members
    FOR INSERT
    WITH CHECK (
        -- User can only add their own health profile
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
        -- And the added_by must be themselves
        AND added_by_user_id = auth.uid()
    );

-- 5. Allow members to SELECT their own family group's members
DROP POLICY IF EXISTS "Members can view their family" ON public.family_members;
CREATE POLICY "Members can view their family" ON public.family_members
    FOR SELECT
    USING (
        -- Owner of the family group
        family_group_id IN (
            SELECT id FROM public.family_groups WHERE owner_user_id = auth.uid()
        )
        -- OR active member of the group
        OR family_group_id IN (
            SELECT fm.family_group_id FROM public.family_members fm
            JOIN public.health_profiles hp ON fm.health_profile_id = hp.id
            WHERE hp.user_id = auth.uid() AND fm.status = 'active'
        )
    );

-- 6. Allow members to DELETE their own membership (leave group)
DROP POLICY IF EXISTS "Members can leave family" ON public.family_members;
CREATE POLICY "Members can leave family" ON public.family_members
    FOR DELETE
    USING (
        -- Can delete own membership
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
        -- OR owner can remove any member
        OR family_group_id IN (
            SELECT id FROM public.family_groups WHERE owner_user_id = auth.uid()
        )
    );

-- 7. Allow owner to UPDATE member status/permissions
DROP POLICY IF EXISTS "Owner can update members" ON public.family_members;
CREATE POLICY "Owner can update members" ON public.family_members
    FOR UPDATE
    USING (
        family_group_id IN (
            SELECT id FROM public.family_groups WHERE owner_user_id = auth.uid()
        )
    )
    WITH CHECK (
        family_group_id IN (
            SELECT id FROM public.family_groups WHERE owner_user_id = auth.uid()
        )
    );
