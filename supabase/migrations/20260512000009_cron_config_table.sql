-- pg_cron on Supabase managed cannot read DB-level GUCs unless they are set by
-- a dashboard-superuser. To avoid manual setup, store the config in a regular
-- table that the migration role CAN write to, and rewrite the cron job to read
-- from it.

CREATE TABLE IF NOT EXISTS public.cron_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.cron_config ENABLE ROW LEVEL SECURITY;
-- No SELECT/INSERT/UPDATE/DELETE policies for regular users — only service role
-- (which bypasses RLS) can read. This protects the cron secret.

INSERT INTO public.cron_config(key, value)
VALUES
  ('supabase_url', 'https://jlumbeyukpnuicyxzvre.supabase.co'),
  ('cron_shared_secret', '7fb3ac54e7be687092d4d41b0045c29ad081e5297c2ec2a474621fe7af9c2b15')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();

-- Rebuild the missed-medications cron job to use the config table instead of
-- current_setting(). Unschedule first if it exists.
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
        'x-cron-secret', (SELECT value FROM public.cron_config WHERE key = 'cron_shared_secret'),
        'Content-Type', 'application/json'
      ),
      body := '{}'::jsonb
    );
  $cron$
);
