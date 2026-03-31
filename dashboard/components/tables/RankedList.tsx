'use client'

interface RankedListProps {
  data: { name: string; count: number }[]
  title?: string
  barColor?: string
  maxItems?: number
}

export default function RankedList({
  data,
  title,
  barColor = 'bg-indigo-500/60',
  maxItems,
}: RankedListProps) {
  const displayData = maxItems ? data.slice(0, maxItems) : data
  const maxCount = Math.max(...displayData.map((item) => item.count), 1)

  const formatCount = (count: number) => {
    return count.toLocaleString()
  }

  return (
    <div className="rounded-xl bg-white/5 p-5">
      {title && (
        <h3 className="mb-4 text-sm font-medium text-neutral-400">{title}</h3>
      )}

      {displayData.length === 0 ? (
        <div className="py-8 text-center text-sm text-neutral-400">No data</div>
      ) : (
        <div className="space-y-3">
          {displayData.map((item, index) => {
            const widthPercent = (item.count / maxCount) * 100

            return (
              <div key={index} className="flex items-center gap-3">
                <div className="flex-1">
                  <div className="mb-1 flex items-center justify-between text-sm">
                    <span className="text-neutral-200">{item.name}</span>
                    <span className="text-neutral-400">{formatCount(item.count)}</span>
                  </div>
                  <div className="h-2 w-full rounded-full bg-white/5">
                    <div
                      className={`h-full rounded-full ${barColor}`}
                      style={{ width: `${widthPercent}%` }}
                    />
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
