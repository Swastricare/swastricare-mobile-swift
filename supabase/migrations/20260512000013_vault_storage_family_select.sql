-- Storage RLS extension for the medical-vault bucket so family members
-- with has_family_access can sign URLs to a peer's file.
--
-- Existing convention: file paths are `<owner_user_id>/<UUID>_<filename>`.
-- We allow SELECT when either:
--   (a) the path's first segment equals auth.uid() (owner), OR
--   (b) the path's first segment is the user_id of a health_profile that
--       the caller has 'view' access to via has_family_access().
DROP POLICY IF EXISTS "medical_vault_family_read" ON storage.objects;
CREATE POLICY "medical_vault_family_read"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'medical-vault'
    AND (
      auth.uid()::text = (storage.foldername(name))[1]
      OR EXISTS (
        SELECT 1 FROM public.health_profiles hp
        WHERE hp.user_id::text = (storage.foldername(name))[1]
          AND public.has_family_access(hp.id, 'view')
      )
    )
  );
