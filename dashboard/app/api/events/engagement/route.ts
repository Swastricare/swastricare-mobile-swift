import { NextRequest, NextResponse } from 'next/server'
import { subDays } from 'date-fns'
import { supabase } from '@/lib/supabase'

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
    const { searchParams } = new URL(request.url)
    const range = parseInt(searchParams.get('range') || '7', 10)
    const platform = searchParams.get('platform') || 'all'
    const since = subDays(new Date(), range).toISOString()

    const [engagementRes, tabRes, appOpenRes] = await Promise.all([
      supabase.rpc('analytics_engagement_stats', { p_since: since }),
      supabase.rpc('analytics_tab_navigation', { p_since: since }),
      // App opens over time: direct targeted query (small result set)
      supabase
        .from('app_events')
        .select('created_at')
        .gte('created_at', since)
        .in('event_name', ['app_open', 'app_opened'])
        .order('created_at', { ascending: true }),
    ])

    if (engagementRes.error) throw engagementRes.error
    if (tabRes.error) throw tabRes.error
    if (appOpenRes.error) throw appOpenRes.error

    const s = engagementRes.data as any

    // Tab navigation
    const tabNavigation = (tabRes.data || []).map((r: any) => ({
      name: r.name,
      count: Number(r.count),
    }))

    // App opens over time — group by IST day
    const appOpensByDay = new Map<string, number>()
    for (const row of (appOpenRes.data || []) as { created_at: string }[]) {
      const dt = new Date(row.created_at)
      // Convert to IST for day label
      const istMs = dt.getTime() + (5.5 * 60 * 60 * 1000)
      const istDate = new Date(istMs)
      const day = istDate.toISOString().slice(0, 10)
      appOpensByDay.set(day, (appOpensByDay.get(day) || 0) + 1)
    }
    const appOpensOverTime = Array.from(appOpensByDay.entries())
      .sort((a, b) => a[0].localeCompare(b[0]))
      .map(([date, count]) => ({ date, count }))

    // Normalise peak_day (Postgres TO_CHAR pads with trailing spaces)
    const rawPeakDay = (s.peak_day || 'Sunday') as string
    const peakDay = rawPeakDay.trim()

    // events_by_day: SQL returns array of {day, count} with padded day names — trim them
    const eventsByDay = (s.events_by_day || []).map((r: any) => ({
      day: String(r.day).trim(),
      count: Number(r.count),
    }))

    return NextResponse.json({
      avgSessionDuration: Number(s.avg_session_duration ?? 0),
      avgEventsPerSession: Number(s.avg_events_per_session ?? 0),
      peakHour: Number(s.peak_hour ?? 0),
      peakDay,
      heatmap: (s.heatmap || []).map((r: any) => ({
        day: Number(r.day),
        hour: Number(r.hour),
        count: Number(r.count),
      })),
      eventsByHour: (s.events_by_hour || []).map((r: any) => ({
        hour: Number(r.hour),
        count: Number(r.count),
      })),
      eventsByDay,
      sessionDurationDist: (s.session_duration_dist || []).map((r: any) => ({
        bucket: r.bucket,
        count: Number(r.count),
      })),
      eventsPerSessionDist: (s.events_per_session_dist || []).map((r: any) => ({
        bucket: r.bucket,
        count: Number(r.count),
      })),
      tabNavigation,
      appOpensOverTime,
    })
  } catch (error: any) {
    console.error('Error fetching engagement data:', error)
    return NextResponse.json({ error: 'Failed to fetch engagement data' }, { status: 500 })
  }
}
