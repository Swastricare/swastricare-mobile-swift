# iOS Responsive Layout Refactor — Phase 1

**Date:** 2026-05-13
**Scope:** HomeView, VaultView, AIView, RunActivityView, ContentView tab bar, shared helpers in `DesignSystem.swift`.
**Out of scope (phase 2+):** Profile tab, ~35 other screens, `HomeViewV2.swift` (dead code).

## Problem

UI is calibrated for ~390pt width (iPhone 15 Pro). On 16 Pro Max (430pt) the layout looks centered and underscaled: cards don't expand, fonts/icons feel small, dividers and spacings are inconsistent, the bottom tab bar floats narrow.

## Approach — Hybrid

- **Scale factor** for fonts + icons + padding magnitudes so the UI feels right-sized on Pro Max.
- **Native adaptive layout** (`maxWidth: .infinity`, `LazyVGrid` with `GridItem(.flexible())`) for structure. No `GeometryReader` inside cards.

### Width buckets and scale

```swift
enum ResponsiveScale: CGFloat {
    case compact = 1.0   // width ≤ 390  (15 Pro, mini, SE)
    case regular = 1.06  // 391–428      (15 Pro Max, 16 Pro)
    case large   = 1.12  // ≥ 429        (16 Pro Max, future plus sizes)
}
```

Bucketed by **width**, not device — future-proof. Read once at `ContentView` root, injected via `@Environment(\.responsiveScale)`.

## Helpers added to `DesignSystem.swift`

- `ResponsiveScale` enum + `EnvironmentKey` + `View.responsive()` modifier (root install).
- `AppFont` — `title`, `headline`, `body`, `caption`, `metric` (large numeric); each takes `ResponsiveScale` and returns a `Font`.
- `AppDimensions` extension — scaled variants of existing constants: `cardPadding(_:)`, `quickActionHeight(_:)`, `iconSize(_:)`, `sectionSpacing(_:)`, `screenPadding(_:)`. Existing static constants stay so untouched screens keep working.
- `View.appDivider()` — consistent 0.5pt divider.

## Layout rules

1. Replace `.frame(width:)` on full-width cards with `.frame(maxWidth: .infinity)`.
2. 2×N stat grids → `LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())])`.
3. Horizontal screen padding: 16 / 18 / 20 by bucket.
4. Vertical section spacing: 16 / 18 / 22 by bucket.
5. Icons via `.iconSize(scale)` — no hardcoded `.frame(24)`.
6. Dividers via `.appDivider()`.

## Per-screen scope

| Screen | Fixes |
|---|---|
| `ContentView` tab bar | Span `maxWidth: .infinity`, items distribute via `Spacer()`, scaled horizontal padding and icon size |
| `HomeView` | Daily activity card: scaled padding + flexible alignment. 2×3 stat grid → `LazyVGrid`. 4 quick actions → `LazyVGrid(.flexible × 2)` with scaled height. Vitals dividers via `.appDivider()` |
| `VaultView` | Cards `maxWidth: .infinity`, scaled padding/spacing |
| `AIView` | Composer full width, message bubbles use scaled font and padding |
| `RunActivityView` | Stat cards in flexible grid; `AppFont.metric(scale)` on big numbers |

## Out of scope (phase 1)

- Profile tab and 35+ other screens
- `HomeViewV2.swift` (dead)
- Colors, gradients, glass effect, brand language
- `.pbxproj` / `Info.plist` edits

## Verification

- After each screen: `xcodebuild -scheme swastricare-mobile-swift -sdk iphonesimulator -configuration Debug build`.
- After full phase 1: install on physical iPhone (FEC4D85A...) per standing instruction.
- Visual check on simulators: iPhone SE (3rd gen), 15 Pro, 16 Pro Max.

## Trade-offs

- Scale-factor pollution: each scaled call site reads `@Environment(\.responsiveScale)`. Accepted for explicitness and debuggability.
- Existing static `AppDimensions` constants stay alongside scaled variants during phase 1 to avoid breaking the 35 untouched screens. Cleanup in phase 2.
