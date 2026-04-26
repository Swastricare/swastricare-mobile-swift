-- Backfill iOS events that stored "os":"iOS" in device_info but no "platform" key
UPDATE public.app_events
SET platform = 'ios'
WHERE platform IS NULL
  AND (
    device_info->>'os' = 'iOS'
    OR device_info->>'platform' = 'ios'
  );

-- Backfill Android events that stored "platform":"android" in device_info
UPDATE public.app_events
SET platform = 'android'
WHERE platform IS NULL
  AND (
    device_info->>'platform' = 'android'
    OR device_info->>'os' = 'android'
    OR LOWER(device_info->>'os') = 'android'
  );

-- Update functions to also fall back to os key for rows that still have NULL platform
-- (handles any future edge cases where platform and device_info->>'platform' are both missing)

CREATE OR REPLACE FUNCTION public.analytics_daily_platform_events(
  p_since timestamptz
) RETURNS TABLE(day text, ios bigint, android bigint, unknown bigint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    TO_CHAR(created_at AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD') AS day,
    COUNT(*) FILTER (WHERE
      LOWER(COALESCE(platform, device_info->>'platform',
        CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'ios'
    ) AS ios,
    COUNT(*) FILTER (WHERE
      LOWER(COALESCE(platform, device_info->>'platform',
        CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'android'
    ) AS android,
    COUNT(*) FILTER (WHERE
      LOWER(COALESCE(platform, device_info->>'platform',
        CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) NOT IN ('ios','android')
      OR COALESCE(platform, device_info->>'platform',
        CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END) IS NULL
    ) AS unknown
  FROM app_events
  WHERE created_at >= p_since
  GROUP BY day
  ORDER BY day;
$$;

CREATE OR REPLACE FUNCTION public.analytics_daily_platform_users(
  p_since timestamptz
) RETURNS TABLE(day text, ios bigint, android bigint, unknown bigint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    TO_CHAR(created_at AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD') AS day,
    COUNT(DISTINCT user_id) FILTER (WHERE
      LOWER(COALESCE(platform, device_info->>'platform',
        CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'ios'
    ) AS ios,
    COUNT(DISTINCT user_id) FILTER (WHERE
      LOWER(COALESCE(platform, device_info->>'platform',
        CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'android'
    ) AS android,
    COUNT(DISTINCT user_id) FILTER (WHERE
      LOWER(COALESCE(platform, device_info->>'platform',
        CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) NOT IN ('ios','android')
      OR COALESCE(platform, device_info->>'platform',
        CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END) IS NULL
    ) AS unknown
  FROM app_events
  WHERE created_at >= p_since
    AND user_id IS NOT NULL
  GROUP BY day
  ORDER BY day;
$$;

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
  'events_ios',     (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'ios'),
  'events_android', (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'android'),
  'prev_events_ios',     (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'ios'),
  'prev_events_android', (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'android'),
  'users_ios',     (SELECT COUNT(DISTINCT user_id) FROM app_events WHERE created_at >= p_since AND LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'ios' AND user_id IS NOT NULL),
  'users_android', (SELECT COUNT(DISTINCT user_id) FROM app_events WHERE created_at >= p_since AND LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'android' AND user_id IS NOT NULL),
  'sessions_ios',     (SELECT COUNT(DISTINCT session_id) FROM app_events WHERE created_at >= p_since AND LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'ios' AND session_id IS NOT NULL),
  'sessions_android', (SELECT COUNT(DISTINCT session_id) FROM app_events WHERE created_at >= p_since AND LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'android' AND session_id IS NOT NULL),
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
      WHERE created_at >= p_since AND LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'ios'
      GROUP BY event_name ORDER BY count DESC LIMIT 15
    ) t
  ),
  'top_events_android', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]')
    FROM (
      SELECT event_name AS name, COUNT(*) AS count
      FROM app_events
      WHERE created_at >= p_since AND LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'android'
      GROUP BY event_name ORDER BY count DESC LIMIT 15
    ) t
  ),
  'event_type_by_platform', (
    SELECT COALESCE(json_agg(row_to_json(t)), '[]')
    FROM (
      SELECT
        event_type AS type,
        COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'ios')     AS ios,
        COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'android') AS android
      FROM app_events
      WHERE created_at >= p_since
      GROUP BY event_type
    ) t
  )
);
$$;

CREATE OR REPLACE FUNCTION public.analytics_overview_stats(
  p_since      timestamptz,
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
        CASE LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END))
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
        COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'ios')     AS ios,
        COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'android') AS android
      FROM app_events
      WHERE created_at >= p_since
        AND event_name = 'screen_view'
        AND properties->>'screen' IS NOT NULL
      GROUP BY screen
      ORDER BY (
        COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'ios') +
        COUNT(*) FILTER (WHERE LOWER(COALESCE(platform, device_info->>'platform', CASE WHEN device_info->>'os' = 'iOS' THEN 'ios' ELSE NULL END)) = 'android')
      ) DESC
      LIMIT 15
    ) t
  )
);
$$;

GRANT EXECUTE ON FUNCTION public.analytics_overview_stats(timestamptz, timestamptz, timestamptz)    TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_daily_platform_events(timestamptz)                        TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_daily_platform_users(timestamptz)                         TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_screen_stats(timestamptz, timestamptz, timestamptz)       TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_platform_stats(timestamptz, timestamptz, timestamptz)     TO service_role;
