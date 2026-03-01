-- Add WhatsApp nudge opt-in to user_settings
ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS whatsapp_nudges_enabled BOOLEAN DEFAULT false;

-- Track WhatsApp delivery on nudge records
ALTER TABLE ai_nudges
  ADD COLUMN IF NOT EXISTS whatsapp_sent BOOLEAN DEFAULT false;
