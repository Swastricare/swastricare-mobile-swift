-- Fix: the earlier migration hardcoded a stale secret. Update to the secret
-- actually configured as CRON_SHARED_SECRET on the edge function. Also store
-- the anon key so pg_net can pass it as the apikey header (the platform
-- gateway requires apikey even when verify_jwt is false).
UPDATE public.cron_config
SET value = '1f1069dee79131f5a13d7a6b6cf97cc2f35405a7d546b6a15a5c2461dcb192b6', updated_at = NOW()
WHERE key = 'cron_shared_secret';

INSERT INTO public.cron_config(key, value)
VALUES ('apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpsdW1iZXl1a3BudWljeXh6dnJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc2Nzc2MzAsImV4cCI6MjA4MzI1MzYzMH0.JYn8tZGP5OomXh968K4zV7L9h7Gam1zVW5YZ81DLC98')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- Reschedule the cron with apikey in the headers so the gateway accepts it.
DO $$
DECLARE
  jid BIGINT;
BEGIN
  SELECT jobid INTO jid FROM cron.job WHERE jobname = 'detect-missed-medications' LIMIT 1;
  IF jid IS NOT NULL THEN
    PERFORM cron.unschedule(jid);
  END IF;
END
$$;

SELECT cron.schedule(
  'detect-missed-medications',
  '*/5 * * * *',
  $cron$
    SELECT net.http_post(
      url := (SELECT value FROM public.cron_config WHERE key = 'supabase_url')
             || '/functions/v1/detect-missed-medications',
      headers := jsonb_build_object(
        'apikey', (SELECT value FROM public.cron_config WHERE key = 'apikey'),
        'x-cron-secret', (SELECT value FROM public.cron_config WHERE key = 'cron_shared_secret'),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb
    );
  $cron$
);
