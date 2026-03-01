-- Create AI nudges table for proactive health notifications
CREATE TABLE IF NOT EXISTS ai_nudges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  health_profile_id UUID REFERENCES health_profiles(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  nudge_type TEXT NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
  action_deeplink TEXT,
  source_data JSONB,
  is_dismissed BOOLEAN DEFAULT false,
  is_acted_on BOOLEAN DEFAULT false,
  push_sent BOOLEAN DEFAULT false,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE ai_nudges ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can read own nudges"
  ON ai_nudges FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own nudges"
  ON ai_nudges FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Service role can insert (edge function runs as service role)
CREATE POLICY "Service role can insert nudges"
  ON ai_nudges FOR INSERT
  WITH CHECK (true);

-- Indexes
CREATE INDEX idx_ai_nudges_user_id ON ai_nudges(user_id);
CREATE INDEX idx_ai_nudges_active ON ai_nudges(user_id, is_dismissed, expires_at)
  WHERE is_dismissed = false;
