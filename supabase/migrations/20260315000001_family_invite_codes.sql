-- SAFE: Only adds invite_code column if missing. No drops, no destructive operations.
ALTER TABLE public.family_groups ADD COLUMN IF NOT EXISTS invite_code VARCHAR(8) UNIQUE;
CREATE INDEX IF NOT EXISTS idx_family_groups_invite_code ON public.family_groups(invite_code) WHERE invite_code IS NOT NULL;
