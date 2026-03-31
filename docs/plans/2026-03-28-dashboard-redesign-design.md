# Dashboard Redesign Design

**Date:** 2026-03-28
**Scope:** SwasthiCare Analytics Dashboard (`dashboard/`)
**Goal:** Advanced layout, global filters, sparklines, comparison mode, visual polish

---

## Layout Architecture

### Left Sidebar (240px → 64px collapsible)
- Collapse toggle button at top-right of sidebar
- Nav items: icon + label. Collapsed: icon only with tooltip.
- Active state: accent-colored left border pill + `bg-white/10`
- Bottom: app version label
- State: `sidebarCollapsed` boolean in localStorage + `DashboardProvider`

### Top Bar (sticky, 56px, full width)
- `bg-neutral-900/80 backdrop-blur-md border-b border-white/8`
- Left: page breadcrumb
- Center: date range preset chips (`24h` `7d` `14d` `30d` `90d` `Custom`) — pill buttons, active = filled
- Custom: calendar popover with `startDate` / `endDate` inputs (date-fns)
- Right: platform segmented control (`All` | `iOS` | `Android`), compare toggle (`vs. prev period`), refresh button + live timestamp

---

## Global State (DashboardProvider)

New fields added:
```ts
sidebarCollapsed: boolean
platform: 'all' | 'iOS' | 'Android'
compareMode: boolean
customRange: { start: string; end: string } | null
```

All API calls gain `platform` and `compare` query params. Compare responses include `{ current: [...], previous: [...] }` shape.

---

## MetricCard Redesign

- Left: accent-color `4px` border-left on card
- Top: `text-xs text-neutral-400` label
- Middle: `text-2xl font-bold` value + delta badge (`▲▼` colored pill)
- Bottom: `SparklineChart` — 7-point inline SVG area chart in accent color at 20% opacity fill
- Hover: `translate-y-[-2px] shadow-lg shadow-accent/10`

New component: `components/charts/Sparkline.tsx` — lightweight SVG, no Recharts dependency.

---

## Overview Page

### KPI Row
6 MetricCards with sparklines: Total Events, Unique Users, DAU, WAU, MAU, Sessions

### Primary Chart (full width)
`EventsUsersTimeChart` — dual-axis area chart:
- Left Y: events (iOS + Android stacked or grouped toggle)
- Right Y: unique users line
- Bottom: zoom brush (Recharts `Brush`)
- Compare mode: dashed lines for previous period

### Secondary Row (3 columns)
- Events by Type: `HorizontalBarChart` sortable
- Platform Split: `DonutChart` with center total count
- Top Screens: `RankedList` with fill bars

### Bottom Row (2 columns)
- Top Events ranked list
- Retention curve (area chart)

---

## Page-Level Upgrades

### Platform Page
- iOS vs Android side-by-side stat cards (delta between platforms)
- Version adoption: stacked bar by app version
- Platform filter in top bar filters this page too

### Features Page
- Each feature section collapsible (open by default)
- Adoption % ring (donut showing % of total users who used feature)
- Drilldown: expandable event list table per feature
- Feature selector chips to show/hide features from trend chart

### Users Page
- Retention cohort heatmap (week × cohort grid, colored by retention %)
- Sparklines in user table (activity over time per user row)
- Search input to filter user table by ID prefix

### Engagement Page
- Session depth funnel (Events 1→2→3→5→10→20+ per session)
- Heatmap tooltips with exact count + % of peak

### Errors Page
- Severity badges (`critical` / `warning` / `info`)
- Error rate trend sparkline per error type
- Group by screen toggle

---

## Visual Language

| Token | Value |
|-------|-------|
| Background | `#0a0a0a` |
| Card bg | `bg-neutral-900` |
| Card border | `border border-white/8` |
| Card radius | `rounded-2xl` |
| Top bar bg | `bg-neutral-900/80 backdrop-blur-md` |
| Active nav | `border-l-2 border-[accent] bg-white/10` |
| Transition | `transition-all duration-200` |
| Font scale | `text-xs` labels / `text-2xl` values / `text-sm` subtitles |

Chart tooltips: custom `TooltipContent` component — `bg-neutral-800 border border-white/10 rounded-xl px-3 py-2 text-xs` with multi-series rows and compare period in muted color.

---

## Implementation Order

1. `DashboardProvider` — add `platform`, `compareMode`, `sidebarCollapsed`, `customRange`
2. `Sidebar` — collapse toggle, icon-only mode
3. `TopBar` — new component replacing `PageHeader` global controls
4. `Sparkline` — lightweight SVG component
5. `MetricCard` — redesign with sparkline + accent border
6. `Overview` page — full rebuild with new layout
7. `Platform`, `Features`, `Users`, `Engagement`, `Errors` pages — targeted upgrades
8. API routes — add `platform` + `compare` query param support
