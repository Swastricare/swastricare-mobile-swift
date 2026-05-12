-- ============================================================================
-- BACKFILL health_profiles.is_primary
-- ============================================================================
-- Every existing health_profiles row carries is_primary=false because the
-- iOS profile-create flow never sets the column and the DB default is false.
-- The run-activities edge function used to filter on is_primary=true, which
-- silently broke goals/activities/stats for every user.
--
-- Mark the single row per user as primary so any downstream code that relies
-- on is_primary continues to work. We pick the oldest row per user_id (or the
-- one already flagged primary, if any).
-- ============================================================================

WITH ranked AS (
    SELECT
        id,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY is_primary DESC NULLS LAST, created_at ASC NULLS LAST
        ) AS rn
    FROM public.health_profiles
)
UPDATE public.health_profiles hp
SET is_primary = true
FROM ranked
WHERE hp.id = ranked.id
  AND ranked.rn = 1
  AND COALESCE(hp.is_primary, false) = false;
