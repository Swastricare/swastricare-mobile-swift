-- Cron + helper SQL for the missed-medication detector.
--
-- Companion to edge functions:
--   - detect-missed-medications  (called every 5 minutes by pg_cron)
--   - send-family-nudge          (invoked per caregiver fanout)
--
-- Out-of-plan setup (run once in Supabase SQL editor):
--   ALTER DATABASE postgres SET app.settings.supabase_url = 'https://<project-ref>.supabase.co';
--   ALTER DATABASE postgres SET app.settings.cron_shared_secret = '<random-secret>';
-- The same CRON_SHARED_SECRET must be set as an env var on the
-- detect-missed-medications edge function.

-- ---------------------------------------------------------------------------
-- detect_overdue_medications(grace_minutes)
-- ---------------------------------------------------------------------------
-- Compute missed doses for v1: schedule_type='daily' with frequency_per_day=1
-- (single time_of_day per day). Future enhancement: support frequency_per_day > 1
-- via interval_hours, weekly/monthly schedules.
--
-- The function returns rows for expected dose times where:
--   - schedule is active and reminder_enabled
--   - schedule_type = 'daily'
--   - frequency_per_day = 1 (or NULL, treated as 1)
--   - today's expected_time (combining today's date with time_of_day in
--     schedule.timezone) is in the past by > grace_minutes
--   - there is NO medication_logs row with any status within +/-1h of the
--     expected_time for this schedule (i.e. the user hasn't logged anything
--     for that dose window, taken/skipped/missed/late/early)
CREATE OR REPLACE FUNCTION public.detect_overdue_medications(grace_minutes INT DEFAULT 30)
RETURNS TABLE (
  schedule_id UUID,
  health_profile_id UUID,
  medication_id UUID,
  medication_name TEXT,
  member_name TEXT,
  expected_time TIMESTAMPTZ
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  WITH today_doses AS (
    SELECT
      ms.id AS schedule_id,
      ms.health_profile_id,
      ms.medication_id,
      ms.timezone,
      ((CURRENT_DATE::TEXT || ' ' || ms.time_of_day::TEXT)::TIMESTAMP
        AT TIME ZONE COALESCE(NULLIF(ms.timezone, ''), 'UTC')) AS expected_time
    FROM medication_schedules ms
    WHERE ms.is_active = TRUE
      AND ms.reminder_enabled = TRUE
      AND ms.schedule_type = 'daily'
      AND COALESCE(ms.frequency_per_day, 1) = 1
  )
  SELECT
    td.schedule_id,
    td.health_profile_id,
    td.medication_id,
    m.name::TEXT AS medication_name,
    hp.full_name::TEXT AS member_name,
    td.expected_time
  FROM today_doses td
  JOIN medications m ON m.id = td.medication_id
  JOIN health_profiles hp ON hp.id = td.health_profile_id
  WHERE td.expected_time < NOW() - (grace_minutes || ' minutes')::INTERVAL
    AND NOT EXISTS (
      SELECT 1 FROM medication_logs ml
      WHERE ml.schedule_id = td.schedule_id
        AND ml.scheduled_time BETWEEN td.expected_time - INTERVAL '1 hour'
                                  AND td.expected_time + INTERVAL '1 hour'
    );
$$;

GRANT EXECUTE ON FUNCTION public.detect_overdue_medications(INT) TO service_role;

-- ---------------------------------------------------------------------------
-- get_caregivers_for_profile(profile_id)
-- ---------------------------------------------------------------------------
-- Caregivers for a given target profile: active family members in the same
-- group who are not that profile themselves, with can_view = TRUE.
-- Returns auth user_ids (one per caregiver, de-duped).
CREATE OR REPLACE FUNCTION public.get_caregivers_for_profile(profile_id UUID)
RETURNS TABLE (user_id UUID)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT DISTINCT hp.user_id
  FROM family_members fm_target
  JOIN family_members fm_caregiver
    ON fm_caregiver.family_group_id = fm_target.family_group_id
  JOIN health_profiles hp ON hp.id = fm_caregiver.health_profile_id
  WHERE fm_target.health_profile_id = profile_id
    AND fm_caregiver.health_profile_id != profile_id
    AND fm_caregiver.status = 'active'
    AND fm_target.status = 'active'
    AND fm_caregiver.can_view = TRUE;
$$;

GRANT EXECUTE ON FUNCTION public.get_caregivers_for_profile(UUID) TO service_role;

-- ---------------------------------------------------------------------------
-- pg_cron schedule
-- ---------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Schedule cron every 5 minutes.
-- Relies on Postgres GUCs `app.settings.supabase_url` and
-- `app.settings.cron_shared_secret` being set by the operator (see top of file).
SELECT cron.schedule(
  'detect-missed-medications',
  '*/5 * * * *',
  $cron$
    SELECT net.http_post(
      url := current_setting('app.settings.supabase_url') || '/functions/v1/detect-missed-medications',
      headers := jsonb_build_object(
        'x-cron-secret', current_setting('app.settings.cron_shared_secret'),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb
    );
  $cron$
);
