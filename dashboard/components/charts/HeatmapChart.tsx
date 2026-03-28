'use client'

import { DAY_NAMES } from '@/lib/constants'

interface HeatmapChartProps {
  data: { day: number; hour: number; count: number }[]
}

export default function HeatmapChart({ data }: HeatmapChartProps) {
  // Find max count for color scaling
  const maxCount = Math.max(...data.map((d) => d.count), 1)

  // Build a map for quick lookup
  const dataMap = new Map<string, number>()
  data.forEach((d) => {
    dataMap.set(`${d.day}-${d.hour}`, d.count)
  })

  const getColorClass = (count: number) => {
    if (count === 0) return 'bg-neutral-800/50'
    const ratio = count / maxCount
    if (ratio > 0.75) return 'bg-indigo-400'
    if (ratio > 0.5) return 'bg-indigo-500/80'
    if (ratio > 0.25) return 'bg-indigo-700/70'
    return 'bg-indigo-900/60'
  }

  const hours = Array.from({ length: 24 }, (_, i) => i)
  const days = Array.from({ length: 7 }, (_, i) => i)

  // Show every 3rd hour label
  const hourLabels = [0, 3, 6, 9, 12, 15, 18, 21]

  return (
    <div className="w-full h-full flex flex-col">
      {/* Hour labels */}
      <div className="flex mb-1">
        <div className="w-12" /> {/* Spacer for day labels */}
        <div className="flex-1 grid grid-cols-24 gap-0.5">
          {hours.map((hour) => (
            <div
              key={`hour-${hour}`}
              className="text-xs text-neutral-500 text-center"
            >
              {hourLabels.includes(hour) ? hour : ''}
            </div>
          ))}
        </div>
      </div>

      {/* Heatmap grid */}
      <div className="flex-1 flex flex-col gap-0.5">
        {days.map((day) => (
          <div key={`day-${day}`} className="flex gap-0.5 flex-1">
            {/* Day label */}
            <div className="w-12 text-xs text-neutral-500 flex items-center">
              {DAY_NAMES[day]}
            </div>

            {/* Hour cells */}
            <div className="flex-1 grid grid-cols-24 gap-0.5">
              {hours.map((hour) => {
                const count = dataMap.get(`${day}-${hour}`) || 0
                const colorClass = getColorClass(count)
                const dayName = DAY_NAMES[day]
                const hourFormatted = hour.toString().padStart(2, '0')

                return (
                  <div
                    key={`cell-${day}-${hour}`}
                    className={`w-full aspect-square rounded-sm ${colorClass}`}
                    title={`${dayName} ${hourFormatted}:00 — ${count} events`}
                  />
                )
              })}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
