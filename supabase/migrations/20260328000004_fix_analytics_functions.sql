-- Fix 1: analytics_screen_transitions — ambiguous column reference
-- Switch to LANGUAGE sql and rename inner aliases to avoid conflict with RETURNS TABLE column names
CREATE OR REPLACE FUNCTION public.analytics_screen_transitions(
  p_since timestamptz
) RETURNS TABLE(from_screen text, to_screen text, cnt bigint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    t.fs,
    t.ts,
    COUNT(*)::bigint AS cnt
  FROM (
    SELECT
      properties->>'screen' AS fs,
      LEAD(properties->>'screen') OVER (
        PARTITION BY session_id ORDER BY created_at
      ) AS ts
    FROM app_events
    WHERE created_at >= p_since
      AND event_name = 'screen_view'
      AND properties->>'screen' IS NOT NULL
      AND session_id IS NOT NULL
  ) t
  WHERE t.fs IS NOT NULL AND t.ts IS NOT NULL
  GROUP BY t.fs, t.ts
  ORDER BY cnt DESC
  LIMIT 30;
$$;

-- Fix 2: analytics_engagement_stats — two bugs:
--   a) events_by_day: TO_CHAR(TO_DATE(dow_name,'Day'),'Day') always returns 'Saturday'
--      → just use d.dow_name directly
--   b) peak_day: TO_CHAR(...,'Day') pads with trailing spaces
--      → use 'FMDay' format modifier
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
      SELECT COALESCE(
        ROUND(AVG(CAST(properties->>'duration_seconds' AS numeric))),
        0
      )
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
          COUNT(*)::numeric / NULLIF(COUNT(DISTINCT session_id), 0),
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
      SELECT TO_CHAR(created_at AT TIME ZONE 'Asia/Kolkata', 'FMDay')
      FROM app_events
      WHERE created_at >= p_since
      GROUP BY TO_CHAR(created_at AT TIME ZONE 'Asia/Kolkata', 'FMDay'),
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
          d.dow_name AS day,
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

GRANT EXECUTE ON FUNCTION public.analytics_screen_transitions(timestamptz) TO service_role;
GRANT EXECUTE ON FUNCTION public.analytics_engagement_stats(timestamptz) TO service_role;
