# P2: UI/Design Polish — Design Doc

> **Date**: 2026-03-04 | **Branch**: android-nikhil | **Scope**: Android alignment to iOS design system

## Goal

Match Android's visual design to iOS across colors, typography, animations, and components. Use iOS exact hex values as the source of truth.

## Color Alignment (P2-1)

### Changes to `Color.kt`

| Token | Current Android | Target (iOS exact) |
|-------|----------------|-------------------|
| PrimaryColor | `#5E5CE6` | `#4F46E5` |
| SecondaryColor | `#32D74B` | `#22C55E` |
| AccentColor | `#FF375F` | `#EF4444` |
| HeartRateColor | `#FF3B30` | `Color.Red` (system, keep `#FF3B30` as iOS equivalent) |
| StepsColor | `#30D158` | keep (close to iOS `Color.green`) |
| HydrationColor | `#00C7BE` | keep (close to iOS `Color.cyan`) |
| MedicationColor | `#5856D6` | keep (matches iOS) |

### Glass modifier alignment
- Stroke width: 0.8dp → 0.5dp (match iOS)
- Keep glass opacity at 0.25f (close to `.ultraThinMaterial`)

### Corner radius standardization
- Cards: 16dp (match iOS `cardRadius`)
- Large cards: 20dp (match iOS `largeCardRadius`)
- Pills: 20dp
- Quick actions: 24dp

## Typography (P2-2)

Keep Roboto (Android system font). Ensure visual weight parity with iOS SF Pro by matching sp values:
- Headlines: 28sp/22sp/18sp (current, close to iOS)
- Adjust text opacity for secondary/tertiary text to match iOS patterns

## Animations (P2-3)

| Animation | iOS | Android Target |
|-----------|-----|---------------|
| Shimmer duration | 1.5s | 1500ms (was 1200ms) |
| Button press scale | 0.95x | 0.95f (already matches) |
| Spring params | 0.3/0.7 | Match via dampingRatio/stiffness |
| PremiumBackground | Static orbs | Keep animated (Android advantage) |
| Water wave | WaterWave shape | Already implemented |
| Haptic feedback | On tab/button press | Add where missing |

## Components (P2-4)

- **PremiumButton**: Add secondary (outline) and ghost styles to match iOS
- **GlassCard**: Align stroke width
- **NudgeCard**: Match iOS card width (240dp) and transition
- **CalorieProgressRing**: Verify 140dp size, lineWidth 16dp
- **MacroBreakdownBar**: Match corner radius 6dp

## Screen Audit (P2-5)

Verify all screens after applying P2-1 through P2-4 changes. Focus on spacing, padding, card layouts.

## Approach

Execute changes in order: Colors → Glass → Typography → Animations → Components → Screen audit. Use parallel agents for independent file changes.
