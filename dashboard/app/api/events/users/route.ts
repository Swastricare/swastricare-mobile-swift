import { NextRequest, NextResponse } from 'next/server'
import { subDays } from 'date-fns'
import { supabase } from '@/lib/supabase'
import { computeDelta, getISTDay } from '@/lib/event-utils'

export const dynamic = 'force-dynamic'

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const range = parseInt(searchParams.get('range') || '7', 10)
    const since = subDays(new Date(), range).toISOString()
    const prevUntil = since
    const prevSince = subDays(new Date(), range * 2).toISOString()

    const [statsRes, dailyNewVsReturningRes] = await Promise.all([
      supabase.rpc('analytics_user_stats', {
        p_since: since,
        p_prev_since: prevSince,
        p_prev_until: prevUntil,
      }),
      // Daily new-vs-returning: targeted query on user_id + created_at only
      supabase
        .from('app_events')
        .select('user_id, created_at')
        .gte('created_at', since)
        .not('user_id', 'is', null)
        .order('created_at', { ascending: true }),
    ])

    if (statsRes.error) throw statsRes.error
    if (dailyNewVsReturningRes.error) throw dailyNewVsReturningRes.error

    const s = statsRes.data as any
    const rows = (dailyNewVsReturningRes.data || []) as { user_id: string; created_at: string }[]

    const totalUsers = Number(s.total_users)
    const prevTotalUsers = Number(s.prev_total_users)
    const newUsers = Number(s.new_users)
    const returningUsers = totalUsers - newUsers

    // We don't have a prev_new_users from the function — set delta to null
    const avgEventsPerUser = Number(s.avg_events_per_user ?? 0)
    const avgSessionsPerUser = Number(s.avg_sessions_per_user ?? 0)

    // New vs returning per day — derive from the targeted row query
    // First, find the earliest event date for each user across all time
    const userFirstSeen = new Map<string, string>()
    for (const row of rows) {
      const prev = userFirstSeen.get(row.user_id)
      if (!prev || row.created_at < prev) {
        userFirstSeen.set(row.user_id, row.created_at)
      }
    }

    const dailyNewMap = new Map<string, Set<string>>()
    const dailyRetMap = new Map<string, Set<string>>()
    for (const row of rows) {
      const day = getISTDay(row.created_at)
      const firstSeenDay = getISTDay(userFirstSeen.get(row.user_id)!)
      if (!dailyNewMap.has(day)) {
        dailyNewMap.set(day, new Set())
        dailyRetMap.set(day, new Set())
      }
      if (firstSeenDay === day) {
        dailyNewMap.get(day)!.add(row.user_id)
      } else {
        dailyRetMap.get(day)!.add(row.user_id)
      }
    }
    const newVsReturning = Array.from(
      new Set([...Array.from(dailyNewMap.keys()), ...Array.from(dailyRetMap.keys())])
    )
      .sort()
      .map(date => ({
        date,
        new: dailyNewMap.get(date)?.size || 0,
        returning: dailyRetMap.get(date)?.size || 0,
      }))

    // Activity distribution: bucket users by event count (from the rows we already have)
    const userEventCounts = new Map<string, number>()
    for (const row of rows) {
      userEventCounts.set(row.user_id, (userEventCounts.get(row.user_id) || 0) + 1)
    }
    const buckets: Record<string, number> = {
      '1': 0, '2-5': 0, '6-10': 0, '11-25': 0, '26-50': 0, '51-100': 0, '100+': 0,
    }
    userEventCounts.forEach(count => {
      if (count === 1) buckets['1']++
      else if (count <= 5) buckets['2-5']++
      else if (count <= 10) buckets['6-10']++
      else if (count <= 25) buckets['11-25']++
      else if (count <= 50) buckets['26-50']++
      else if (count <= 100) buckets['51-100']++
      else buckets['100+']++
    })
    const activityDistribution = Object.entries(buckets).map(([bucket, count]) => ({ bucket, count }))

    // Top users from SQL
    const topUsers = (s.top_users || []).map((u: any) => ({
      userId: u.user_id,
      events: Number(u.events),
      sessions: Number(u.sessions),
      firstSeen: u.first_seen,
      lastSeen: u.last_seen,
      platform: u.platform,
    }))

    // Daily retention: computed from newVsReturning days
    const allDays = newVsReturning.map(r => r.date)
    const dailyUserSets = new Map<string, Set<string>>()
    for (const row of rows) {
      const day = getISTDay(row.created_at)
      if (!dailyUserSets.has(day)) dailyUserSets.set(day, new Set())
      dailyUserSets.get(day)!.add(row.user_id)
    }
    const dailyRetention: { date: string; rate: number }[] = []
    for (let i = 0; i < allDays.length - 1; i++) {
      const today = allDays[i]
      const tomorrow = allDays[i + 1]
      const todayUsers = dailyUserSets.get(today) || new Set()
      const tomorrowUsers = dailyUserSets.get(tomorrow) || new Set()
      const retained = Array.from(todayUsers).filter(uid => tomorrowUsers.has(uid)).length
      const rate = todayUsers.size > 0
        ? parseFloat(((retained / todayUsers.size) * 100).toFixed(2))
        : 0
      dailyRetention.push({ date: today, rate })
    }

    // Login methods from SQL
    const loginMethods: Record<string, number> = {}
    for (const [k, v] of Object.entries(s.login_methods || {})) {
      loginMethods[k] = Number(v)
    }

    // Login failures and logout: small targeted queries
    const [failuresRes, logoutRes] = await Promise.all([
      supabase
        .from('app_events')
        .select('properties')
        .gte('created_at', since)
        .eq('event_name', 'login_failed'),
      supabase
        .from('app_events')
        .select('*', { count: 'exact', head: true })
        .gte('created_at', since)
        .eq('event_name', 'logout'),
    ])

    const loginFailures: Record<string, number> = {}
    for (const row of (failuresRes.data || []) as { properties: any }[]) {
      const reason = row.properties?.reason || row.properties?.error || 'unknown'
      loginFailures[reason] = (loginFailures[reason] || 0) + 1
    }

    const logoutCount = logoutRes.count ?? 0

    return NextResponse.json({
      totalUsers: { value: totalUsers, ...computeDelta(totalUsers, prevTotalUsers) },
      newUsers: { value: newUsers, delta: null, deltaPercent: null },
      returningUsers: { value: returningUsers, delta: null, deltaPercent: null },
      avgEventsPerUser,
      avgSessionsPerUser,
      newVsReturning,
      activityDistribution,
      topUsers,
      dailyRetention,
      loginMethods,
      loginFailures,
      logoutCount,
    })
  } catch (error: any) {
    console.error('Error fetching users data:', error)
    return NextResponse.json({ error: 'Failed to fetch users data' }, { status: 500 })
  }
}
