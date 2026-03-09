# AI Health Context Integration - Design Document

**Date**: 2026-03-09
**Platform**: Android
**Approach**: Client-Side Health Context Builder (Always-on)

## Summary

Give the AI chat screen access to all health data so it can provide contextual, personalized health insights. A new `HealthContextProvider` class aggregates data from all repositories and builds a structured text summary sent with every AI message via the existing `healthContext` parameter.

## Requirements

- AI always knows the user's current health state (no manual "Analyze My Health" trigger needed)
- Data sources: HealthConnect vitals, hydration, diet, medications, run activity, menstrual cycle, vault documents, user profile
- Vault: metadata always included; actual document content fetched on-demand via vision model
- Timeframes: today for real-time metrics, rolling 7 days for trend data
- Graceful degradation: omit sections when data is unavailable or permissions denied

## Architecture

```
AIViewModel.sendMessage()
    → HealthContextProvider.buildContext()
    → attach to ChatRequest.healthContext
    → AIService → ai-router edge function
    → forwarded to ai-chat / medgemma-chat system prompt
```

### HealthContextProvider Dependencies

- ProfileRepository (static: age, gender, height, weight, blood type)
- HealthConnectService (today: steps, heart rate, sleep, calories, exercise, distance)
- HydrationRepository (today: intake, goal, drink breakdown)
- DietRepository (today: meals & macros; 7 days: calorie trend)
- MedicationRepository (today: adherence; 7 days: adherence %; active meds list)
- RunActivityRepository (7 days: recent activities)
- MenstrualCycleRepository (current: phase, cycle day, symptoms, mood)
- VaultRepository (all: document metadata — title, category, date, doctor, tags)

## Data Collected Per Message

| Source | Timeframe | Data Points |
|--------|-----------|-------------|
| Profile | Static | Age, gender, height, weight, blood type |
| HealthConnect | Today | Steps, heart rate, sleep, calories, exercise mins, distance |
| Hydration | Today | Total intake, goal, drink breakdown |
| Diet | Today + 7 days | Today's meals & macros, weekly calorie trend |
| Medications | Today + 7 days | Today's adherence, weekly adherence %, active meds |
| Run Activity | 7 days | Recent activities (type, distance, duration, pace) |
| Menstrual Cycle | Current | Phase, cycle day, recent symptoms/mood |
| Vault | All | Document metadata (title, category, date, doctor, tags) |

## Context Format

Plain text structured with section headers, sent as `healthContext` string:

```
=== HEALTH PROFILE ===
Age: 28 | Gender: Female | Height: 165cm | Weight: 58kg | Blood Type: B+

=== TODAY'S VITALS ===
Steps: 4,230 | Heart Rate: 72 bpm | Sleep: 7h 15m | Active Calories: 180 | Exercise: 22 min

=== HYDRATION (Today) ===
Intake: 1,200ml / 2,500ml goal (48%) | Water: 800ml, Tea: 200ml, Coffee: 200ml

=== DIET ===
Today: Breakfast (420 cal), Lunch (650 cal) | Total: 1,070 / 2,000 cal goal
Weekly avg: 1,850 cal/day | Protein: 65g, Carbs: 220g, Fat: 58g avg

=== MEDICATIONS (Today) ===
Active: Metformin 500mg (taken), Vitamin D (pending)
Weekly adherence: 85% (6/7 days fully taken)

=== ACTIVITY (Last 7 days) ===
3 activities: Running 5.2km (Mar 8), Walking 3.1km (Mar 7), Cycling 12km (Mar 5)

=== MENSTRUAL CYCLE ===
Phase: Follicular (Day 8) | Last period: Mar 1-5 | Recent symptoms: mild cramps, fatigue

=== MEDICAL VAULT ===
8 documents: Blood Test (Dr. Sharma, Feb 2026), X-Ray Chest (Jan 2026), ...
```

## Vault Document Deep Access

- Metadata is always in the context string
- When user asks about a specific document (e.g., "what did my blood test show?"):
  1. Fetch signed URL from VaultRepository
  2. Download document image/PDF
  3. Pass via existing `imageData` field to vision model (MedGemma 4B)

## Files to Change

| File | Change |
|------|--------|
| **New: `data/services/HealthContextProvider.kt`** | Aggregates all repos into context string |
| `ui/screens/ai/AIViewModel.kt` | Inject HealthContextProvider, call buildContext() before send |
| `data/models/AIModels.kt` | Add healthContext field to ChatRequest |
| `data/services/AIService.kt` | Pass healthContext in edge function payload |
| `di/AppContainer.kt` | Register HealthContextProvider with all repo dependencies |
| `supabase/functions/ai-router/index.ts` | Forward healthContext to sub-functions |
| `supabase/functions/ai-chat/index.ts` | Include healthContext in system prompt |
| `supabase/functions/medgemma-chat/index.ts` | Include healthContext in system prompt |

## Edge Cases

- **No data**: Section omitted from context if repository returns empty
- **Permissions denied**: HealthConnect section omitted if no read permissions
- **Offline**: Uses local cache — context may be slightly stale but still useful
- **Large vault**: Only include last 20 documents metadata to limit payload size
- **Health profile not found**: Omit profile section, AI still works with available data
