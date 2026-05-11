-- ============================================================================
-- FIX: Family join-by-invite-code + non-owner visibility
-- ============================================================================
-- Problem (root cause):
--   * RLS on family_groups/family_members only allows owner_user_id = auth.uid()
--     so a user joining via invite code cannot SELECT the group or INSERT the
--     member row. Joining is structurally impossible for non-owners.
--   * has_family_access() only returns true for owners, so even if a member
--     joined, they would have no access to shared health data.
--
-- Fix shape:
--   * Add SECURITY DEFINER functions for the privileged join + invite lookup,
--     so the client never needs RLS-bypassing reach on these tables.
--   * Add a SECURITY DEFINER helper for the caller's group ids, used by RLS
--     policies to avoid recursion when checking membership.
--   * Relax SELECT on family_groups/family_members to include active members.
--   * Allow members to DELETE their own row (self-leave).
--   * Replace has_family_access() so non-owner active members get access.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Helper: caller's active family_group ids (bypasses RLS for use inside policies)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.user_family_group_ids()
RETURNS SETOF UUID
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
    SELECT fm.family_group_id
    FROM public.family_members fm
    JOIN public.health_profiles hp ON hp.id = fm.health_profile_id
    WHERE hp.user_id = auth.uid()
      AND fm.status = 'active';
$$;

GRANT EXECUTE ON FUNCTION public.user_family_group_ids() TO authenticated;

-- ----------------------------------------------------------------------------
-- Read: lookup a family group by invite code (used for the pre-join "validate"
-- step in the UI). Only returns id + name; no member data.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_family_by_invite_code(p_invite_code TEXT)
RETURNS TABLE (
    id UUID,
    name VARCHAR(100)
)
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT fg.id, fg.name
    FROM public.family_groups fg
    WHERE fg.invite_code = upper(p_invite_code)
    LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_family_by_invite_code(TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- Write: join a family group via invite code. Validates code, resolves the
-- caller's primary health_profile, inserts the family_member row, returns
-- the family_group_id.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.join_family_by_invite_code(p_invite_code TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_group_id UUID;
    v_health_profile_id UUID;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    SELECT id INTO v_group_id
    FROM public.family_groups
    WHERE invite_code = upper(p_invite_code)
    LIMIT 1;

    IF v_group_id IS NULL THEN
        RAISE EXCEPTION 'Invalid invite code' USING ERRCODE = 'P0001';
    END IF;

    SELECT id INTO v_health_profile_id
    FROM public.health_profiles
    WHERE user_id = v_user_id
    ORDER BY is_primary DESC NULLS LAST, created_at ASC
    LIMIT 1;

    IF v_health_profile_id IS NULL THEN
        RAISE EXCEPTION 'Health profile not found. Please complete onboarding.'
            USING ERRCODE = 'P0002';
    END IF;

    -- Already a member of this group?
    IF EXISTS (
        SELECT 1 FROM public.family_members
        WHERE family_group_id = v_group_id
          AND health_profile_id = v_health_profile_id
    ) THEN
        RAISE EXCEPTION 'You are already a member of this family group'
            USING ERRCODE = 'P0003';
    END IF;

    INSERT INTO public.family_members (
        family_group_id,
        health_profile_id,
        added_by_user_id,
        role,
        status,
        can_view,
        can_edit,
        can_add_medications,
        can_add_appointments,
        can_view_medical_documents,
        can_manage_members
    ) VALUES (
        v_group_id,
        v_health_profile_id,
        v_user_id,
        'viewer',
        'active',
        true,
        false,
        false,
        false,
        true,
        false
    );

    RETURN v_group_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_family_by_invite_code(TEXT) TO authenticated;

-- ----------------------------------------------------------------------------
-- Replace has_family_access() to cover non-owner active members.
--   Access is granted if EITHER:
--     1. The caller owns the profile directly, OR
--     2. The profile and the caller are both active members of the same group
--        (and the caller has the requested permission on their own row).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.has_family_access(
    profile_id UUID,
    required_permission TEXT DEFAULT 'view'
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
    v_user_id UUID := auth.uid();
BEGIN
    IF v_user_id IS NULL THEN
        RETURN false;
    END IF;

    -- Direct ownership of the profile
    IF EXISTS (
        SELECT 1 FROM public.health_profiles
        WHERE id = profile_id AND user_id = v_user_id
    ) THEN
        RETURN true;
    END IF;

    -- Shared family group membership
    RETURN EXISTS (
        SELECT 1
        FROM public.family_members fm_target
        JOIN public.family_members fm_self
          ON fm_self.family_group_id = fm_target.family_group_id
        JOIN public.health_profiles hp_self
          ON hp_self.id = fm_self.health_profile_id
        WHERE fm_target.health_profile_id = profile_id
          AND fm_target.status = 'active'
          AND fm_self.status   = 'active'
          AND hp_self.user_id  = v_user_id
          AND CASE required_permission
                WHEN 'edit' THEN fm_self.can_edit
                ELSE fm_self.can_view
              END = true
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- RLS: family_groups — owners and active members can SELECT.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can view own family groups" ON public.family_groups;
DROP POLICY IF EXISTS "Users can view their family groups" ON public.family_groups;
CREATE POLICY "Users can view their family groups" ON public.family_groups
    FOR SELECT USING (
        owner_user_id = auth.uid()
        OR id IN (SELECT public.user_family_group_ids())
    );

-- INSERT/UPDATE/DELETE on family_groups remain owner-only (kept from
-- 20260311000001_add_missing_rls_policies.sql).

-- ----------------------------------------------------------------------------
-- RLS: family_members — visible to all members of the same group.
-- INSERT/UPDATE remain owner-only on the client; joining happens via the
-- SECURITY DEFINER function above. DELETE is permitted for self-leave.
-- ----------------------------------------------------------------------------
DROP POLICY IF EXISTS "Users can view family members" ON public.family_members;
CREATE POLICY "Users can view family members" ON public.family_members
    FOR SELECT USING (
        family_group_id IN (
            SELECT id FROM public.family_groups WHERE owner_user_id = auth.uid()
        )
        OR family_group_id IN (SELECT public.user_family_group_ids())
    );

DROP POLICY IF EXISTS "Users can leave family group" ON public.family_members;
CREATE POLICY "Users can leave family group" ON public.family_members
    FOR DELETE USING (
        health_profile_id IN (
            SELECT id FROM public.health_profiles WHERE user_id = auth.uid()
        )
    );

-- Owner-side INSERT/UPDATE/DELETE policies from 20260311000001 are unchanged.
