-- Add CHECK constraint to platform column to prevent case/spelling variations
-- that would silently break iOS/Android dashboard splits.
ALTER TABLE public.app_events
    ADD CONSTRAINT app_events_platform_check
    CHECK (platform IN ('ios', 'android'));
