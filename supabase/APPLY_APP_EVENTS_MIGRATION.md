# Apply `app_events` migration

The analytics feature writes to the `app_events` table. Apply the migration once using either method below.

## Option A: Supabase Dashboard (no CLI)

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project → **SQL Editor**.
2. New query → paste and run the contents of:
   ```
   supabase/migrations/20260129000001_create_app_events.sql
   ```
3. Run the query. That creates `app_events`, RLS policies, and indexes.

## Option B: Supabase CLI

```bash
supabase login
supabase link   # if not already linked
supabase db push
```

This applies all pending migrations under `supabase/migrations/`, including `20260129000001_create_app_events.sql`.
