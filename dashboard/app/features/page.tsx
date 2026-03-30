'use client'

import { useEffect, useState, useCallback } from 'react'
import dynamic from 'next/dynamic'
import { useDashboard } from '@/components/providers/DashboardProvider'
import TopBar from '@/components/layout/TopBar'
import LoadingSkeleton from '@/components/LoadingSkeleton'
import MetricCard from '@/components/MetricCard'
import ChartCard from '@/components/ChartCard'
import { FEATURE_COLORS, PLATFORM_COLORS } from '@/lib/constants'
import type { FeaturesData } from '@/lib/types'

const HorizontalBarChart = dynamic(() => import('@/components/charts/HorizontalBarChart'), { ssr: false })
const DualLineChart = dynamic(() => import('@/components/charts/DualLineChart'), { ssr: false })
const GroupedBarChart = dynamic(() => import('@/components/charts/GroupedBarChart'), { ssr: false })
const DonutChart = dynamic(() => import('@/components/charts/DonutChart'), { ssr: false })
const HistogramChart = dynamic(() => import('@/components/charts/HistogramChart'), { ssr: false })
const AreaTimeChart = dynamic(() => import('@/components/charts/AreaTimeChart'), { ssr: false })

export default function FeaturesPage() {
  const { range, refreshKey, platform } = useDashboard()
  const [data, setData] = useState<FeaturesData | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const fetchData = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const res = await fetch(`/api/events/features?range=${range}&platform=${platform}`)
      if (!res.ok) throw new Error('Failed to fetch features data')
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

  const trendSeries = [
    { key: 'Hydration', color: FEATURE_COLORS.Hydration, name: 'Hydration' },
    { key: 'Medication', color: FEATURE_COLORS.Medication, name: 'Medication' },
    { key: 'Workout', color: FEATURE_COLORS.Workout, name: 'Workout' },
    { key: 'AI', color: FEATURE_COLORS.AI, name: 'AI' },
    { key: 'Vault', color: FEATURE_COLORS.Vault, name: 'Vault' },
    { key: 'Heart Rate', color: FEATURE_COLORS['Heart Rate'], name: 'Heart Rate' },
  ]

  return (
    <>
      <TopBar title="Features" description="Feature adoption and usage details" />

      <div className="p-6 md:p-8">
      <div className="mb-6 grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-6">
        <MetricCard title="Hydration" value={data.hydrationEvents.value} deltaPercent={data.hydrationEvents.deltaPercent} color={FEATURE_COLORS.Hydration} />
        <MetricCard title="Medication" value={data.medicationEvents.value} deltaPercent={data.medicationEvents.deltaPercent} color={FEATURE_COLORS.Medication} />
        <MetricCard title="Workout" value={data.workoutEvents.value} deltaPercent={data.workoutEvents.deltaPercent} color={FEATURE_COLORS.Workout} />
        <MetricCard title="AI" value={data.aiEvents.value} deltaPercent={data.aiEvents.deltaPercent} color={FEATURE_COLORS.AI} />
        <MetricCard title="Vault" value={data.vaultEvents.value} deltaPercent={data.vaultEvents.deltaPercent} color={FEATURE_COLORS.Vault} />
        <MetricCard title="Heart Rate" value={data.heartRateEvents.value} deltaPercent={data.heartRateEvents.deltaPercent} color={FEATURE_COLORS['Heart Rate']} />
      </div>

      <div className="mb-6 grid gap-6 lg:grid-cols-2">
        <ChartCard title="Feature Usage Totals">
          <HorizontalBarChart data={data.featureTotals.map(f => ({ name: f.name, value: f.count, color: FEATURE_COLORS[f.name] || '#6B7280' }))} />
        </ChartCard>
        <ChartCard title="Feature Trends">
          <DualLineChart data={data.featureTrends} series={trendSeries} />
        </ChartCard>
      </div>

      <div className="mb-6">
        <ChartCard title="Feature by Platform">
          <GroupedBarChart data={data.featureByPlatform} categoryKey="feature" series={[{ key: 'iOS', color: PLATFORM_COLORS.iOS, name: 'iOS' }, { key: 'Android', color: PLATFORM_COLORS.Android, name: 'Android' }]} />
        </ChartCard>
      </div>

      {/* Hydration */}
      <div className="mb-6 rounded-xl border border-white/10 bg-white/5 p-5">
        <h3 className="mb-4 text-sm font-medium text-neutral-300">Hydration</h3>
        <div className="grid grid-cols-2 gap-4">
          <MetricCard title="Avg Amount/Log" value={`${Math.round(data.hydration.avgAmount)} ml`} color={FEATURE_COLORS.Hydration} />
          <MetricCard title="Goal Completion" value={`${Math.round(data.hydration.goalCompletionRate * 100)}%`} color="#22C55E" />
        </div>
      </div>

      {/* Medication */}
      <div className="mb-6 rounded-xl border border-white/10 bg-white/5 p-5">
        <h3 className="mb-4 text-sm font-medium text-neutral-300">Medication</h3>
        <div className="grid gap-6 lg:grid-cols-2">
          <ChartCard title="Taken / Skipped / Snoozed">
            <DonutChart data={[{ name: 'Taken', value: data.medication.taken }, { name: 'Skipped', value: data.medication.skipped }, { name: 'Snoozed', value: data.medication.snoozed }]} colors={['#22C55E', '#EF4444', '#F59E0B']} />
          </ChartCard>
          <ChartCard title="Source Breakdown">
            <DonutChart data={Object.entries(data.medication.sourceBreakdown).map(([name, value]) => ({ name, value }))} />
          </ChartCard>
        </div>
      </div>

      {/* Workout */}
      <div className="mb-6 rounded-xl border border-white/10 bg-white/5 p-5">
        <h3 className="mb-4 text-sm font-medium text-neutral-300">Workout</h3>
        <div className="grid gap-4 md:grid-cols-3">
          <ChartCard title="Activity Types">
            <DonutChart data={Object.entries(data.workout.activityTypes).map(([name, value]) => ({ name, value }))} />
          </ChartCard>
          <MetricCard title="Avg Duration" value={`${Math.round(data.workout.avgDuration)}s`} color={FEATURE_COLORS.Workout} />
          <MetricCard title="Completion Rate" value={`${Math.round(data.workout.completionRate * 100)}%`} color="#22C55E" />
        </div>
      </div>

      {/* AI */}
      <div className="mb-6 rounded-xl border border-white/10 bg-white/5 p-5">
        <h3 className="mb-4 text-sm font-medium text-neutral-300">AI</h3>
        <div className="grid gap-6 lg:grid-cols-2">
          <ChartCard title="Mode Distribution">
            <DonutChart data={Object.entries(data.ai.modeDistribution).map(([name, value]) => ({ name, value }))} />
          </ChartCard>
          <ChartCard title="Message Volume">
            <AreaTimeChart data={data.ai.messageTrend} series={[{ key: 'count', color: FEATURE_COLORS.AI }]} />
          </ChartCard>
        </div>
      </div>

      {/* Heart Rate */}
      <div className="rounded-xl border border-white/10 bg-white/5 p-5">
        <h3 className="mb-4 text-sm font-medium text-neutral-300">Heart Rate</h3>
        <div className="grid gap-6 lg:grid-cols-2">
          <MetricCard title="Avg BPM" value={Math.round(data.heartRate.avgBpm)} color={FEATURE_COLORS['Heart Rate']} />
          <ChartCard title="BPM Distribution">
            <HistogramChart data={data.heartRate.bpmDistribution} color={FEATURE_COLORS['Heart Rate']} />
          </ChartCard>
        </div>
      </div>
      </div>
    </>
  )
}
