-- Backfill the platform column for all existing rows that have it in device_info
UPDATE public.app_events
SET platform = LOWER(device_info->>'platform')
WHERE platform IS NULL
  AND device_info->>'platform' IS NOT NULL
  AND LOWER(device_info->>'platform') IN ('ios', 'android');

-- Helper: resolve platform from column first, fall back to device_info JSONB
-- Used inline in all functions below via:
--   COALESCE(platform, LOWER(device_info->>'platform'))

-- Re-create overview stats with COALESCE fallback
CREATE OR REPLACE FUNCTION public.analytics_overview_stats(
  p_since     timestamptz,
  p_prev_since timestamptz,
  p_prev_until timestamptz
) RETURNS json
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
SELECT json_build_object(
  'total_events',        (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since),
  'prev_total_events',   (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until),
  'unique_users',        (SELECT COUNT(DISTINCT user_id) FROM app_events WHERE created_at >= p_since AND user_id IS NOT NULL),
  'prev_unique_users',   (SELECT COUNT(DISTINCT user_id) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND user_id IS NOT NULL),
  'unique_sessions',     (SELECT COUNT(DISTINCT session_id) FROM app_events WHERE created_at >= p_since AND session_id IS NOT NULL),
  'prev_unique_sessions',(SELECT COUNT(DISTINCT session_id) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND session_id IS NOT NULL),
  'dau', (SELECT COUNT(DISTINCT user_id) FROM app_events WHERE created_at >= NOW() - INTERVAL '24 hours' AND user_id IS NOT NULL),
  'wau', (SELECT COUNT(DISTINCT user_id) FROM app_events WHERE created_at >= NOW() - INTERVAL '7 days'  AND user_id IS NOT NULL),
  'mau', (SELECT COUNT(DISTINCT user_id) FROM app_events WHERE created_at >= NOW() - INTERVAL '30 days' AND user_id IS NOT NULL),
  'events_by_type', (
    SELECT COALESCE(json_object_agg(event_type, cnt), '{}')
    FROM (SELECT event_type, COUNT(*) AS cnt FROM app_events WHERE created_at >= p_since GROUP BY event_type) t
  ),
  'platform_counts', (
    SELECT COALESCE(json_object_agg(p, cnt), '{}')
    FROM (
      SELECT
        CASE LOWER(COALESCE(platform, device_info->>'platform'))
          WHEN 'ios'     THEN 'iOS'
          WHEN 'android' THEN 'Android'
          ELSE 'Unknown'
        END AS p,
        COUNT(*) AS cnt
      FROM app_events
      WHERE created_at >= p_since
      GROUP BY p
    ) t
  ),
  'top_events', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]')
    FROM (
      SELECT event_name AS name, COUNT(*) AS count
      FROM app_events WHERE created_at >= p_since
      GROUP BY event_name ORDER BY count DESC LIMIT 20
    ) t
  ),
  'top_screens', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]')
    FROM (
      SELECT properties->>'screen' AS name, COUNT(*) AS count
      FROM app_events
      WHERE created_at >= p_since
        AND event_name = 'screen_view'
        AND properties->>'screen' IS NOT NULL
      GROUP BY name ORDER BY count DESC LIMIT 15
    ) t
  )
);
$$;

-- Re-create daily platform events with COALESCE
CREATE OR REPLACE FUNCTION public.analytics_daily_platform_events(
  p_since timestamptz
) RETURNS TABLE(day text, ios bigint, android bigint, unknown bigint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    TO_CHAR(created_at AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD') AS day,
    COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform')) = 'ios')     AS ios,
    COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform')) = 'android') AS android,
    COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform')) NOT IN ('ios','android') OR COALESCE(platform, device_info->>'platform') IS NULL) AS unknown
  FROM app_events
  WHERE created_at >= p_since
  GROUP BY day
  ORDER BY day;
$$;

-- Re-create daily platform users with COALESCE
CREATE OR REPLACE FUNCTION public.analytics_daily_platform_users(
  p_since timestamptz
) RETURNS TABLE(day text, ios bigint, android bigint, unknown bigint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    TO_CHAR(created_at AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD') AS day,
    COUNT(DISTINCT user_id) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform')) = 'ios')     AS ios,
    COUNT(DISTINCT user_id) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform')) = 'android') AS android,
    COUNT(DISTINCT user_id) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform')) NOT IN ('ios','android') OR COALESCE(platform, device_info->>'platform') IS NULL) AS unknown
  FROM app_events
  WHERE created_at >= p_since
    AND user_id IS NOT NULL
  GROUP BY day
  ORDER BY day;
$$;

-- Re-create screen stats with COALESCE on platform
CREATE OR REPLACE FUNCTION public.analytics_screen_stats(
  p_since      timestamptz,
  p_prev_since timestamptz,
  p_prev_until timestamptz
) RETURNS json
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
SELECT json_build_object(
  'total_screen_views',      (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name = 'screen_view'),
  'prev_total_screen_views', (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND event_name = 'screen_view'),
  'unique_screens', (
    SELECT COUNT(DISTINCT properties->>'screen') FROM app_events
    WHERE created_at >= p_since AND event_name = 'screen_view' AND properties->>'screen' IS NOT NULL
  ),
  'screen_rankings', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]')
    FROM (
      SELECT properties->>'screen' AS name, COUNT(*) AS count
      FROM app_events
      WHERE created_at >= p_since AND event_name = 'screen_view' AND properties->>'screen' IS NOT NULL
      GROUP BY name ORDER BY count DESC LIMIT 30
    ) t
  ),
  'dwell_times', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]')
    FROM (
      SELECT
        properties->>'screen' AS screen,
        ROUND(AVG(CAST(properties->>'duration_seconds' AS numeric)), 1) AS avg_seconds,
        COUNT(*) AS views
      FROM app_events
      WHERE created_at >= p_since
        AND event_name = 'screen_view'
        AND properties->>'screen' IS NOT NULL
        AND properties->>'duration_seconds' IS NOT NULL
        AND CAST(properties->>'duration_seconds' AS numeric) > 0
      GROUP BY screen
      ORDER BY views DESC
      LIMIT 20
    ) t
  ),
  'screens_by_platform', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]')
    FROM (
      SELECT
        properties->>'screen' AS screen,
        COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform')) = 'ios')     AS ios,
        COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform')) = 'android') AS android
      FROM app_events
      WHERE created_at >= p_since
        AND event_name = 'screen_view'
        AND properties->>'screen' IS NOT NULL
      GROUP BY screen
      ORDER BY (COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform')) = 'ios') +
                COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform')) = 'android')) DESC
      LIMIT 15
    ) t
  )
);
$$;

-- Re-create platform stats with COALESCE
CREATE OR REPLACE FUNCTION public.analytics_platform_stats(
  p_since      timestamptz,
  p_prev_since timestamptz,
  p_prev_until timestamptz
) RETURNS json
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
SELECT json_build_object(
  'events_ios',     (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND LOWER(COALESCE(platform, device_info->>'platform')) = 'ios'),
  'events_android', (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND LOWER(COALESCE(platform, device_info->>'platform')) = 'android'),
  'prev_events_ios',     (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND LOWER(COALESCE(platform, device_info->>'platform')) = 'ios'),
  'prev_events_android', (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND LOWER(COALESCE(platform, device_info->>'platform')) = 'android'),
  'users_ios',     (SELECT COUNT(DISTINCT user_id) FROM app_events WHERE created_at >= p_since AND LOWER(COALESCE(platform, device_info->>'platform')) = 'ios' AND user_id IS NOT NULL),
  'users_android', (SELECT COUNT(DISTINCT user_id) FROM app_events WHERE created_at >= p_since AND LOWER(COALESCE(platform, device_info->>'platform')) = 'android' AND user_id IS NOT NULL),
  'sessions_ios',     (SELECT COUNT(DISTINCT session_id) FROM app_events WHERE created_at >= p_since AND LOWER(COALESCE(platform, device_info->>'platform')) = 'ios' AND session_id IS NOT NULL),
  'sessions_android', (SELECT COUNT(DISTINCT session_id) FROM app_events WHERE created_at >= p_since AND LOWER(COALESCE(platform, device_info->>'platform')) = 'android' AND session_id IS NOT NULL),
  'app_versions', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]')
    FROM (
      SELECT device_info->>'app_version' AS name, COUNT(*) AS count
      FROM app_events
      WHERE created_at >= p_since AND device_info->>'app_version' IS NOT NULL
      GROUP BY name ORDER BY count DESC LIMIT 15
    ) t
  ),
  'device_models', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]')
    FROM (
      SELECT device_info->>'device_model' AS name, COUNT(*) AS count
      FROM app_events
      WHERE created_at >= p_since AND device_info->>'device_model' IS NOT NULL
      GROUP BY name ORDER BY count DESC LIMIT 15
    ) t
  ),
  'top_events_ios', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]')
    FROM (
      SELECT event_name AS name, COUNT(*) AS count
      FROM app_events
      WHERE created_at >= p_since AND LOWER(COALESCE(platform, device_info->>'platform')) = 'ios'
      GROUP BY event_name ORDER BY count DESC LIMIT 15
    ) t
  ),
  'top_events_android', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]')
    FROM (
      SELECT event_name AS name, COUNT(*) AS count
      FROM app_events
      WHERE created_at >= p_since AND LOWER(COALESCE(platform, device_info->>'platform')) = 'android'
      GROUP BY event_name ORDER BY count DESC LIMIT 15
    ) t
  ),
  'event_type_by_platform', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]')
    FROM (
      SELECT
        event_type AS type,
        COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform')) = 'ios')     AS ios,
        COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform')) = 'android') AS android
      FROM app_events
      WHERE created_at >= p_since
      GROUP BY event_type
    ) t
  )
);
$$;

-- Re-create feature stats with COALESCE on platform
CREATE OR REPLACE FUNCTION public.analytics_feature_stats(
  p_since      timestamptz,
  p_prev_since timestamptz,
  p_prev_until timestamptz
) RETURNS json
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
SELECT json_build_object(
  'hydration_events',      (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name IN ('hydration_logged','hydration_goal_met','hydration_button_tap')),
  'prev_hydration_events', (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND event_name IN ('hydration_logged','hydration_goal_met','hydration_button_tap')),
  'medication_events',      (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name IN ('medication_taken','medication_skipped','medication_snoozed')),
  'prev_medication_events', (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND event_name IN ('medication_taken','medication_skipped','medication_snoozed')),
  'workout_events',      (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name IN ('workout_started','workout_completed','workout_start','workout_complete')),
  'prev_workout_events', (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND event_name IN ('workout_started','workout_completed','workout_start','workout_complete')),
  'ai_events',      (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name IN ('ai_message_sent','ai_analysis_request','conversation_started','chat_message_sent')),
  'prev_ai_events', (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND event_name IN ('ai_message_sent','ai_analysis_request','conversation_started','chat_message_sent')),
  'vault_events',      (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name IN ('vault_upload','vault_delete')),
  'prev_vault_events', (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND event_name IN ('vault_upload','vault_delete')),
  'heart_rate_events',      (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name IN ('heartbeat_measurement','heart_rate_measured')),
  'prev_heart_rate_events', (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND event_name IN ('heartbeat_measurement','heart_rate_measured')),
  'feature_totals', (
    SELECT COALESCE(json_agg(row_to_json(t) ORDER BY t.count DESC), '[]')
    FROM (
      SELECT name, count FROM (
        SELECT
          CASE
            WHEN event_name IN ('hydration_logged','hydration_goal_met','hydration_button_tap') THEN 'Hydration'
            WHEN event_name IN ('medication_taken','medication_skipped','medication_snoozed')   THEN 'Medication'
            WHEN event_name IN ('workout_started','workout_completed','workout_start','workout_complete') THEN 'Workout'
            WHEN event_name IN ('ai_message_sent','ai_analysis_request','conversation_started','chat_message_sent') THEN 'AI'
            WHEN event_name IN ('vault_upload','vault_delete')                                  THEN 'Vault'
            WHEN event_name IN ('heartbeat_measurement','heart_rate_measured')                  THEN 'Heart Rate'
            WHEN event_name IN ('food_searched','food_added','food_deleted','meal_copied','calorie_goal_reached','diet_logged') THEN 'Diet'
            WHEN event_name IN ('cycle_logged','symptom_logged','cycle_prediction_viewed')      THEN 'Cycle'
            WHEN event_name IN ('family_created','family_joined','family_member_viewed','family_invite_sent') THEN 'Family'
            ELSE NULL
          END AS name,
          COUNT(*) AS count
        FROM app_events
        WHERE created_at >= p_since
        GROUP BY 1
      ) inner_q
      WHERE name IS NOT NULL
    ) t
  ),
  'feature_by_platform', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]')
    FROM (
      SELECT feature, ios, android FROM (
        SELECT
          CASE
            WHEN event_name IN ('hydration_logged','hydration_goal_met','hydration_button_tap') THEN 'Hydration'
            WHEN event_name IN ('medication_taken','medication_skipped','medication_snoozed')   THEN 'Medication'
            WHEN event_name IN ('workout_started','workout_completed','workout_start','workout_complete') THEN 'Workout'
            WHEN event_name IN ('ai_message_sent','ai_analysis_request','conversation_started','chat_message_sent') THEN 'AI'
            WHEN event_name IN ('vault_upload','vault_delete')                                  THEN 'Vault'
            WHEN event_name IN ('heartbeat_measurement','heart_rate_measured')                  THEN 'Heart Rate'
            WHEN event_name IN ('food_searched','food_added','food_deleted','meal_copied','calorie_goal_reached','diet_logged') THEN 'Diet'
            WHEN event_name IN ('cycle_logged','symptom_logged','cycle_prediction_viewed')      THEN 'Cycle'
            WHEN event_name IN ('family_created','family_joined','family_member_viewed','family_invite_sent') THEN 'Family'
            ELSE NULL
          END AS feature,
          COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform')) = 'ios')     AS ios,
          COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform')) = 'android') AS android
        FROM app_events
        WHERE created_at >= p_since
        GROUP BY 1
      ) inner_q
      WHERE feature IS NOT NULL
    ) t
  ),
  'hydration_avg_amount', (
    SELECT COALESCE(ROUND(AVG(CAST(NULLIF(properties->>'amount','') AS numeric))), 0)
    FROM app_events WHERE created_at >= p_since AND event_name = 'hydration_logged' AND properties->>'amount' IS NOT NULL
  ),
  'medication_taken',   (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name = 'medication_taken'),
  'medication_skipped', (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name = 'medication_skipped'),
  'medication_snoozed', (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name = 'medication_snoozed'),
  'heartrate_avg_bpm', (
    SELECT COALESCE(ROUND(AVG(CAST(NULLIF(properties->>'bpm','') AS numeric))), 0)
    FROM app_events WHERE created_at >= p_since AND event_name IN ('heartbeat_measurement','heart_rate_measured') AND properties->>'bpm' IS NOT NULL
  )
);
$$;

GRANT EXECUTE ON FUNCTION public.analytics_overview_stats(timestamptz, timestamptz, timestamptz)    TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_daily_platform_events(timestamptz)                        TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_daily_platform_users(timestamptz)                         TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_screen_stats(timestamptz, timestamptz, timestamptz)       TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_platform_stats(timestamptz, timestamptz, timestamptz)     TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_feature_stats(timestamptz, timestamptz, timestamptz)      TO service_role;
