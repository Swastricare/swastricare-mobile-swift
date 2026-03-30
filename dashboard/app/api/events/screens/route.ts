import { NextRequest, NextResponse } from 'next/server'
import { subDays } from 'date-fns'
import { supabase } from '@/lib/supabase'
import { computeDelta } from '@/lib/event-utils'

export const dynamic = 'force-dynamic'

function filterByPlatform<T extends Record<string, unknown>>(rows: T[], plat: string): T[] {
  if (plat === 'all') return rows
  return rows.filter(r => {
    const p = (r.platform ?? (r as any).device_info?.platform ?? '') as string
    return p.toLowerCase() === plat.toLowerCase()
  })
}

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams
    const range = searchParams.get('range')
    const days = range ? parseInt(range, 10) : 7
    const platform = searchParams.get('platform') || 'all'

    const since = subDays(new Date(), days).toISOString()
    const prevUntil = since
    const prevSince = subDays(new Date(), days * 2).toISOString()

    const [statsRes, dailyRes, transitionsRes] = await Promise.all([
      supabase.rpc('analytics_screen_stats', {
        p_since: since,
        p_prev_since: prevSince,
        p_prev_until: prevUntil,
      }),
      supabase.rpc('analytics_daily_screen_counts', { p_since: since }),
      supabase.rpc('analytics_screen_transitions', { p_since: since }),
    ])

    if (statsRes.error) throw statsRes.error
    if (dailyRes.error) throw dailyRes.error
    if (transitionsRes.error) throw transitionsRes.error

    const s = statsRes.data as any
    const dailyRows: { day: string; screen: string; cnt: number }[] = dailyRes.data || []
    const transitionRows: { from_screen: string; to_screen: string; cnt: number }[] = transitionsRes.data || []

    const totalScreenViews = Number(s.total_screen_views)
    const prevTotalScreenViews = Number(s.prev_total_screen_views)
    const uniqueScreens = Number(s.unique_screens)

    const screenRankings = (s.screen_rankings || []).map((r: any) => ({
      name: r.name,
      count: Number(r.count),
    }))

    // Build top-5-screens-over-time from daily counts
    const top5Screens = screenRankings.slice(0, 5).map((r: any) => r.name as string)
    const dayMap = new Map<string, Map<string, number>>()
    for (const row of dailyRows) {
      if (!top5Screens.includes(row.screen)) continue
      if (!dayMap.has(row.day)) dayMap.set(row.day, new Map())
      dayMap.get(row.day)!.set(row.screen, Number(row.cnt))
    }
    const topScreensOverTime = Array.from(dayMap.entries())
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([date, screenMap]) => {
        const entry: any = { date }
        top5Screens.forEach((screen: string) => { entry[screen] = screenMap.get(screen) || 0 })
        return entry
      })

    // Dwell times — comes from SQL using actual duration_seconds
    const dwellTimes = (s.dwell_times || []).map((r: any) => ({
      screen: r.screen,
      avgSeconds: Number(r.avg_seconds),
      views: Number(r.views),
    }))

    // Screens by platform — normalise ios/android keys to iOS/Android
    const screensByPlatform = (s.screens_by_platform || []).map((r: any) => ({
      screen: r.screen,
      iOS: Number(r.ios),
      Android: Number(r.android),
    }))

    // Transitions
    const transitions = transitionRows.map(r => ({
      from: r.from_screen,
      to: r.to_screen,
      count: Number(r.cnt),
    }))

    // avgViewsPerUserPerDay: kept for frontend compatibility (compute from available totals)
    // We don't have daily-unique-users here, so return 0 as a safe default
    const avgViewsPerUserPerDay = 0

    return NextResponse.json({
      totalScreenViews: {
        value: totalScreenViews,
        ...computeDelta(totalScreenViews, prevTotalScreenViews),
      },
      uniqueScreens,
      avgViewsPerUserPerDay,
      screenRankings,
      topScreensOverTime,
      screensByPlatform,
      dwellTimes,
      transitions,
    })
  } catch (error: any) {
    console.error('Screens API error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch screens data' },
      { status: 500 }
    )
  }
}
