'use client'

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Cell,
} from 'recharts'

interface HorizontalBarChartProps {
  data: { name: string; value: number; color?: string }[]
  defaultColor?: string
}

export default function HorizontalBarChart({
  data,
  defaultColor = '#4F46E5',
}: HorizontalBarChartProps) {
  const tooltipStyle = {
    background: '#1a1a1a',
    border: '1px solid #333',
    borderRadius: '8px',
    color: '#e5e5e5',
  }

  return (
    <ResponsiveContainer width="100%" height="100%">
      <BarChart data={data} layout="vertical">
        <CartesianGrid strokeDasharray="3 3" stroke="#333" />
        <XAxis type="number" stroke="#666" fontSize={12} />
        <YAxis
          type="category"
          dataKey="name"
          width={120}
          stroke="#666"
          fontSize={12}
        />
        <Tooltip contentStyle={tooltipStyle} />
        <Bar dataKey="value" radius={[0, 4, 4, 0]}>
          {data.map((entry, index) => (
            <Cell key={`cell-${index}`} fill={entry.color || defaultColor} />
          ))}
        </Bar>
      </BarChart>
    </ResponsiveContainer>
  )
}
