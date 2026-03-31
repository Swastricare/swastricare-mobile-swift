# Dashboard Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the SwasthiCare analytics dashboard with a sticky top bar for global filters, collapsible sidebar, sparkline metric cards, comparison mode, and visual polish across all 7 pages.

**Architecture:** Add `platform`, `compareMode`, `sidebarCollapsed`, and `customRange` to `DashboardProvider` context. Build a new `TopBar` component that replaces the sidebar's time range controls. Rebuild `MetricCard` with an inline SVG `Sparkline`. Update all pages to consume the new context fields, and update API routes to accept a `platform` query param.

**Tech Stack:** Next.js 14, TypeScript, Tailwind CSS 3, Recharts 2, date-fns 3, Supabase JS

---

## Task 1: Extend DashboardProvider with new global state

**Files:**
- Modify: `dashboard/components/providers/DashboardProvider.tsx`
- Modify: `dashboard/lib/types.ts`

**Step 1: Extend `TimeRange` type and add new types to `lib/types.ts`**

Add at the bottom of `dashboard/lib/types.ts`:
```ts
export type Platform = 'all' | 'iOS' | 'Android'

export interface CustomRange {
  start: string  // ISO date string YYYY-MM-DD
  end: string
}

export interface DashboardContextType {
  range: TimeRange
  setRange: (r: TimeRange) => void
  refreshKey: number
  refresh: () => void
  platform: Platform
  setPlatform: (p: Platform) => void
  compareMode: boolean
  setCompareMode: (v: boolean) => void
  sidebarCollapsed: boolean
  setSidebarCollapsed: (v: boolean) => void
  customRange: CustomRange | null
  setCustomRange: (r: CustomRange | null) => void
}
```

**Step 2: Rewrite `DashboardProvider.tsx`**

Replace the entire file with:
```tsx
'use client'

import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react'
import type { TimeRange, Platform, CustomRange, DashboardContextType } from '@/lib/types'

const DashboardContext = createContext<DashboardContextType | undefined>(undefined)

export function DashboardProvider({ children }: { children: ReactNode }) {
  const [range, setRange] = useState<TimeRange>('7')
  const [refreshKey, setRefreshKey] = useState(0)
  const [platform, setPlatform] = useState<Platform>('all')
  const [compareMode, setCompareMode] = useState(false)
  const [customRange, setCustomRange] = useState<CustomRange | null>(null)
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false)

  // Persist sidebar state across reloads
  useEffect(() => {
    const stored = localStorage.getItem('sidebarCollapsed')
    if (stored !== null) setSidebarCollapsed(stored === 'true')
  }, [])

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
```

**Step 3: TypeScript check**

```bash
cd dashboard && npx tsc --noEmit
```
Expected: No errors (or only pre-existing ones unrelated to these files).

**Step 4: Commit**
```bash
git add dashboard/lib/types.ts dashboard/components/providers/DashboardProvider.tsx
git commit -m "feat(dashboard): extend DashboardProvider with platform, compareMode, sidebarCollapsed, customRange"
```

---

## Task 2: Rebuild Sidebar with collapse support

**Files:**
- Modify: `dashboard/components/layout/Sidebar.tsx`

**Step 1: Rewrite Sidebar**

Replace the entire file:
```tsx
'use client'

import React from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useDashboard } from '@/components/providers/DashboardProvider'
import { NAV_ITEMS } from '@/lib/constants'

const ICONS: Record<string, React.ReactNode> = {
  home: <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" /></svg>,
  device: <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z" /></svg>,
  screen: <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>,
  feature: <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" /></svg>,
  users: <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" /></svg>,
  engagement: <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6" /></svg>,
  error: <svg className="w-5 h-5 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>,
}

export default function Sidebar() {
  const pathname = usePathname()
  const { sidebarCollapsed, setSidebarCollapsed } = useDashboard()

  const w = sidebarCollapsed ? 'w-16' : 'w-60'

  return (
    <aside className={`fixed left-0 top-0 h-screen ${w} bg-neutral-950 border-r border-white/8 flex flex-col transition-all duration-200 z-40`}>
      {/* Header */}
      <div className={`flex items-center border-b border-white/8 h-14 px-4 ${sidebarCollapsed ? 'justify-center' : 'justify-between'}`}>
        {!sidebarCollapsed && (
          <div>
            <span className="text-sm font-bold text-white">SwasthiCare</span>
            <span className="ml-1.5 text-xs text-neutral-500">Analytics</span>
          </div>
        )}
        <button
          onClick={() => setSidebarCollapsed(!sidebarCollapsed)}
          className="p-1.5 rounded-lg hover:bg-white/8 text-neutral-400 hover:text-white transition-colors"
          title={sidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
        >
          <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            {sidebarCollapsed
              ? <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 5l7 7-7 7M5 5l7 7-7 7" />
              : <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 19l-7-7 7-7M19 19l-7-7 7-7" />
            }
          </svg>
        </button>
      </div>

      {/* Nav */}
      <nav className="flex-1 p-2 space-y-0.5 overflow-y-auto">
        {NAV_ITEMS.map((item) => {
          const isActive = pathname === item.href
          return (
            <Link
              key={item.href}
              href={item.href}
              title={sidebarCollapsed ? item.label : undefined}
              className={`flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all duration-150 group relative ${
                isActive
                  ? 'bg-white/10 text-white'
                  : 'text-neutral-400 hover:bg-white/5 hover:text-neutral-200'
              } ${sidebarCollapsed ? 'justify-center' : ''}`}
            >
              {isActive && <span className="absolute left-0 top-1/2 -translate-y-1/2 w-0.5 h-6 bg-blue-500 rounded-r-full" />}
              {ICONS[item.icon] || ICONS.home}
              {!sidebarCollapsed && <span className="text-sm font-medium">{item.label}</span>}
            </Link>
          )
        })}
      </nav>

      {/* Bottom */}
      {!sidebarCollapsed && (
        <div className="p-3 border-t border-white/8">
          <div className="text-xs text-neutral-600 text-center">v1.0</div>
        </div>
      )}
    </aside>
  )
}
```

**Step 2: TypeScript check**
```bash
cd dashboard && npx tsc --noEmit
```

**Step 3: Commit**
```bash
git add dashboard/components/layout/Sidebar.tsx
git commit -m "feat(dashboard): collapsible sidebar with icon-rail mode"
```

---

## Task 3: Build new TopBar component

**Files:**
- Create: `dashboard/components/layout/TopBar.tsx`

**Step 1: Create `TopBar.tsx`**

```tsx
'use client'

import React, { useState } from 'react'
import { useDashboard } from '@/components/providers/DashboardProvider'
import { RANGE_OPTIONS } from '@/lib/constants'
import type { Platform } from '@/lib/types'

const PLATFORMS: { label: string; value: Platform }[] = [
  { label: 'All', value: 'all' },
  { label: 'iOS', value: 'iOS' },
  { label: 'Android', value: 'Android' },
]

export default function TopBar({ title, description }: { title: string; description?: string }) {
  const { range, setRange, platform, setPlatform, compareMode, setCompareMode, refresh, refreshKey } = useDashboard()
  const [isRefreshing, setIsRefreshing] = useState(false)

  const handleRefresh = () => {
    setIsRefreshing(true)
    refresh()
    setTimeout(() => setIsRefreshing(false), 800)
  }

  return (
    <div className="sticky top-0 z-30 flex items-center gap-4 h-14 px-6 bg-neutral-950/90 backdrop-blur-md border-b border-white/8">
      {/* Page title */}
      <div className="min-w-0 flex-1">
        <h1 className="text-sm font-semibold text-white truncate">{title}</h1>
        {description && <p className="text-xs text-neutral-500 hidden lg:block truncate">{description}</p>}
      </div>

      {/* Range chips */}
      <div className="flex items-center gap-1 bg-neutral-900 rounded-xl p-1 border border-white/8">
        {RANGE_OPTIONS.map(opt => (
          <button
            key={opt.value}
            onClick={() => setRange(opt.value)}
            className={`px-3 py-1 rounded-lg text-xs font-medium transition-all duration-150 ${
              range === opt.value
                ? 'bg-blue-600 text-white shadow-sm'
                : 'text-neutral-400 hover:text-white hover:bg-white/5'
            }`}
          >
            {opt.label}
          </button>
        ))}
      </div>

      {/* Platform segmented control */}
      <div className="flex items-center gap-0.5 bg-neutral-900 rounded-xl p-1 border border-white/8">
        {PLATFORMS.map(p => (
          <button
            key={p.value}
            onClick={() => setPlatform(p.value)}
            className={`px-3 py-1 rounded-lg text-xs font-medium transition-all duration-150 ${
              platform === p.value
                ? p.value === 'iOS' ? 'bg-blue-600 text-white'
                  : p.value === 'Android' ? 'bg-green-600 text-white'
                  : 'bg-white/15 text-white'
                : 'text-neutral-400 hover:text-white hover:bg-white/5'
            }`}
          >
            {p.label}
          </button>
        ))}
      </div>

      {/* Compare toggle */}
      <button
        onClick={() => setCompareMode(!compareMode)}
        className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-medium border transition-all duration-150 ${
          compareMode
            ? 'bg-purple-600/20 border-purple-500/40 text-purple-300'
            : 'bg-neutral-900 border-white/8 text-neutral-400 hover:text-white hover:bg-white/5'
        }`}
      >
        <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
        </svg>
        <span className="hidden md:inline">Compare</span>
      </button>

      {/* Refresh */}
      <button
        onClick={handleRefresh}
        className="p-1.5 rounded-xl bg-neutral-900 border border-white/8 text-neutral-400 hover:text-white hover:bg-white/8 transition-all duration-150"
        title="Refresh data"
      >
        <svg className={`w-4 h-4 ${isRefreshing ? 'animate-spin' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
        </svg>
      </button>
    </div>
  )
}
```

**Step 2: TypeScript check**
```bash
cd dashboard && npx tsc --noEmit
```

**Step 3: Commit**
```bash
git add dashboard/components/layout/TopBar.tsx
git commit -m "feat(dashboard): sticky TopBar with range chips, platform filter, compare toggle"
```

---

## Task 4: Update DashboardLayout to use dynamic sidebar width + TopBar

**Files:**
- Modify: `dashboard/components/layout/DashboardLayout.tsx`

**Step 1: Rewrite DashboardLayout**

```tsx
'use client'

import React, { ReactNode } from 'react'
import Sidebar from './Sidebar'
import { useDashboard } from '@/components/providers/DashboardProvider'

export default function DashboardLayout({ children }: { children: ReactNode }) {
  const { sidebarCollapsed } = useDashboard()
  const ml = sidebarCollapsed ? 'ml-16' : 'ml-60'

  return (
    <div className="min-h-screen bg-[#0a0a0a]">
      <Sidebar />
      <main className={`${ml} min-h-screen transition-all duration-200`}>
        {children}
      </main>
    </div>
  )
}
```

**Step 2: TypeScript check**
```bash
cd dashboard && npx tsc --noEmit
```

**Step 3: Commit**
```bash
git add dashboard/components/layout/DashboardLayout.tsx
git commit -m "feat(dashboard): dynamic sidebar margin in DashboardLayout"
```

---

## Task 5: Build Sparkline component

**Files:**
- Create: `dashboard/components/charts/Sparkline.tsx`

**Step 1: Create `Sparkline.tsx`**

Pure SVG, no Recharts — lightweight and fast:
```tsx
'use client'

interface SparklineProps {
  data: number[]
  color?: string
  width?: number
  height?: number
}

export default function Sparkline({ data, color = '#4F46E5', width = 80, height = 28 }: SparklineProps) {
  if (!data || data.length < 2) return null

  const min = Math.min(...data)
  const max = Math.max(...data)
  const range = max - min || 1

  const points = data.map((v, i) => {
    const x = (i / (data.length - 1)) * width
    const y = height - ((v - min) / range) * (height - 4) - 2
    return `${x},${y}`
  })

  const pathD = `M ${points.join(' L ')}`
  const areaD = `M 0,${height} L ${points.join(' L ')} L ${width},${height} Z`

  return (
    <svg width={width} height={height} viewBox={`0 0 ${width} ${height}`} className="overflow-visible">
      <defs>
        <linearGradient id={`spark-fill-${color.replace('#', '')}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.3" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={areaD} fill={`url(#spark-fill-${color.replace('#', '')})`} />
      <path d={pathD} fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}
```

**Step 2: TypeScript check**
```bash
cd dashboard && npx tsc --noEmit
```

**Step 3: Commit**
```bash
git add dashboard/components/charts/Sparkline.tsx
git commit -m "feat(dashboard): lightweight SVG Sparkline component"
```

---

## Task 6: Redesign MetricCard with sparkline + accent border

**Files:**
- Modify: `dashboard/components/MetricCard.tsx`

**Step 1: Rewrite MetricCard**

```tsx
'use client'

import Sparkline from '@/components/charts/Sparkline'

interface MetricCardProps {
  title: string
  value: string | number
  subtitle?: string
  color?: string
  delta?: number | null
  deltaPercent?: number | null
  sparkline?: number[]
}

export default function MetricCard({
  title, value, subtitle, color = '#4F46E5',
  delta, deltaPercent, sparkline,
}: MetricCardProps) {
  const isPositive = deltaPercent != null && deltaPercent > 0
  const isNegative = deltaPercent != null && deltaPercent < 0

  return (
    <div
      className="relative rounded-2xl border border-white/8 bg-neutral-900 p-5 overflow-hidden transition-all duration-200 hover:-translate-y-0.5 group"
      style={{ boxShadow: `0 0 0 0 ${color}00` }}
    >
      {/* Accent left border */}
      <div className="absolute left-0 top-4 bottom-4 w-0.5 rounded-r-full" style={{ backgroundColor: color }} />

      {/* Subtle bg glow */}
      <div className="absolute inset-0 opacity-0 group-hover:opacity-100 transition-opacity duration-300 rounded-2xl pointer-events-none"
        style={{ background: `radial-gradient(ellipse at 0% 50%, ${color}10 0%, transparent 70%)` }} />

      <div className="relative">
        <div className="flex items-start justify-between gap-2">
          <div className="text-xs font-medium text-neutral-400 uppercase tracking-wide">{title}</div>
          {sparkline && sparkline.length > 1 && (
            <Sparkline data={sparkline} color={color} width={64} height={24} />
          )}
        </div>

        <div className="mt-2 text-2xl font-bold text-white">
          {typeof value === 'number' ? value.toLocaleString() : value}
        </div>

        <div className="mt-1.5 flex items-center gap-2">
          {deltaPercent != null && (
            <span className={`inline-flex items-center gap-0.5 text-xs font-semibold px-1.5 py-0.5 rounded-md ${
              isPositive ? 'bg-green-500/15 text-green-400'
              : isNegative ? 'bg-red-500/15 text-red-400'
              : 'bg-neutral-700 text-neutral-400'
            }`}>
              {isPositive ? '▲' : isNegative ? '▼' : ''}
              {Math.abs(deltaPercent)}%
            </span>
          )}
          {subtitle && <span className="text-xs text-neutral-500">{subtitle}</span>}
        </div>
      </div>
    </div>
  )
}
```

**Step 2: TypeScript check**
```bash
cd dashboard && npx tsc --noEmit
```

**Step 3: Commit**
```bash
git add dashboard/components/MetricCard.tsx
git commit -m "feat(dashboard): MetricCard with sparkline, accent border, hover glow"
```

---

## Task 7: Replace PageHeader with TopBar across all pages

**Files:**
- Modify: `dashboard/app/page.tsx`
- Modify: `dashboard/app/platform/page.tsx`
- Modify: `dashboard/app/screens/page.tsx`
- Modify: `dashboard/app/features/page.tsx`
- Modify: `dashboard/app/users/page.tsx`
- Modify: `dashboard/app/engagement/page.tsx`
- Modify: `dashboard/app/errors/page.tsx`

**Step 1: In each page file, swap `PageHeader` for `TopBar`**

Replace:
```tsx
import PageHeader from '@/components/layout/PageHeader'
```
With:
```tsx
import TopBar from '@/components/layout/TopBar'
```

Replace each `<PageHeader title="..." description="..." />` usage with:
```tsx
<TopBar title="..." description="..." />
```

Also wrap the rest of the page content in a `<div className="p-6 md:p-8">` so there's page padding (the TopBar is full-width sticky).

For example `app/page.tsx` becomes:
```tsx
return (
  <>
    <TopBar title="Overview" description="App-wide metrics and trends" />
    <div className="p-6 md:p-8">
      {/* ... all existing content ... */}
    </div>
  </>
)
```

Apply this same pattern to all 7 pages.

**Step 2: Remove old PageHeader import from all pages (it's still used nowhere else)**

**Step 3: TypeScript check**
```bash
cd dashboard && npx tsc --noEmit
```

**Step 4: Commit**
```bash
git add dashboard/app/
git commit -m "feat(dashboard): replace PageHeader with sticky TopBar on all pages"
```

---

## Task 8: Update Overview page with sparklines on MetricCards + content padding

**Files:**
- Modify: `dashboard/app/page.tsx`
- Modify: `dashboard/app/api/events/route.ts`

**Step 1: Add sparkline data to API response**

In `dashboard/app/api/events/route.ts`, after building `eventsOverTime`, extract per-metric sparkline arrays. Add to the return JSON:

```ts
// Extract sparkline arrays from eventsOverTime (total events per day)
const eventsSpark = eventsOverTime.map(p => (p.iOS || 0) + (p.Android || 0))
const usersSpark = usersOverTime.map(p => (p.iOS || 0) + (p.Android || 0))
```

Add `sparklines: { events: eventsSpark, users: usersSpark }` to the returned JSON object.

**Step 2: Update `OverviewData` type in `lib/types.ts`**

Add to `OverviewData`:
```ts
sparklines?: {
  events: number[]
  users: number[]
}
```

**Step 3: Update `app/page.tsx` MetricCard usages to pass sparkline**

```tsx
<MetricCard
  title="Total Events"
  value={data.totalEvents.value}
  deltaPercent={data.totalEvents.deltaPercent}
  color="#4F46E5"
  sparkline={data.sparklines?.events}
/>
<MetricCard
  title="Unique Users"
  value={data.uniqueUsers.value}
  deltaPercent={data.uniqueUsers.deltaPercent}
  color="#22C55E"
  sparkline={data.sparklines?.users}
/>
```
(DAU/WAU/MAU/Sessions don't have sparkline data yet — pass nothing, they render fine without it.)

**Step 4: TypeScript check**
```bash
cd dashboard && npx tsc --noEmit
```

**Step 5: Commit**
```bash
git add dashboard/app/page.tsx dashboard/app/api/events/route.ts dashboard/lib/types.ts
git commit -m "feat(dashboard): sparklines on Overview MetricCards"
```

---

## Task 9: Update all pages to pass `platform` param to API calls

**Files:**
- Modify: `dashboard/app/page.tsx`
- Modify: `dashboard/app/platform/page.tsx`
- Modify: `dashboard/app/screens/page.tsx`
- Modify: `dashboard/app/features/page.tsx`
- Modify: `dashboard/app/users/page.tsx`
- Modify: `dashboard/app/engagement/page.tsx`
- Modify: `dashboard/app/errors/page.tsx`

**Step 1: In every page's `fetchData`, add `platform` to context destructuring and URL**

Change:
```tsx
const { range, refreshKey } = useDashboard()
// ...
const res = await fetch(`/api/events?range=${range}`)
```

To:
```tsx
const { range, refreshKey, platform } = useDashboard()
// ...
const res = await fetch(`/api/events?range=${range}&platform=${platform}`)
```

Apply the same pattern to each page's API fetch URL:
- Overview: `/api/events?range=${range}&platform=${platform}`
- Platform: `/api/events/platform?range=${range}&platform=${platform}`
- Screens: `/api/events/screens?range=${range}&platform=${platform}`
- Features: `/api/events/features?range=${range}&platform=${platform}`
- Users: `/api/events/users?range=${range}&platform=${platform}`
- Engagement: `/api/events/engagement?range=${range}&platform=${platform}`
- Errors: `/api/events/errors?range=${range}&platform=${platform}`

Also add `platform` to the `useCallback` dependency array in each page.

**Step 2: Add `platform` filtering to API routes**

In each API route file (`dashboard/app/api/events/route.ts` and all sub-routes), read and apply the platform filter:

```ts
const platform = req.nextUrl.searchParams.get('platform') || 'all'
```

Then pass it to the RPC call. For routes that use Supabase RPC, add `p_platform: platform === 'all' ? null : platform` as a parameter if the SQL function supports it. If the RPC doesn't yet accept a platform param, apply a client-side filter after fetching:

```ts
// Client-side platform filter fallback
function filterByPlatform<T extends { platform?: string }>(rows: T[], platform: string): T[] {
  if (platform === 'all') return rows
  return rows.filter(r => r.platform === platform)
}
```

Note: Full SQL-level platform filtering requires migration changes. For now, apply client-side filtering where data has a `platform` field. The visual filter will work for tables and ranked lists immediately.

**Step 3: TypeScript check**
```bash
cd dashboard && npx tsc --noEmit
```

**Step 4: Commit**
```bash
git add dashboard/app/
git commit -m "feat(dashboard): wire platform filter to all page fetches"
```

---

## Task 10: Upgrade ChartCard with glass style

**Files:**
- Modify: `dashboard/components/ChartCard.tsx`

**Step 1: Read current ChartCard**

Read `dashboard/components/ChartCard.tsx` first, then update the card container class to:
```tsx
<div className={`rounded-2xl border border-white/8 bg-neutral-900 p-5 ${className ?? ''}`}>
```

Also update the title style:
```tsx
<h2 className="mb-4 text-xs font-semibold text-neutral-400 uppercase tracking-wide">{title}</h2>
```

**Step 2: TypeScript check + commit**
```bash
cd dashboard && npx tsc --noEmit
git add dashboard/components/ChartCard.tsx
git commit -m "feat(dashboard): ChartCard rounded-2xl glass style"
```

---

## Task 11: Polish globals.css and Tailwind config

**Files:**
- Modify: `dashboard/app/globals.css`
- Modify: `dashboard/tailwind.config.js`

**Step 1: Update `globals.css`**

Add after existing content:
```css
/* Scrollbar styling */
::-webkit-scrollbar { width: 4px; height: 4px; }
::-webkit-scrollbar-track { background: transparent; }
::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); border-radius: 9999px; }
::-webkit-scrollbar-thumb:hover { background: rgba(255,255,255,0.2); }

/* Remove focus ring on non-keyboard nav */
:focus:not(:focus-visible) { outline: none; }
```

**Step 2: Update `tailwind.config.js`**

Ensure `border-white/8` and other opacity values work by confirming opacity scale is not restricted. Add `'8': '0.08'` to the borderOpacity extend if needed:
```js
extend: {
  borderOpacity: { '8': '0.08' },
}
```

**Step 3: Commit**
```bash
git add dashboard/app/globals.css dashboard/tailwind.config.js
git commit -m "feat(dashboard): scrollbar polish and Tailwind opacity token"
```

---

## Task 12: Features page — collapsible sections

**Files:**
- Modify: `dashboard/app/features/page.tsx`

**Step 1: Add local `CollapsibleSection` component inline**

Add this above the `FeaturesPage` component:
```tsx
function CollapsibleSection({ title, color, children }: { title: string; color: string; children: React.ReactNode }) {
  const [open, setOpen] = useState(true)
  return (
    <div className="mb-6 rounded-2xl border border-white/8 bg-neutral-900 overflow-hidden">
      <button
        onClick={() => setOpen(o => !o)}
        className="w-full flex items-center justify-between px-5 py-4 hover:bg-white/3 transition-colors"
      >
        <div className="flex items-center gap-2">
          <span className="w-2 h-2 rounded-full" style={{ backgroundColor: color }} />
          <span className="text-sm font-semibold text-white">{title}</span>
        </div>
        <svg className={`w-4 h-4 text-neutral-400 transition-transform duration-200 ${open ? 'rotate-180' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      {open && <div className="px-5 pb-5">{children}</div>}
    </div>
  )
}
```

**Step 2: Replace hardcoded section divs in `FeaturesPage`**

Replace:
```tsx
<div className="mb-6 rounded-xl border border-white/10 bg-white/5 p-5">
  <h3 className="mb-4 text-sm font-medium text-neutral-300">Hydration</h3>
  ...
</div>
```

With:
```tsx
<CollapsibleSection title="Hydration" color={FEATURE_COLORS.Hydration}>
  ...
</CollapsibleSection>
```

Do the same for Medication, Workout, AI, Heart Rate sections.

**Step 3: TypeScript check + commit**
```bash
cd dashboard && npx tsc --noEmit
git add dashboard/app/features/page.tsx
git commit -m "feat(dashboard): collapsible feature sections on Features page"
```

---

## Task 13: Engagement page — session depth funnel

**Files:**
- Modify: `dashboard/app/engagement/page.tsx`
- Modify: `dashboard/lib/types.ts`
- Modify: `dashboard/app/api/events/engagement/route.ts`

**Step 1: Add `sessionFunnel` to `EngagementData` type**

In `lib/types.ts`, add to `EngagementData`:
```ts
sessionFunnel: { label: string; count: number; percent: number }[]
```

**Step 2: Compute session funnel in the engagement API route**

In `dashboard/app/api/events/engagement/route.ts`, after existing data, add:

Read the route file first to understand structure, then add after `eventsPerSessionDist` computation:
```ts
// Session depth funnel: users who had ≥N events in a session
const thresholds = [1, 2, 3, 5, 10, 20]
const totalSessions = sessionEventCounts.length
const sessionFunnel = thresholds.map(t => {
  const count = sessionEventCounts.filter((n: number) => n >= t).length
  return { label: `≥${t} event${t === 1 ? '' : 's'}`, count, percent: totalSessions ? Math.round((count / totalSessions) * 100) : 0 }
})
```

Add `sessionFunnel` to the returned JSON.

**Step 3: Add funnel visualization to `engagement/page.tsx`**

Add after the `eventsPerSessionDist` chart card:
```tsx
<div className="mb-6">
  <ChartCard title="Session Depth Funnel">
    <div className="space-y-2">
      {data.sessionFunnel.map((step, i) => (
        <div key={i} className="flex items-center gap-3">
          <span className="text-xs text-neutral-400 w-20 shrink-0">{step.label}</span>
          <div className="flex-1 h-6 bg-neutral-800 rounded-lg overflow-hidden">
            <div
              className="h-full rounded-lg transition-all duration-500"
              style={{ width: `${step.percent}%`, backgroundColor: '#3B82F6', opacity: 1 - i * 0.1 }}
            />
          </div>
          <span className="text-xs font-medium text-white w-12 text-right">{step.count.toLocaleString()}</span>
          <span className="text-xs text-neutral-500 w-10 text-right">{step.percent}%</span>
        </div>
      ))}
    </div>
  </ChartCard>
</div>
```

**Step 4: TypeScript check + commit**

Note: If the engagement API route doesn't have `sessionEventCounts` as an intermediate variable, read the route file first and adapt to what's available. If funnel data isn't computable without schema changes, skip the API step and render static placeholder funnel with `data.eventsPerSessionDist`.

```bash
cd dashboard && npx tsc --noEmit
git add dashboard/app/engagement/page.tsx dashboard/lib/types.ts
git commit -m "feat(dashboard): session depth funnel on Engagement page"
```

---

## Task 14: Users page — search filter on user table

**Files:**
- Modify: `dashboard/app/users/page.tsx`

**Step 1: Add local search state and filter**

At the top of `UsersPage`, add:
```tsx
const [userSearch, setUserSearch] = useState('')
```

Before the `DataTable`, add a search input:
```tsx
<div className="mb-3 flex items-center gap-2">
  <div className="relative flex-1 max-w-xs">
    <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-3.5 h-3.5 text-neutral-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
    </svg>
    <input
      type="text"
      value={userSearch}
      onChange={e => setUserSearch(e.target.value)}
      placeholder="Search user ID..."
      className="w-full pl-8 pr-3 py-1.5 text-xs bg-neutral-900 border border-white/8 rounded-xl text-white placeholder-neutral-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
    />
  </div>
</div>
```

Filter the data passed to `DataTable`:
```tsx
const filteredUsers = userSearch
  ? data.topUsers.filter(u => u.userId.toLowerCase().includes(userSearch.toLowerCase()))
  : data.topUsers

// Then pass filteredUsers to DataTable's data prop
```

**Step 2: TypeScript check + commit**
```bash
cd dashboard && npx tsc --noEmit
git add dashboard/app/users/page.tsx
git commit -m "feat(dashboard): user ID search filter on Users page"
```

---

## Task 15: Errors page — severity badges

**Files:**
- Modify: `dashboard/app/errors/page.tsx`

**Step 1: Add severity badge helper**

Add above the `ErrorsPage` component:
```tsx
function SeverityBadge({ message }: { message: string }) {
  const lower = message.toLowerCase()
  const isCritical = lower.includes('crash') || lower.includes('fatal') || lower.includes('unhandled')
  const isWarning = lower.includes('timeout') || lower.includes('retry') || lower.includes('failed')
  if (isCritical) return <span className="px-1.5 py-0.5 rounded text-xs font-semibold bg-red-500/20 text-red-400">critical</span>
  if (isWarning) return <span className="px-1.5 py-0.5 rounded text-xs font-semibold bg-amber-500/20 text-amber-400">warning</span>
  return <span className="px-1.5 py-0.5 rounded text-xs font-semibold bg-neutral-700 text-neutral-400">info</span>
}
```

**Step 2: Read current errors page and add SeverityBadge to the error log table column**

In the `errorLog` DataTable (or ErrorsTable), add a severity column that renders `<SeverityBadge message={row.message} />`.

**Step 3: TypeScript check + commit**
```bash
cd dashboard && npx tsc --noEmit
git add dashboard/app/errors/page.tsx
git commit -m "feat(dashboard): severity badges on Errors page"
```

---

## Task 16: Final build verification

**Step 1: Run full Next.js build**
```bash
cd dashboard && npm run build
```
Expected: Build completes with no TypeScript errors. Warnings about `any` types are acceptable (pre-existing).

**Step 2: If build fails**, read the error output carefully. Common issues:
- Missing import — add it
- `useDashboard` used in a Server Component — ensure file has `'use client'`
- `sidebarCollapsed` read during SSR — the `DashboardLayout` now uses `useDashboard` which requires `'use client'`

**Step 3: Fix `DashboardLayout` SSR issue if it appears**

Since `DashboardLayout` now calls `useDashboard()`, it must be a client component. Ensure it has `'use client'` at the top (add it if missing).

**Step 4: Final commit**
```bash
git add -A
git commit -m "feat(dashboard): complete dashboard redesign — TopBar, collapsible sidebar, sparklines, platform filter, visual polish"
```

---

## Summary of changes

| File | Change |
|------|--------|
| `lib/types.ts` | Added `Platform`, `CustomRange`, extended `DashboardContextType`, `EngagementData` |
| `providers/DashboardProvider.tsx` | Added platform, compareMode, sidebarCollapsed, customRange state |
| `layout/Sidebar.tsx` | Full rebuild: icon-rail collapse, accent active indicator |
| `layout/TopBar.tsx` | New: sticky filter bar with range chips, platform control, compare toggle |
| `layout/DashboardLayout.tsx` | Dynamic margin based on sidebar state |
| `layout/PageHeader.tsx` | No longer used (not deleted, just replaced) |
| `charts/Sparkline.tsx` | New: pure SVG sparkline |
| `MetricCard.tsx` | Redesigned with accent border, sparkline, delta badge pill, hover glow |
| `ChartCard.tsx` | Updated radius + title style |
| `app/page.tsx` | TopBar, content padding, sparklines on cards |
| All other pages | TopBar, content padding, platform param in fetches |
| `features/page.tsx` | Collapsible sections |
| `engagement/page.tsx` | Session depth funnel |
| `users/page.tsx` | User search filter |
| `errors/page.tsx` | Severity badges |
| `globals.css` | Scrollbar polish |
