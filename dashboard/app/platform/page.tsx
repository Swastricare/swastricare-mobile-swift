'use client'

import { useEffect, useState, useCallback } from 'react'
import dynamic from 'next/dynamic'
import { useDashboard } from '@/components/providers/DashboardProvider'
import TopBar from '@/components/layout/TopBar'
import LoadingSkeleton from '@/components/LoadingSkeleton'
import ComparisonMetricCard from '@/components/ComparisonMetricCard'
import ChartCard from '@/components/ChartCard'
import RankedList from '@/components/tables/RankedList'
import { PLATFORM_COLORS } from '@/lib/constants'
import type { PlatformData } from '@/lib/types'

const AreaTimeChart = dynamic(() => import('@/components/charts/AreaTimeChart'), { ssr: false })
const GroupedBarChart = dynamic(() => import('@/components/charts/GroupedBarChart'), { ssr: false })
const HorizontalBarChart = dynamic(() => import('@/components/charts/HorizontalBarChart'), { ssr: false })

export default function PlatformPage() {
  const { range, refreshKey, platform } = useDashboard()
  const [data, setData] = useState<PlatformData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchData = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const res = await fetch(`/api/events/platform?range=${range}&platform=${platform}`)
      if (!res.ok) throw new Error('Failed to fetch platform data')
      setData(await res.json())
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [range, refreshKey, platform])

  useEffect(() => { fetchData() }, [fetchData])

  if (loading && !data) return <LoadingSkeleton />
  if (error) return <div className="rounded-xl border border-red-500/30 bg-red-500/10 p-4 text-sm text-red-400">{error}</div>
  if (!data) return null

  return (
    <>
      <TopBar title="Platform" description="iOS vs Android comparison" />

      <div className="p-6 md:p-8">
      <div className="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <ComparisonMetricCard title="Events" iosValue={data.eventsIOS} androidValue={data.eventsAndroid} />
        <ComparisonMetricCard title="Users" iosValue={data.usersIOS} androidValue={data.usersAndroid} />
        <ComparisonMetricCard title="Sessions" iosValue={data.sessionsIOS} androidValue={data.sessionsAndroid} />
        <ComparisonMetricCard title="Avg Events/User" iosValue={Math.round(data.avgEventsPerUserIOS * 10) / 10} androidValue={Math.round(data.avgEventsPerUserAndroid * 10) / 10} />
      </div>

      <div className="mb-6 grid gap-6 lg:grid-cols-2">
        <ChartCard title="Events Over Time by Platform">
          <AreaTimeChart data={data.eventsOverTime} series={[{ key: 'iOS', color: PLATFORM_COLORS.iOS, name: 'iOS' }, { key: 'Android', color: PLATFORM_COLORS.Android, name: 'Android' }]} stacked />
        </ChartCard>
        <ChartCard title="Users Over Time by Platform">
          <AreaTimeChart data={data.usersOverTime} series={[{ key: 'iOS', color: PLATFORM_COLORS.iOS, name: 'iOS' }, { key: 'Android', color: PLATFORM_COLORS.Android, name: 'Android' }]} stacked />
        </ChartCard>
      </div>

      <div className="mb-6 grid gap-6 lg:grid-cols-2">
        <ChartCard title="Event Type by Platform">
          <GroupedBarChart data={data.eventTypeByPlatform} categoryKey="type" series={[{ key: 'iOS', color: PLATFORM_COLORS.iOS, name: 'iOS' }, { key: 'Android', color: PLATFORM_COLORS.Android, name: 'Android' }]} />
        </ChartCard>
        <ChartCard title="App Version Distribution">
          <HorizontalBarChart data={data.appVersions.map(v => ({ name: v.name, value: v.count }))} />
        </ChartCard>
      </div>

      <div className="mb-6">
        <ChartCard title="Device Models (Top 15)">
          <HorizontalBarChart data={data.deviceModels.map(d => ({ name: d.name, value: d.count }))} />
        </ChartCard>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <RankedList data={data.topEventsIOS} title="Top Events — iOS" barColor="bg-blue-500/60" />
        <RankedList data={data.topEventsAndroid} title="Top Events — Android" barColor="bg-green-500/60" />
      </div>
      </div>
    </>
  )
}
