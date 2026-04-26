-- Add platform column to app_events for reliable iOS/Android split.
-- Android service already sends platform:"android"; iOS will send platform:"ios".
ALTER TABLE public.app_events
    ADD COLUMN IF NOT EXISTS platform VARCHAR(20);

CREATE INDEX IF NOT EXISTS idx_app_events_platform ON public.app_events(platform)
    WHERE platform IS NOT NULL;
