'use client'

interface ChartCardProps {
  title: string
  children: React.ReactNode
  className?: string
}

export default function ChartCard({ title, children, className }: ChartCardProps) {
  return (
    <div className="rounded-2xl bg-[var(--bg-card)] p-5">
      <div className="text-xs font-semibold text-neutral-400 uppercase tracking-wide mb-4">{title}</div>
      <div className={className || 'h-64'}>{children}</div>
    </div>
  )
}
