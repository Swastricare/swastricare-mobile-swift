import { NextRequest, NextResponse } from 'next/server'
import { subDays } from 'date-fns'
import { supabase } from '@/lib/supabase'
import { computeDelta } from '@/lib/event-utils'

export const dynamic = 'force-dynamic'

export async function GET(req: NextRequest) {
  const range = req.nextUrl.searchParams.get('range') || '7'
  const days = parseInt(range, 10)
  const since = subDays(new Date(), days).toISOString()
  const prevUntil = since
  const prevSince = subDays(new Date(), days * 2).toISOString()

  try {
    const [statsRes, eventsOverTimeRes, usersOverTimeRes] = await Promise.all([
      supabase.rpc('analytics_overview_stats', {
        p_since: since,
        p_prev_since: prevSince,
        p_prev_until: prevUntil,
      }),
      supabase.rpc('analytics_daily_platform_events', { p_since: since }),
      supabase.rpc('analytics_daily_platform_users', { p_since: since }),
    ])

    if (statsRes.error) throw statsRes.error
    if (eventsOverTimeRes.error) throw eventsOverTimeRes.error
    if (usersOverTimeRes.error) throw usersOverTimeRes.error

    const s = statsRes.data as any

    // Map TABLE rows → StackedTimeSeriesPoint (SQL returns lowercase ios/android)
    const eventsOverTime = (eventsOverTimeRes.data as any[]).map((r: any) => ({
      date: r.day,
      iOS: Number(r.ios),
      Android: Number(r.android),
      Unknown: Number(r.unknown),
    }))

    const usersOverTime = (usersOverTimeRes.data as any[]).map((r: any) => ({
      date: r.day,
      iOS: Number(r.ios),
      Android: Number(r.android),
      Unknown: Number(r.unknown),
    }))

    const eventsSpark = eventsOverTime.map(p => (p.iOS || 0) + (p.Android || 0))
    const usersSpark = usersOverTime.map(p => (p.iOS || 0) + (p.Android || 0))

    const totalEvents = Number(s.total_events)
    const prevTotalEvents = Number(s.prev_total_events)
    const users = Number(s.unique_users)
    const prevUsers = Number(s.prev_unique_users)
    const sessions = Number(s.unique_sessions)
    const prevSessions = Number(s.prev_unique_sessions)

    // Normalize platform_counts keys (sql returns 'ios'/'android'/'Unknown')
    const rawPlatform: Record<string, number> = s.platform_counts || {}
    const platformCounts: Record<string, number> = {}
    for (const [k, v] of Object.entries(rawPlatform)) {
      const display = k === 'ios' ? 'iOS' : k === 'android' ? 'Android' : k
      platformCounts[display] = Number(v)
    }

    return NextResponse.json({
      totalEvents: { value: totalEvents, ...computeDelta(totalEvents, prevTotalEvents) },
      uniqueUsers: { value: users, ...computeDelta(users, prevUsers) },
      dau: { value: Number(s.dau), delta: null, deltaPercent: null },
      wau: { value: Number(s.wau), delta: null, deltaPercent: null },
      mau: { value: Number(s.mau), delta: null, deltaPercent: null },
      sessions: { value: sessions, ...computeDelta(sessions, prevSessions) },
      eventsOverTime,
      usersOverTime,
      eventsByType: s.events_by_type || {},
      platformCounts,
      topEvents: (s.top_events || []).map((e: any) => ({ name: e.name, count: Number(e.count) })),
      topScreens: (s.top_screens || []).map((e: any) => ({ name: e.name, count: Number(e.count) })),
      sparklines: { events: eventsSpark, users: usersSpark },
    })
  } catch (err: any) {
    return NextResponse.json({ error: err.message }, { status: 500 })
  }
}
