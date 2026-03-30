'use client'

import Sparkline from '@/components/charts/Sparkline'

interface MetricCardProps {
  title: string
  value: string | number
  subtitle?: string
  color?: string
  delta?: number | null
  deltaPercent?: number | null
  sparkline?: number[]
}

export default function MetricCard({
  title, value, subtitle, color = '#4F46E5',
  delta, deltaPercent, sparkline,
}: MetricCardProps) {
  const isPositive = deltaPercent != null && deltaPercent > 0
  const isNegative = deltaPercent != null && deltaPercent < 0

  return (
    <div className="relative rounded-2xl border border-white/[0.08] bg-neutral-900 p-5 overflow-hidden transition-all duration-200 hover:-translate-y-0.5 group">
      {/* Accent left border */}
      <div className="absolute left-0 top-4 bottom-4 w-0.5 rounded-r-full" style={{ backgroundColor: color }} />

      {/* Subtle bg glow on hover */}
      <div
        className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-300 rounded-2xl pointer-events-none"
        style={{ background: `radial-gradient(ellipse at 0% 50%, ${color}1a 0%, transparent 70%)` }}
      />

      <div className="relative">
        <div className="flex items-start justify-between gap-2">
          <div className="text-xs font-medium text-neutral-400 uppercase tracking-wide">{title}</div>
          {sparkline && sparkline.length > 1 && (
            <Sparkline data={sparkline} color={color} width={64} height={24} />
          )}
        </div>

        <div className="mt-2 text-2xl font-bold text-white">
          {typeof value === 'number' ? value.toLocaleString() : value}
        </div>

        <div className="mt-1.5 flex items-center gap-2">
          {deltaPercent != null && (
            <span className={`inline-flex items-center gap-0.5 text-xs font-semibold px-1.5 py-0.5 rounded-md ${
              isPositive ? 'bg-green-500/15 text-green-400'
              : isNegative ? 'bg-red-500/15 text-red-400'
              : 'bg-neutral-700 text-neutral-400'
            }`}>
              {isPositive ? '▲' : isNegative ? '▼' : ''}
              {Math.abs(deltaPercent)}%
            </span>
          )}
          {subtitle && <span className="text-xs text-neutral-500">{subtitle}</span>}
        </div>
      </div>
    </div>
  )
}
