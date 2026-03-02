# MedicationsView Full Overhaul Design

## Date: 2026-03-02

## Summary

Replace the MedicationsView's circular progress ring with an animated pill bottle filling up, restructure medication cards into a chronological timeline layout, and add an Ask AI button.

## 1. Progress Section — Pill Bottle Animation

### PillBottleShape (custom Shape)

Draws a medicine bottle silhouette:
- Rectangular body with rounded corners
- Narrow neck at top with a cap/lid
- Approximate size: 120pt tall, 80pt wide

### PillBottleView (animated component)

Same animation pattern as WaterGlassView in HydrationView:
- `@State wavePhase` drives continuous wave animation
- `@State visualProgress` animates from 0 to actual adherence percentage on appear
- Bottle outline stroked with teal (#11998e) at reduced opacity
- Fill uses shared `WaterWave` shape (from DesignSystem.swift), colored teal, clipped to bottle body
- Two wave layers (back + front) for depth
- Percentage text centered inside the bottle
- Green checkmark when 100% adherence

Below the bottle: horizontal row of stat pills (same pattern as HydrationView's `statPill`):
- Taken count (teal)
- Remaining count (orange)
- Adherence % (green)

## 2. Medication Cards — Timeline Layout

Replace flat LazyVStack with a vertical timeline grouped by scheduled time:

```
8:00 AM ── ● ── [Card: Metformin 500mg]     ✓ taken
                [Card: Vitamin D3]           ✓ taken

2:00 PM ── ● ── [Card: Omeprazole 20mg]     ⏰ upcoming

9:00 PM ── ● ── [Card: Metformin 500mg]     ○ pending
                [Card: Melatonin 5mg]        ○ pending
```

### Timeline structure

- Time labels on the left side, connected by a vertical line
- Dot indicator at each time slot: green (all taken), red (overdue), gray (pending)
- Cards branch to the right of each time marker
- Vertical connecting line runs the full height between first and last time slot

### Simplified cards

- Keep: medication type icon, name, dosage, status indicator, quick-take checkmark button
- Remove: per-card mini progress ring (the pill bottle handles overall progress)
- Status shown as colored badge text (Taken/Overdue/Upcoming/Pending)

### Data grouping

Group `viewModel.todaysMedications` by scheduled time. Each `MedicationWithAdherence` has dose records with `scheduledTime` — group by hour:minute to create timeline slots.

## 3. Other Changes

- Enable `PremiumBackground()` (currently commented out on line 24)
- Add "Ask AI about my medications" button at bottom of scroll content (same pattern as HydrationView)
- Calendar strip: no changes (already good)
- Skeleton loading view: no changes
- Empty state view: no changes

## Files Modified

| File | Change |
|------|--------|
| `Views/Home/MedicationsView.swift` | Full rewrite: PillBottleShape, PillBottleView, timeline layout, progressSection, AI button |

No new files needed. WaterWave is already shared in DesignSystem.swift.

## Verification

1. `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build`
2. Pill bottle animates with wave fill matching adherence percentage
3. Timeline groups medications by scheduled time with correct status indicators
4. Quick-take checkmark still works on timeline cards
5. Ask AI button navigates to AI tab
