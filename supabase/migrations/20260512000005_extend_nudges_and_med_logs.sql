-- Extend ai_nudges (the existing nudges table; the spec called it "health_nudges"
-- but the real table is public.ai_nudges defined in 20260301000001_create_ai_nudges.sql)
-- to support cross-user nudges (e.g. caregiver -> dependent / dependent -> caregiver).
ALTER TABLE public.ai_nudges
  ADD COLUMN IF NOT EXISTS sender_user_id UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS recipient_user_id UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS preset_key TEXT,
  ADD COLUMN IF NOT EXISTS is_critical BOOLEAN NOT NULL DEFAULT FALSE;

-- The existing dismissal flag on ai_nudges is named "is_dismissed" (not "dismissed").
CREATE INDEX IF NOT EXISTS idx_ai_nudges_recipient
  ON public.ai_nudges(recipient_user_id, is_dismissed, created_at DESC);

-- Track when a missed-medication alert was sent (de-dup guard for the missed-med cron).
ALTER TABLE public.medication_logs
  ADD COLUMN IF NOT EXISTS missed_alert_sent_at TIMESTAMPTZ;

-- The medication_logs.status check constraint uses lowercase values
-- ('taken','skipped','missed','late','early') and has no 'PENDING' state.
-- Pending intakes are not represented as rows in medication_logs today;
-- a row is inserted when the user (or system) marks an intake. The
-- "missed-medication alert" cron will detect medications whose scheduled_time
-- has passed without a corresponding log. For rows that DO exist with status
-- 'missed' and have not yet been alerted, the index below speeds that lookup.
-- The real scheduled-time column on medication_logs is `scheduled_time`, not `scheduled_at`.
CREATE INDEX IF NOT EXISTS idx_medication_logs_missed_unalerted
  ON public.medication_logs(status, scheduled_time)
  WHERE status = 'missed' AND missed_alert_sent_at IS NULL;

-- Allow recipients to see nudges sent to them (cross-user case).
-- Owners of the health profile still see their own nudges via the existing
-- "Users can read own nudges" policy (auth.uid() = user_id). This adds an
-- additional SELECT policy for the new recipient_user_id case so caregivers
-- can read nudges addressed to them about a family member.
DROP POLICY IF EXISTS "ai_nudges_recipient_select" ON public.ai_nudges;
CREATE POLICY "ai_nudges_recipient_select"
  ON public.ai_nudges FOR SELECT
  USING (
    recipient_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.health_profiles hp
      WHERE hp.id = ai_nudges.health_profile_id AND hp.user_id = auth.uid()
    )
  );
