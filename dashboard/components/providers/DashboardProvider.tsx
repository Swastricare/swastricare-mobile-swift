'use client';

import React, { createContext, useContext, useState, ReactNode } from 'react';
import type { TimeRange } from '@/lib/types';

interface DashboardContextValue {
  range: TimeRange;
  setRange: (range: TimeRange) => void;
  refreshKey: number;
  refresh: () => void;
}

const DashboardContext = createContext<DashboardContextValue | undefined>(undefined);

interface DashboardProviderProps {
  children: ReactNode;
}

export function DashboardProvider({ children }: DashboardProviderProps) {
  const [range, setRange] = useState<TimeRange>('7');
  const [refreshKey, setRefreshKey] = useState(0);

  const refresh = () => {
    setRefreshKey((prev) => prev + 1);
  };

  const value: DashboardContextValue = {
    range,
    setRange,
    refreshKey,
    refresh,
  };

  return (
    <DashboardContext.Provider value={value}>
      {children}
    </DashboardContext.Provider>
  );
}

export function useDashboard() {
  const context = useContext(DashboardContext);
  if (context === undefined) {
    throw new Error('useDashboard must be used within a DashboardProvider');
  }
  return context;
}
