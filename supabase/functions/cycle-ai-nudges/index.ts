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

// ─── Helper: extract top 3 most common symptoms from recent logs ─────────────

function extractCommonSymptoms(logs: Array<{ symptoms: string | null }>): string {
  if (!logs || logs.length === 0) return 'none logged'

  const freq: Record<string, number> = {}
  for (const log of logs) {
    if (!log.symptoms) continue
    const parts = log.symptoms.split(',').map((s) => s.trim()).filter(Boolean)
    for (const symptom of parts) {
      freq[symptom] = (freq[symptom] ?? 0) + 1
    }
  }

  const sorted = Object.entries(freq)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(([symptom]) => symptom)

  return sorted.length > 0 ? sorted.join(', ') : 'none logged'
}

// ─── Helper: infer cycle regularity from past cycle lengths ─────────────────

function inferRegularity(pastCycleLengths: number[], avgLength: number): string {
  if (pastCycleLengths.length < 2) return 'Unknown'

  const maxDev = Math.max(...pastCycleLengths.map((l) => Math.abs(l - avgLength)))

  if (maxDev <= 2) return 'Regular'
  if (maxDev <= 5) return 'Somewhat Irregular'
  return 'Irregular'
}

// ─── Helper: format a Date as a YYYY-MM-DD string ───────────────────────────

function toDateStr(date: Date): string {
  return date.toISOString().split('T')[0]
}

// ─── AI message generation ──────────────────────────────────────────────────

async function generateCycleMessage(nudgeType: string, context: string): Promise<string> {
  const FALLBACKS: Record<string, string> = {
    cycle_period: 'Your period is due in 2 days. Stock up on essentials and keep a heating pad handy for cramp relief.',
    cycle_ovulation: 'Today is your predicted ovulation day. Stay hydrated and track any changes in your body.',
  }

  try {
    const messages: MiniMaxMessage[] = [
      { role: 'system', content: CYCLE_SYSTEM_PROMPT },
      { role: 'user', content: `Event type: ${nudgeType}\nContext: ${context}` },
    ]
    const response = await callMiniMax(messages, { temperature: 0.75, maxTokens: 150 })
    return response.trim()
  } catch (err) {
    console.error('cycle-ai-nudges: generateCycleMessage error:', (err as Error).message)
    return FALLBACKS[nudgeType] ?? 'Take care of yourself today.'
  }
}

// ─── Dedup + insert one nudge ────────────────────────────────────────────────

interface MaybeInsertOpts {
  userId: string
  profileId: string
  nudgeType: string
  today: string
  promptContext: string
  eventLabel: string
  deeplink: string
}

async function maybeInsertNudge(supabase: ReturnType<typeof createClient>, opts: MaybeInsertOpts): Promise<boolean> {
  const { userId, profileId, nudgeType, today, promptContext, eventLabel, deeplink } = opts

  // Dedup: skip if we already inserted this nudge type for this user today
  const { data: existing } = await supabase
    .from('ai_nudges')
    .select('id')
    .eq('user_id', userId)
    .eq('nudge_type', nudgeType)
    .gte('created_at', `${today}T00:00:00Z`)
    .limit(1)

  if (existing && existing.length > 0) {
    console.log(`cycle-ai-nudges: skipping ${nudgeType} for ${userId} (already exists today)`)
    return false
  }

  const message = await generateCycleMessage(nudgeType, promptContext)

  const now = new Date()
  const expiresAt = new Date(now.getTime() + 24 * 3600 * 1000).toISOString()

  const { error: insertError } = await supabase.from('ai_nudges').insert({
    user_id: userId,
    health_profile_id: profileId,
    nudge_type: nudgeType,
    title: eventLabel,
    message,
    priority: 'high',
    action_deeplink: deeplink,
    push_sent: false,
    is_dismissed: false,
    source_data: { context: promptContext },
    expires_at: expiresAt,
  })

  if (insertError) {
    console.error(`cycle-ai-nudges: insert error for ${nudgeType}/${userId}:`, insertError.message)
    return false
  }

  console.log(`cycle-ai-nudges: inserted ${nudgeType} for ${userId}`)
  return true
}

// ─── Per-user processing ─────────────────────────────────────────────────────

interface MenstrualSetting {
  health_profile_id: string
  average_cycle_length: number | null
  average_period_length: number | null
  reminder_enabled: boolean
}

async function processUserCycleNudges(
  supabase: ReturnType<typeof createClient>,
  setting: MenstrualSetting,
  today: string,
  twoDaysFromNow: string,
): Promise<number> {
  // 1. Resolve user_id from health_profiles
  const { data: profileRow, error: profileError } = await supabase
    .from('health_profiles')
    .select('user_id')
    .eq('id', setting.health_profile_id)
    .single()

  if (profileError || !profileRow?.user_id) {
    console.log(`cycle-ai-nudges: no user_id for profile ${setting.health_profile_id}`)
    return 0
  }

  const userId: string = profileRow.user_id
  const profileId: string = setting.health_profile_id

  // 2. Fetch recent menstrual cycles (up to 6, most recent first)
  const { data: cycles, error: cyclesError } = await supabase
    .from('menstrual_cycles')
    .select('start_date, end_date, cycle_length')
    .eq('health_profile_id', profileId)
    .order('start_date', { ascending: false })
    .limit(6)

  if (cyclesError || !cycles || cycles.length === 0) {
    console.log(`cycle-ai-nudges: no cycle data for profile ${profileId}`)
    return 0
  }

  // 3. Compute predicted dates
  const lastPeriodStart = new Date(cycles[0].start_date + 'T00:00:00Z')
  const cycleLength = setting.average_cycle_length ?? 28

  const predictedNextPeriod = new Date(lastPeriodStart)
  predictedNextPeriod.setDate(predictedNextPeriod.getDate() + cycleLength)

  const ovulationDay = new Date(lastPeriodStart)
  ovulationDay.setDate(ovulationDay.getDate() + (cycleLength - 14))

  const predictedNextPeriodStr = toDateStr(predictedNextPeriod)
  const ovulationDayStr = toDateStr(ovulationDay)

  // 4. Fetch recent daily logs for symptom context
  const { data: recentLogs } = await supabase
    .from('menstrual_daily_logs')
    .select('symptoms, mood, pain_level')
    .eq('health_profile_id', profileId)
    .order('date', { ascending: false })
    .limit(5)

  const logs = recentLogs ?? []
  const commonSymptoms = extractCommonSymptoms(logs)

  const painLevels = logs
    .map((l: { pain_level: number | null }) => l.pain_level)
    .filter((p): p is number => p !== null && p !== undefined)
  const avgPain = painLevels.length > 0
    ? Math.round(painLevels.reduce((a, b) => a + b, 0) / painLevels.length)
    : 0

  const pastCycleLengths = cycles
    .map((c: { cycle_length: number | null }) => c.cycle_length)
    .filter((l): l is number => l !== null && l !== undefined)
  const regularity = inferRegularity(pastCycleLengths, cycleLength)

  let inserted = 0

  // 5. Period approaching in 2 days
  if (predictedNextPeriodStr === twoDaysFromNow) {
    const periodContext = [
      `Period predicted in 2 days (${predictedNextPeriodStr}).`,
      `Cycle regularity: ${regularity}.`,
      `Common recent symptoms: ${commonSymptoms}.`,
      `Average pain level: ${avgPain}/10.`,
    ].join(' ')

    const ok = await maybeInsertNudge(supabase, {
      userId,
      profileId,
      nudgeType: 'cycle_period',
      today,
      promptContext: periodContext,
      eventLabel: 'Period Approaching',
      deeplink: 'swastricareapp://menstrual',
    })
    if (ok) inserted++
  }

  // 6. Ovulation today
  if (ovulationDayStr === today) {
    const ovulationContext = [
      `Today (${today}) is the predicted ovulation day.`,
      `Cycle regularity: ${regularity}.`,
      `Common recent symptoms: ${commonSymptoms}.`,
    ].join(' ')

    const ok = await maybeInsertNudge(supabase, {
      userId,
      profileId,
      nudgeType: 'cycle_ovulation',
      today,
      promptContext: ovulationContext,
      eventLabel: 'Ovulation Day',
      deeplink: 'swastricareapp://menstrual',
    })
    if (ok) inserted++
  }

  return inserted
}

// ─── Entry point ─────────────────────────────────────────────────────────────

serve(async (req) => {
  try {
    const corsResponse = handleCors(req)
    if (corsResponse) return corsResponse

    // Use service role for server-side operations
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const { user_id } = await req.json().catch(() => ({}))

    const now = new Date()
    const today = toDateStr(now)
    const twoDaysLater = new Date(now)
    twoDaysLater.setDate(twoDaysLater.getDate() + 2)
    const twoDaysFromNow = toDateStr(twoDaysLater)

    console.log(`cycle-ai-nudges: Starting. today=${today}, twoDaysFromNow=${twoDaysFromNow}`, user_id ? `user_id=${user_id}` : '(all users)')

    // When user_id is provided, resolve health_profile_id first
    let profileIdFilter: string | null = null
    if (user_id) {
      const { data: profile } = await supabase
        .from('health_profiles')
        .select('id')
        .eq('user_id', user_id)
        .eq('is_primary', true)
        .single()
      profileIdFilter = profile?.id ?? null
      if (!profileIdFilter) {
        return new Response(JSON.stringify({ nudges_generated: 0 }), {
          headers: { 'Content-Type': 'application/json', ...corsHeaders }
        })
      }
    }

    let settingsQuery = supabase
      .from('menstrual_settings')
      .select('health_profile_id, average_cycle_length, average_period_length, reminder_enabled')
      .eq('reminder_enabled', true)

    if (profileIdFilter) {
      settingsQuery = settingsQuery.eq('health_profile_id', profileIdFilter)
    }

    const { data: settings, error: settingsError } = await settingsQuery

    if (settingsError || !settings || settings.length === 0) {
      console.log('cycle-ai-nudges: No settings found:', settingsError?.message)
      return new Response(JSON.stringify({ nudges_generated: 0 }), {
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      })
    }

    let totalNudges = 0

    for (const setting of settings) {
      const count = await processUserCycleNudges(supabase, setting, today, twoDaysFromNow)
      totalNudges += count
    }

    console.log(`cycle-ai-nudges: Done. Generated ${totalNudges} nudge(s).`)

    return new Response(JSON.stringify({ nudges_generated: totalNudges }), {
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  } catch (error) {
    console.error('cycle-ai-nudges: Unhandled error:', (error as Error).message)
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    })
  }
})
