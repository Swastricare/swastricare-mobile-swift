-- Allow family members with can_view to read medical_documents of profiles they have access to.
-- Relies on has_family_access(profile_id, required_permission) defined in
-- 20260511000001_fix_family_join_and_visibility.sql
DROP POLICY IF EXISTS "medical_documents_family_select" ON public.medical_documents;
CREATE POLICY "medical_documents_family_select"
  ON public.medical_documents FOR SELECT
  USING (
    public.has_family_access(health_profile_id, 'view')
  );

DROP POLICY IF EXISTS "medical_documents_family_update" ON public.medical_documents;
CREATE POLICY "medical_documents_family_update"
  ON public.medical_documents FOR UPDATE
  USING (
    public.has_family_access(health_profile_id, 'edit')
  );
