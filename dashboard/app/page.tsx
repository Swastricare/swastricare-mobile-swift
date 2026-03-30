'use client'

import { useEffect, useState, useCallback } from 'react'
import dynamic from 'next/dynamic'
import { useDashboard } from '@/components/providers/DashboardProvider'
import TopBar from '@/components/layout/TopBar'
import MetricCard from '@/components/MetricCard'
import ChartCard from '@/components/ChartCard'
import LoadingSkeleton from '@/components/LoadingSkeleton'
import RankedList from '@/components/tables/RankedList'
import { PLATFORM_COLORS, EVENT_TYPE_COLORS } from '@/lib/constants'
import type { OverviewData } from '@/lib/types'

const AreaTimeChart = dynamic(() => import('@/components/charts/AreaTimeChart'), { ssr: false })
const HorizontalBarChart = dynamic(() => import('@/components/charts/HorizontalBarChart'), { ssr: false })
const DonutChart = dynamic(() => import('@/components/charts/DonutChart'), { ssr: false })

export default function OverviewPage() {
  const { range, refreshKey } = useDashboard()
  const [data, setData] = useState<OverviewData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchData = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const res = await fetch(`/api/events?range=${range}`)
      if (!res.ok) throw new Error((await res.json()).error || 'Failed to fetch')
      setData(await res.json())
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [range, refreshKey])

  useEffect(() => { fetchData() }, [fetchData])

  if (loading && !data) return <LoadingSkeleton />
  if (error) return <div className="rounded-xl border border-red-500/30 bg-red-500/10 p-4 text-sm text-red-400">{error}</div>
  if (!data) return null

  return (
    <>
      <TopBar title="Overview" description="App-wide metrics and trends" />

      <div className="p-6 md:p-8">
      <div className="mb-6 grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-6">
        <MetricCard title="Total Events" value={data.totalEvents.value} deltaPercent={data.totalEvents.deltaPercent} subtitle={`Last ${range === '1' ? '24h' : range + 'd'}`} />
        <MetricCard title="Unique Users" value={data.uniqueUsers.value} deltaPercent={data.uniqueUsers.deltaPercent} color="#22C55E" />
        <MetricCard title="DAU" value={data.dau.value} color="#3B82F6" />
        <MetricCard title="WAU" value={data.wau.value} color="#8B5CF6" />
        <MetricCard title="MAU" value={data.mau.value} color="#A855F7" />
        <MetricCard title="Sessions" value={data.sessions.value} deltaPercent={data.sessions.deltaPercent} color="#F59E0B" />
      </div>

      <div className="mb-6 grid gap-6 lg:grid-cols-2">
        <ChartCard title="Events Over Time">
          <AreaTimeChart data={data.eventsOverTime} series={[{ key: 'iOS', color: PLATFORM_COLORS.iOS, name: 'iOS' }, { key: 'Android', color: PLATFORM_COLORS.Android, name: 'Android' }]} stacked />
        </ChartCard>
        <ChartCard title="Users Over Time">
          <AreaTimeChart data={data.usersOverTime} series={[{ key: 'iOS', color: PLATFORM_COLORS.iOS, name: 'iOS' }, { key: 'Android', color: PLATFORM_COLORS.Android, name: 'Android' }]} stacked />
        </ChartCard>
      </div>

      <div className="mb-6 grid gap-6 lg:grid-cols-2">
        <ChartCard title="Events by Type">
          <HorizontalBarChart data={Object.entries(data.eventsByType).map(([name, value]) => ({ name, value, color: EVENT_TYPE_COLORS[name] || '#6B7280' })).sort((a, b) => b.value - a.value)} />
        </ChartCard>
        <ChartCard title="Platform Split">
          <DonutChart data={Object.entries(data.platformCounts).map(([name, value]) => ({ name, value })).sort((a, b) => b.value - a.value)} />
        </ChartCard>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <RankedList data={data.topEvents} title="Top Events" />
        <RankedList data={data.topScreens} title="Top Screens" />
      </div>
      </div>
    </>
  )
}
