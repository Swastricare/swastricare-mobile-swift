# Android Family Monitoring — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build family-member monitoring on Android: per-member dashboard, FCM nudges (preset + custom), AI on members, server-cron missed-medication alerts, and caregiver/member reminder customization.

**Architecture:** A new Android per-member dashboard reaches existing health repositories with a target `health_profile_id` (RLS enforces access via `has_family_access`). FCM is added end-to-end: token table, `FirebaseMessagingService`, edge function `send-family-nudge`, and a `pg_cron`-driven `detect-missed-medications` edge function that fans out alerts.

**Tech Stack:** Kotlin/Jetpack Compose, Hilt, Supabase Kotlin SDK, Firebase Messaging (FCM HTTP v1), Supabase Edge Functions (Deno/TypeScript), PostgreSQL + `pg_cron`.

**Design doc:** [`2026-05-12-android-family-monitoring-design.md`](./2026-05-12-android-family-monitoring-design.md)

**Verification convention:** This project has no Android unit tests configured for this feature area. Each task verifies via either (a) `xcodebuild`-equivalent Android: `cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug`, then `adb -s acac8d4b install -r app/build/outputs/apk/debug/app-debug.apk && adb -s acac8d4b shell am start -n com.swastricare.health/.MainActivity` on the user's OnePlus 8T, OR (b) for SQL: apply migration with `supabase db push` and verify via Supabase Studio.

**Commit policy:** Per user feedback, do NOT commit per task. Leave commits to the user. After each task, the verifier should print `--- VERIFIED ---` and stop.

**Brand & UI constraints:**
- Android primary color: `AITeal` (#22C5A6) — never PrimaryColor indigo or SecondaryColor green
- Backgrounds: pure `Color.White`, never `AppColors.background`
- Buttons: solid `AITeal`, never gradients
- iOS UI strings stay "Swastricare" (not relevant here, but for cross-reference)

---

## Phase 0 — Backend (Supabase migrations + edge functions)

### Task 0.1: Migration — `device_tokens` table

**Files:**
- Create: `supabase/migrations/20260512000003_device_tokens.sql`

**Code:**

```sql
-- Device tokens for FCM push delivery
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  app_version TEXT,
  device_model TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, fcm_token)
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON public.device_tokens(user_id);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "device_tokens_self_select"
  ON public.device_tokens FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "device_tokens_self_insert"
  ON public.device_tokens FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "device_tokens_self_update"
  ON public.device_tokens FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "device_tokens_self_delete"
  ON public.device_tokens FOR DELETE
  USING (user_id = auth.uid());

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION public.touch_device_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_device_tokens_updated_at
  BEFORE UPDATE ON public.device_tokens
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_device_tokens_updated_at();
```

**Verification:**
```
cd supabase && supabase db push
psql ... -c "\d device_tokens"
```
Expect: table exists, 4 RLS policies, unique constraint on `(user_id, fcm_token)`.

---

### Task 0.2: Migration — `family_alert_preferences` table

**Files:**
- Create: `supabase/migrations/20260512000004_family_alert_preferences.sql`

**Code:**

```sql
CREATE TABLE IF NOT EXISTS public.family_alert_preferences (
  caregiver_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  target_health_profile_id UUID NOT NULL REFERENCES public.health_profiles(id) ON DELETE CASCADE,
  missed_medication_alerts BOOLEAN NOT NULL DEFAULT TRUE,
  low_hydration_alerts BOOLEAN NOT NULL DEFAULT TRUE,
  missed_vitals_alerts BOOLEAN NOT NULL DEFAULT FALSE,
  custom_nudge_alerts BOOLEAN NOT NULL DEFAULT TRUE,
  quiet_hours_start TIME,
  quiet_hours_end TIME,
  missed_med_grace_minutes INTEGER NOT NULL DEFAULT 30 CHECK (missed_med_grace_minutes BETWEEN 5 AND 240),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (caregiver_user_id, target_health_profile_id)
);

CREATE INDEX IF NOT EXISTS idx_fap_caregiver ON public.family_alert_preferences(caregiver_user_id);
CREATE INDEX IF NOT EXISTS idx_fap_target ON public.family_alert_preferences(target_health_profile_id);

ALTER TABLE public.family_alert_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fap_self_all"
  ON public.family_alert_preferences FOR ALL
  USING (caregiver_user_id = auth.uid())
  WITH CHECK (caregiver_user_id = auth.uid());

CREATE OR REPLACE FUNCTION public.touch_fap_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_fap_updated_at
  BEFORE UPDATE ON public.family_alert_preferences
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_fap_updated_at();
```

**Verification:** `supabase db push`. Confirm table + RLS via `\d family_alert_preferences`.

---

### Task 0.3: Migration — Extend `health_nudges` + add `missed_alert_sent_at` to `medication_logs`

**Files:**
- Create: `supabase/migrations/20260512000005_extend_nudges_and_med_logs.sql`

**Code:**

```sql
-- Extend health_nudges to support cross-user nudges
ALTER TABLE public.health_nudges
  ADD COLUMN IF NOT EXISTS sender_user_id UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS recipient_user_id UUID REFERENCES auth.users(id),
  ADD COLUMN IF NOT EXISTS preset_key TEXT,
  ADD COLUMN IF NOT EXISTS is_critical BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX IF NOT EXISTS idx_health_nudges_recipient ON public.health_nudges(recipient_user_id, dismissed, created_at DESC);

-- Track when missed-medication alert was sent (de-dup for cron)
ALTER TABLE public.medication_logs
  ADD COLUMN IF NOT EXISTS missed_alert_sent_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_medication_logs_pending_due
  ON public.medication_logs(status, scheduled_at)
  WHERE status = 'PENDING' AND missed_alert_sent_at IS NULL;

-- Allow recipients to see nudges sent to them
DROP POLICY IF EXISTS "health_nudges_recipient_select" ON public.health_nudges;
CREATE POLICY "health_nudges_recipient_select"
  ON public.health_nudges FOR SELECT
  USING (
    recipient_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.health_profiles hp
      WHERE hp.id = health_nudges.health_profile_id AND hp.user_id = auth.uid()
    )
  );
```

**Verification:** `supabase db push`. Confirm `\d health_nudges` shows new columns.

---

### Task 0.4: Migration — Extend Vault RLS to use `has_family_access`

**Files:**
- Create: `supabase/migrations/20260512000006_vault_family_access.sql`
- Reference existing: `supabase/migrations/20260511000001_fix_family_join_and_visibility.sql` (has_family_access definition)

**Code:**

```sql
-- Allow family members with can_view to read medical_documents of profiles they have access to
DROP POLICY IF EXISTS "medical_documents_family_select" ON public.medical_documents;
CREATE POLICY "medical_documents_family_select"
  ON public.medical_documents FOR SELECT
  USING (
    public.has_family_access(health_profile_id, 'view')
  );

-- Edit requires can_edit
DROP POLICY IF EXISTS "medical_documents_family_update" ON public.medical_documents;
CREATE POLICY "medical_documents_family_update"
  ON public.medical_documents FOR UPDATE
  USING (
    public.has_family_access(health_profile_id, 'edit')
  );
```

**Verification:** Apply, then as a non-owner family member, attempt `SELECT * FROM medical_documents WHERE health_profile_id=<other-member-id>` — should succeed.

---

### Task 0.5: Edge function — `send-family-nudge`

**Files:**
- Create: `supabase/functions/send-family-nudge/index.ts`
- Reference: `supabase/functions/_shared/cors.ts`, `supabase/functions/ai-router/index.ts` (for shape)
- Secrets needed: `FCM_SERVICE_ACCOUNT_JSON` (base64-encoded Firebase service account JSON), `FCM_PROJECT_ID`

**Code:**

```typescript
// supabase/functions/send-family-nudge/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

interface NudgePayload {
  recipient_user_id: string;
  target_health_profile_id?: string; // present for context-bearing nudges
  preset_key?: string;               // e.g. "MEDICATION", "HYDRATION", "VITALS", "APPOINTMENT", "CHECKIN"
  custom_message?: string;
  category: "MEDICATION" | "HYDRATION" | "VITALS" | "APPOINTMENT" | "CHECKIN" | "MEDICATION_MISSED";
  is_critical?: boolean;
  internal_caller?: boolean;         // when invoked by detect-missed-medications, skip auth check
}

const PRESET_TEMPLATES: Record<string, { title: string; body: string }> = {
  MEDICATION: { title: "💊 Time for your medication", body: "Your family is reminding you to take your medication." },
  HYDRATION: { title: "💧 Drink water", body: "Stay hydrated — your family is checking in." },
  VITALS: { title: "🩺 Log your vitals", body: "Take a moment to log your vitals." },
  APPOINTMENT: { title: "📅 Upcoming appointment", body: "Don't miss your appointment." },
  CHECKIN: { title: "❤️ Just checking in", body: "Your family is thinking of you." },
};

function isInQuietHours(start: string | null, end: string | null, nowUtc: Date): boolean {
  if (!start || !end) return false;
  const [sh, sm] = start.split(":").map(Number);
  const [eh, em] = end.split(":").map(Number);
  const mins = nowUtc.getHours() * 60 + nowUtc.getMinutes();
  const s = sh * 60 + sm;
  const e = eh * 60 + em;
  if (s <= e) return mins >= s && mins < e;
  // overnight window (e.g. 23:00–07:00)
  return mins >= s || mins < e;
}

async function getAccessToken(saJson: any): Promise<string> {
  // Sign a JWT with the service account, exchange for access_token
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const iat = Math.floor(Date.now() / 1000);
  const claims = {
    iss: saJson.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat,
    exp: iat + 3600,
  };
  const body = btoa(JSON.stringify(claims));
  const toSign = `${header}.${body}`;

  const pem = saJson.private_key.replace(/-----[^-]+-----/g, "").replace(/\s/g, "");
  const der = Uint8Array.from(atob(pem), c => c.charCodeAt(0));
  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(toSign));
  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig))).replace(/=+$/, "").replace(/\+/g, "-").replace(/\//g, "_");
  const jwt = `${toSign}.${sigB64}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });
  const tokenJson = await tokenRes.json();
  if (!tokenJson.access_token) throw new Error("FCM auth failed: " + JSON.stringify(tokenJson));
  return tokenJson.access_token;
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const payload = await req.json() as NudgePayload;
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    // Authenticate caller unless this is an internal cron call
    let senderUserId: string | null = null;
    if (!payload.internal_caller) {
      const authHeader = req.headers.get("Authorization");
      if (!authHeader) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: corsHeaders });
      const { data: { user } } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
      if (!user) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401, headers: corsHeaders });
      senderUserId = user.id;

      // Verify sender and recipient share a family group
      const { data: sharedFamily, error: famErr } = await supabase.rpc("users_share_family", {
        user_a: senderUserId, user_b: payload.recipient_user_id,
      });
      if (famErr || !sharedFamily) {
        return new Response(JSON.stringify({ error: "Forbidden" }), { status: 403, headers: corsHeaders });
      }
    }

    // Resolve title/body
    const tpl = payload.preset_key ? PRESET_TEMPLATES[payload.preset_key] : null;
    const title = tpl?.title ?? "Family nudge";
    const body = payload.custom_message ?? tpl?.body ?? "";

    // Lookup recipient profile id (for health_nudges row)
    const { data: recipientProfile } = await supabase
      .from("health_profiles")
      .select("id")
      .eq("user_id", payload.recipient_user_id)
      .eq("is_primary", true)
      .single();

    // Insert nudge row (record of the nudge regardless of FCM delivery)
    const { data: nudgeRow, error: nudgeErr } = await supabase
      .from("health_nudges")
      .insert({
        health_profile_id: recipientProfile?.id,
        recipient_user_id: payload.recipient_user_id,
        sender_user_id: senderUserId,
        type: payload.category,
        title,
        message: body,
        priority: payload.is_critical ? "high" : "normal",
        preset_key: payload.preset_key,
        is_critical: payload.is_critical ?? false,
      })
      .select("id")
      .single();
    if (nudgeErr) throw nudgeErr;

    // Check recipient quiet hours (only for non-critical)
    if (!payload.is_critical) {
      const { data: prefs } = await supabase
        .from("family_alert_preferences")
        .select("quiet_hours_start, quiet_hours_end")
        .eq("caregiver_user_id", payload.recipient_user_id)
        .limit(1)
        .maybeSingle();
      if (prefs && isInQuietHours(prefs.quiet_hours_start, prefs.quiet_hours_end, new Date())) {
        return new Response(JSON.stringify({ delivered: false, reason: "quiet_hours", nudge_id: nudgeRow.id }), { headers: corsHeaders });
      }
    }

    // Lookup FCM tokens
    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("fcm_token")
      .eq("user_id", payload.recipient_user_id);

    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ delivered: false, reason: "no_tokens", nudge_id: nudgeRow.id }), { headers: corsHeaders });
    }

    // Send to FCM
    const saJson = JSON.parse(atob(Deno.env.get("FCM_SERVICE_ACCOUNT_JSON")!));
    const accessToken = await getAccessToken(saJson);
    const projectId = Deno.env.get("FCM_PROJECT_ID")!;

    const results = await Promise.all(tokens.map(async (t) => {
      const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
        method: "POST",
        headers: { "Authorization": `Bearer ${accessToken}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          message: {
            token: t.fcm_token,
            notification: { title, body },
            data: {
              nudge_id: nudgeRow.id,
              category: payload.category,
              deep_link: `swastricareapp://nudge/${nudgeRow.id}`,
            },
            android: { priority: payload.is_critical ? "HIGH" : "NORMAL" },
          },
        }),
      });
      return { token: t.fcm_token, status: res.status };
    }));

    // Cleanup stale tokens
    for (const r of results) {
      if (r.status === 404 || r.status === 400) {
        await supabase.from("device_tokens").delete().eq("fcm_token", r.token);
      }
    }

    return new Response(JSON.stringify({ delivered: true, nudge_id: nudgeRow.id, results }), { headers: corsHeaders });
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: corsHeaders });
  }
});
```

Also add SQL helper used above:

```sql
-- Append to migration 20260512000003 or a fresh helper migration:
CREATE OR REPLACE FUNCTION public.users_share_family(user_a UUID, user_b UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1
    FROM family_members fm_a
    JOIN family_members fm_b ON fm_a.family_group_id = fm_b.family_group_id
    JOIN health_profiles hp_a ON hp_a.id = fm_a.health_profile_id
    JOIN health_profiles hp_b ON hp_b.id = fm_b.health_profile_id
    WHERE hp_a.user_id = user_a
      AND hp_b.user_id = user_b
      AND fm_a.status = 'active'
      AND fm_b.status = 'active'
  );
$$;
GRANT EXECUTE ON FUNCTION public.users_share_family(UUID, UUID) TO authenticated, anon, service_role;
```

**Verification:** Deploy with `supabase functions deploy send-family-nudge`. Invoke from `curl` with two real test users sharing a family; confirm `health_nudges` row inserted; if real FCM token registered on a test device, confirm push lands.

---

### ⚠ DI correction discovered during Batch C

CLAUDE.md and earlier survey reports described Android DI as a manual `AppContainer` singleton with `by lazy`. The real project uses **Hilt + KSP** — `@Singleton` / `@Inject` / `@AndroidEntryPoint`, with Hilt modules under `android/app/src/main/kotlin/com/swastricare/health/di/` (e.g. `ServiceModule.kt`). All subsequent Android tasks must use Hilt patterns:
- Repositories: `@Singleton class FooRepository @Inject constructor(...) { }`
- ViewModels: `@HiltViewModel class FooViewModel @Inject constructor(...) : ViewModel()`
- Service classes (e.g. `FirebaseMessagingService`): `@AndroidEntryPoint`
- Wire optional things (like `ApplicationContext`) via Hilt modules where direct `@Inject` isn't sufficient.

### ⚠ Schema correction discovered during Batch A

After implementing the migrations, three plan assumptions turned out to be wrong against the real DB. All downstream tasks (Batch B onward) must use these real names:

| Plan assumed | Reality |
|---|---|
| Table `health_nudges` | Table `ai_nudges` (defined in `20260301000001_create_ai_nudges.sql`) |
| Column `dismissed` | Column `is_dismissed` |
| Column `type` | Column `nudge_type` |
| Has `action_url` | Has `action_deeplink` |
| `medication_logs.scheduled_at` | `medication_logs.scheduled_time` |
| `medication_logs.status` includes `'PENDING'` (uppercase) | Status is **lowercase** (`'taken','skipped','missed','late','early'`), **no `'PENDING'` value** |

Critical implication for the missed-med cron: there is no `PENDING` row to query. The cron must compute "missed" by joining `medication_schedules` (the *expected* doses) against `medication_logs` (the *actual* recorded events) and detecting expected dose times with no log.

The `ai_nudges` table also has a `user_id NOT NULL` owner column — when inserting nudges from the edge function, set `user_id = recipient_user_id`.

For v1 cron support: only `schedule_type='daily'` with `frequency_per_day=1` (single `time_of_day`). Weekly/monthly/multi-dose-daily schedules deferred — they'll still get client-side missed reporting, just no server fallback.

---

### Task 0.6: Edge function — `detect-missed-medications` + pg_cron schedule

**Files:**
- Create: `supabase/functions/detect-missed-medications/index.ts`
- Create: `supabase/migrations/20260512000007_cron_missed_meds.sql`

**Edge function code:**

```typescript
// supabase/functions/detect-missed-medications/index.ts
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  // Internal cron-only: require shared secret header
  const secret = req.headers.get("x-cron-secret");
  if (secret !== Deno.env.get("CRON_SHARED_SECRET")) {
    return new Response("Forbidden", { status: 403 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Find overdue PENDING logs — joins with alert prefs to apply per-caregiver grace
  const { data: overdueLogs } = await supabase.rpc("get_overdue_pending_medications");
  if (!overdueLogs || overdueLogs.length === 0) {
    return new Response(JSON.stringify({ processed: 0 }), { status: 200 });
  }

  let fanouts = 0;
  for (const log of overdueLogs) {
    // Mark as MISSED with alert sent
    await supabase
      .from("medication_logs")
      .update({ status: "MISSED", missed_alert_sent_at: new Date().toISOString() })
      .eq("id", log.id);

    // Fan out to caregivers
    const { data: caregivers } = await supabase.rpc("get_caregivers_for_profile", {
      profile_id: log.health_profile_id,
    });
    for (const cg of caregivers ?? []) {
      // Skip if caregiver disabled missed-med alerts for this member
      const { data: prefs } = await supabase
        .from("family_alert_preferences")
        .select("missed_medication_alerts")
        .eq("caregiver_user_id", cg.user_id)
        .eq("target_health_profile_id", log.health_profile_id)
        .maybeSingle();
      if (prefs && !prefs.missed_medication_alerts) continue;

      // Invoke send-family-nudge with internal_caller flag
      await fetch(`${Deno.env.get("SUPABASE_URL")}/functions/v1/send-family-nudge`, {
        method: "POST",
        headers: { "Authorization": `Bearer ${Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          recipient_user_id: cg.user_id,
          target_health_profile_id: log.health_profile_id,
          category: "MEDICATION_MISSED",
          preset_key: "MEDICATION",
          custom_message: `${log.member_name ?? "A family member"} missed their ${log.medication_name} dose.`,
          is_critical: true,
          internal_caller: true,
        }),
      });
      fanouts++;
    }
  }

  return new Response(JSON.stringify({ processed: overdueLogs.length, fanouts }), { status: 200 });
});
```

**SQL helper + cron migration:**

```sql
-- supabase/migrations/20260512000007_cron_missed_meds.sql

CREATE OR REPLACE FUNCTION public.get_overdue_pending_medications()
RETURNS TABLE (
  id UUID,
  health_profile_id UUID,
  scheduled_at TIMESTAMPTZ,
  medication_name TEXT,
  member_name TEXT
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    ml.id,
    ml.health_profile_id,
    ml.scheduled_at,
    m.name AS medication_name,
    hp.full_name AS member_name
  FROM medication_logs ml
  JOIN medications m ON m.id = ml.medication_id
  JOIN health_profiles hp ON hp.id = ml.health_profile_id
  WHERE ml.status = 'PENDING'
    AND ml.missed_alert_sent_at IS NULL
    AND ml.scheduled_at < NOW() - INTERVAL '30 minutes';
$$;

CREATE OR REPLACE FUNCTION public.get_caregivers_for_profile(profile_id UUID)
RETURNS TABLE (user_id UUID)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT DISTINCT hp.user_id
  FROM family_members fm_target
  JOIN family_members fm_caregiver ON fm_caregiver.family_group_id = fm_target.family_group_id
  JOIN health_profiles hp ON hp.id = fm_caregiver.health_profile_id
  WHERE fm_target.health_profile_id = profile_id
    AND fm_caregiver.health_profile_id != profile_id
    AND fm_caregiver.status = 'active'
    AND fm_caregiver.can_view = TRUE;
$$;

-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule every 5 minutes
SELECT cron.schedule(
  'detect-missed-medications',
  '*/5 * * * *',
  $$
    SELECT net.http_post(
      url := current_setting('app.settings.supabase_url') || '/functions/v1/detect-missed-medications',
      headers := jsonb_build_object('x-cron-secret', current_setting('app.settings.cron_shared_secret')),
      body := '{}'::jsonb
    );
  $$
);
```

**Verification:**
- Deploy: `supabase functions deploy detect-missed-medications`
- Set secrets: `supabase secrets set CRON_SHARED_SECRET=...`
- Manually invoke with curl. Insert a test PENDING log dated 1 hour ago. Confirm it becomes MISSED + fan-out fires.

---

## Phase 1 — Android Foundation (FCM + device tokens)

### Task 1.1: Add `firebase-messaging` dependency

**Files:**
- Modify: `android/app/build.gradle.kts` (dependencies block near line 163-166)

**Code (add after `firebase-analytics-ktx` line):**

```kotlin
    implementation("com.google.firebase:firebase-messaging-ktx")
```

**Verification:** `cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug` → BUILD SUCCESSFUL.

---

### Task 1.2: `DeviceTokenRepository` + Supabase wiring

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/data/repository/DeviceTokenRepository.kt`

**Code:**

```kotlin
package com.swastricare.health.data.repository

import com.swastricare.health.data.SupabaseConfig
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DeviceTokenRepository @Inject constructor(
    private val supabase: SupabaseConfig,
) {
    @Serializable
    private data class DeviceTokenRow(
        val user_id: String,
        val fcm_token: String,
        val platform: String = "android",
        val app_version: String? = null,
        val device_model: String? = null,
    )

    suspend fun upsertToken(userId: String, token: String, appVersion: String?, deviceModel: String?) {
        supabase.client.from("device_tokens").upsert(
            DeviceTokenRow(userId, token, "android", appVersion, deviceModel),
            onConflict = "user_id,fcm_token",
        )
    }

    suspend fun deleteToken(userId: String, token: String) {
        supabase.client.from("device_tokens").delete {
            filter {
                eq("user_id", userId)
                eq("fcm_token", token)
            }
        }
    }
}
```

**Add to `AppContainer.kt`:**
```kotlin
val deviceTokenRepository: DeviceTokenRepository by lazy { DeviceTokenRepository(supabaseConfig) }
```

**Verification:** `./gradlew assembleDebug` → BUILD SUCCESSFUL.

---

### Task 1.3: `SwastricareMessagingService` (FirebaseMessagingService)

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/notifications/SwastricareMessagingService.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Service code:**

```kotlin
package com.swastricare.health.notifications

import android.app.PendingIntent
import android.content.Intent
import android.net.Uri
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.swastricare.health.MainActivity
import com.swastricare.health.R
import com.swastricare.health.data.services.NotificationService
import com.swastricare.health.di.AppContainer
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class SwastricareMessagingService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        val container = AppContainer.get(applicationContext)
        val userId = container.authService.currentUserId() ?: return
        CoroutineScope(Dispatchers.IO).launch {
            runCatching {
                container.deviceTokenRepository.upsertToken(
                    userId = userId,
                    token = token,
                    appVersion = packageManager.getPackageInfo(packageName, 0).versionName,
                    deviceModel = android.os.Build.MODEL,
                )
            }
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val category = data["category"] ?: "GENERAL"
        val nudgeId = data["nudge_id"]
        val deepLink = data["deep_link"] ?: "swastricareapp://home"
        val title = message.notification?.title ?: "Swastricare"
        val body = message.notification?.body ?: ""

        val channelId = when (category) {
            "MEDICATION", "MEDICATION_MISSED" -> NotificationService.CHANNEL_MEDICATION
            "HYDRATION" -> NotificationService.CHANNEL_HYDRATION
            "APPOINTMENT" -> NotificationService.CHANNEL_APPOINTMENT
            "VITALS" -> NotificationService.CHANNEL_GENERAL
            "CHECKIN" -> NotificationService.CHANNEL_AI_NUDGE
            else -> NotificationService.CHANNEL_GENERAL
        }

        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLink)).apply {
            setClass(this@SwastricareMessagingService, MainActivity::class.java)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            this, nudgeId?.hashCode() ?: 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notif = NotificationCompat.Builder(this, channelId)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setPriority(if (category == "MEDICATION_MISSED") NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_DEFAULT)
            .build()

        val mgr = androidx.core.app.NotificationManagerCompat.from(this)
        if (mgr.areNotificationsEnabled()) {
            mgr.notify(nudgeId?.hashCode() ?: System.currentTimeMillis().toInt(), notif)
        }
    }
}
```

**Manifest addition (inside `<application>`):**

```xml
<service
    android:name=".notifications.SwastricareMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>

<!-- Deep link route for nudges (add to MainActivity activity tag) -->
<intent-filter android:autoVerify="false">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="swastricareapp" android:host="nudge" />
</intent-filter>
```

**Verification:** Build, install on OnePlus 8T. Confirm `adb logcat | grep -i fcm` shows token registered after login.

---

### Task 1.4: Register FCM token on login/app start

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/MainActivity.kt` (in `onCreate` after auth check) OR equivalent post-auth hook

**Code (snippet to add):**

```kotlin
// In MainActivity onCreate after auth is confirmed, OR in SessionManager.onUserAuthenticated
lifecycleScope.launch {
    val userId = container.authService.currentUserId() ?: return@launch
    val token = com.google.firebase.messaging.FirebaseMessaging.getInstance().token.await()
    runCatching {
        container.deviceTokenRepository.upsertToken(
            userId = userId,
            token = token,
            appVersion = packageManager.getPackageInfo(packageName, 0).versionName,
            deviceModel = android.os.Build.MODEL,
        )
    }
}
```

Add to top imports if missing:
```kotlin
import kotlinx.coroutines.tasks.await
```

And in `app/build.gradle.kts` dependencies:
```kotlin
implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.8.0")
```

**Verification:** Login on OnePlus 8T, check Supabase Studio `device_tokens` table for new row.

---

### Task 1.5: Deep link routing for `swastricareapp://nudge/{id}`

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/navigation/DeepLinkHandler.kt`

**Code (add to `parse` function):**

```kotlin
// Inside the family/join case or as a new branch:
"nudge" -> {
    val nudgeId = pathSegments.firstOrNull() ?: return DeepLinkRoute.Unknown
    DeepLinkRoute.NudgeDetail(nudgeId)
}
```

Add to `DeepLinkRoute` sealed class:
```kotlin
data class NudgeDetail(val nudgeId: String) : DeepLinkRoute()
```

Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/navigation/AppNavigation.kt` — add a composable route for `nudge/{nudgeId}` that opens a NudgeSheet bottom sheet showing the message and a link to the relevant feature (medication / hydration / etc).

**Verification:** Test via `adb shell am start -W -a android.intent.action.VIEW -d "swastricareapp://nudge/00000000-0000-0000-0000-000000000001" com.swastricare.health` — app launches and shows the nudge route.

---

## Phase 2 — Per-Member Dashboard

### Task 2.1: `FamilyAlertPreferencesRepository` + DTOs

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/data/repository/FamilyAlertPreferencesRepository.kt`

**Code:**

```kotlin
package com.swastricare.health.data.repository

import com.swastricare.health.data.SupabaseConfig
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

@Serializable
data class FamilyAlertPreferences(
    val caregiver_user_id: String,
    val target_health_profile_id: String,
    val missed_medication_alerts: Boolean = true,
    val low_hydration_alerts: Boolean = true,
    val missed_vitals_alerts: Boolean = false,
    val custom_nudge_alerts: Boolean = true,
    val quiet_hours_start: String? = null,  // "HH:mm:ss"
    val quiet_hours_end: String? = null,
    val missed_med_grace_minutes: Int = 30,
)

@Singleton
class FamilyAlertPreferencesRepository @Inject constructor(
    private val supabase: SupabaseConfig,
) {
    suspend fun get(caregiverUserId: String, targetProfileId: String): FamilyAlertPreferences? =
        supabase.client.from("family_alert_preferences").select {
            filter {
                eq("caregiver_user_id", caregiverUserId)
                eq("target_health_profile_id", targetProfileId)
            }
        }.decodeSingleOrNull<FamilyAlertPreferences>()

    suspend fun upsert(prefs: FamilyAlertPreferences) {
        supabase.client.from("family_alert_preferences").upsert(prefs)
    }
}
```

Register in `AppContainer.kt`:
```kotlin
val familyAlertPreferencesRepository: FamilyAlertPreferencesRepository by lazy { FamilyAlertPreferencesRepository(supabaseConfig) }
```

**Verification:** Build success.

---

### Task 2.2: `FamilyNudgeRepository`

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/data/repository/FamilyNudgeRepository.kt`

**Code:**

```kotlin
package com.swastricare.health.data.repository

import com.swastricare.health.data.SupabaseConfig
import io.github.jan.supabase.functions.functions
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

enum class NudgePreset(val key: String, val category: String) {
    MEDICATION("MEDICATION", "MEDICATION"),
    HYDRATION("HYDRATION", "HYDRATION"),
    VITALS("VITALS", "VITALS"),
    APPOINTMENT("APPOINTMENT", "APPOINTMENT"),
    CHECKIN("CHECKIN", "CHECKIN"),
}

@Singleton
class FamilyNudgeRepository @Inject constructor(
    private val supabase: SupabaseConfig,
) {
    @Serializable
    private data class NudgeRequest(
        val recipient_user_id: String,
        val target_health_profile_id: String?,
        val preset_key: String?,
        val custom_message: String?,
        val category: String,
        val is_critical: Boolean = false,
    )

    suspend fun sendPreset(recipientUserId: String, targetProfileId: String, preset: NudgePreset): Result<String> = runCatching {
        val req = NudgeRequest(
            recipient_user_id = recipientUserId,
            target_health_profile_id = targetProfileId,
            preset_key = preset.key,
            custom_message = null,
            category = preset.category,
        )
        val res = supabase.client.functions.invoke("send-family-nudge", req)
        res.body<String>() ?: ""
    }

    suspend fun sendCustom(recipientUserId: String, targetProfileId: String, message: String, category: String = "CHECKIN"): Result<String> = runCatching {
        val req = NudgeRequest(
            recipient_user_id = recipientUserId,
            target_health_profile_id = targetProfileId,
            preset_key = null,
            custom_message = message,
            category = category,
        )
        val res = supabase.client.functions.invoke("send-family-nudge", req)
        res.body<String>() ?: ""
    }
}
```

Register in `AppContainer.kt`:
```kotlin
val familyNudgeRepository: FamilyNudgeRepository by lazy { FamilyNudgeRepository(supabaseConfig) }
```

**Verification:** Build success.

---

### Task 2.3: `FamilyMemberDashboardViewModel`

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/family/member/FamilyMemberDashboardViewModel.kt`

**Code:**

```kotlin
package com.swastricare.health.ui.screens.family.member

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.repository.*
import com.swastricare.health.domain.model.FamilyMember
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate

data class FamilyMemberDashboardState(
    val member: FamilyMember? = null,
    val latestHeartRate: Int? = null,
    val latestSpO2: Int? = null,
    val sleepHours: Double? = null,
    val hydrationMl: Int = 0,
    val hydrationGoalMl: Int = 2500,
    val medicationsToday: List<MedicationDoseSummary> = emptyList(),
    val adherencePercent: Int = 0,
    val vaultDocCount: Int = 0,
    val dietCaloriesToday: Int = 0,
    val isLoading: Boolean = true,
    val canEdit: Boolean = false,
    val error: String? = null,
)

data class MedicationDoseSummary(
    val id: String,
    val name: String,
    val scheduledAt: String,
    val status: String, // PENDING/TAKEN/MISSED/SKIPPED
)

class FamilyMemberDashboardViewModel(
    private val medicationRepo: MedicationRepository,
    private val hydrationRepo: HydrationRepository,
    private val heartRateRepo: HeartRateRepositoryImpl,
    private val sleepRepo: SleepRepositoryImpl,
    private val vaultRepo: VaultRepository,
    private val dietRepo: DietRepository,
    private val familyRepo: FamilyRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(FamilyMemberDashboardState())
    val state: StateFlow<FamilyMemberDashboardState> = _state.asStateFlow()

    fun load(targetHealthProfileId: String) {
        _state.value = _state.value.copy(isLoading = true, error = null)
        viewModelScope.launch {
            runCatching {
                val today = LocalDate.now().toString()
                val members = familyRepo.getMembers(familyRepo.getMyFamilyGroup()!!.id)
                val member = members.find { it.healthProfileId == targetHealthProfileId }!!
                val callerMember = members.find { it.userId == familyRepo.currentUserId() }
                val canEdit = callerMember?.permissions?.canEdit == true || callerMember?.role?.name == "OWNER"

                val hr = heartRateRepo.getLatest(targetHealthProfileId)
                val sleep = sleepRepo.getNightSleepHours(targetHealthProfileId, today)
                val hydration = hydrationRepo.getTodayTotal(targetHealthProfileId)
                val meds = medicationRepo.getDosesForDay(targetHealthProfileId, today)
                val vault = vaultRepo.listForProfile(targetHealthProfileId)
                val diet = dietRepo.getDayCalories(targetHealthProfileId, today)

                val adherence = if (meds.isNotEmpty()) {
                    meds.count { it.status == "TAKEN" } * 100 / meds.size
                } else 0

                _state.value = FamilyMemberDashboardState(
                    member = member,
                    latestHeartRate = hr?.bpm,
                    sleepHours = sleep,
                    hydrationMl = hydration,
                    medicationsToday = meds.map {
                        MedicationDoseSummary(it.id, it.medicationName, it.scheduledAt, it.status)
                    },
                    adherencePercent = adherence,
                    vaultDocCount = vault.size,
                    dietCaloriesToday = diet,
                    canEdit = canEdit,
                    isLoading = false,
                )
            }.onFailure { e ->
                _state.value = _state.value.copy(isLoading = false, error = e.message)
            }
        }
    }
}
```

Note: helper methods like `getDosesForDay`, `getNightSleepHours`, `getDayCalories`, `getLatest`, `getTodayTotal`, `listForProfile` may need to be added to the respective repos if they don't accept a profile-id param yet. Add as needed in Task 2.3a (sub-task).

**Verification:** Build success. Add to AppContainer:
```kotlin
fun familyMemberDashboardViewModel() = FamilyMemberDashboardViewModel(
    medicationRepository, hydrationRepository, heartRateRepository,
    sleepRepository, vaultRepository, dietRepository, familyRepository,
)
```

---

### Task 2.3a: Extend existing repos with profile-id-parameterized accessors (where missing)

**Files:**
- Modify: `MedicationRepositoryImpl.kt` — add `suspend fun getDosesForDay(profileId: String, date: String): List<MedicationDose>`
- Modify: `HydrationRepositoryImpl.kt` — add `suspend fun getTodayTotal(profileId: String): Int`
- Modify: `HeartRateRepositoryImpl.kt` — add `suspend fun getLatest(profileId: String): HeartRateMeasurement?`
- Modify: `SleepRepositoryImpl.kt` — add `suspend fun getNightSleepHours(profileId: String, date: String): Double?`
- Modify: `VaultRepositoryImpl.kt` — add `suspend fun listForProfile(profileId: String): List<MedicalDocument>`
- Modify: `DietRepository.kt` — add `suspend fun getDayCalories(profileId: String, date: String): Int`

Pattern (example for hydration):
```kotlin
suspend fun getTodayTotal(profileId: String): Int {
    val today = LocalDate.now().toString()
    return supabase.client.from("hydration_logs").select {
        filter {
            eq("health_profile_id", profileId)
            gte("logged_at", "${today}T00:00:00")
        }
    }.decodeList<HydrationLogDto>().sumOf { it.amount_ml }
}
```

**Verification:** Build success.

---

### Task 2.4: `FamilyMemberDashboardScreen` (Compose)

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/family/member/FamilyMemberDashboardScreen.kt`

**Layout (sketch — full Compose code in the actual implementation):**

```
Scaffold(topBar = "Member Name", back arrow)
├─ Column(scrollable, white background)
│   ├─ MemberHeaderCard(avatar, name, role badge)
│   ├─ VitalsCard(heart rate, sleep, latest reading time)
│   ├─ AdherenceCard(ring chart, today's doses list)
│   ├─ HydrationCard(progress bar, ml/goal)
│   ├─ DietCard(calories today)
│   ├─ VaultCard(doc count, tap → vault list scoped to this profile)
│   └─ ActionRow:
│        - [Nudge] → opens FamilyNudgeSheet
│        - [Ask AI] → opens FamilyMemberAIScreen
│        - [Reminders] (if canEdit) → FamilyMemberRemindersScreen
│        - [Alert prefs] → FamilyAlertPreferencesScreen
```

All buttons solid `AITeal` (#22C5A6), no gradients. Background pure white.

**Verification:** Build, install, navigate to Family → member → confirm dashboard renders with mock/real data.

---

### Task 2.5: Wire dashboard into navigation from `FamilyScreen`

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/navigation/AppNavigation.kt` — add route `family/member/{healthProfileId}`
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/family/FamilyScreen.kt` — make each member row tappable, navigate to dashboard

**Verification:** Tap a member → dashboard opens.

---

## Phase 3 — Nudge Sheet (Send Nudges UI)

### Task 3.1: `FamilyNudgeSheet` Compose component

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/family/member/FamilyNudgeSheet.kt`

**Layout:**
```
ModalBottomSheet
├─ Title: "Nudge {Member.firstName}"
├─ Preset chip row (LazyRow):
│   - 💊 Take medication
│   - 💧 Drink water
│   - 🩺 Log vitals
│   - 📅 Appointment
│   - ❤️ Just checking in
├─ "Or write a custom message" expandable
│   - TextField (max 200 chars)
│   - [Send] button (solid AITeal)
└─ Success/error snackbar
```

Behavior: tap preset → immediately calls `viewModel.sendPreset()`. Custom requires Send button.

**Viewmodel:** new tiny `FamilyNudgeViewModel` with `sendPreset(preset)` / `sendCustom(text)` calling `FamilyNudgeRepository`.

**Verification:** From a test caregiver account, tap "💧 Drink water" on a member. Confirm:
1. `health_nudges` row inserted in Supabase
2. Member device (logged-in elsewhere) receives FCM push within 10 seconds
3. Tapping notification opens app to the nudge sheet

---

## Phase 4 — AI on Member Context

### Task 4.1: `FamilyMemberContextBuilder` + `AIRepository` extension

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/data/repository/FamilyMemberContextBuilder.kt`
- Modify: `android/app/src/main/kotlin/com/swastricare/health/data/repository/AIRepositoryImpl.kt` — accept optional `targetHealthProfileId` in `sendChatMessage`

**Builder code:**

```kotlin
package com.swastricare.health.data.repository

import javax.inject.Inject

class FamilyMemberContextBuilder @Inject constructor(
    private val medicationRepo: MedicationRepository,
    private val hydrationRepo: HydrationRepository,
    private val heartRateRepo: HeartRateRepositoryImpl,
    private val sleepRepo: SleepRepositoryImpl,
    private val profileRepo: ProfileRepository,
) {
    suspend fun build(targetHealthProfileId: String, days: Int = 7): String {
        val profile = profileRepo.getProfile(targetHealthProfileId)
        val hr = heartRateRepo.getRecent(targetHealthProfileId, days)
        val sleep = sleepRepo.getRecent(targetHealthProfileId, days)
        val meds = medicationRepo.getRecentDoses(targetHealthProfileId, days)
        val hydration = hydrationRepo.getRecentTotals(targetHealthProfileId, days)

        return buildString {
            appendLine("# Family member context (read-only)")
            appendLine("Name: ${profile.fullName}, Age: ${profile.age}, Sex: ${profile.sex}")
            appendLine()
            appendLine("## Last $days days summary")
            appendLine("- Avg heart rate: ${hr.map { it.bpm }.average().toInt()} bpm")
            appendLine("- Avg sleep: ${sleep.map { it.hours }.average()} h")
            appendLine("- Daily hydration avg: ${hydration.average().toInt()} ml")
            appendLine()
            appendLine("## Medications")
            meds.groupBy { it.medicationName }.forEach { (name, doses) ->
                val taken = doses.count { it.status == "TAKEN" }
                val total = doses.size
                appendLine("- $name: $taken/$total taken")
            }
        }
    }
}
```

**AIRepository change:** `sendChatMessage` already accepts `healthContext: String`. Add overload that fetches via builder if `targetHealthProfileId` provided:

```kotlin
suspend fun sendChatMessage(
    message: String,
    targetHealthProfileId: String? = null,
    conversationId: String? = null,
): AIResponse {
    val ctx = targetHealthProfileId?.let { contextBuilder.build(it) }
    return aiService.sendChatMessage(message, ctx, conversationId)
}
```

**Verification:** Build success.

---

### Task 4.2: `FamilyMemberAIScreen`

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/family/member/FamilyMemberAIScreen.kt`
- Reuse: existing `AIScreen` chat composables if possible (extract a shared `AIChatColumn` if needed)

**Behavior:**
- Receives `targetHealthProfileId` arg
- ViewModel passes it to `AIRepository.sendChatMessage`
- TopBar reads "Ask about {Member.firstName}"
- Pre-fills suggestion chips: "How is their sleep?", "Are they hydrated enough?", "How's medication adherence?"

**Verification:** From member dashboard tap "Ask AI" → screen opens → send "How is their adherence?" → response references member's actual data.

---

## Phase 5 — Caregiver Alert Preferences UI

### Task 5.1: `FamilyAlertPreferencesScreen` + ViewModel

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/family/member/FamilyAlertPreferencesScreen.kt`
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/family/member/FamilyAlertPreferencesViewModel.kt`

**Layout:**
```
TopBar: "Alert preferences for {Member.firstName}"
Column:
- Section "Alerts I want to receive"
  - Switch: Missed medication alerts (default ON)
  - Switch: Low hydration alerts (default ON)
  - Switch: Missed vitals alerts (default OFF)
  - Switch: Custom nudge replies (default ON)
- Section "Quiet hours"
  - Time picker: From [11:00 PM]
  - Time picker: To   [7:00 AM]
- Section "Missed-medication grace period"
  - Stepper: [15] [30] [45] [60] minutes (segmented)
- [Save] button (solid AITeal, sticky bottom)
```

ViewModel: load on init, debounced upsert on change OR explicit Save.

**Verification:** Adjust prefs, exit, re-enter — prefs persisted via Supabase.

---

## Phase 6 — Remote Reminder Editing

### Task 6.1: `FamilyMemberRemindersScreen` + ViewModel

**Files:**
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/family/member/FamilyMemberRemindersScreen.kt`
- Create: `android/app/src/main/kotlin/com/swastricare/health/ui/screens/family/member/FamilyMemberRemindersViewModel.kt`

**Gated by:** `canEdit` flag on dashboard state. If false, screen shows a "View-only" banner.

**Layout:**
```
TopBar: "Reminders for {Member.firstName}"
LazyColumn of member's medications:
  - Med name + dosage
  - Times today (chips with edit pencil)
  - Snooze duration dropdown
  - "Escalate after N missed" stepper (0/1/2/3)
  - [Save] per row OR sticky save
Footer note: "Changes apply to {Member.firstName}'s reminders."
```

Uses existing `MedicationRepository.updateSchedule(profileId, medId, ...)` (add the signature if missing). Server-side RLS via `has_family_access(profile_id, 'edit')` enforces caregiver permission.

**Verification:** As caregiver with `can_edit=true`, change John's medication time. Log in as John on another device, confirm new reminder time. As caregiver with `can_edit=false`, screen is read-only.

---

## Phase 7 — End-to-End Verification on Device

### Task 7.1: Manual E2E checklist

Run on the user's OnePlus 8T (`acac8d4b`) with a second test account:

| Scenario | Steps | Expected |
|---|---|---|
| FCM token registered | Fresh install, log in | New row in `device_tokens` table |
| View member dashboard | Family → tap member | All cards load with real data |
| Send preset nudge | Dashboard → 💊 preset | Member device receives push within 10s |
| Send custom nudge | Dashboard → Custom → "test" → Send | Member receives "test" |
| Quiet hours respected | Set member's quiet hours 00:00–23:59 → send non-critical | No push but `health_nudges` row inserted |
| Critical bypasses quiet hours | Insert PENDING med dated 1h ago | Push lands even in quiet hours |
| Missed med detection | PENDING log dated > 30 min ago | Within 5 min cron tick → log MISSED + caregiver push |
| Alert pref toggle | Disable missed-med alerts for John → induce missed med | No push to caregiver, log still MISSED |
| AI on member | Ask "How is John's adherence?" | Response uses John's real adherence data |
| Permission gating | Remove caregiver `can_view` | Dashboard returns RLS error / blank |
| Remote reminder edit | Edit John's med time | John's local AlarmManager picks up new time |

### Task 7.2: Smoke verify in CI/build

```bash
cd android
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug
# Expect: BUILD SUCCESSFUL with no new warnings beyond baseline
adb -s acac8d4b install -r app/build/outputs/apk/debug/app-debug.apk
adb -s acac8d4b shell am start -n com.swastricare.health/.MainActivity
adb -s acac8d4b logcat -c && adb -s acac8d4b logcat | grep -iE "fcm|swastricare|nudge" &
# Exercise UI flows manually
```

---

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| FCM service-account secret leaks | Stored only in Supabase Secrets (`FCM_SERVICE_ACCOUNT_JSON` base64) |
| Cron + edge function hot-loop | `missed_alert_sent_at IS NULL` guard prevents re-sends |
| Caregiver abuses nudges | v1 has no rate limit; future task to add per-(sender, recipient) cooldown |
| Member's app uninstalled / tokens stale | FCM 404/400 responses auto-prune `device_tokens` |
| Permission revoked mid-session | RLS rejects subsequent reads; client surfaces "no longer have access" |
| AI prompt-injection via member data | Context builder only includes structured fields, not free-form notes |
| `pg_cron` not enabled on Supabase project | First migration enables; if it fails, manual enable in dashboard required |

---

## Out of Scope (v1)

- iOS port (designed for transfer; not implemented this pass)
- Rate limiting on nudges
- Notification snooze / escalation chains
- Group nudges (broadcast to multiple)
- Editing non-medication reminders (hydration cadence, etc.)
- Wearables companion alerts

---

## Out-of-Plan Setup Steps (one-time, by user)

These cannot be automated by the implementation agent — the user must do them:

1. **Generate Firebase service account key**: Firebase Console → Project Settings → Service Accounts → "Generate new private key". Save the JSON.
2. **Base64 the key**: `base64 -i path/to/key.json > key.b64` and copy contents.
3. **Set Supabase secrets**:
   ```bash
   supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat key.b64)"
   supabase secrets set FCM_PROJECT_ID="<your-firebase-project-id>"
   supabase secrets set CRON_SHARED_SECRET="$(openssl rand -hex 32)"
   ```
4. **Enable `pg_cron`** on Supabase project: Dashboard → Database → Extensions → enable `pg_cron` and `pg_net`.
5. **Set Postgres GUCs**:
   ```sql
   ALTER DATABASE postgres SET app.settings.supabase_url = '<your-supabase-url>';
   ALTER DATABASE postgres SET app.settings.cron_shared_secret = '<same as above>';
   ```

---

**End of plan.**
