# Cycle AI Notifications Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace static hardcoded cycle notification strings with AI-generated, personalized messages using full cycle context (phase, symptoms, mood, pain, regularity, fertile window).

**Architecture:** Two parallel systems — (1) a new `CycleAINudgeWorker` runs daily on-device via WorkManager, calls `AIService → ai-router` with full cycle context, and shows the tip immediately; (2) a new `cycle-ai-nudges` Supabase Edge Function runs server-side on a cron to generate period-approaching and ovulation-day alerts, inserting them into `ai_nudges` for delivery by the existing `AiNudgeWorker`.

**Tech Stack:** Kotlin/Compose, WorkManager, Supabase Kotlin client, Deno/TypeScript Edge Functions, MiniMax AI (server-side, same as `ai-nudge-generator`), `AIService` → `ai-router` (on-device).

---

## Task 1: Create CycleAINudgeWorker

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/workers/CycleAINudgeWorker.kt`

**Step 1: Create the worker file**

```kotlin
package com.swasthicare.mobile.data.workers

import android.content.Context
import android.util.Log
import androidx.work.*
import com.swasthicare.mobile.data.models.CyclePhase
import com.swasthicare.mobile.data.models.MenstrualDailyLog
import com.swasthicare.mobile.data.services.AIService
import com.swasthicare.mobile.data.services.NotificationService
import com.swasthicare.mobile.di.AppContainer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.concurrent.TimeUnit

class CycleAINudgeWorker(appContext: Context, params: WorkerParameters) :
    CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            AppContainer.initialize(applicationContext)
            val notifService = AppContainer.notificationService
            if (!notifService.cycleEnabled) return@withContext Result.success()

            val repo = AppContainer.menstrualCycleRepository
            val cycles = repo.loadLocalCycles()
            if (cycles.isEmpty()) return@withContext Result.success()

            val settings = repo.loadSettings()
            val logs = repo.loadLocalDailyLogs()
            val today = LocalDate.now()

            // Current cycle state
            val latestCycle = cycles.maxByOrNull { it.startDate } ?: return@withContext Result.success()
            val dayInCycle = ChronoUnit.DAYS.between(latestCycle.startDate, today).toInt() + 1
            val cycleLength = settings.averageCycleLength
            val daysUntilPeriod = (cycleLength - dayInCycle).coerceAtLeast(0)

            val currentPhase = repo.detectCurrentPhase(cycles, settings)
            val predictions = repo.calculatePredictions(cycles, settings)
            val stats = repo.calculateStatistics(cycles)

            // Fertile window check
            val inFertileWindow = predictions?.let {
                !today.isBefore(it.fertileWindowStart) && !today.isAfter(it.fertileWindowEnd)
            } ?: false

            // Recent logs (last 3 days)
            val recentLogs = logs.filter {
                ChronoUnit.DAYS.between(it.date, today) in 0..2
            }.sortedByDescending { it.date }
            val todayLog = recentLogs.firstOrNull { it.date == today }

            val symptomsText = recentLogs.flatMap { it.symptoms }.map { it.displayName }
                .distinct().takeIf { it.isNotEmpty() }?.joinToString(", ") ?: "none logged"
            val moodText = todayLog?.mood?.displayName ?: "not logged"
            val painLevel = todayLog?.painLevel ?: 0

            val regularity = when {
                stats.totalCyclesTracked < 2 -> "Unknown"
                stats.longestCycle - stats.shortestCycle <= 3 -> "Regular"
                stats.longestCycle - stats.shortestCycle <= 7 -> "Somewhat Irregular"
                else -> "Irregular"
            }

            val prompt = buildPrompt(
                phase = currentPhase,
                dayInCycle = dayInCycle,
                totalDays = cycleLength,
                daysUntilPeriod = daysUntilPeriod,
                symptoms = symptomsText,
                mood = moodText,
                painLevel = painLevel,
                inFertileWindow = inFertileWindow,
                regularity = regularity
            )

            val message = try {
                val aiService = AIService(AppContainer.supabaseClient)
                aiService.sendChatMessage(prompt, emptyList())
            } catch (e: Exception) {
                Log.w(TAG, "AI generation failed, using fallback: ${e.message}")
                staticFallback(currentPhase)
            }

            notifService.showNotification(
                channelId = NotificationService.CHANNEL_CYCLE,
                notificationId = NotificationService.NOTIF_CYCLE_LOG,
                title = "Today's Cycle Tip",
                body = message.take(200)
            )

            Log.d(TAG, "Cycle AI tip delivered")
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "CycleAINudgeWorker failed: ${e.message}")
            Result.retry()
        }
    }

    private fun buildPrompt(
        phase: CyclePhase,
        dayInCycle: Int,
        totalDays: Int,
        daysUntilPeriod: Int,
        symptoms: String,
        mood: String,
        painLevel: Int,
        inFertileWindow: Boolean,
        regularity: String
    ): String = """
        You are a women's health assistant. Write a warm, personalized daily health tip as a push notification (max 2 sentences, actionable).

        Cycle context:
        - Phase: ${phase.displayName} (Day $dayInCycle of $totalDays)
        - Days until next period: $daysUntilPeriod
        - Logged symptoms recently: $symptoms
        - Mood: $mood | Pain level: $painLevel/10
        - Fertile window: ${if (inFertileWindow) "Yes" else "No"} | Cycle regularity: $regularity

        Reply with only the notification message. No title, no formatting.
    """.trimIndent()

    private fun staticFallback(phase: CyclePhase): String = when (phase) {
        CyclePhase.MENSTRUAL -> "Rest and stay warm today — your body is working hard. Gentle movement and iron-rich foods can help."
        CyclePhase.FOLLICULAR -> "Your energy is rising! It's a great day for a workout or starting something new."
        CyclePhase.OVULATION -> "You're at peak energy today. Stay hydrated and make the most of it!"
        CyclePhase.LUTEAL -> "Feeling a little low? Magnesium-rich foods and gentle movement can ease PMS symptoms."
        CyclePhase.UNKNOWN -> "Track your period to get personalized daily cycle tips."
    }

    companion object {
        private const val TAG = "CycleAINudgeWorker"
        const val WORK_TAG = "cycle_ai_nudge_daily"
        const val WORK_NAME = "cycle_ai_nudge_daily"

        fun enqueue(context: Context) {
            val now = java.util.Calendar.getInstance()
            val next8AM = java.util.Calendar.getInstance().apply {
                set(java.util.Calendar.HOUR_OF_DAY, 8)
                set(java.util.Calendar.MINUTE, 0)
                set(java.util.Calendar.SECOND, 0)
                set(java.util.Calendar.MILLISECOND, 0)
                if (before(now)) add(java.util.Calendar.DAY_OF_MONTH, 1)
            }
            val initialDelay = next8AM.timeInMillis - now.timeInMillis

            val request = PeriodicWorkRequestBuilder<CycleAINudgeWorker>(24, TimeUnit.HOURS)
                .setInitialDelay(initialDelay, TimeUnit.MILLISECONDS)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build()
                )
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 5, TimeUnit.MINUTES)
                .addTag(WORK_TAG)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME, ExistingPeriodicWorkPolicy.KEEP, request
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }
}
```

**Step 2: Verify it compiles**

```bash
cd android && ./gradlew :app:compileDebugKotlin 2>&1 | grep -E "error:|CycleAINudge"
```

Expected: no errors mentioning `CycleAINudgeWorker`.

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/workers/CycleAINudgeWorker.kt
git commit -m "feat(android): add CycleAINudgeWorker for daily AI-generated phase tips"
```

---

## Task 2: Wire CycleAINudgeWorker into CycleNotificationScheduler

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/CycleNotificationScheduler.kt`

**Step 1: Read the current file**

Read `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/CycleNotificationScheduler.kt` before editing.

**Step 2: Update `scheduleFromPredictions` to enqueue the worker**

In `scheduleFromPredictions`, after the existing alarm scheduling logic, add:

```kotlin
// Enqueue daily AI-generated phase tip (replaces static daily log reminder)
CycleAINudgeWorker.enqueue(context)
```

Also remove the existing `dailyLogEnabled` block (the static "Log Today's Cycle" notification), since `CycleAINudgeWorker` replaces it:

```kotlin
// REMOVE this block:
if (dailyLogEnabled) {
    val cal = Calendar.getInstance().apply { ... }
    notifService.scheduleCycleReminder("log", cal, "Log Today's Cycle", "Don't forget to log...")
}
```

Add the import at the top:
```kotlin
import com.swasthicare.mobile.data.workers.CycleAINudgeWorker
```

**Step 3: Compile check**

```bash
cd android && ./gradlew :app:compileDebugKotlin 2>&1 | grep "error:"
```

Expected: no errors.

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/services/CycleNotificationScheduler.kt
git commit -m "feat(android): replace static daily cycle reminder with CycleAINudgeWorker"
```

---

## Task 3: Create the cycle-ai-nudges Supabase Edge Function

**Files:**
- Create: `supabase/functions/cycle-ai-nudges/index.ts`

This function runs server-side on a cron schedule. It finds users whose period is due in 2 days or whose ovulation is today, fetches their recent log data, generates a personalized AI message via MiniMax (same pattern as `ai-nudge-generator`), and inserts into `ai_nudges`.

**Step 1: Create the edge function directory and file**

```bash
mkdir -p supabase/functions/cycle-ai-nudges
```

**Step 2: Write the function**

```typescript
// supabase/functions/cycle-ai-nudges/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { callMiniMax, type MiniMaxMessage } from '../_shared/minimax.ts'
import { handleCors, corsHeaders } from '../_shared/cors.ts'

const CYCLE_SYSTEM_PROMPT = `You are a compassionate women's health assistant. Generate a brief, warm push notification message (max 2 sentences) for a menstrual cycle event.
Rules:
- Keep under 180 characters
- Be supportive and practical
- Include one actionable tip
- Do not use clinical/scary language
- Return only the message text, no title, no formatting`

serve(async (req) => {
  try {
    const corsResponse = handleCors(req)
    if (corsResponse) return corsResponse

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const today = new Date().toISOString().split('T')[0]
    const twoDaysFromNow = new Date(Date.now() + 2 * 86400000).toISOString().split('T')[0]

    console.log('🌸 CYCLE NUDGES: Running for date', today)

    // Get all active menstrual settings with cycle predictions
    const { data: settings, error: settingsError } = await supabase
      .from('menstrual_settings')
      .select('health_profile_id, average_cycle_length, average_period_length, reminder_enabled')
      .eq('reminder_enabled', true)

    if (settingsError || !settings?.length) {
      console.log('🌸 No settings found:', settingsError?.message)
      return new Response(JSON.stringify({ nudges_generated: 0 }), {
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      })
    }

    let totalNudges = 0

    for (const setting of settings) {
      try {
        await processUserCycleNudges(supabase, setting, today, twoDaysFromNow)
        totalNudges++
      } catch (e) {
        console.error(`🌸 Error processing ${setting.health_profile_id}:`, e.message)
      }
    }

    console.log(`🌸 CYCLE NUDGES: Done. Processed ${totalNudges} users.`)
    return new Response(JSON.stringify({ nudges_generated: totalNudges }), {
      headers: { 'Content-Type': 'application/json', ...corsHeaders }
    })
  } catch (error) {
    console.error('🌸 Cycle nudges error:', error.message)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders }
    })
  }
})

async function processUserCycleNudges(
  supabase: any,
  setting: any,
  today: string,
  twoDaysFromNow: string
) {
  const profileId = setting.health_profile_id
  const cycleLength: number = setting.average_cycle_length ?? 28

  // Get user_id from health_profiles
  const { data: profile } = await supabase
    .from('health_profiles')
    .select('user_id')
    .eq('id', profileId)
    .single()

  if (!profile?.user_id) return

  const userId = profile.user_id

  // Get most recent cycle
  const { data: cycles } = await supabase
    .from('menstrual_cycles')
    .select('start_date, end_date, cycle_length')
    .eq('health_profile_id', profileId)
    .order('start_date', { ascending: false })
    .limit(6)

  if (!cycles?.length) return

  const latestCycle = cycles[0]
  const lastPeriodStart = new Date(latestCycle.start_date)
  const predictedNextPeriod = new Date(lastPeriodStart.getTime() + cycleLength * 86400000)
  const predictedNextPeriodStr = predictedNextPeriod.toISOString().split('T')[0]

  // Ovulation is cycleLength - 14 days after period start
  const ovulationDay = new Date(lastPeriodStart.getTime() + (cycleLength - 14) * 86400000)
  const ovulationDayStr = ovulationDay.toISOString().split('T')[0]

  // Get recent symptom/mood context (last 5 logs)
  const { data: recentLogs } = await supabase
    .from('menstrual_daily_logs')
    .select('symptoms, mood, pain_level, flow_level')
    .eq('health_profile_id', profileId)
    .order('date', { ascending: false })
    .limit(5)

  const commonSymptoms = extractCommonSymptoms(recentLogs ?? [])
  const avgPain = recentLogs?.length
    ? Math.round(recentLogs.reduce((sum: number, l: any) => sum + (l.pain_level ?? 0), 0) / recentLogs.length)
    : 0

  const cycleVariances = cycles.slice(1).map((c: any) => c.cycle_length ?? cycleLength)
  const regularity = inferRegularity(cycleVariances, cycleLength)

  // Period approaching in 2 days
  if (predictedNextPeriodStr === twoDaysFromNow) {
    await maybeInsertNudge(supabase, {
      userId,
      profileId,
      nudgeType: 'cycle_period',
      today,
      promptContext: `Period expected in 2 days. Common symptoms: ${commonSymptoms}. Average pain: ${avgPain}/10. Regularity: ${regularity}.`,
      eventLabel: 'Period Approaching',
      deeplink: 'swastricareapp://menstrual'
    })
  }

  // Ovulation today
  if (ovulationDayStr === today) {
    const fertileStart = new Date(ovulationDay.getTime() - 5 * 86400000).toISOString().split('T')[0]
    const fertileEnd = new Date(ovulationDay.getTime() + 1 * 86400000).toISOString().split('T')[0]
    await maybeInsertNudge(supabase, {
      userId,
      profileId,
      nudgeType: 'cycle_ovulation',
      today,
      promptContext: `Today is predicted ovulation day. Fertile window: ${fertileStart} to ${fertileEnd}. Regularity: ${regularity}.`,
      eventLabel: 'Ovulation Day',
      deeplink: 'swastricareapp://menstrual'
    })
  }
}

async function maybeInsertNudge(supabase: any, opts: {
  userId: string
  profileId: string
  nudgeType: string
  today: string
  promptContext: string
  eventLabel: string
  deeplink: string
}) {
  // Dedup: skip if already inserted today for this type
  const { data: existing } = await supabase
    .from('ai_nudges')
    .select('id')
    .eq('user_id', opts.userId)
    .eq('nudge_type', opts.nudgeType)
    .gte('created_at', opts.today + 'T00:00:00Z')
    .limit(1)

  if (existing?.length) {
    console.log(`🌸 Skipping ${opts.nudgeType} for ${opts.userId} — already sent today`)
    return
  }

  const message = await generateCycleMessage(opts.nudgeType, opts.promptContext)

  await supabase.from('ai_nudges').insert({
    user_id: opts.userId,
    health_profile_id: opts.profileId,
    nudge_type: opts.nudgeType,
    title: opts.eventLabel,
    message,
    priority: 'high',
    action_deeplink: opts.deeplink,
    push_sent: false,
    is_dismissed: false,
    source_data: { context: opts.promptContext },
    expires_at: new Date(Date.now() + 24 * 3600 * 1000).toISOString()
  })

  console.log(`🌸 Inserted ${opts.nudgeType} nudge for ${opts.userId}`)
}

async function generateCycleMessage(nudgeType: string, context: string): Promise<string> {
  try {
    const messages: MiniMaxMessage[] = [
      { role: 'system', content: CYCLE_SYSTEM_PROMPT },
      { role: 'user', content: `Event: ${nudgeType}\nContext: ${context}` }
    ]
    const response = await callMiniMax(messages, { temperature: 0.75, maxTokens: 150 })
    return response.trim()
  } catch {
    // Static fallbacks
    if (nudgeType === 'cycle_period') {
      return 'Your period is due in 2 days. Stock up on essentials and keep a heating pad handy for cramp relief.'
    }
    return 'Today is your predicted ovulation day. Stay hydrated and track any changes in your body.'
  }
}

function extractCommonSymptoms(logs: any[]): string {
  if (!logs.length) return 'none logged'
  const all = logs.flatMap((l: any) =>
    l.symptoms ? l.symptoms.split(',').map((s: string) => s.trim()) : []
  )
  if (!all.length) return 'none logged'
  const freq: Record<string, number> = {}
  all.forEach(s => { freq[s] = (freq[s] ?? 0) + 1 })
  return Object.entries(freq)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([s]) => s)
    .join(', ')
}

function inferRegularity(pastCycleLengths: number[], avgLength: number): string {
  if (pastCycleLengths.length < 2) return 'Unknown'
  const maxDev = Math.max(...pastCycleLengths.map(l => Math.abs(l - avgLength)))
  if (maxDev <= 2) return 'Regular'
  if (maxDev <= 5) return 'Somewhat Irregular'
  return 'Irregular'
}
```

**Step 3: Commit**

```bash
git add supabase/functions/cycle-ai-nudges/index.ts
git commit -m "feat(supabase): add cycle-ai-nudges edge function for event-triggered AI notifications"
```

---

## Task 4: Register Cron Schedule for the Edge Function

**Files:**
- Modify: `supabase/config.toml` (if it exists) OR note manual step

**Step 1: Check if config.toml exists**

```bash
ls supabase/config.toml
```

**Step 2a: If config.toml exists**, add the cron schedule under `[functions]`:

```toml
[functions.cycle-ai-nudges]
schedule = "0 7 * * *"
```

**Step 2b: If config.toml does NOT exist**, this is a manual step. Document in the edge function's README or in `docs/plans/2026-03-09-cycle-ai-notifications-design.md`:

> Deploy and schedule via Supabase Dashboard → Edge Functions → `cycle-ai-nudges` → Schedule: `0 7 * * *` (daily 7 AM UTC).

Or deploy via CLI:
```bash
supabase functions deploy cycle-ai-nudges
```

**Step 3: Commit**

```bash
git add supabase/config.toml  # only if modified
git commit -m "feat(supabase): schedule cycle-ai-nudges cron at 7 AM UTC daily"
```

---

## Task 5: Add aiService to AppContainer (if needed)

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt`

**Step 1: Verify `AIService` is not already in AppContainer**

```bash
grep -n "AIService\|aiService" android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt
```

**Step 2: If NOT found**, add it after the `cycleNotificationScheduler` entry (around line 188):

```kotlin
// AI Service — used by CycleAINudgeWorker and other on-device AI features
val aiService: AIService by lazy {
    AIService(supabaseClient)
}
```

And add the import at the top of the file:
```kotlin
import com.swasthicare.mobile.data.services.AIService
```

Then update `CycleAINudgeWorker` to use `AppContainer.aiService` instead of instantiating it directly:

```kotlin
// In CycleAINudgeWorker.doWork(), replace:
val aiService = AIService(AppContainer.supabaseClient)
// with:
val aiService = AppContainer.aiService
```

**Step 3: Compile check**

```bash
cd android && ./gradlew :app:compileDebugKotlin 2>&1 | grep "error:"
```

**Step 4: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/workers/CycleAINudgeWorker.kt
git commit -m "refactor(android): expose AIService via AppContainer, use in CycleAINudgeWorker"
```

---

## Task 6: Full Debug Build Verification

**Step 1: Clean build**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -20
```

Expected: `BUILD SUCCESSFUL`

**Step 2: If build fails**, read the error output carefully. Common issues:
- Missing import in `CycleAINudgeWorker` → add it
- `CyclePhase` ambiguity (there are two definitions — one in `MenstrualCycleModels.kt` and one in `MenstrualCycleViewModel.kt`) → use the fully qualified `com.swasthicare.mobile.data.models.CyclePhase` in the worker

**Step 3: Commit any fixes**

```bash
git add -p
git commit -m "fix(android): resolve compile issues in CycleAINudgeWorker"
```

---

## Task 7: Manual Smoke Test

**Step 1: Trigger the worker manually**

In Android Studio → Device File Explorer, or add a temporary debug button in the app to call:

```kotlin
CycleAINudgeWorker.enqueue(context)
// Then immediately trigger it (skip the 24h delay) via:
WorkManager.getInstance(context).enqueue(
    OneTimeWorkRequestBuilder<CycleAINudgeWorker>().build()
)
```

**Step 2: Check Logcat**

Filter by tag `CycleAINudgeWorker`. Expected output:
```
D/CycleAINudgeWorker: Cycle AI tip delivered
```

If fallback fires:
```
W/CycleAINudgeWorker: AI generation failed, using fallback: ...
```

Either way, a notification should appear in the notification shade with title "Today's Cycle Tip".

**Step 3: Verify event-triggered nudge (server-side)**

Manually invoke the edge function:
```bash
supabase functions invoke cycle-ai-nudges --no-verify-jwt
```

Expected response: `{"nudges_generated": N}`

Check `ai_nudges` table in Supabase Dashboard — new rows with `nudge_type = "cycle_period"` or `"cycle_ovulation"` should appear for eligible users. `AiNudgeWorker` will pick these up within 30 minutes.

**Step 4: Final commit (clean up any debug triggers)**

```bash
git add -p
git commit -m "test(android): smoke test CycleAINudgeWorker — verified tip delivery and fallback"
```

---

## Notes

### CyclePhase Ambiguity
There are **two** `CyclePhase` definitions in the codebase:
- `com.swasthicare.mobile.data.models.CyclePhase` (in `MenstrualCycleModels.kt`) — used by the repository's `detectCurrentPhase()`
- `com.swasthicare.mobile.ui.screens.menstrualcycle.CyclePhase` (in `MenstrualCycleViewModel.kt`) — UI-only

The worker uses the **data model** version (`com.swasthicare.mobile.data.models.CyclePhase`) since that is what `MenstrualCycleRepository.detectCurrentPhase()` returns. Use the fully qualified name if there is an import conflict.

### ai_nudges Table Schema
The `cycle-ai-nudges` edge function inserts into the existing `ai_nudges` table. The `AiNudgeWorker` already reads from this table and delivers notifications. No schema migration required — existing columns (`user_id`, `health_profile_id`, `nudge_type`, `title`, `message`, `priority`, `action_deeplink`, `push_sent`, `is_dismissed`, `source_data`, `expires_at`) are sufficient.

### MiniMax vs ai-router for server-side
The server-side function uses `callMiniMax` (same as `ai-nudge-generator`) rather than calling `ai-router`, since `ai-router` is designed to be called from the client with a user auth token. MiniMax is the server-side AI provider used in all Supabase edge functions in this project.
