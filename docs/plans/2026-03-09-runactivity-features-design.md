# RunActivity Features Design

Date: 2026-03-09

## Features

### 1. GPX Export
- `GpxExporter` generates GPX 1.1 XML from `RouteCoordinate` list
- Writes to app cache dir, shares via `FileProvider` + `Intent.ACTION_SEND` with `application/gpx+xml`
- "Export GPX" button in `ActivityDetailTopBar`

### 2. Workout Templates
- `WorkoutTemplate` model: name, type, target distance/duration/pace (all optional)
- Stored in SharedPreferences as JSON (local-only)
- Template cards in `IdlePhaseContent` with horizontal scroll
- 4 built-in defaults: Easy Run 5K, Long Run 10K, Walk 30min, Interval Training
- Save current workout as template from summary screen

### 3. Elevation Profile Chart
- New `ELEVATION` tab in `ActivityDetailScreen`
- Canvas area chart: altitude vs distance from `RouteCoordinate.altitude`
- Shows min/max/gain stats above chart
- Green gradient fill, grid lines

### 4. VO2Max + Training Load
- **VO2Max**: Read `Vo2MaxRecord` from Health Connect (primary). Fallback: Cooper formula from runs >= 12 min
- **Training Load**: TRIMP score = `duration_minutes * intensity_factor` (pace relative to best pace)
- **Weekly Load**: Sum of last 7 days, displayed as bar on dashboard
- `FitnessAnalyticsService` handles all calculations
- "Fitness" card on `RunActivityScreen` below today's stats

### 5. Battery-Aware GPS
- `RouteTracker` checks `BatteryManager` on start + every 60s
- `>20%`: HIGH_ACCURACY, 3s/2m (current)
- `10-20%`: BALANCED_POWER, 5s/5m
- `<10%`: LOW_POWER, 10s/10m
- Battery-mode chip next to GPS status during tracking

## New Files
| File | Purpose |
|------|---------|
| `data/services/GpxExporter.kt` | GPX XML generation + file share |
| `data/services/FitnessAnalyticsService.kt` | VO2Max read/estimate + Training Load |
| `data/models/WorkoutTemplate.kt` | Template model + persistence |
| `ui/screens/runactivity/ElevationProfileChart.kt` | Canvas elevation chart |

## Modified Files
| File | Changes |
|------|---------|
| `RouteTracker.kt` | Battery check, dynamic LocationRequest |
| `LiveWorkoutViewModel.kt` | Battery mode state, template target |
| `LiveWorkoutScreen.kt` | Template cards, battery chip, target overlay |
| `RunActivityScreen.kt` | Fitness card (VO2Max + weekly load) |
| `ActivityDetailScreen.kt` | ELEVATION tab, GPX export button |
| `HealthConnectService.kt` | Vo2MaxRecord read permission + getter |
| `AppContainer.kt` | Register new services |
