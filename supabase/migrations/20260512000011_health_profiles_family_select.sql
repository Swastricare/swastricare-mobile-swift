-- Allow family members to read each other's health_profiles basic fields
-- (user_id, full_name, avatar_url). Without this, the PostgREST embed
-- `family_members.select(*, health_profiles(user_id, full_name, avatar_url))`
-- returns null for peer rows, which breaks the "nudge member" flow (no userId
-- to push to) and the member-list UI (no names).
--
-- This relies on has_family_access(profile_id, 'view') defined in
-- 20260511000001_fix_family_join_and_visibility.sql.
DROP POLICY IF EXISTS "health_profiles_family_select" ON public.health_profiles;
CREATE POLICY "health_profiles_family_select"
  ON public.health_profiles FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.has_family_access(id, 'view')
  );
