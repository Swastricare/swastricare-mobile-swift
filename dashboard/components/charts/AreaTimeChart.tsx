'use client'

import { format, parseISO } from 'date-fns'
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from 'recharts'

interface AreaTimeChartProps {
  data: Record<string, any>[]
  xKey?: string
  series: { key: string; color: string; name?: string }[]
  stacked?: boolean
}

export default function AreaTimeChart({
  data,
  xKey = 'date',
  series,
  stacked = false,
}: AreaTimeChartProps) {
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
      <AreaChart data={data}>
        <defs>
          {series.map((s) => (
            <linearGradient
              key={`gradient-${s.key}`}
              id={`gradient-${s.key}`}
              x1="0"
              y1="0"
              x2="0"
              y2="1"
            >
              <stop offset="5%" stopColor={s.color} stopOpacity={0.8} />
              <stop offset="95%" stopColor={s.color} stopOpacity={0.1} />
            </linearGradient>
          ))}
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="#333" />
        <XAxis
          dataKey={xKey}
          tickFormatter={formatXAxis}
          stroke="#666"
          fontSize={12}
        />
        <YAxis stroke="#666" fontSize={12} />
        <Tooltip contentStyle={tooltipStyle} />
        {series.length > 1 && <Legend />}
        {series.map((s) => (
          <Area
            key={s.key}
            type="monotone"
            dataKey={s.key}
            name={s.name || s.key}
            stroke={s.color}
            fill={`url(#gradient-${s.key})`}
            strokeWidth={2}
            {...(stacked && { stackId: '1' })}
          />
        ))}
      </AreaChart>
    </ResponsiveContainer>
  )
}
