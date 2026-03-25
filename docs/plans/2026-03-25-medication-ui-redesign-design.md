# Medication UI Redesign — Native iOS System Design

**Date:** 2026-03-25
**Scope:** All 3 medication screens (MedicationsView, AddMedicationView, MedicationDetailView)
**Approach:** Native iOS System Design — no PremiumBackground, no .glass(), proper light/dark theme support

## Core Principles

- Use UIKit adaptive system colors exclusively (systemGroupedBackground, secondarySystemGroupedBackground, tertiarySystemFill)
- Unified accent: `AppColors.medication` (#5856D6) replaces all medBlue/accentBlue references within medication screens
- No `.glass()` modifier — replaced with solid system background cards
- No `PremiumBackground()` — plain grouped background

## MedicationsView

- **Background:** `Color(.systemGroupedBackground).ignoresSafeArea()`
- **Calendar strip:** Selected = filled circle with `AppColors.medication`, today unselected = ring outline, others = plain
- **Progress section:** `secondarySystemGroupedBackground` card, PillBottleView recolored to `AppColors.medication`, 3 stat pills with semantic color backgrounds at 0.1 opacity
- **Timeline cards:** `secondarySystemGroupedBackground`, cornerRadius 14, no glass
- **Quick-take checkmark:** `AppColors.accentGreen` (replaces teal #11998e)
- **Ask AI button:** `accentBlue` tint on `secondarySystemGroupedBackground`
- **Skeleton loading:** system grouped background cards, no glass
- **Empty state:** Icon uses `AppColors.medication.opacity(0.15)`, CTA uses `AppColors.medication` solid fill

## AddMedicationView

- **Background:** `Color(.systemGroupedBackground).ignoresSafeArea()`
- **Section wrappers:** `secondarySystemGroupedBackground` + cornerRadius 16 (replaces .glass)
- **All chips (type, schedule, duration, preset):** Selected = `AppColors.medication` fill + white text, Unselected = `tertiarySystemFill` + primary text
- **Text fields:** `tertiarySystemFill` background
- **Drug search field:** `secondarySystemGroupedBackground`
- **Drug info section:** `secondarySystemGroupedBackground` outer, keep ExpandableInfoRow internal tints
- **Calculated date banner:** Keep teal green (#10B981) — distinct computed-result signal
- **Notes TextEditor:** `tertiarySystemFill`, no manual border
- **Save button:** Enabled = `AppColors.medication` solid (no gradient), Disabled = `tertiarySystemFill`
- **Color unification:** Replace all `medBlue`/`medPurple` with `AppColors.medication`

## MedicationDetailView

- **Background:** `Color(.systemGroupedBackground)` (already present)
- **Header card:** `secondarySystemGroupedBackground` cornerRadius 16, icon accent = `AppColors.medication`
- **DoseCard:** `secondarySystemGroupedBackground` cornerRadius 14 (replaces .glass)
- **Details section:** Outer = `secondarySystemGroupedBackground` cornerRadius 16, inner DetailRow = `tertiarySystemFill` cornerRadius 12
- **Edit form:** `secondarySystemGroupedBackground` cornerRadius 16, TextEditor = `tertiarySystemFill`
- **Adherence history:** `secondarySystemGroupedBackground` cornerRadius 16
- **Toggle tint:** `AppColors.medication`
- **Toolbar Edit/Save:** `AppColors.medication`
- **Delete button:** Keep red destructive styling

## Shared Component Changes

- `PremiumTextFieldStyle`: Already uses `tertiarySystemFill` — no change needed
- `TimelineSlot.dotColor`: Keep green/red/secondary — semantic
- `PillBottleView`: Recolor teal (#11998e) to `AppColors.medication`
