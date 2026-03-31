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

const TYPE_COLORS: Record<string, string> = {
  navigation: '#3B82F6',
  action: '#22C55E',
  error: '#EF4444',
  count: '#F59E0B',
  feature_usage: '#8B5CF6',
  auth: '#EC4899',
  screen: '#06B6D4',
}

interface EventTypeChartProps {
  data: Record<string, number>
}

export function EventTypeChart({ data }: EventTypeChartProps) {
  const chartData = Object.entries(data)
    .map(([type, count]) => ({ type, count }))
    .sort((a, b) => b.count - a.count)

  return (
    <div className="rounded-xl bg-white/5 p-5">
      <h3 className="mb-4 text-sm font-medium text-neutral-400">Events by Type</h3>
      <div className="h-64">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={chartData} layout="vertical">
            <CartesianGrid strokeDasharray="3 3" stroke="#333" horizontal={false} />
            <XAxis type="number" stroke="#666" fontSize={12} />
            <YAxis
              dataKey="type"
              type="category"
              stroke="#666"
              fontSize={12}
              width={100}
            />
            <Tooltip
              contentStyle={{
                background: '#1a1a1a',
                border: '1px solid #333',
                borderRadius: '8px',
                color: '#e5e5e5',
              }}
            />
            <Bar dataKey="count" radius={[0, 4, 4, 0]}>
              {chartData.map((entry) => (
                <Cell
                  key={entry.type}
                  fill={TYPE_COLORS[entry.type] || '#6B7280'}
                />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>
    </div>
  )
}
