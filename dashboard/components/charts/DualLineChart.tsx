'use client'

import { format, parseISO } from 'date-fns'
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from 'recharts'

interface DualLineChartProps {
  data: Record<string, any>[]
  xKey?: string
  series: { key: string; color: string; name?: string }[]
}

export default function DualLineChart({
  data,
  xKey = 'date',
  series,
}: DualLineChartProps) {
  const tooltipStyle = {
    background: '#1a1a1a',
    border: '1px solid #333',
    borderRadius: '8px',
    color: '#e5e5e5',
  }

  const formatXAxis = (value: string) => {
    try {
      return format(parseISO(value), 'MMM d')
    } catch {
      return value
    }
  }

  return (
    <ResponsiveContainer width="100%" height="100%">
      <LineChart data={data}>
        <CartesianGrid strokeDasharray="3 3" stroke="#333" />
        <XAxis
          dataKey={xKey}
          tickFormatter={formatXAxis}
          stroke="#666"
          fontSize={12}
        />
        <YAxis stroke="#666" fontSize={12} />
        <Tooltip contentStyle={tooltipStyle} />
        <Legend />
        {series.map((s) => (
          <Line
            key={s.key}
            type="monotone"
            dataKey={s.key}
            name={s.name || s.key}
            stroke={s.color}
            strokeWidth={2}
          />
        ))}
      </LineChart>
    </ResponsiveContainer>
  )
}
