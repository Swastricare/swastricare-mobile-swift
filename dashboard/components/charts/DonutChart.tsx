'use client'

import {
  PieChart,
  Pie,
  Cell,
  ResponsiveContainer,
  Tooltip,
  Legend,
} from 'recharts'
import { PALETTE } from '@/lib/constants'

interface DonutChartProps {
  data: { name: string; value: number }[]
  colors?: string[]
}

export default function DonutChart({ data, colors = PALETTE }: DonutChartProps) {
  const tooltipStyle = {
    background: '#1a1a1a',
    border: '1px solid #333',
    borderRadius: '8px',
    color: '#e5e5e5',
  }

  return (
    <ResponsiveContainer width="100%" height="100%">
      <PieChart>
        <Pie
          data={data}
          dataKey="value"
          nameKey="name"
          cx="50%"
          cy="50%"
          innerRadius={60}
          outerRadius={90}
          paddingAngle={2}
        >
          {data.map((entry, index) => (
            <Cell key={`cell-${index}`} fill={colors[index % colors.length]} />
          ))}
        </Pie>
        <Tooltip contentStyle={tooltipStyle} />
        <Legend />
      </PieChart>
    </ResponsiveContainer>
  )
}
