-- ============================================================================
-- UPDATE APP VERSIONS DATA
-- ============================================================================
-- The seeded rows in 20250110000002 and 20260311000002 are now stale —
-- latest_version/latest_build sit behind the currently shipped apps, so the
-- force-update and "update available" popups never trigger.
--
-- This migration:
--   1. Normalizes production rows to match currently shipped store versions
--      (iOS 1.2.1 / build 12, Android 1.2.2 / build 13). force_update=false
--      because the installed app already IS the latest published build.
--   2. Bumps staging rows to a synthetic next release (1.3.0 / 14) with
--      force_update=true so DEBUG builds running on dev devices see the
--      force-update screen for testing.
--   3. Strips the stray trailing newline that crept into android/production
--      latest_version ("1.2.2\n").
--   4. Bumps testflight to 1.3.0 / 14 with force_update=false so TestFlight
--      builds exercise the OPTIONAL-update path.
-- ============================================================================

UPDATE public.app_versions
SET latest_version = '1.3.0',
    latest_build = 14,
    force_update = true,
    update_title = 'Update Required',
    update_message = 'A required update is available. Please install the latest version to continue.'
WHERE platform = 'ios' AND channel = 'staging';

UPDATE public.app_versions
SET latest_version = '1.3.0',
    latest_build = 14,
    force_update = false,
    update_title = 'New Beta Available',
    update_message = 'A new beta build is available for testing.'
WHERE platform = 'ios' AND channel = 'testflight';

UPDATE public.app_versions
SET latest_version = '1.2.1',
    latest_build = 12,
    force_update = false
WHERE platform = 'ios' AND channel = 'production';

UPDATE public.app_versions
SET latest_version = '1.3.0',
    latest_build = 14,
    force_update = true,
    update_title = 'Update Required',
    update_message = 'A required update is available. Please install the latest version to continue.'
WHERE platform = 'android' AND channel = 'staging';

UPDATE public.app_versions
SET latest_version = '1.2.2',
    latest_build = 13,
    force_update = false,
    update_url = 'https://play.google.com/store/apps/details?id=com.swastricare.health'
WHERE platform = 'android' AND channel = 'production';
