'use client'

interface ChartCardProps {
  title: string
  children: React.ReactNode
  className?: string
}

export default function ChartCard({ title, children, className }: ChartCardProps) {
  return (
    <div className="rounded-xl border border-white/10 bg-white/5 p-5">
      <div className="text-sm font-medium text-neutral-400 mb-4">{title}</div>
      <div className={className || 'h-64'}>{children}</div>
    </div>
  )
}
