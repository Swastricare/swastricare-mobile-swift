'use client'

interface TopEventsTableProps {
  data: { name: string; count: number }[]
  title: string
}

export function TopEventsTable({ data, title }: TopEventsTableProps) {
  const max = data.length > 0 ? data[0].count : 1

  return (
    <div className="rounded-xl bg-white/5 p-5">
      <h3 className="mb-4 text-sm font-medium text-neutral-400">{title}</h3>
      <div className="space-y-2">
        {data.map((item) => (
          <div key={item.name} className="flex items-center gap-3">
            <div className="min-w-0 flex-1">
              <div className="flex items-center justify-between">
                <span className="truncate text-sm text-neutral-200">{item.name}</span>
                <span className="ml-2 shrink-0 text-xs font-mono text-neutral-400">
                  {item.count.toLocaleString()}
                </span>
              </div>
              <div className="mt-1 h-1.5 w-full rounded-full bg-white/5">
                <div
                  className="h-full rounded-full bg-indigo-500/60"
                  style={{ width: `${(item.count / max) * 100}%` }}
                />
              </div>
            </div>
          </div>
        ))}
        {data.length === 0 && (
          <p className="text-sm text-neutral-500">No data</p>
        )}
      </div>
    </div>
  )
}
