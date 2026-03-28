'use client'

interface ComparisonMetricCardProps {
  title: string
  iosValue: number
  androidValue: number
  iosColor?: string
  androidColor?: string
}

export default function ComparisonMetricCard({
  title,
  iosValue,
  androidValue,
  iosColor = '#3B82F6',
  androidColor = '#22C55E',
}: ComparisonMetricCardProps) {
  return (
    <div className="rounded-xl border border-white/10 bg-white/5 p-5">
      <div className="text-sm text-neutral-400 mb-4">{title}</div>
      <div className="grid grid-cols-2 gap-4">
        <div className="text-center">
          <div className="text-2xl font-bold" style={{ color: iosColor }}>
            {iosValue.toLocaleString()}
          </div>
          <div className="mt-1 text-xs text-neutral-500">iOS</div>
        </div>
        <div className="text-center">
          <div className="text-2xl font-bold" style={{ color: androidColor }}>
            {androidValue.toLocaleString()}
          </div>
          <div className="mt-1 text-xs text-neutral-500">Android</div>
        </div>
      </div>
    </div>
  )
}
