# Custom Bottom Navigation Bar — Design

**Date:** 2026-03-07
**Platform:** Android (Jetpack Compose)
**Status:** Approved

## Goal

Replace the standard Material3 `NavigationBar` in `MainScaffold.kt` with a fully custom, production-grade bottom navigation bar. No Material icon usage. Phosphor Icons library. Per-tab semantic colors. Spring bounce + icon fill animations. No floating style.

## Files Affected

- `android/app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/MainScaffold.kt` — replace `MainBottomNavigation`
- `android/app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/NavConfig.kt` — extend `BottomNavTab` with color + Phosphor icon refs
- `android/app/build.gradle.kts` — add Phosphor Icons dependency

## Dependency

```
implementation("com.adamglin:phosphor-icons:2.1.0")
```

## Tab Configuration

| Tab     | Phosphor Icon (unselected) | Phosphor Icon (selected) | Semantic Color           | Hex     |
|---------|---------------------------|--------------------------|--------------------------|---------|
| Vitals  | `PhosphorIcons.Heart`     | `PhosphorIcons.HeartFill`| `HeartRateColor`         | #FF3B30 |
| Vault   | `PhosphorIcons.Lock`      | `PhosphorIcons.LockFill` | `MedicationColor`        | #5856D6 |
| AI      | `PhosphorIcons.Sparkle`   | `PhosphorIcons.SparkleFill` | `PrimaryColor`        | #4F46E5 |
| Steps   | `PhosphorIcons.Sneaker`   | `PhosphorIcons.SneakerFill` | `StepsColor`          | #30D158 |
| Profile | `PhosphorIcons.User`      | `PhosphorIcons.UserFill` | `SystemBlue`             | #007AFF |

## Visual Spec

### Bar
- Height: 72dp
- Background: `SurfaceLight` (white) / `SurfaceDark` (#1C1C1E)
- Top border: 1dp hairline in `outlineVariant` color
- No elevation / no shadow
- Edge-to-edge: uses `WindowInsets.navigationBars` padding

### Tab Item (per slot)
- Equal width (1/5 of screen)
- Vertically stacked: pill background + icon + label
- Pill: rounded rect behind icon, height ~36dp, width animates from icon-width to ~72dp on select
- Pill fill alpha: `animateFloatAsState` 0f → 0.13f, tab semantic color

### Label
- `AnimatedVisibility` fade+slide down, shown only when selected
- Font: `labelSmall` (11sp, medium weight)
- Color: tab semantic color when selected, `onSurfaceVariant` when unselected

## Animation Spec

| Property        | Mechanism                              | Values                                    |
|----------------|----------------------------------------|-------------------------------------------|
| Icon scale      | `animateFloatAsState(spring(...))`     | 1.0f → 1.18f, DampingRatioMediumBouncy   |
| Icon tint       | `animateColorAsState(tween(250ms))`    | `onSurfaceVariant` → tab semantic color   |
| Pill alpha      | `animateFloatAsState(tween(200ms))`    | 0f → 0.13f                                |
| Pill width      | `animateFloatAsState(spring(...))`     | icon-width → 72dp                         |
| Label visibility| `AnimatedVisibility(fadeIn+slideIn)`   | hidden → visible                          |
| AI glow ring    | `InfiniteTransition` alpha pulse       | 0.3f ↔ 0.7f, 1800ms, EaseInOut           |

## Component Structure

```
SwasthiCareNavBar              // replaces MainBottomNavigation
  NavBarTabItem (x5)           // one per tab
    Box (pill background)
      Icon (Phosphor, animated scale + tint)
      [AI only] GlowRing pulse
    AnimatedVisibility
      Text (label)
```

### New file
`android/app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/SwasthiCareNavBar.kt`

### Modified files
- `NavConfig.kt` — add `color: Color` and `selectedIcon`/`unselectedIcon: ImageVector` fields to `BottomNavTab`
- `MainScaffold.kt` — swap `MainBottomNavigation` call to `SwasthiCareNavBar`
- `build.gradle.kts` — add Phosphor dependency

## What Does NOT Change

- Route names, navigation logic, back-stack behavior
- `BottomNavConfig.hiddenRoutes` and `shouldShowBottomNav`
- Slide-in/out visibility animation in `MainScaffold`
- All other screens and ViewModels
