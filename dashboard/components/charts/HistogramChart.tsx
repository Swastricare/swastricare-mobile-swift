'use client'

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts'

interface HistogramChartProps {
  data: { bucket: string; count: number }[]
  color?: string
  xLabel?: string
  yLabel?: string
}

export default function HistogramChart({
  data,
  color = '#4F46E5',
  xLabel,
  yLabel,
}: HistogramChartProps) {
  const tooltipStyle = {
    background: '#1a1a1a',
    border: '1px solid #333',
    borderRadius: '8px',
    color: '#e5e5e5',
  }

  return (
    <ResponsiveContainer width="100%" height="100%">
      <BarChart data={data}>
        <CartesianGrid strokeDasharray="3 3" stroke="#333" />
        <XAxis
          dataKey="bucket"
          stroke="#666"
          fontSize={12}
          label={xLabel ? { value: xLabel, position: 'insideBottom', offset: -5 } : undefined}
        />
        <YAxis
          stroke="#666"
          fontSize={12}
          label={yLabel ? { value: yLabel, angle: -90, position: 'insideLeft' } : undefined}
        />
        <Tooltip contentStyle={tooltipStyle} />
        <Bar dataKey="count" fill={color} radius={[4, 4, 0, 0]} />
      </BarChart>
    </ResponsiveContainer>
  )
}
