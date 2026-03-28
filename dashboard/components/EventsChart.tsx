'use client'

import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from 'recharts'
import { format, parseISO } from 'date-fns'

interface EventsChartProps {
  data: { date: string; count: number }[]
  title: string
  color?: string
}

export function EventsChart({ data, title, color = '#4F46E5' }: EventsChartProps) {
  return (
    <div className="rounded-xl border border-white/10 bg-white/5 p-5">
      <h3 className="mb-4 text-sm font-medium text-neutral-400">{title}</h3>
      <div className="h-64">
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={data}>
            <defs>
              <linearGradient id={`grad-${color.replace('#', '')}`} x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor={color} stopOpacity={0.3} />
                <stop offset="95%" stopColor={color} stopOpacity={0} />
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" stroke="#333" />
            <XAxis
              dataKey="date"
              stroke="#666"
              fontSize={12}
              tickFormatter={(val) => format(parseISO(val), 'MMM d')}
            />
            <YAxis stroke="#666" fontSize={12} />
            <Tooltip
              contentStyle={{
                background: '#1a1a1a',
                border: '1px solid #333',
                borderRadius: '8px',
                color: '#e5e5e5',
              }}
              labelFormatter={(val) => format(parseISO(val as string), 'MMM d, yyyy')}
            />
            <Area
              type="monotone"
              dataKey="count"
              stroke={color}
              fill={`url(#grad-${color.replace('#', '')})`}
              strokeWidth={2}
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
