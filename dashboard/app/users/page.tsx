'use client'

import { useEffect, useState, useCallback } from 'react'
import dynamic from 'next/dynamic'
import { format, parseISO } from 'date-fns'
import { useDashboard } from '@/components/providers/DashboardProvider'
import TopBar from '@/components/layout/TopBar'
import LoadingSkeleton from '@/components/LoadingSkeleton'
import MetricCard from '@/components/MetricCard'
import ChartCard from '@/components/ChartCard'
import DataTable from '@/components/tables/DataTable'
import PlatformBadge from '@/components/PlatformBadge'
import type { UsersData } from '@/lib/types'

const AreaTimeChart = dynamic(() => import('@/components/charts/AreaTimeChart'), { ssr: false })
const HistogramChart = dynamic(() => import('@/components/charts/HistogramChart'), { ssr: false })
const DonutChart = dynamic(() => import('@/components/charts/DonutChart'), { ssr: false })

export default function UsersPage() {
  const { range, refreshKey } = useDashboard()
  const [data, setData] = useState<UsersData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchData = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const res = await fetch(`/api/events/users?range=${range}`)
      if (!res.ok) throw new Error('Failed to fetch users data')
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
      <TopBar title="Users" description="User acquisition, retention, and behavior" />

      <div className="p-6 md:p-8">
      <div className="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-5">
        <MetricCard title="Total Users" value={data.totalUsers.value} deltaPercent={data.totalUsers.deltaPercent} />
        <MetricCard title="New Users" value={data.newUsers.value} deltaPercent={data.newUsers.deltaPercent} color="#22C55E" />
        <MetricCard title="Returning Users" value={data.returningUsers.value} deltaPercent={data.returningUsers.deltaPercent} color="#3B82F6" />
        <MetricCard title="Avg Events/User" value={data.avgEventsPerUser} color="#8B5CF6" />
        <MetricCard title="Avg Sessions/User" value={data.avgSessionsPerUser} color="#F59E0B" />
      </div>

      <div className="mb-6 grid gap-6 lg:grid-cols-2">
        <ChartCard title="New vs Returning Over Time">
          <AreaTimeChart data={data.newVsReturning} series={[{ key: 'new', color: '#22C55E', name: 'New' }, { key: 'returning', color: '#3B82F6', name: 'Returning' }]} stacked />
        </ChartCard>
        <ChartCard title="Activity Distribution">
          <HistogramChart data={data.activityDistribution} color="#8B5CF6" />
        </ChartCard>
      </div>

      <div className="mb-6">
        <DataTable
          columns={[
            { key: 'userId', label: 'User', sortable: true, render: (val: string) => <span className="font-mono text-xs">{val.slice(0, 12)}</span> },
            { key: 'events', label: 'Events', sortable: true },
            { key: 'sessions', label: 'Sessions', sortable: true },
            { key: 'platform', label: 'Platform', render: (val: string) => <PlatformBadge platform={val} /> },
            { key: 'firstSeen', label: 'First Seen', sortable: true, render: (val: string) => <span className="text-neutral-400 text-xs">{format(parseISO(val), 'MMM d')}</span> },
            { key: 'lastSeen', label: 'Last Seen', sortable: true, render: (val: string) => <span className="text-neutral-400 text-xs">{format(parseISO(val), 'MMM d')}</span> },
          ]}
          data={data.topUsers}
          defaultSort={{ key: 'events', dir: 'desc' }}
        />
      </div>

      <div className="mb-6">
        <ChartCard title="Daily Retention">
          <AreaTimeChart data={data.dailyRetention} series={[{ key: 'rate', color: '#F59E0B', name: 'Retention %' }]} />
        </ChartCard>
      </div>

      <h3 className="mb-4 text-lg font-semibold text-white">Authentication</h3>
      <div className="grid gap-6 md:grid-cols-3">
        <ChartCard title="Login Methods">
          <DonutChart data={Object.entries(data.loginMethods).map(([name, value]) => ({ name, value }))} />
        </ChartCard>
        <ChartCard title="Login Failures">
          <DonutChart data={Object.entries(data.loginFailures).map(([name, value]) => ({ name, value }))} />
        </ChartCard>
        <MetricCard title="Logout Count" value={data.logoutCount} color="#EF4444" />
      </div>
      </div>
    </>
  )
}
