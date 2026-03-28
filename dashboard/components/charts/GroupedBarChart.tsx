'use client'

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from 'recharts'

interface GroupedBarChartProps {
  data: Record<string, any>[]
  categoryKey: string
  series: { key: string; color: string; name?: string }[]
  layout?: 'horizontal' | 'vertical'
}

export default function GroupedBarChart({
  data,
  categoryKey,
  series,
  layout = 'horizontal',
}: GroupedBarChartProps) {
  const tooltipStyle = {
    background: '#1a1a1a',
    border: '1px solid #333',
    borderRadius: '8px',
    color: '#e5e5e5',
  }

  const isVertical = layout === 'vertical'
  const barRadius: [number, number, number, number] = isVertical ? [0, 4, 4, 0] : [4, 4, 0, 0]

  return (
    <ResponsiveContainer width="100%" height="100%">
      <BarChart data={data} layout={isVertical ? 'vertical' : 'horizontal'}>
        <CartesianGrid strokeDasharray="3 3" stroke="#333" />
        {isVertical ? (
          <>
            <XAxis type="number" stroke="#666" fontSize={12} />
            <YAxis
              type="category"
              dataKey={categoryKey}
              stroke="#666"
              fontSize={12}
            />
          </>
        ) : (
          <>
            <XAxis
              type="category"
              dataKey={categoryKey}
              stroke="#666"
              fontSize={12}
            />
            <YAxis type="number" stroke="#666" fontSize={12} />
          </>
        )}
        <Tooltip contentStyle={tooltipStyle} />
        <Legend />
        {series.map((s) => (
          <Bar
            key={s.key}
            dataKey={s.key}
            name={s.name || s.key}
            fill={s.color}
            radius={barRadius}
          />
        ))}
      </BarChart>
    </ResponsiveContainer>
  )
}
