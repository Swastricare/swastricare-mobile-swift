'use client'

import React, { useState } from 'react'
import { useDashboard } from '@/components/providers/DashboardProvider'
import { RANGE_OPTIONS } from '@/lib/constants'
import type { Platform, Theme } from '@/lib/types'

const PLATFORMS: { label: string; value: Platform }[] = [
  { label: 'All', value: 'all' },
  { label: 'iOS', value: 'iOS' },
  { label: 'Android', value: 'Android' },
]

const THEME_CYCLE: Theme[] = ['dark', 'black', 'light']

function ThemeIcon({ theme }: { theme: Theme }) {
  if (theme === 'light') return (
    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364-6.364l-.707.707M6.343 17.657l-.707.707M17.657 17.657l-.707-.707M6.343 6.343l-.707-.707M12 7a5 5 0 100 10A5 5 0 0012 7z" />
    </svg>
  )
  if (theme === 'black') return (
    <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
      <circle cx="12" cy="12" r="9" />
    </svg>
  )
  // dark
  return (
    <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
    </svg>
  )
}

const THEME_LABELS: Record<Theme, string> = {
  dark: 'Dark',
  black: 'Pitch Black',
  light: 'Light',
}

export default function TopBar({ title, description }: { title: string; description?: string }) {
  const { range, setRange, platform, setPlatform, compareMode, setCompareMode, refresh, theme, setTheme } = useDashboard()
  const [isRefreshing, setIsRefreshing] = useState(false)

  const handleRefresh = () => {
    setIsRefreshing(true)
    refresh()
    setTimeout(() => setIsRefreshing(false), 800)
  }

  const cycleTheme = () => {
    const idx = THEME_CYCLE.indexOf(theme)
    setTheme(THEME_CYCLE[(idx + 1) % THEME_CYCLE.length])
  }

  return (
    <div className="sticky top-0 z-30 flex items-center gap-3 h-14 px-6 bg-neutral-950/90 backdrop-blur-md border-b border-white/[0.08]">
      {/* Page title */}
      <div className="min-w-0 flex-1">
        <h1 className="text-sm font-semibold text-white truncate">{title}</h1>
        {description && <p className="text-xs text-neutral-500 hidden lg:block truncate">{description}</p>}
      </div>

      {/* Range chips */}
      <div className="flex items-center gap-1 bg-neutral-900 rounded-xl p-1 border border-white/[0.08]">
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
      <div className="flex items-center gap-0.5 bg-neutral-900 rounded-xl p-1 border border-white/[0.08]">
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
            : 'bg-neutral-900 border-white/[0.08] text-neutral-400 hover:text-white hover:bg-white/5'
        }`}
      >
        <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7h12m0 0l-4-4m4 4l-4 4m0 6H4m0 0l4 4m-4-4l4-4" />
        </svg>
        <span className="hidden md:inline">Compare</span>
      </button>

      {/* Theme switcher */}
      <button
        onClick={cycleTheme}
        title={`Theme: ${THEME_LABELS[theme]} — click to switch`}
        className="p-1.5 rounded-xl bg-neutral-900 border border-white/[0.08] text-neutral-400 hover:text-white hover:bg-white/[0.08] transition-all duration-150"
      >
        <ThemeIcon theme={theme} />
      </button>

      {/* Refresh */}
      <button
        onClick={handleRefresh}
        className="p-1.5 rounded-xl bg-neutral-900 border border-white/[0.08] text-neutral-400 hover:text-white hover:bg-white/[0.08] transition-all duration-150"
        title="Refresh data"
      >
        <svg className={`w-4 h-4 ${isRefreshing ? 'animate-spin' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
        </svg>
      </button>
    </div>
  )
}
