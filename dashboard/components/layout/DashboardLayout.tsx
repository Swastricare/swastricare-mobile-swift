'use client'

import React, { ReactNode } from 'react'
import Sidebar from './Sidebar'
import { useDashboard } from '@/components/providers/DashboardProvider'

export default function DashboardLayout({ children }: { children: ReactNode }) {
  const { sidebarCollapsed } = useDashboard()
  const ml = sidebarCollapsed ? 'ml-16' : 'ml-60'

  return (
    <div className="min-h-screen bg-[var(--bg-base)]">
      <Sidebar />
      <main className={`${ml} min-h-screen transition-all duration-200`}>
        {children}
      </main>
    </div>
  )
}
