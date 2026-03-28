'use client'

interface MetricCardProps {
  title: string
  value: string | number
  subtitle?: string
  color?: string
  delta?: number | null
  deltaPercent?: number | null
}

export default function MetricCard({
  title,
  value,
  subtitle,
  color = '#4F46E5',
  delta,
  deltaPercent,
}: MetricCardProps) {
  const getDeltaColor = (percent: number) => {
    if (percent > 0) return 'text-green-400'
    if (percent < 0) return 'text-red-400'
    return 'text-neutral-400'
  }

  const getDeltaPrefix = (percent: number) => {
    if (percent > 0) return '▲ '
    if (percent < 0) return '▼ '
    return ''
  }

  const formatDelta = (percent: number) => {
    return `${getDeltaPrefix(percent)}${Math.abs(percent)}%`
  }

  return (
    <div className="rounded-xl border border-white/10 bg-white/5 p-5">
      <div className="text-sm text-neutral-400">{title}</div>
      <div className="mt-2 text-3xl font-bold" style={{ color }}>
        {typeof value === 'number' ? value.toLocaleString() : value}
      </div>
      {deltaPercent !== null && deltaPercent !== undefined && (
        <div className={`mt-1 text-xs font-medium ${getDeltaColor(deltaPercent)}`}>
          {formatDelta(deltaPercent)}
        </div>
      )}
      {subtitle && (
        <div className="mt-1 text-xs text-neutral-500">{subtitle}</div>
      )}
    </div>
  )
}
