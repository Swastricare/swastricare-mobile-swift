import { NextRequest, NextResponse } from 'next/server'
import { subDays } from 'date-fns'
import { supabase } from '@/lib/supabase'
import { computeDelta, buildDailyTimeSeries, getISTDay } from '@/lib/event-utils'
import type { AppEvent } from '@/lib/types'

export const dynamic = 'force-dynamic'

function filterByPlatform<T extends Record<string, unknown>>(rows: T[], plat: string): T[] {
  if (plat === 'all') return rows
  return rows.filter(r => {
    const p = (r.platform ?? (r as any).device_info?.platform ?? '') as string
    return p.toLowerCase() === plat.toLowerCase()
  })
}

const PAGE_SIZE = 25

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const range = parseInt(searchParams.get('range') || '7', 10)
    const page = parseInt(searchParams.get('page') || '1', 10)
    const search = searchParams.get('search') || ''
    const platform = searchParams.get('platform') || 'all'
    const since = subDays(new Date(), range).toISOString()
    const prevUntil = since
    const prevSince = subDays(new Date(), range * 2).toISOString()

    // Run aggregate stats + count of all events in period in parallel
    const [statsRes, totalAllRes] = await Promise.all([
      supabase.rpc('analytics_error_stats', {
        p_since: since,
        p_prev_since: prevSince,
        p_prev_until: prevUntil,
      }),
      // Total event count for error rate calculation
      supabase
        .from('app_events')
        .select('*', { count: 'exact', head: true })
        .gte('created_at', since),
    ])

    if (statsRes.error) throw statsRes.error
    if (totalAllRes.error) throw totalAllRes.error

    const s = statsRes.data as any
    const totalErrors = Number(s.total_errors)
    const prevTotalErrors = Number(s.prev_total_errors)
    const totalAllEvents = totalAllRes.count ?? 0

    const errorRate = totalAllEvents > 0
      ? parseFloat(((totalErrors / totalAllEvents) * 100).toFixed(2))
      : 0

    // Error trend + error rate over time: fetch error events (created_at only for trend)
    const trendRes = await supabase
      .from('app_events')
      .select('created_at')
      .gte('created_at', since)
      .eq('event_type', 'error')
      .order('created_at', { ascending: true })

    if (trendRes.error) throw trendRes.error

    // Build error trend using helper (needs created_at field)
    const errorTrendEvents = (trendRes.data || []) as Pick<AppEvent, 'created_at'>[]
    const errorTrend = buildDailyTimeSeries(errorTrendEvents as AppEvent[])

    // Error rate over time: need total events per day
    const allEventsForRateRes = await supabase
      .from('app_events')
      .select('created_at, event_type')
      .gte('created_at', since)
      .order('created_at', { ascending: true })

    if (allEventsForRateRes.error) throw allEventsForRateRes.error

    const dailyErrorCounts = new Map<string, number>()
    const dailyTotalCounts = new Map<string, number>()
    for (const e of (trendRes.data || [])) {
      const day = getISTDay((e as any).created_at)
      dailyErrorCounts.set(day, (dailyErrorCounts.get(day) || 0) + 1)
    }
    for (const e of (allEventsForRateRes.data || [])) {
      const day = getISTDay((e as any).created_at)
      dailyTotalCounts.set(day, (dailyTotalCounts.get(day) || 0) + 1)
    }
    const allDays = Array.from(
      new Set([
        ...Array.from(dailyErrorCounts.keys()),
        ...Array.from(dailyTotalCounts.keys()),
      ])
    ).sort()
    const errorRateOverTime = allDays.map(date => {
      const dayErrors = dailyErrorCounts.get(date) || 0
      const dayTotal = dailyTotalCounts.get(date) || 0
      return {
        date,
        rate: dayTotal > 0 ? parseFloat(((dayErrors / dayTotal) * 100).toFixed(2)) : 0,
      }
    })

    // Error log: paginated direct query (supports search)
    let logQuery = supabase
      .from('app_events')
      .select('event_name, properties, created_at, user_id, platform', { count: 'exact' })
      .gte('created_at', since)
      .eq('event_type', 'error')
      .order('created_at', { ascending: false })

    // Apply search filter in SQL when no wildcards needed
    if (search) {
      logQuery = logQuery.or(
        `event_name.ilike.%${search}%,properties->>message.ilike.%${search}%`
      )
    }

    // Get total count first, then paginate
    const logCountRes = await logQuery.range(0, 0)
    const errorLogFiltered = logCountRes.count ?? 0
    const totalPages = Math.ceil(errorLogFiltered / PAGE_SIZE)

    const offset = (page - 1) * PAGE_SIZE
    const logPageRes = await supabase
      .from('app_events')
      .select('event_name, properties, created_at, user_id, platform')
      .gte('created_at', since)
      .eq('event_type', 'error')
      .order('created_at', { ascending: false })
      .range(offset, offset + PAGE_SIZE - 1)

    if (logPageRes.error) throw logPageRes.error

    // Apply JS-side search filter for user_id matches (not possible in simple .or)
    let errorLog = (logPageRes.data || []).map((e: any) => ({
      name: e.event_name,
      message: e.properties?.message || e.properties?.error || e.properties?.description || 'No message',
      properties: e.properties,
      created_at: e.created_at,
      user_id: e.user_id,
      platform: e.platform === 'ios' ? 'iOS' : e.platform === 'android' ? 'Android' : 'Unknown',
    }))

    if (search) {
      const searchLower = search.toLowerCase()
      errorLog = errorLog.filter(e =>
        e.name.toLowerCase().includes(searchLower) ||
        e.message.toLowerCase().includes(searchLower) ||
        (e.user_id && e.user_id.toLowerCase().includes(searchLower))
      )
    }

    errorLog = filterByPlatform(errorLog as Record<string, unknown>[], platform) as typeof errorLog

    // errorsByCategory/Platform from SQL (keys may be lowercase platform names)
    const rawByPlatform: Record<string, number> = s.errors_by_platform || {}
    const errorsByPlatform: Record<string, number> = {}
    for (const [k, v] of Object.entries(rawByPlatform)) {
      const display = k === 'ios' ? 'iOS' : k === 'android' ? 'Android' : k
      errorsByPlatform[display] = Number(v)
    }

    return NextResponse.json({
      totalErrors: {
        value: totalErrors,
        ...computeDelta(totalErrors, prevTotalErrors),
      },
      uniqueErrorTypes: Number(s.unique_error_types),
      errorRate,
      usersAffected: Number(s.users_affected),
      errorTrend,
      errorRateOverTime,
      errorsByCategory: s.errors_by_category || {},
      errorsByPlatform,
      topErrorMessages: (s.top_error_messages || []).map((r: any) => ({
        message: r.message,
        count: Number(r.count),
        lastSeen: r.last_seen,
      })),
      errorLog,
      errorLogTotal: totalErrors,
      errorLogFiltered,
      currentPage: page,
      totalPages,
    })
  } catch (error: any) {
    console.error('Error fetching errors data:', error)
    return NextResponse.json({ error: 'Failed to fetch errors data' }, { status: 500 })
  }
}
