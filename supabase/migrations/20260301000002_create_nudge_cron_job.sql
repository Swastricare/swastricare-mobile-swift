-- Auto-expire old nudges (run daily at midnight)
-- Uses pg_cron which is pre-enabled on Supabase
SELECT cron.schedule(
  'expire-old-nudges',
  '0 0 * * *',
  $$
  UPDATE ai_nudges
  SET is_dismissed = true, updated_at = now()
  WHERE expires_at < now() AND is_dismissed = false;
  $$
);

-- Note: The ai-nudge-generator edge function should be invoked via
-- Supabase Cron (Dashboard > Database > Cron Jobs) or pg_net HTTP calls.
-- Schedule: every 2 hours between 6am-11pm: '0 6,8,10,12,14,16,18,20,22 * * *'
-- The HTTP call requires pg_net extension and service role key configuration.
-- Configure this via the Supabase Dashboard for security (avoids hardcoding keys in SQL).
