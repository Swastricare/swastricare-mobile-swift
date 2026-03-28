'use client'

import { useEffect, useState, useCallback } from 'react'
import dynamic from 'next/dynamic'
import { useDashboard } from '@/components/providers/DashboardProvider'
import PageHeader from '@/components/layout/PageHeader'
import LoadingSkeleton from '@/components/LoadingSkeleton'
import MetricCard from '@/components/MetricCard'
import ChartCard from '@/components/ChartCard'
import DataTable from '@/components/tables/DataTable'
import { PALETTE, PLATFORM_COLORS } from '@/lib/constants'
import type { ScreensData } from '@/lib/types'

const HorizontalBarChart = dynamic(() => import('@/components/charts/HorizontalBarChart'), { ssr: false })
const DualLineChart = dynamic(() => import('@/components/charts/DualLineChart'), { ssr: false })
const GroupedBarChart = dynamic(() => import('@/components/charts/GroupedBarChart'), { ssr: false })

export default function ScreensPage() {
  const { range, refreshKey } = useDashboard()
  const [data, setData] = useState<ScreensData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchData = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const res = await fetch(`/api/events/screens?range=${range}`)
      if (!res.ok) throw new Error('Failed to fetch screens data')
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

  const topScreenSeries = data.topScreensOverTime.length > 0
    ? Object.keys(data.topScreensOverTime[0]).filter(k => k !== 'date').slice(0, 5).map((name, i) => ({
        key: name, color: PALETTE[i % PALETTE.length], name,
      }))
    : []

  return (
    <>
      <PageHeader title="Screens" description="Screen views, navigation flow, and dwell times" />

      <div className="mb-6 grid grid-cols-1 gap-4 md:grid-cols-3">
        <MetricCard title="Total Screen Views" value={data.totalScreenViews.value} deltaPercent={data.totalScreenViews.deltaPercent} />
        <MetricCard title="Unique Screens" value={data.uniqueScreens} color="#22C55E" />
        <MetricCard title="Avg Views/User/Day" value={data.avgViewsPerUserPerDay} color="#3B82F6" />
      </div>

      <div className="mb-6 grid gap-6 lg:grid-cols-2">
        <ChartCard title="Screen Rankings">
          <HorizontalBarChart data={data.screenRankings.map(s => ({ name: s.name, value: s.count }))} />
        </ChartCard>
        <ChartCard title="Top 5 Screens Over Time">
          <DualLineChart data={data.topScreensOverTime} series={topScreenSeries} />
        </ChartCard>
      </div>

      <div className="mb-6">
        <ChartCard title="Screens by Platform">
          <GroupedBarChart data={data.screensByPlatform} categoryKey="screen" series={[{ key: 'iOS', color: PLATFORM_COLORS.iOS, name: 'iOS' }, { key: 'Android', color: PLATFORM_COLORS.Android, name: 'Android' }]} />
        </ChartCard>
      </div>

      <div className="mb-6">
        <DataTable
          columns={[
            { key: 'screen', label: 'Screen', sortable: true },
            { key: 'avgSeconds', label: 'Avg Duration', sortable: true, render: (val: number) => `${val}s` },
            { key: 'views', label: 'Views', sortable: true },
          ]}
          data={data.dwellTimes}
          defaultSort={{ key: 'avgSeconds', dir: 'desc' }}
        />
      </div>

      <DataTable
        columns={[
          { key: 'from', label: 'From', sortable: true },
          { key: 'to', label: 'To', sortable: true },
          { key: 'count', label: 'Count', sortable: true },
        ]}
        data={data.transitions}
        defaultSort={{ key: 'count', dir: 'desc' }}
      />
    </>
  )
}
