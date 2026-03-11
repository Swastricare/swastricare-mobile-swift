-- ============================================================================
-- SEED ANDROID APP VERSIONS
-- ============================================================================
-- Adds Android rows to app_versions table (iOS rows were seeded in 20250110000002).
-- Uses ON CONFLICT to be idempotent.

INSERT INTO public.app_versions (platform, channel, min_supported_version, min_supported_build, latest_version, latest_build, force_update, rollout_percentage, update_title, update_message, update_url, is_active)
VALUES
    ('android', 'production', '1.0.0', 1, '1.0.0', 1, false, 100, 'Update Available', 'A new version of SwasthiCare is available with improvements and bug fixes.', 'https://play.google.com/store/apps/details?id=com.swasthicare.mobile', true),
    ('android', 'staging', '1.0.0', 1, '1.0.0', 1, false, 100, 'Dev Update', 'Development build update available.', null, true)
ON CONFLICT (platform, channel) DO NOTHING;
