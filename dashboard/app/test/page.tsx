'use client'

import { useState, useEffect } from 'react'
import { useDashboard } from '@/components/providers/DashboardProvider'

export default function TestPage() {
  const { range } = useDashboard()
  const [status, setStatus] = useState('Mounting...')

  useEffect(() => {
    setStatus('Hydrated OK! Range: ' + range)
  }, [range])

  return (
    <div style={{ padding: 20 }}>
      <h1 style={{ color: '#fff', fontSize: 24 }}>Test Page</h1>
      <p style={{ color: '#22C55E', marginTop: 10 }}>{status}</p>
      <p style={{ color: '#888', marginTop: 10 }}>
        If you see this, the layout + provider + routing all work.
      </p>
    </div>
  )
}
