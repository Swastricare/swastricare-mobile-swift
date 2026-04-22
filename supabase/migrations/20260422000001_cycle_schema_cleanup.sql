-- ============================================================================
-- CYCLE SCHEMA CLEANUP
-- ============================================================================
-- Slims menstrual_cycles to per-cycle data only (daily-varying data belongs
-- in menstrual_daily_logs). Extends menstrual_daily_logs with fields iOS
-- already writes. Extends menstrual_settings with reminder toggles the
-- Android UI already exposes.
--
-- Safety:
--   * Wrapped in a transaction.
--   * Before each DROP COLUMN, RAISE NOTICE reports non-null row counts so
--     the migration log contains a paper trail of data loss.
--   * All drops use IF EXISTS so re-running is safe.
--   * Rollback block at the bottom re-adds nullable columns (will NOT
--     restore data).

BEGIN;

-- ----------------------------------------------------------------------------
-- 1. Log non-null counts for columns about to be dropped.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    col text;
    cnt bigint;
    cols text[] := ARRAY[
        'flow_intensity','daily_flow','symptoms','symptom_severity',
        'pain_level','pain_location','pain_relief_used',
        'mood','mood_notes','energy_level','sleep_quality',
        'ovulation_date','ovulation_confirmed','ovulation_symptoms',
        'fertile_window_start','fertile_window_end','basal_body_temp',
        'cervical_mucus','intimacy_logged','protection_used','protection_type',
        'predicted_period_start','predicted_ovulation'
    ];
BEGIN
    FOREACH col IN ARRAY cols LOOP
        EXECUTE format(
            'SELECT count(*) FROM public.menstrual_cycles WHERE %I IS NOT NULL',
            col
        ) INTO cnt;
        RAISE NOTICE 'menstrual_cycles.% non-null rows: %', col, cnt;
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- 2. Add is_predicted (iOS sends this; column was missing).
-- ----------------------------------------------------------------------------
ALTER TABLE public.menstrual_cycles
    ADD COLUMN IF NOT EXISTS is_predicted BOOLEAN NOT NULL DEFAULT false;

-- ----------------------------------------------------------------------------
-- 3. Drop unused columns on menstrual_cycles.
-- ----------------------------------------------------------------------------
ALTER TABLE public.menstrual_cycles
    DROP COLUMN IF EXISTS flow_intensity,
    DROP COLUMN IF EXISTS daily_flow,
    DROP COLUMN IF EXISTS symptoms,
    DROP COLUMN IF EXISTS symptom_severity,
    DROP COLUMN IF EXISTS pain_level,
    DROP COLUMN IF EXISTS pain_location,
    DROP COLUMN IF EXISTS pain_relief_used,
    DROP COLUMN IF EXISTS mood,
    DROP COLUMN IF EXISTS mood_notes,
    DROP COLUMN IF EXISTS energy_level,
    DROP COLUMN IF EXISTS sleep_quality,
    DROP COLUMN IF EXISTS ovulation_date,
    DROP COLUMN IF EXISTS ovulation_confirmed,
    DROP COLUMN IF EXISTS ovulation_symptoms,
    DROP COLUMN IF EXISTS fertile_window_start,
    DROP COLUMN IF EXISTS fertile_window_end,
    DROP COLUMN IF EXISTS basal_body_temp,
    DROP COLUMN IF EXISTS cervical_mucus,
    DROP COLUMN IF EXISTS intimacy_logged,
    DROP COLUMN IF EXISTS protection_used,
    DROP COLUMN IF EXISTS protection_type,
    DROP COLUMN IF EXISTS predicted_period_start,
    DROP COLUMN IF EXISTS predicted_ovulation;

-- The ovulation-date index no longer has a column to index.
DROP INDEX IF EXISTS public.idx_menstrual_cycles_ovulation;

-- ----------------------------------------------------------------------------
-- 4. Extend menstrual_daily_logs with fields iOS already sends.
-- ----------------------------------------------------------------------------
ALTER TABLE public.menstrual_daily_logs
    ADD COLUMN IF NOT EXISTS energy_level INT CHECK (energy_level BETWEEN 0 AND 10),
    ADD COLUMN IF NOT EXISTS sleep_quality VARCHAR(20),
    ADD COLUMN IF NOT EXISTS temperature DECIMAL(4,2),
    ADD COLUMN IF NOT EXISTS weight DECIMAL(5,2),
    ADD COLUMN IF NOT EXISTS cervical_mucus VARCHAR(20),
    ADD COLUMN IF NOT EXISTS sexual_activity BOOLEAN,
    ADD COLUMN IF NOT EXISTS protected_sex BOOLEAN;

-- One log row per (profile, date) so re-logging the same day upserts cleanly.
-- Safe against existing duplicates: the migration will fail loudly if any
-- exist, signalling we need a manual de-dupe first.
ALTER TABLE public.menstrual_daily_logs
    ADD CONSTRAINT menstrual_daily_logs_profile_date_key
    UNIQUE (health_profile_id, date);

-- ----------------------------------------------------------------------------
-- 5. Extend menstrual_settings with reminder controls.
-- ----------------------------------------------------------------------------
ALTER TABLE public.menstrual_settings
    ADD COLUMN IF NOT EXISTS reminder_days_before INT NOT NULL DEFAULT 2
        CHECK (reminder_days_before BETWEEN 1 AND 7),
    ADD COLUMN IF NOT EXISTS fertile_reminder_enabled BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS pms_reminder_enabled BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS ovulation_reminder_enabled BOOLEAN NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS luteal_phase_length INT NOT NULL DEFAULT 14
        CHECK (luteal_phase_length BETWEEN 10 AND 16);

COMMIT;

-- ============================================================================
-- ROLLBACK (manual — re-adds columns as nullable; WILL NOT RESTORE DATA)
-- ============================================================================
-- BEGIN;
-- ALTER TABLE public.menstrual_cycles
--     ADD COLUMN IF NOT EXISTS flow_intensity VARCHAR(20) CHECK (flow_intensity IN (
--         'spotting','light','medium','heavy','very_heavy')),
--     ADD COLUMN IF NOT EXISTS daily_flow JSONB,
--     ADD COLUMN IF NOT EXISTS symptoms TEXT[],
--     ADD COLUMN IF NOT EXISTS symptom_severity JSONB,
--     ADD COLUMN IF NOT EXISTS pain_level INT CHECK (pain_level BETWEEN 0 AND 10),
--     ADD COLUMN IF NOT EXISTS pain_location TEXT[],
--     ADD COLUMN IF NOT EXISTS pain_relief_used TEXT[],
--     ADD COLUMN IF NOT EXISTS mood TEXT[],
--     ADD COLUMN IF NOT EXISTS mood_notes TEXT,
--     ADD COLUMN IF NOT EXISTS energy_level INT CHECK (energy_level BETWEEN 1 AND 5),
--     ADD COLUMN IF NOT EXISTS sleep_quality INT CHECK (sleep_quality BETWEEN 1 AND 5),
--     ADD COLUMN IF NOT EXISTS ovulation_date DATE,
--     ADD COLUMN IF NOT EXISTS ovulation_confirmed BOOLEAN DEFAULT false,
--     ADD COLUMN IF NOT EXISTS ovulation_symptoms TEXT[],
--     ADD COLUMN IF NOT EXISTS fertile_window_start DATE,
--     ADD COLUMN IF NOT EXISTS fertile_window_end DATE,
--     ADD COLUMN IF NOT EXISTS basal_body_temp DECIMAL(4,2),
--     ADD COLUMN IF NOT EXISTS cervical_mucus VARCHAR(30),
--     ADD COLUMN IF NOT EXISTS intimacy_logged BOOLEAN DEFAULT false,
--     ADD COLUMN IF NOT EXISTS protection_used BOOLEAN,
--     ADD COLUMN IF NOT EXISTS protection_type VARCHAR(30),
--     ADD COLUMN IF NOT EXISTS predicted_period_start DATE,
--     ADD COLUMN IF NOT EXISTS predicted_ovulation DATE,
--     DROP COLUMN IF EXISTS is_predicted;
-- ALTER TABLE public.menstrual_daily_logs
--     DROP CONSTRAINT IF EXISTS menstrual_daily_logs_profile_date_key,
--     DROP COLUMN IF EXISTS energy_level,
--     DROP COLUMN IF EXISTS sleep_quality,
--     DROP COLUMN IF EXISTS temperature,
--     DROP COLUMN IF EXISTS weight,
--     DROP COLUMN IF EXISTS cervical_mucus,
--     DROP COLUMN IF EXISTS sexual_activity,
--     DROP COLUMN IF EXISTS protected_sex;
-- ALTER TABLE public.menstrual_settings
--     DROP COLUMN IF EXISTS reminder_days_before,
--     DROP COLUMN IF EXISTS fertile_reminder_enabled,
--     DROP COLUMN IF EXISTS pms_reminder_enabled,
--     DROP COLUMN IF EXISTS ovulation_reminder_enabled,
--     DROP COLUMN IF EXISTS luteal_phase_length;
-- COMMIT;
