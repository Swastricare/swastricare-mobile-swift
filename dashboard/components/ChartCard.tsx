'use client'

interface ChartCardProps {
  title: string
  children: React.ReactNode
  className?: string
}

export default function ChartCard({ title, children, className }: ChartCardProps) {
  return (
    <div className="rounded-2xl border border-white/[0.08] bg-neutral-900 p-5">
      <div className="text-xs font-semibold text-neutral-400 uppercase tracking-wide mb-4">{title}</div>
      <div className={className || 'h-64'}>{children}</div>
    </div>
  )
}
