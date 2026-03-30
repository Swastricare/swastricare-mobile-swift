'use client'

import { useEffect, useState, useCallback } from 'react'
import dynamic from 'next/dynamic'
import { useDashboard } from '@/components/providers/DashboardProvider'
import TopBar from '@/components/layout/TopBar'
import LoadingSkeleton from '@/components/LoadingSkeleton'
import MetricCard from '@/components/MetricCard'
import ChartCard from '@/components/ChartCard'
import RankedList from '@/components/tables/RankedList'
import type { EngagementData } from '@/lib/types'

const HeatmapChart = dynamic(() => import('@/components/charts/HeatmapChart'), { ssr: false })
const HistogramChart = dynamic(() => import('@/components/charts/HistogramChart'), { ssr: false })
const AreaTimeChart = dynamic(() => import('@/components/charts/AreaTimeChart'), { ssr: false })

function formatDuration(seconds: number): string {
  if (seconds < 60) return `${Math.round(seconds)}s`
  if (seconds < 3600) {
    const m = Math.floor(seconds / 60)
    const s = Math.round(seconds % 60)
    return `${m}m ${s}s`
  }
  const h = Math.floor(seconds / 3600)
  const m = Math.round((seconds % 3600) / 60)
  return `${h}h ${m}m`
}

export default function EngagementPage() {
  const { range, refreshKey } = useDashboard()
  const [data, setData] = useState<EngagementData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchData = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const res = await fetch(`/api/events/engagement?range=${range}`)
      if (!res.ok) throw new Error('Failed to fetch engagement data')
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
      <TopBar title="Engagement" description="Session behavior, timing patterns, and usage depth" />

      <div className="p-6 md:p-8">
      <div className="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <MetricCard title="Avg Session Duration" value={formatDuration(data.avgSessionDuration)} color="#3B82F6" />
        <MetricCard title="Avg Events/Session" value={data.avgEventsPerSession.toFixed(1)} color="#22C55E" />
        <MetricCard title="Peak Hour" value={`${String(data.peakHour).padStart(2, '0')}:00 IST`} color="#F59E0B" />
        <MetricCard title="Peak Day" value={data.peakDay} color="#8B5CF6" />
      </div>

      <div className="mb-6">
        <ChartCard title="Activity Heatmap (IST)" className="h-auto">
          <HeatmapChart data={data.heatmap} />
        </ChartCard>
      </div>

      <div className="mb-6 grid gap-6 lg:grid-cols-2">
        <ChartCard title="Events by Hour">
          <HistogramChart data={data.eventsByHour.map(h => ({ bucket: `${h.hour}:00`, count: h.count }))} color="#3B82F6" xLabel="Hour (IST)" />
        </ChartCard>
        <ChartCard title="Events by Day">
          <HistogramChart data={data.eventsByDay.map(d => ({ bucket: d.day, count: d.count }))} color="#8B5CF6" />
        </ChartCard>
      </div>

      <div className="mb-6 grid gap-6 lg:grid-cols-2">
        <ChartCard title="Session Duration Distribution">
          <HistogramChart data={data.sessionDurationDist} color="#22C55E" />
        </ChartCard>
        <ChartCard title="Events per Session Distribution">
          <HistogramChart data={data.eventsPerSessionDist} color="#F59E0B" />
        </ChartCard>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <RankedList data={data.tabNavigation} title="Tab Navigation Frequency" />
        <ChartCard title="App Opens Over Time">
          <AreaTimeChart data={data.appOpensOverTime} series={[{ key: 'count', color: '#06B6D4' }]} />
        </ChartCard>
      </div>
      </div>
    </>
  )
}
