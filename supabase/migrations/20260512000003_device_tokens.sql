-- Device tokens for FCM push delivery
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  app_version TEXT,
  device_model TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, fcm_token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON public.device_tokens(user_id);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "device_tokens_self_select"
  ON public.device_tokens FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "device_tokens_self_insert"
  ON public.device_tokens FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "device_tokens_self_update"
  ON public.device_tokens FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "device_tokens_self_delete"
  ON public.device_tokens FOR DELETE
  USING (user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.touch_device_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_device_tokens_updated_at ON public.device_tokens;
CREATE TRIGGER trg_device_tokens_updated_at
  BEFORE UPDATE ON public.device_tokens
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_device_tokens_updated_at();

-- Helper used by send-family-nudge edge function to verify caller and recipient share a family
CREATE OR REPLACE FUNCTION public.users_share_family(user_a UUID, user_b UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1
    FROM family_members fm_a
    JOIN family_members fm_b ON fm_a.family_group_id = fm_b.family_group_id
    JOIN health_profiles hp_a ON hp_a.id = fm_a.health_profile_id
    JOIN health_profiles hp_b ON hp_b.id = fm_b.health_profile_id
    WHERE hp_a.user_id = user_a
      AND hp_b.user_id = user_b
      AND fm_a.status = 'active'
      AND fm_b.status = 'active'
  );
$$;
GRANT EXECUTE ON FUNCTION public.users_share_family(UUID, UUID) TO authenticated, anon, service_role;
