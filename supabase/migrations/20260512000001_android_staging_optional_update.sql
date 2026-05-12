-- ============================================================================
-- ANDROID STAGING: route to OPTIONAL update path
-- ============================================================================
-- Previous migration set android/staging force_update=true so DEBUG builds
-- exercised the full-screen Force Update layout. With the redesigned optional
-- update dialog landing, flip the staging row to force_update=false so dev
-- devices now hit the OptionalUpdateDialog path instead. ios/staging stays
-- force_update=true so the iOS team can keep testing the force flow.
-- ============================================================================

UPDATE public.app_versions
SET force_update = false,
    update_title = 'Update Available',
    update_message = 'A new version is available with improvements and bug fixes.'
WHERE platform = 'android' AND channel = 'staging';
