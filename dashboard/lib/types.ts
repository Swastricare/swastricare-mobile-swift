// ── Raw event from Supabase ──
export interface AppEvent {
  id: string
  created_at: string
  user_id: string | null
  session_id: string | null
  event_type: string
  event_name: string
  properties: Record<string, any> | null
  device_info: Record<string, any> | null
}

// ── Shared ──
export interface TimeSeriesPoint {
  date: string
  count: number
}

export interface StackedTimeSeriesPoint {
  date: string
  iOS: number
  Android: number
  Unknown?: number
}

export interface NameCount {
  name: string
  count: number
}

export interface DeltaMetric {
  value: number
  delta: number | null       // absolute change
  deltaPercent: number | null // percentage change
}

// ── Overview ──
export interface OverviewData {
  totalEvents: DeltaMetric
  uniqueUsers: DeltaMetric
  dau: DeltaMetric
  wau: DeltaMetric
  mau: DeltaMetric
  sessions: DeltaMetric
  eventsOverTime: StackedTimeSeriesPoint[]
  usersOverTime: StackedTimeSeriesPoint[]
  eventsByType: Record<string, number>
  platformCounts: Record<string, number>
  topEvents: NameCount[]
  topScreens: NameCount[]
  sparklines?: {
    events: number[]
    users: number[]
  }
}

// ── Platform ──
export interface PlatformData {
  eventsIOS: number
  eventsAndroid: number
  usersIOS: number
  usersAndroid: number
  sessionsIOS: number
  sessionsAndroid: number
  avgEventsPerUserIOS: number
  avgEventsPerUserAndroid: number
  eventsOverTime: StackedTimeSeriesPoint[]
  usersOverTime: StackedTimeSeriesPoint[]
  eventTypeByPlatform: { type: string; iOS: number; Android: number }[]
  appVersions: NameCount[]
  deviceModels: NameCount[]
  topEventsIOS: NameCount[]
  topEventsAndroid: NameCount[]
}

// ── Screens ──
export interface ScreensData {
  totalScreenViews: DeltaMetric
  uniqueScreens: number
  avgViewsPerUserPerDay: number
  screenRankings: NameCount[]
  topScreensOverTime: { date: string; [screen: string]: string | number }[]
  screensByPlatform: { screen: string; iOS: number; Android: number }[]
  dwellTimes: { screen: string; avgSeconds: number; views: number }[]
  transitions: { from: string; to: string; count: number }[]
}

// ── Features ──
export interface FeaturesData {
  hydrationEvents: DeltaMetric
  medicationEvents: DeltaMetric
  workoutEvents: DeltaMetric
  aiEvents: DeltaMetric
  vaultEvents: DeltaMetric
  heartRateEvents: DeltaMetric
  featureTotals: NameCount[]
  featureTrends: { date: string; [feature: string]: string | number }[]
  featureByPlatform: { feature: string; iOS: number; Android: number }[]
  hydration: { avgAmount: number; goalCompletionRate: number }
  medication: { taken: number; skipped: number; snoozed: number; sourceBreakdown: Record<string, number> }
  workout: { activityTypes: Record<string, number>; avgDuration: number; completionRate: number }
  ai: { modeDistribution: Record<string, number>; messageTrend: TimeSeriesPoint[] }
  heartRate: { avgBpm: number; bpmDistribution: { bucket: string; count: number }[] }
}

// ── Users ──
export interface UsersData {
  totalUsers: DeltaMetric
  newUsers: DeltaMetric
  returningUsers: DeltaMetric
  avgEventsPerUser: number
  avgSessionsPerUser: number
  newVsReturning: { date: string; new: number; returning: number }[]
  activityDistribution: { bucket: string; count: number }[]
  topUsers: {
    userId: string
    events: number
    sessions: number
    firstSeen: string
    lastSeen: string
    platform: string
  }[]
  dailyRetention: { date: string; rate: number }[]
  loginMethods: Record<string, number>
  loginFailures: Record<string, number>
  logoutCount: number
}

// ── Engagement ──
export interface EngagementData {
  avgSessionDuration: number
  avgEventsPerSession: number
  peakHour: number
  peakDay: string
  heatmap: { day: number; hour: number; count: number }[]
  eventsByHour: { hour: number; count: number }[]
  eventsByDay: { day: string; count: number }[]
  sessionDurationDist: { bucket: string; count: number }[]
  eventsPerSessionDist: { bucket: string; count: number }[]
  tabNavigation: NameCount[]
  appOpensOverTime: TimeSeriesPoint[]
  sessionFunnel: { label: string; count: number; percent: number }[]
}

// ── Errors ──
export interface ErrorsData {
  totalErrors: DeltaMetric
  uniqueErrorTypes: number
  errorRate: number
  usersAffected: number
  errorTrend: TimeSeriesPoint[]
  errorRateOverTime: { date: string; rate: number }[]
  errorsByCategory: Record<string, number>
  errorsByPlatform: Record<string, number>
  topErrorMessages: { message: string; count: number; lastSeen: string }[]
  errorLog: {
    name: string
    message: string
    properties: Record<string, any> | null
    created_at: string
    user_id: string | null
    platform: string
  }[]
  errorLogTotal: number
}

// ── Dashboard context ──
export type TimeRange = '1' | '7' | '14' | '30' | '90'

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
