-- ============================================================
-- Dashboard: push aggregation to SQL
-- Indexes + analytics functions for all 7 API routes
-- ============================================================

-- ── Additional indexes ──────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_app_events_event_type_created
  ON public.app_events (event_type, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_events_event_name_created
  ON public.app_events (event_name, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_app_events_created_at
  ON public.app_events (created_at DESC);

-- JSONB indexes for frequently extracted keys
CREATE INDEX IF NOT EXISTS idx_app_events_properties_screen
  ON public.app_events ((properties->>'screen'))
  WHERE event_type = 'screen';

CREATE INDEX IF NOT EXISTS idx_app_events_properties_duration
  ON public.app_events ((properties->>'duration_seconds'))
  WHERE event_name IN ('screen_view', 'session_end');


-- ============================================================
-- 1. analytics_overview_stats
-- ============================================================
CREATE OR REPLACE FUNCTION public.analytics_overview_stats(
  p_since       timestamptz,
  p_prev_since  timestamptz,
  p_prev_until  timestamptz
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result json;
BEGIN
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
      FROM (
        SELECT event_type, COUNT(*) AS cnt
        FROM app_events
        WHERE created_at >= p_since
        GROUP BY event_type
      ) t
    ),
    'platform_counts', (
      SELECT COALESCE(json_object_agg(p, cnt), '{}')
      FROM (
        SELECT COALESCE(platform, 'Unknown') AS p, COUNT(*) AS cnt
        FROM app_events
        WHERE created_at >= p_since
        GROUP BY COALESCE(platform, 'Unknown')
      ) t
    ),
    'top_events', (
      SELECT COALESCE(json_agg(row_to_json(t)), '[]')
      FROM (
        SELECT event_name AS name, COUNT(*) AS count
        FROM app_events
        WHERE created_at >= p_since
        GROUP BY event_name
        ORDER BY count DESC
        LIMIT 20
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
        GROUP BY properties->>'screen'
        ORDER BY count DESC
        LIMIT 15
      ) t
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;


-- ============================================================
-- 2. analytics_daily_platform_events
-- ============================================================
CREATE OR REPLACE FUNCTION public.analytics_daily_platform_events(
  p_since timestamptz
) RETURNS TABLE(day text, ios bigint, android bigint, unknown bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    TO_CHAR(created_at AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD') AS day,
    COUNT(*) FILTER (WHERE platform = 'ios')     AS ios,
    COUNT(*) FILTER (WHERE platform = 'android') AS android,
    COUNT(*) FILTER (WHERE platform IS NULL OR platform NOT IN ('ios','android')) AS unknown
  FROM app_events
  WHERE created_at >= p_since
  GROUP BY TO_CHAR(created_at AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD')
  ORDER BY day;
END;
$$;


-- ============================================================
-- 3. analytics_daily_platform_users
-- ============================================================
CREATE OR REPLACE FUNCTION public.analytics_daily_platform_users(
  p_since timestamptz
) RETURNS TABLE(day text, ios bigint, android bigint, unknown bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    TO_CHAR(created_at AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD') AS day,
    COUNT(DISTINCT user_id) FILTER (WHERE platform = 'ios')     AS ios,
    COUNT(DISTINCT user_id) FILTER (WHERE platform = 'android') AS android,
    COUNT(DISTINCT user_id) FILTER (WHERE platform IS NULL OR platform NOT IN ('ios','android')) AS unknown
  FROM app_events
  WHERE created_at >= p_since
    AND user_id IS NOT NULL
  GROUP BY TO_CHAR(created_at AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD')
  ORDER BY day;
END;
$$;


-- ============================================================
-- 4. analytics_screen_stats
-- ============================================================
CREATE OR REPLACE FUNCTION public.analytics_screen_stats(
  p_since       timestamptz,
  p_prev_since  timestamptz,
  p_prev_until  timestamptz
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'total_screen_views', (
      SELECT COUNT(*) FROM app_events
      WHERE created_at >= p_since AND event_name = 'screen_view'
    ),
    'prev_total_screen_views', (
      SELECT COUNT(*) FROM app_events
      WHERE created_at >= p_prev_since AND created_at < p_prev_until AND event_name = 'screen_view'
    ),
    'unique_screens', (
      SELECT COUNT(DISTINCT properties->>'screen')
      FROM app_events
      WHERE created_at >= p_since
        AND event_name = 'screen_view'
        AND properties->>'screen' IS NOT NULL
    ),
    'screen_rankings', (
      SELECT COALESCE(json_agg(row_to_json(t)), '[]')
      FROM (
        SELECT properties->>'screen' AS name, COUNT(*) AS count
        FROM app_events
        WHERE created_at >= p_since
          AND event_name = 'screen_view'
          AND properties->>'screen' IS NOT NULL
        GROUP BY properties->>'screen'
        ORDER BY count DESC
        LIMIT 30
      ) t
    ),
    'dwell_times', (
      SELECT COALESCE(json_agg(row_to_json(t)), '[]')
      FROM (
        SELECT
          properties->>'screen' AS screen,
          ROUND(AVG(CAST(properties->>'duration_seconds' AS numeric))::numeric, 1) AS avg_seconds,
          COUNT(*) AS views
        FROM app_events
        WHERE created_at >= p_since
          AND event_name = 'screen_view'
          AND properties->>'screen' IS NOT NULL
          AND properties->>'duration_seconds' IS NOT NULL
          AND CAST(properties->>'duration_seconds' AS numeric) > 0
        GROUP BY properties->>'screen'
        ORDER BY views DESC
        LIMIT 20
      ) t
    ),
    'screens_by_platform', (
      SELECT COALESCE(json_agg(row_to_json(t)), '[]')
      FROM (
        SELECT
          screen,
          COUNT(*) FILTER (WHERE platform = 'ios')     AS ios,
          COUNT(*) FILTER (WHERE platform = 'android') AS android
        FROM (
          SELECT properties->>'screen' AS screen, platform
          FROM app_events
          WHERE created_at >= p_since
            AND event_name = 'screen_view'
            AND properties->>'screen' IS NOT NULL
        ) sub
        WHERE screen IN (
          SELECT properties->>'screen'
          FROM app_events
          WHERE created_at >= p_since
            AND event_name = 'screen_view'
            AND properties->>'screen' IS NOT NULL
          GROUP BY properties->>'screen'
          ORDER BY COUNT(*) DESC
          LIMIT 15
        )
        GROUP BY screen
        ORDER BY (COUNT(*) FILTER (WHERE platform = 'ios') + COUNT(*) FILTER (WHERE platform = 'android')) DESC
      ) t
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;


-- ============================================================
-- 5. analytics_daily_screen_counts
-- ============================================================
CREATE OR REPLACE FUNCTION public.analytics_daily_screen_counts(
  p_since timestamptz
) RETURNS TABLE(day text, screen text, cnt bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    TO_CHAR(created_at AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD') AS day,
    properties->>'screen' AS screen,
    COUNT(*) AS cnt
  FROM app_events
  WHERE created_at >= p_since
    AND event_name = 'screen_view'
    AND properties->>'screen' IS NOT NULL
  GROUP BY
    TO_CHAR(created_at AT TIME ZONE 'Asia/Kolkata', 'YYYY-MM-DD'),
    properties->>'screen'
  ORDER BY day, cnt DESC;
END;
$$;


-- ============================================================
-- 6. analytics_screen_transitions
-- ============================================================
CREATE OR REPLACE FUNCTION public.analytics_screen_transitions(
  p_since timestamptz
) RETURNS TABLE(from_screen text, to_screen text, cnt bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    from_screen,
    to_screen,
    COUNT(*) AS cnt
  FROM (
    SELECT
      properties->>'screen' AS from_screen,
      LEAD(properties->>'screen') OVER (
        PARTITION BY session_id ORDER BY created_at
      ) AS to_screen
    FROM app_events
    WHERE created_at >= p_since
      AND event_name = 'screen_view'
      AND properties->>'screen' IS NOT NULL
      AND session_id IS NOT NULL
  ) transitions
  WHERE from_screen IS NOT NULL
    AND to_screen IS NOT NULL
  GROUP BY from_screen, to_screen
  ORDER BY cnt DESC
  LIMIT 30;
END;
$$;


-- ============================================================
-- 7. analytics_engagement_stats
-- ============================================================
CREATE OR REPLACE FUNCTION public.analytics_engagement_stats(
  p_since timestamptz
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'avg_session_duration', (
      SELECT COALESCE(ROUND(AVG(CAST(properties->>'duration_seconds' AS numeric))::numeric, 1), 0)
      FROM app_events
      WHERE created_at >= p_since
        AND event_name = 'session_end'
        AND properties->>'duration_seconds' IS NOT NULL
        AND CAST(properties->>'duration_seconds' AS numeric) > 0
        AND CAST(properties->>'duration_seconds' AS numeric) < 86400
    ),
    'avg_events_per_session', (
      SELECT COALESCE(
        ROUND(
          (COUNT(*)::numeric / NULLIF(COUNT(DISTINCT session_id), 0))::numeric,
          1
        ),
        0
      )
      FROM app_events
      WHERE created_at >= p_since
        AND session_id IS NOT NULL
    ),
    'peak_hour', (
      SELECT EXTRACT(HOUR FROM created_at AT TIME ZONE 'Asia/Kolkata')::int
      FROM app_events
      WHERE created_at >= p_since
      GROUP BY EXTRACT(HOUR FROM created_at AT TIME ZONE 'Asia/Kolkata')
      ORDER BY COUNT(*) DESC
      LIMIT 1
    ),
    'peak_day', (
      SELECT TO_CHAR(created_at AT TIME ZONE 'Asia/Kolkata', 'Day')
      FROM app_events
      WHERE created_at >= p_since
      GROUP BY TO_CHAR(created_at AT TIME ZONE 'Asia/Kolkata', 'Day'),
               EXTRACT(DOW FROM created_at AT TIME ZONE 'Asia/Kolkata')
      ORDER BY COUNT(*) DESC
      LIMIT 1
    ),
    'session_duration_dist', (
      SELECT COALESCE(json_agg(row_to_json(t) ORDER BY sort_order), '[]')
      FROM (
        SELECT
          bucket,
          COUNT(*) AS count,
          CASE bucket
            WHEN '0-10s'  THEN 1
            WHEN '10-30s' THEN 2
            WHEN '30-60s' THEN 3
            WHEN '1-3m'   THEN 4
            WHEN '3-5m'   THEN 5
            WHEN '5-10m'  THEN 6
            WHEN '10m+'   THEN 7
          END AS sort_order
        FROM (
          SELECT
            CASE
              WHEN CAST(properties->>'duration_seconds' AS numeric) <= 10   THEN '0-10s'
              WHEN CAST(properties->>'duration_seconds' AS numeric) <= 30   THEN '10-30s'
              WHEN CAST(properties->>'duration_seconds' AS numeric) <= 60   THEN '30-60s'
              WHEN CAST(properties->>'duration_seconds' AS numeric) <= 180  THEN '1-3m'
              WHEN CAST(properties->>'duration_seconds' AS numeric) <= 300  THEN '3-5m'
              WHEN CAST(properties->>'duration_seconds' AS numeric) <= 600  THEN '5-10m'
              ELSE '10m+'
            END AS bucket
          FROM app_events
          WHERE created_at >= p_since
            AND event_name = 'session_end'
            AND properties->>'duration_seconds' IS NOT NULL
            AND CAST(properties->>'duration_seconds' AS numeric) > 0
            AND CAST(properties->>'duration_seconds' AS numeric) < 86400
        ) bucketed
        GROUP BY bucket
      ) t
    ),
    'events_per_session_dist', (
      SELECT COALESCE(json_agg(row_to_json(t) ORDER BY sort_order), '[]')
      FROM (
        SELECT
          bucket,
          COUNT(*) AS count,
          CASE bucket
            WHEN '1'     THEN 1
            WHEN '2-5'   THEN 2
            WHEN '6-10'  THEN 3
            WHEN '11-25' THEN 4
            WHEN '26-50' THEN 5
            WHEN '50+'   THEN 6
          END AS sort_order
        FROM (
          SELECT
            CASE
              WHEN session_event_count = 1              THEN '1'
              WHEN session_event_count <= 5             THEN '2-5'
              WHEN session_event_count <= 10            THEN '6-10'
              WHEN session_event_count <= 25            THEN '11-25'
              WHEN session_event_count <= 50            THEN '26-50'
              ELSE '50+'
            END AS bucket
          FROM (
            SELECT session_id, COUNT(*) AS session_event_count
            FROM app_events
            WHERE created_at >= p_since
              AND session_id IS NOT NULL
            GROUP BY session_id
          ) session_counts
        ) bucketed
        GROUP BY bucket
      ) t
    ),
    'events_by_hour', (
      SELECT COALESCE(json_agg(row_to_json(t) ORDER BY hour), '[]')
      FROM (
        SELECT
          h.hour,
          COALESCE(e.cnt, 0) AS count
        FROM generate_series(0, 23) AS h(hour)
        LEFT JOIN (
          SELECT
            EXTRACT(HOUR FROM created_at AT TIME ZONE 'Asia/Kolkata')::int AS hour,
            COUNT(*) AS cnt
          FROM app_events
          WHERE created_at >= p_since
          GROUP BY EXTRACT(HOUR FROM created_at AT TIME ZONE 'Asia/Kolkata')
        ) e ON e.hour = h.hour
      ) t
    ),
    'events_by_day', (
      SELECT COALESCE(json_agg(row_to_json(t) ORDER BY dow_order), '[]')
      FROM (
        SELECT
          TO_CHAR(TO_DATE(dow_name, 'Day'), 'Day') AS day,
          COALESCE(e.cnt, 0) AS count,
          d.dow_order
        FROM (
          VALUES
            (0, 'Sunday'),
            (1, 'Monday'),
            (2, 'Tuesday'),
            (3, 'Wednesday'),
            (4, 'Thursday'),
            (5, 'Friday'),
            (6, 'Saturday')
        ) d(dow_order, dow_name)
        LEFT JOIN (
          SELECT
            EXTRACT(DOW FROM created_at AT TIME ZONE 'Asia/Kolkata')::int AS dow,
            COUNT(*) AS cnt
          FROM app_events
          WHERE created_at >= p_since
          GROUP BY EXTRACT(DOW FROM created_at AT TIME ZONE 'Asia/Kolkata')
        ) e ON e.dow = d.dow_order
      ) t
    ),
    'heatmap', (
      SELECT COALESCE(json_agg(row_to_json(t)), '[]')
      FROM (
        SELECT
          EXTRACT(DOW FROM created_at AT TIME ZONE 'Asia/Kolkata')::int AS day,
          EXTRACT(HOUR FROM created_at AT TIME ZONE 'Asia/Kolkata')::int AS hour,
          COUNT(*) AS count
        FROM app_events
        WHERE created_at >= p_since
        GROUP BY
          EXTRACT(DOW FROM created_at AT TIME ZONE 'Asia/Kolkata'),
          EXTRACT(HOUR FROM created_at AT TIME ZONE 'Asia/Kolkata')
      ) t
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;


-- ============================================================
-- 8. analytics_tab_navigation
-- ============================================================
CREATE OR REPLACE FUNCTION public.analytics_tab_navigation(
  p_since timestamptz
) RETURNS TABLE(name text, count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    properties->>'tab_name' AS name,
    COUNT(*) AS count
  FROM app_events
  WHERE created_at >= p_since
    AND event_name = 'tab_selected'
    AND properties->>'tab_name' IS NOT NULL
  GROUP BY properties->>'tab_name'
  ORDER BY count DESC
  LIMIT 10;
END;
$$;


-- ============================================================
-- 9. analytics_platform_stats
-- ============================================================
CREATE OR REPLACE FUNCTION public.analytics_platform_stats(
  p_since       timestamptz,
  p_prev_since  timestamptz,
  p_prev_until  timestamptz
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'events_ios',          (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND platform = 'ios'),
    'events_android',      (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND platform = 'android'),
    'prev_events_ios',     (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND platform = 'ios'),
    'prev_events_android', (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND platform = 'android'),
    'users_ios',           (SELECT COUNT(DISTINCT user_id) FROM app_events WHERE created_at >= p_since AND platform = 'ios' AND user_id IS NOT NULL),
    'users_android',       (SELECT COUNT(DISTINCT user_id) FROM app_events WHERE created_at >= p_since AND platform = 'android' AND user_id IS NOT NULL),
    'sessions_ios',        (SELECT COUNT(DISTINCT session_id) FROM app_events WHERE created_at >= p_since AND platform = 'ios' AND session_id IS NOT NULL),
    'sessions_android',    (SELECT COUNT(DISTINCT session_id) FROM app_events WHERE created_at >= p_since AND platform = 'android' AND session_id IS NOT NULL),
    'app_versions', (
      SELECT COALESCE(json_agg(row_to_json(t)), '[]')
      FROM (
        SELECT
          COALESCE(device_info->>'app_version', 'unknown') AS name,
          COUNT(*) AS count
        FROM app_events
        WHERE created_at >= p_since
        GROUP BY device_info->>'app_version'
        ORDER BY count DESC
        LIMIT 15
      ) t
    ),
    'device_models', (
      SELECT COALESCE(json_agg(row_to_json(t)), '[]')
      FROM (
        SELECT
          COALESCE(device_info->>'device_model', 'unknown') AS name,
          COUNT(*) AS count
        FROM app_events
        WHERE created_at >= p_since
        GROUP BY device_info->>'device_model'
        ORDER BY count DESC
        LIMIT 15
      ) t
    ),
    'top_events_ios', (
      SELECT COALESCE(json_agg(row_to_json(t)), '[]')
      FROM (
        SELECT event_name AS name, COUNT(*) AS count
        FROM app_events
        WHERE created_at >= p_since AND platform = 'ios'
        GROUP BY event_name
        ORDER BY count DESC
        LIMIT 15
      ) t
    ),
    'top_events_android', (
      SELECT COALESCE(json_agg(row_to_json(t)), '[]')
      FROM (
        SELECT event_name AS name, COUNT(*) AS count
        FROM app_events
        WHERE created_at >= p_since AND platform = 'android'
        GROUP BY event_name
        ORDER BY count DESC
        LIMIT 15
      ) t
    ),
    'event_type_by_platform', (
      SELECT COALESCE(json_agg(row_to_json(t)), '[]')
      FROM (
        SELECT
          event_type AS type,
          COUNT(*) FILTER (WHERE platform = 'ios')     AS ios,
          COUNT(*) FILTER (WHERE platform = 'android') AS android
        FROM app_events
        WHERE created_at >= p_since
        GROUP BY event_type
        ORDER BY (COUNT(*) FILTER (WHERE platform = 'ios') + COUNT(*) FILTER (WHERE platform = 'android')) DESC
      ) t
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;


-- ============================================================
-- 10. analytics_feature_stats
-- ============================================================
CREATE OR REPLACE FUNCTION public.analytics_feature_stats(
  p_since       timestamptz,
  p_prev_since  timestamptz,
  p_prev_until  timestamptz
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    -- Current period counts
    'hydration',   (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name IN ('hydration_logged','hydration_goal_met')),
    'medication',  (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name IN ('medication_taken','medication_skipped')),
    'workout',     (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name IN ('workout_started','workout_completed')),
    'ai',          (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name IN ('ai_message_sent','ai_analysis_request','conversation_started')),
    'vault',       (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name IN ('vault_upload')),
    'heart_rate',  (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name IN ('heartbeat_measurement')),
    'diet',        (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name IN ('food_searched','food_added','food_deleted','meal_copied','calorie_goal_reached')),
    'cycle',       (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name IN ('cycle_logged','symptom_logged','cycle_prediction_viewed')),
    'family',      (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name IN ('family_created','family_joined','family_member_viewed','family_invite_sent')),

    -- Previous period counts
    'prev_hydration',   (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND event_name IN ('hydration_logged','hydration_goal_met')),
    'prev_medication',  (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND event_name IN ('medication_taken','medication_skipped')),
    'prev_workout',     (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND event_name IN ('workout_started','workout_completed')),
    'prev_ai',          (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND event_name IN ('ai_message_sent','ai_analysis_request','conversation_started')),
    'prev_vault',       (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND event_name IN ('vault_upload')),
    'prev_heart_rate',  (SELECT COUNT(*) FROM app_events WHERE created_at >= p_prev_since AND created_at < p_prev_until AND event_name IN ('heartbeat_measurement')),

    -- Feature detail stats
    'hydration_avg_amount', (
      SELECT COALESCE(ROUND(AVG(CAST(properties->>'amount' AS numeric))::numeric, 1), 0)
      FROM app_events
      WHERE created_at >= p_since
        AND event_name = 'hydration_logged'
        AND properties->>'amount' IS NOT NULL
    ),
    'medication_taken',   (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name = 'medication_taken'),
    'medication_skipped', (SELECT COUNT(*) FROM app_events WHERE created_at >= p_since AND event_name = 'medication_skipped'),
    'heartrate_avg_bpm', (
      SELECT COALESCE(ROUND(AVG(CAST(properties->>'bpm' AS numeric))::numeric, 1), 0)
      FROM app_events
      WHERE created_at >= p_since
        AND event_name = 'heartbeat_measurement'
        AND properties->>'bpm' IS NOT NULL
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;


-- ============================================================
-- 11. analytics_user_stats
-- ============================================================
CREATE OR REPLACE FUNCTION public.analytics_user_stats(
  p_since       timestamptz,
  p_prev_since  timestamptz,
  p_prev_until  timestamptz
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'total_users', (
      SELECT COUNT(DISTINCT user_id)
      FROM app_events
      WHERE created_at >= p_since AND user_id IS NOT NULL
    ),
    'prev_total_users', (
      SELECT COUNT(DISTINCT user_id)
      FROM app_events
      WHERE created_at >= p_prev_since AND created_at < p_prev_until AND user_id IS NOT NULL
    ),
    'new_users', (
      SELECT COUNT(*)
      FROM (
        SELECT user_id
        FROM app_events
        WHERE user_id IS NOT NULL
        GROUP BY user_id
        HAVING MIN(created_at) >= p_since
      ) new_u
    ),
    'avg_events_per_user', (
      SELECT COALESCE(
        ROUND(
          (COUNT(*)::numeric / NULLIF(COUNT(DISTINCT user_id), 0))::numeric,
          1
        ),
        0
      )
      FROM app_events
      WHERE created_at >= p_since AND user_id IS NOT NULL
    ),
    'avg_sessions_per_user', (
      SELECT COALESCE(
        ROUND(
          (COUNT(DISTINCT session_id)::numeric / NULLIF(COUNT(DISTINCT user_id), 0))::numeric,
          1
        ),
        0
      )
      FROM app_events
      WHERE created_at >= p_since
        AND user_id IS NOT NULL
        AND session_id IS NOT NULL
    ),
    'top_users', (
      SELECT COALESCE(json_agg(row_to_json(t)), '[]')
      FROM (
        SELECT
          LEFT(user_id::text, 12) AS user_id,
          COUNT(*) AS events,
          COUNT(DISTINCT session_id) AS sessions,
          MIN(created_at) AS first_seen,
          MAX(created_at) AS last_seen,
          CASE
            WHEN COUNT(*) FILTER (WHERE platform = 'ios') >= COUNT(*) FILTER (WHERE platform = 'android')
              THEN 'iOS'
            ELSE 'Android'
          END AS platform
        FROM app_events
        WHERE created_at >= p_since AND user_id IS NOT NULL
        GROUP BY user_id
        ORDER BY events DESC
        LIMIT 25
      ) t
    ),
    'login_methods', (
      SELECT COALESCE(json_object_agg(method, cnt), '{}')
      FROM (
        SELECT
          COALESCE(properties->>'method', 'unknown') AS method,
          COUNT(*) AS cnt
        FROM app_events
        WHERE created_at >= p_since
          AND event_name = 'login_success'
        GROUP BY properties->>'method'
      ) t
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;


-- ============================================================
-- 12. analytics_error_stats
-- ============================================================
CREATE OR REPLACE FUNCTION public.analytics_error_stats(
  p_since       timestamptz,
  p_prev_since  timestamptz,
  p_prev_until  timestamptz
) RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result json;
BEGIN
  SELECT json_build_object(
    'total_errors', (
      SELECT COUNT(*) FROM app_events
      WHERE created_at >= p_since AND event_type = 'error'
    ),
    'prev_total_errors', (
      SELECT COUNT(*) FROM app_events
      WHERE created_at >= p_prev_since AND created_at < p_prev_until AND event_type = 'error'
    ),
    'unique_error_types', (
      SELECT COUNT(DISTINCT event_name) FROM app_events
      WHERE created_at >= p_since AND event_type = 'error'
    ),
    'users_affected', (
      SELECT COUNT(DISTINCT user_id) FROM app_events
      WHERE created_at >= p_since AND event_type = 'error' AND user_id IS NOT NULL
    ),
    'errors_by_category', (
      SELECT COALESCE(json_object_agg(event_name, cnt), '{}')
      FROM (
        SELECT event_name, COUNT(*) AS cnt
        FROM app_events
        WHERE created_at >= p_since AND event_type = 'error'
        GROUP BY event_name
      ) t
    ),
    'errors_by_platform', (
      SELECT COALESCE(json_object_agg(p, cnt), '{}')
      FROM (
        SELECT COALESCE(platform, 'Unknown') AS p, COUNT(*) AS cnt
        FROM app_events
        WHERE created_at >= p_since AND event_type = 'error'
        GROUP BY COALESCE(platform, 'Unknown')
      ) t
    ),
    'top_error_messages', (
      SELECT COALESCE(json_agg(row_to_json(t)), '[]')
      FROM (
        SELECT
          COALESCE(
            properties->>'message',
            properties->>'error',
            properties->>'description',
            event_name
          ) AS message,
          COUNT(*) AS count,
          MAX(created_at) AS last_seen
        FROM app_events
        WHERE created_at >= p_since AND event_type = 'error'
        GROUP BY COALESCE(
          properties->>'message',
          properties->>'error',
          properties->>'description',
          event_name
        )
        ORDER BY count DESC
        LIMIT 20
      ) t
    )
  ) INTO v_result;

  RETURN v_result;
END;
$$;


-- Grant execute to authenticated and service_role
GRANT EXECUTE ON FUNCTION public.analytics_overview_stats(timestamptz, timestamptz, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_daily_platform_events(timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_daily_platform_users(timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_screen_stats(timestamptz, timestamptz, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_daily_screen_counts(timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_screen_transitions(timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_engagement_stats(timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_tab_navigation(timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_platform_stats(timestamptz, timestamptz, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_feature_stats(timestamptz, timestamptz, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_user_stats(timestamptz, timestamptz, timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_error_stats(timestamptz, timestamptz, timestamptz) TO service_role;
