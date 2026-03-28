'use client'

import { useEffect, useState, useCallback } from 'react'
import dynamic from 'next/dynamic'
import { format, parseISO } from 'date-fns'
import { useDashboard } from '@/components/providers/DashboardProvider'
import PageHeader from '@/components/layout/PageHeader'
import LoadingSkeleton from '@/components/LoadingSkeleton'
import MetricCard from '@/components/MetricCard'
import ChartCard from '@/components/ChartCard'
import DataTable from '@/components/tables/DataTable'
import PlatformBadge from '@/components/PlatformBadge'
import type { ErrorsData } from '@/lib/types'

const AreaTimeChart = dynamic(() => import('@/components/charts/AreaTimeChart'), { ssr: false })
const DualLineChart = dynamic(() => import('@/components/charts/DualLineChart'), { ssr: false })
const HorizontalBarChart = dynamic(() => import('@/components/charts/HorizontalBarChart'), { ssr: false })
const DonutChart = dynamic(() => import('@/components/charts/DonutChart'), { ssr: false })

export default function ErrorsPage() {
  const { range, refreshKey } = useDashboard()
  const [data, setData] = useState<ErrorsData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)

  const fetchData = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const params = new URLSearchParams({ range, page: String(page) })
      if (search) params.set('search', search)
      const res = await fetch(`/api/events/errors?${params}`)
      if (!res.ok) throw new Error('Failed to fetch errors data')
      setData(await res.json())
    } catch (err: any) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }, [range, refreshKey, page, search])

  useEffect(() => { fetchData() }, [fetchData])

  if (loading && !data) return <LoadingSkeleton />
  if (error) return <div className="rounded-xl border border-red-500/30 bg-red-500/10 p-4 text-sm text-red-400">{error}</div>
  if (!data) return null

  const pageSize = 25
  const totalPages = Math.ceil(data.errorLogTotal / pageSize)

  return (
    <>
      <PageHeader title="Errors" description="Error tracking, rates, and diagnostics" />

      <div className="mb-6 grid grid-cols-2 gap-4 lg:grid-cols-4">
        <MetricCard title="Total Errors" value={data.totalErrors.value} deltaPercent={data.totalErrors.deltaPercent} color="#EF4444" />
        <MetricCard title="Unique Error Types" value={data.uniqueErrorTypes} color="#F59E0B" />
        <MetricCard title="Error Rate" value={`${data.errorRate}%`} color="#EF4444" />
        <MetricCard title="Users Affected" value={data.usersAffected} color="#8B5CF6" />
      </div>

      <div className="mb-6 grid gap-6 lg:grid-cols-2">
        <ChartCard title="Error Trend">
          <AreaTimeChart data={data.errorTrend} series={[{ key: 'count', color: '#EF4444', name: 'Errors' }]} />
        </ChartCard>
        <ChartCard title="Error Rate Over Time">
          <DualLineChart data={data.errorRateOverTime} series={[{ key: 'rate', color: '#F59E0B', name: 'Error Rate %' }]} />
        </ChartCard>
      </div>

      <div className="mb-6 grid gap-6 lg:grid-cols-2">
        <ChartCard title="Errors by Category">
          <HorizontalBarChart data={Object.entries(data.errorsByCategory).map(([name, value]) => ({ name, value, color: '#EF4444' }))} />
        </ChartCard>
        <ChartCard title="Errors by Platform">
          <DonutChart data={Object.entries(data.errorsByPlatform).map(([name, value]) => ({ name, value }))} />
        </ChartCard>
      </div>

      <div className="mb-6">
        <DataTable
          columns={[
            { key: 'message', label: 'Message', sortable: true },
            { key: 'count', label: 'Count', sortable: true },
            { key: 'lastSeen', label: 'Last Seen', sortable: true, render: (val: string) => format(parseISO(val), 'MMM d, HH:mm') },
          ]}
          data={data.topErrorMessages}
          defaultSort={{ key: 'count', dir: 'desc' }}
        />
      </div>

      {/* Error Log */}
      <div className="rounded-xl border border-white/10 bg-white/5 p-5">
        <div className="mb-4 flex items-center justify-between">
          <h3 className="text-sm font-medium text-neutral-400">Error Log ({data.errorLogTotal})</h3>
          <input
            type="text"
            placeholder="Search errors..."
            value={search}
            onChange={(e) => { setSearch(e.target.value); setPage(1) }}
            className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm text-neutral-200 placeholder-neutral-500 focus:border-white/20 focus:outline-none"
          />
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-white/10 text-left text-neutral-400">
                <th className="pb-2 pr-4 font-medium">Event</th>
                <th className="pb-2 pr-4 font-medium">Message</th>
                <th className="pb-2 pr-4 font-medium">Platform</th>
                <th className="pb-2 pr-4 font-medium">User</th>
                <th className="pb-2 font-medium">Time</th>
              </tr>
            </thead>
            <tbody>
              {data.errorLog.map((err, i) => (
                <tr key={i} className="border-b border-white/5">
                  <td className="py-2 pr-4">
                    <span className="rounded bg-red-500/20 px-2 py-0.5 text-xs text-red-400">{err.name}</span>
                  </td>
                  <td className="max-w-xs truncate py-2 pr-4 text-neutral-400">{err.message}</td>
                  <td className="py-2 pr-4"><PlatformBadge platform={err.platform} /></td>
                  <td className="py-2 pr-4 font-mono text-xs text-neutral-500">
                    {err.user_id ? err.user_id.slice(0, 8) + '...' : 'anon'}
                  </td>
                  <td className="py-2 text-neutral-500">{format(parseISO(err.created_at), 'MMM d, HH:mm')}</td>
                </tr>
              ))}
              {data.errorLog.length === 0 && (
                <tr><td colSpan={5} className="py-8 text-center text-neutral-500">No errors found</td></tr>
              )}
            </tbody>
          </table>
        </div>

        {totalPages > 1 && (
          <div className="mt-4 flex items-center justify-between">
            <span className="text-sm text-neutral-400">Page {page} of {totalPages}</span>
            <div className="flex gap-2">
              <button onClick={() => setPage(p => Math.max(1, p - 1))} disabled={page === 1} className="rounded-lg bg-white/5 px-3 py-1.5 text-sm text-neutral-400 hover:bg-white/10 disabled:opacity-50">Prev</button>
              <button onClick={() => setPage(p => Math.min(totalPages, p + 1))} disabled={page === totalPages} className="rounded-lg bg-white/5 px-3 py-1.5 text-sm text-neutral-400 hover:bg-white/10 disabled:opacity-50">Next</button>
            </div>
          </div>
        )}
      </div>
    </>
  )
}
