'use client'

import React, { createContext, useContext, useState, ReactNode } from 'react'
import type { TimeRange, Platform, CustomRange, DashboardContextType } from '@/lib/types'

const DashboardContext = createContext<DashboardContextType | undefined>(undefined)

export function DashboardProvider({ children }: { children: ReactNode }) {
  const [range, setRange] = useState<TimeRange>('7')
  const [refreshKey, setRefreshKey] = useState(0)
  const [platform, setPlatform] = useState<Platform>('all')
  const [compareMode, setCompareMode] = useState(false)
  const [customRange, setCustomRange] = useState<CustomRange | null>(null)
  const [sidebarCollapsed, setSidebarCollapsed] = useState(() => {
    if (typeof window === 'undefined') return false
    return localStorage.getItem('sidebarCollapsed') === 'true'
  })

  const handleSetSidebarCollapsed = (v: boolean) => {
    setSidebarCollapsed(v)
    localStorage.setItem('sidebarCollapsed', String(v))
  }

  return (
    <DashboardContext.Provider value={{
      range, setRange,
      refreshKey, refresh: () => setRefreshKey(k => k + 1),
      platform, setPlatform,
      compareMode, setCompareMode,
      sidebarCollapsed, setSidebarCollapsed: handleSetSidebarCollapsed,
      customRange, setCustomRange,
    }}>
      {children}
    </DashboardContext.Provider>
  )
}

export function useDashboard() {
  const ctx = useContext(DashboardContext)
  if (!ctx) throw new Error('useDashboard must be used within DashboardProvider')
  return ctx
}
