-- Family screen reads avatar_url from health_profiles via PostgREST embed, but
-- the column is rarely populated because the OAuth avatar lives in
-- auth.users.raw_user_meta_data.avatar_url. Backfill the existing rows and add
-- a trigger so future user-metadata updates flow through.

-- 1. One-time backfill: copy any auth-side avatar into health_profiles where missing.
UPDATE public.health_profiles hp
SET avatar_url = au.raw_user_meta_data->>'avatar_url',
    updated_at = NOW()
FROM auth.users au
WHERE hp.user_id = au.id
  AND (hp.avatar_url IS NULL OR hp.avatar_url = '')
  AND au.raw_user_meta_data->>'avatar_url' IS NOT NULL
  AND au.raw_user_meta_data->>'avatar_url' <> '';

-- 2. Trigger: keep health_profiles.avatar_url in sync when auth.users metadata changes.
--    Runs as SECURITY DEFINER so it can touch health_profiles even when the auth
--    update is fired by an unrelated role.
CREATE OR REPLACE FUNCTION public.sync_health_profile_avatar()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
DECLARE
  new_avatar TEXT := NEW.raw_user_meta_data->>'avatar_url';
BEGIN
  IF new_avatar IS NOT NULL AND new_avatar <> '' THEN
    UPDATE public.health_profiles
    SET avatar_url = new_avatar, updated_at = NOW()
    WHERE user_id = NEW.id
      AND (avatar_url IS NULL OR avatar_url = '' OR avatar_url <> new_avatar);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_health_profile_avatar ON auth.users;
CREATE TRIGGER trg_sync_health_profile_avatar
  AFTER INSERT OR UPDATE OF raw_user_meta_data ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_health_profile_avatar();
