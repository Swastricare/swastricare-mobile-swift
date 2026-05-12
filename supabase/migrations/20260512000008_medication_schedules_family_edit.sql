-- Allow family caregivers with can_edit permission to update medication
-- schedules for any health profile they have access to. Existing policy
-- "Users can update own medication schedules" from
-- 20260311000001_add_missing_rls_policies.sql uses 'can_edit'::text but
-- has_family_access() (replaced in 20260511000001_fix_family_join_and_visibility.sql)
-- only recognises the literal 'edit'. This migration adds an additional
-- permissive UPDATE policy keyed on 'edit', covering remote reminder edits
-- from the Family Member Reminders screen (Android Batch J).
--
-- Idempotent: drops + recreates the family-update policy. The existing
-- owner-update policy is left untouched so direct self-care isn't affected.

DROP POLICY IF EXISTS "medication_schedules_family_update" ON public.medication_schedules;
CREATE POLICY "medication_schedules_family_update"
  ON public.medication_schedules FOR UPDATE
  USING (
    public.has_family_access(health_profile_id, 'edit')
  );
