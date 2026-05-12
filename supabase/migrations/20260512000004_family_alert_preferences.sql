CREATE TABLE IF NOT EXISTS public.family_alert_preferences (
  caregiver_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
  missed_medication_alerts BOOLEAN NOT NULL DEFAULT TRUE,
  low_hydration_alerts BOOLEAN NOT NULL DEFAULT TRUE,
  missed_vitals_alerts BOOLEAN NOT NULL DEFAULT FALSE,
  custom_nudge_alerts BOOLEAN NOT NULL DEFAULT TRUE,
  quiet_hours_start TIME,
  quiet_hours_end TIME,
  missed_med_grace_minutes INTEGER NOT NULL DEFAULT 30 CHECK (missed_med_grace_minutes BETWEEN 5 AND 240),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (caregiver_user_id, target_health_profile_id)
);

CREATE INDEX IF NOT EXISTS idx_fap_caregiver ON public.family_alert_preferences(caregiver_user_id);
CREATE INDEX IF NOT EXISTS idx_fap_target ON public.family_alert_preferences(target_health_profile_id);

ALTER TABLE public.family_alert_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fap_self_all"
  ON public.family_alert_preferences FOR ALL
  USING (caregiver_user_id = auth.uid())
  WITH CHECK (caregiver_user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.touch_fap_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_fap_updated_at ON public.family_alert_preferences;
CREATE TRIGGER trg_fap_updated_at
  BEFORE UPDATE ON public.family_alert_preferences
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_fap_updated_at();
