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

    const [statsRes, eventsOverTimeRes, usersOverTimeRes] = await Promise.all([
      supabase.rpc('analytics_platform_stats', {
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

    const eventsIOS = Number(s.events_ios)
    const eventsAndroid = Number(s.events_android)
    const usersIOS = Number(s.users_ios)
    const usersAndroid = Number(s.users_android)

    const avgEventsPerUserIOS = usersIOS > 0 ? Math.round((eventsIOS / usersIOS) * 10) / 10 : 0
    const avgEventsPerUserAndroid = usersAndroid > 0 ? Math.round((eventsAndroid / usersAndroid) * 10) / 10 : 0

    const appVersions = (s.app_versions || []).map((r: any) => ({
      name: r.name,
      count: Number(r.count),
    }))

    const deviceModels = (s.device_models || []).map((r: any) => ({
      name: r.name,
      count: Number(r.count),
    }))

    const topEventsIOS = (s.top_events_ios || []).map((r: any) => ({
      name: r.name,
      count: Number(r.count),
    }))

    const topEventsAndroid = (s.top_events_android || []).map((r: any) => ({
      name: r.name,
      count: Number(r.count),
    }))

    const eventTypeByPlatform = (s.event_type_by_platform || []).map((r: any) => ({
      type: r.type,
      iOS: Number(r.ios),
      Android: Number(r.android),
    }))

    return NextResponse.json({
      eventsIOS,
      eventsAndroid,
      usersIOS,
      usersAndroid,
      sessionsIOS: Number(s.sessions_ios),
      sessionsAndroid: Number(s.sessions_android),
      avgEventsPerUserIOS,
      avgEventsPerUserAndroid,
      eventsOverTime,
      usersOverTime,
      eventTypeByPlatform,
      appVersions,
      deviceModels,
      topEventsIOS,
      topEventsAndroid,
    })
  } catch (error: any) {
    console.error('Platform API error:', error)
    return NextResponse.json(
      { error: 'Failed to fetch platform data' },
      { status: 500 }
    )
  }
}
