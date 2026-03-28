import { supabase } from './supabase'
import { subDays, format } from 'date-fns'
import { FEATURE_CATEGORIES } from './constants'
import type { AppEvent } from './types'

const PAGE_SIZE = 1000

// ── IST offset: UTC+5:30 ──
const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000

export function toIST(date: Date): Date {
  const utc = date.getTime() + date.getTimezoneOffset() * 60000
  return new Date(utc + IST_OFFSET_MS)
}

export function getISTDay(dateStr: string): string {
  const ist = toIST(new Date(dateStr))
  return format(ist, 'yyyy-MM-dd')
}

export function getISTHour(dateStr: string): number {
  const ist = toIST(new Date(dateStr))
  return ist.getHours()
}

export function getISTDayOfWeek(dateStr: string): number {
  const ist = toIST(new Date(dateStr))
  return ist.getDay()
}

// ── Fetch all events with pagination ──
export async function fetchAllEvents(since: string, select = '*'): Promise<AppEvent[]> {
  const allRows: AppEvent[] = []
  let offset = 0
  while (true) {
    const { data, error } = await supabase
      .from('app_events')
      .select(select)
      .gte('created_at', since)
      .order('created_at', { ascending: false })
      .range(offset, offset + PAGE_SIZE - 1)

    if (error) throw error
    if (!data || data.length === 0) break

    allRows.push(...(data as unknown as AppEvent[]))
    if (data.length < PAGE_SIZE) break
    offset += PAGE_SIZE
  }
  return allRows
}

// ── Platform normalization ──
export function normalizePlatform(event: AppEvent): string {
  const raw = (event as any).platform || event.device_info?.platform || event.device_info?.os || event.properties?.platform || 'unknown'
  const lower = String(raw).toLowerCase()
  if (lower === 'ios' || lower === 'iphone' || lower === 'ipad') return 'iOS'
  if (lower === 'android') return 'Android'
  return 'Unknown'
}

// ── Screen name normalization ──
export function normalizeScreenName(event: AppEvent): string {
  return (
    event.properties?.screen ||
    event.properties?.screen_name ||
    event.properties?.screen_class ||
    event.event_name ||
    'unknown'
  )
}

// ── Feature categorization ──
export function categorizeFeature(eventName: string): string | null {
  return FEATURE_CATEGORIES[eventName] || null
}

// ── Compute delta metrics ──
export function computeDelta(current: number, previous: number): { delta: number | null; deltaPercent: number | null } {
  if (previous === 0 && current === 0) return { delta: 0, deltaPercent: 0 }
  if (previous === 0) return { delta: current, deltaPercent: null }
  const delta = current - previous
  const deltaPercent = Math.round((delta / previous) * 100)
  return { delta, deltaPercent }
}

// ── Get the "previous period" date range for delta calculation ──
export function getPreviousPeriodSince(days: number): { since: string; until: string } {
  const now = new Date()
  const until = subDays(now, days).toISOString()
  const since = subDays(now, days * 2).toISOString()
  return { since, until }
}

// ── Fetch events for a previous period ──
export async function fetchPreviousPeriodEvents(days: number, select = '*'): Promise<AppEvent[]> {
  const { since, until } = getPreviousPeriodSince(days)
  const allRows: AppEvent[] = []
  let offset = 0
  while (true) {
    const { data, error } = await supabase
      .from('app_events')
      .select(select)
      .gte('created_at', since)
      .lt('created_at', until)
      .order('created_at', { ascending: false })
      .range(offset, offset + PAGE_SIZE - 1)

    if (error) throw error
    if (!data || data.length === 0) break

    allRows.push(...(data as unknown as AppEvent[]))
    if (data.length < PAGE_SIZE) break
    offset += PAGE_SIZE
  }
  return allRows
}

// ── Get unique user count from events ──
export function uniqueUserCount(events: AppEvent[]): number {
  return new Set(events.filter(e => e.user_id).map(e => e.user_id)).size
}

// ── Get unique session count from events ──
export function uniqueSessionCount(events: AppEvent[]): number {
  return new Set(events.filter(e => e.session_id).map(e => e.session_id)).size
}

// ── Group events by day (IST) ──
export function groupByDay(events: AppEvent[]): Record<string, AppEvent[]> {
  const groups: Record<string, AppEvent[]> = {}
  for (const e of events) {
    const day = getISTDay(e.created_at)
    if (!groups[day]) groups[day] = []
    groups[day].push(e)
  }
  return groups
}

// ── Build daily time series ──
export function buildDailyTimeSeries(events: AppEvent[]): { date: string; count: number }[] {
  const counts: Record<string, number> = {}
  for (const e of events) {
    const day = getISTDay(e.created_at)
    counts[day] = (counts[day] || 0) + 1
  }
  return Object.entries(counts)
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([date, count]) => ({ date, count }))
}

// ── Build stacked platform time series ──
export function buildPlatformTimeSeries(events: AppEvent[]): { date: string; iOS: number; Android: number; Unknown: number }[] {
  const buckets: Record<string, { iOS: number; Android: number; Unknown: number }> = {}
  for (const e of events) {
    const day = getISTDay(e.created_at)
    const platform = normalizePlatform(e)
    if (!buckets[day]) buckets[day] = { iOS: 0, Android: 0, Unknown: 0 }
    if (platform === 'iOS') buckets[day].iOS++
    else if (platform === 'Android') buckets[day].Android++
    else buckets[day].Unknown++
  }
  return Object.entries(buckets)
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([date, counts]) => ({ date, ...counts }))
}

// ── Fetch exact count from app_events ──
export async function fetchCount(since: string, filter?: Record<string, any>): Promise<number> {
  let q = supabase.from('app_events').select('*', { count: 'exact', head: true }).gte('created_at', since)
  if (filter) {
    Object.entries(filter).forEach(([k, v]) => { q = q.eq(k, v) })
  }
  const { count, error } = await q
  if (error) throw error
  return count ?? 0
}
