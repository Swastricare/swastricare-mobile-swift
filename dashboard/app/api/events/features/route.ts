import { NextRequest, NextResponse } from 'next/server'
import { subDays } from 'date-fns'
import { supabase } from '@/lib/supabase'
import { computeDelta, getISTDay } from '@/lib/event-utils'

export const dynamic = 'force-dynamic'

// Feature group definitions — kept in sync with event inventory
const FEATURE_GROUPS: Record<string, string[]> = {
  Hydration:    ['hydration_logged', 'hydration_goal_met'],
  Medication:   ['medication_taken', 'medication_skipped'],
  Workout:      ['workout_started', 'workout_completed'],
  AI:           ['ai_message_sent', 'ai_analysis_request', 'conversation_started'],
  Vault:        ['vault_upload'],
  'Heart Rate': ['heartbeat_measurement'],
  Diet:         ['food_searched', 'food_added', 'food_deleted', 'meal_copied', 'calorie_goal_reached'],
  Cycle:        ['cycle_logged', 'symptom_logged', 'cycle_prediction_viewed'],
  Family:       ['family_created', 'family_joined', 'family_member_viewed', 'family_invite_sent'],
}

const MAIN_FEATURES = ['Hydration', 'Medication', 'Workout', 'AI', 'Vault', 'Heart Rate']

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const range = searchParams.get('range')
    const days = range ? parseInt(range, 10) : 7

    const since = subDays(new Date(), days).toISOString()
    const prevUntil = since
    const prevSince = subDays(new Date(), days * 2).toISOString()

    // All event names across all feature groups for the daily trends query
    const allFeatureEvents = Object.values(FEATURE_GROUPS).flat()

    const [statsRes, trendsRes, platformRes] = await Promise.all([
      supabase.rpc('analytics_feature_stats', {
        p_since: since,
        p_prev_since: prevSince,
        p_prev_until: prevUntil,
      }),
      // Daily trends: targeted query for main feature events only
      supabase
        .from('app_events')
        .select('created_at, event_name, platform')
        .gte('created_at', since)
        .in('event_name', allFeatureEvents)
        .order('created_at', { ascending: true }),
      // Feature by platform: platform breakdown for feature events
      supabase
        .from('app_events')
        .select('event_name, platform')
        .gte('created_at', since)
        .in('event_name', allFeatureEvents),
    ])

    if (statsRes.error) throw statsRes.error
    if (trendsRes.error) throw trendsRes.error
    if (platformRes.error) throw platformRes.error

    const s = statsRes.data as any

    // Build DeltaMetric objects for main features
    const makeMetric = (cur: number, prev: number) => ({
      value: cur,
      ...computeDelta(cur, prev),
    })

    // Feature totals (all feature groups sorted desc)
    const featureTotals = Object.entries(FEATURE_GROUPS).map(([name, events]) => {
      const fieldName = name.toLowerCase().replace(' ', '_')
      const count = Number(s[fieldName] ?? s[name.toLowerCase()] ?? 0)
      return { name, count }
    }).sort((a, b) => b.count - a.count)

    // Feature trends: daily time series for main features
    const dailyFeatureMap = new Map<string, Map<string, number>>()
    for (const row of (trendsRes.data || []) as { created_at: string; event_name: string }[]) {
      const day = getISTDay(row.created_at)
      const feature = Object.entries(FEATURE_GROUPS).find(([, evts]) => evts.includes(row.event_name))?.[0]
      if (!feature || !MAIN_FEATURES.includes(feature)) continue
      if (!dailyFeatureMap.has(day)) dailyFeatureMap.set(day, new Map())
      const dm = dailyFeatureMap.get(day)!
      dm.set(feature, (dm.get(feature) || 0) + 1)
    }
    const featureTrends = Array.from(dailyFeatureMap.entries())
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([date, dm]) => {
        const entry: any = { date }
        MAIN_FEATURES.forEach(f => { entry[f] = dm.get(f) || 0 })
        return entry
      })

    // Feature by platform
    const fpMap = new Map<string, { iOS: number; Android: number }>()
    for (const row of (platformRes.data || []) as { event_name: string; platform: string | null }[]) {
      const feature = Object.entries(FEATURE_GROUPS).find(([, evts]) => evts.includes(row.event_name))?.[0]
      if (!feature) continue
      if (!fpMap.has(feature)) fpMap.set(feature, { iOS: 0, Android: 0 })
      const c = fpMap.get(feature)!
      if (row.platform === 'ios') c.iOS++
      else if (row.platform === 'android') c.Android++
    }
    const featureByPlatform = Array.from(fpMap.entries()).map(([feature, counts]) => ({
      feature,
      iOS: counts.iOS,
      Android: counts.Android,
    }))

    // AI message trend: use trends data filtered to AI
    const aiDailyMap = new Map<string, number>()
    for (const row of (trendsRes.data || []) as { created_at: string; event_name: string }[]) {
      if (!FEATURE_GROUPS['AI'].includes(row.event_name)) continue
      const day = getISTDay(row.created_at)
      aiDailyMap.set(day, (aiDailyMap.get(day) || 0) + 1)
    }
    const messageTrend = Array.from(aiDailyMap.entries())
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([date, count]) => ({ date, count }))

    return NextResponse.json({
      // Main feature counts with deltas
      hydrationEvents:  makeMetric(Number(s.hydration),   Number(s.prev_hydration)),
      medicationEvents: makeMetric(Number(s.medication),  Number(s.prev_medication)),
      workoutEvents:    makeMetric(Number(s.workout),     Number(s.prev_workout)),
      aiEvents:         makeMetric(Number(s.ai),          Number(s.prev_ai)),
      vaultEvents:      makeMetric(Number(s.vault),       Number(s.prev_vault)),
      heartRateEvents:  makeMetric(Number(s.heart_rate),  Number(s.prev_heart_rate)),

      // Aggregated views
      featureTotals,
      featureTrends,
      featureByPlatform,

      // Feature details
      hydration: {
        avgAmount: Number(s.hydration_avg_amount ?? 0),
        goalCompletionRate: 0, // not tracked in new event inventory
      },
      medication: {
        taken: Number(s.medication_taken ?? 0),
        skipped: Number(s.medication_skipped ?? 0),
        snoozed: 0,
        sourceBreakdown: {},
      },
      workout: {
        activityTypes: {},
        avgDuration: 0,
        completionRate: 0,
      },
      ai: {
        modeDistribution: {},
        messageTrend,
      },
      heartRate: {
        avgBpm: Number(s.heartrate_avg_bpm ?? 0),
        bpmDistribution: [],
      },
    })
  } catch (error: any) {
    console.error('Features API error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch features data' },
      { status: 500 }
    )
  }
}
