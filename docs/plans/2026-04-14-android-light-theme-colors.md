# Android Light Theme Color Update — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update the Android light mode color system to use an off-white screen background (`#F6F7F9`), pure white card surfaces (`#FFFFFF`), and a soft divider token (`#E6E8EB`), so cards visually lift off the page.

**Architecture:** All changes are confined to `Color.kt` in the theme layer. `BackgroundLight` is updated, `DividerLight` is added as a new token, and `AppColors` gains a `divider` property and an updated `cardBorder`. No screen files are modified — the cascade happens through `MaterialTheme.colorScheme` and `AppColors.*`.

**Tech Stack:** Kotlin, Jetpack Compose, Material3

**Design doc:** `docs/plans/2026-04-14-android-light-theme-colors-design.md`

---

### Task 1: Update `BackgroundLight` and add `DividerLight` token

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/theme/Color.kt:15-20`

**Step 1: Update `BackgroundLight`**

In `Color.kt`, find:
```kotlin
val BackgroundLight = Color(0xFFFFFFFF) // Pure white for light theme
```

Replace with:
```kotlin
val BackgroundLight = Color(0xFFF6F7F9) // Off-white for light theme
```

**Step 2: Add `DividerLight` after `SurfaceLight`**

Find:
```kotlin
val SurfaceDark = Color(0xFF0A0A0A) // Near Black
```

Add after `SurfaceLight`:
```kotlin
val DividerLight = Color(0xFFE6E8EB) // Soft card shadow / divider
```

Result for the Background/Surface block:
```kotlin
// Background Colors
val BackgroundLight = Color(0xFFF6F7F9) // Off-white for light theme
val BackgroundDark = Color(0xFF000000) // Pitch Black

// Surface Colors
val SurfaceLight = Color(0xFFFFFFFF)
val DividerLight = Color(0xFFE6E8EB) // Soft card shadow / divider
val SurfaceDark = Color(0xFF0A0A0A) // Near Black
```

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/theme/Color.kt
git commit -m "feat(android): add DividerLight token and update BackgroundLight to off-white #F6F7F9"
```

---

### Task 2: Update `AppColors` — fix `cardBorder` and add `divider`

**Files:**
- Modify: `android/app/src/main/kotlin/com/swastricare/health/ui/theme/Color.kt` — `AppColors` object (lines ~128–135)

**Step 1: Update `AppColors.cardBorder`**

Find:
```kotlin
val cardBorder: Color
    @Composable @ReadOnlyComposable
    get() = if (isSystemInDarkTheme()) Color.Transparent else Color.Black.copy(alpha = 0.3f)
```

Replace with:
```kotlin
val cardBorder: Color
    @Composable @ReadOnlyComposable
    get() = if (isSystemInDarkTheme()) Color.Transparent else DividerLight
```

**Step 2: Add `AppColors.divider` property**

Add immediately after `cardBorder`:
```kotlin
val divider: Color
    @Composable @ReadOnlyComposable
    get() = if (isSystemInDarkTheme()) Color(0xFF3C3C3E) else DividerLight
```

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swastricare/health/ui/theme/Color.kt
git commit -m "feat(android): update AppColors.cardBorder to DividerLight, add AppColors.divider"
```

---

### Task 3: Verify cascade — build the app

**Step 1: Run a debug build to confirm no compile errors**

```bash
cd android && JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug
```

Expected: `BUILD SUCCESSFUL`

If errors appear, they will be in `Color.kt` — check for missing imports or syntax issues.

**Step 2: Visual verification checklist**

Launch the app on a device/emulator in **light mode** and verify:

- [ ] Home screen — background is off-white (not pure white)
- [ ] Medications screen — list background is off-white, cards are white
- [ ] Profile screen — background is off-white
- [ ] Settings screen — background is off-white
- [ ] Card borders/dividers use the soft grey (#E6E8EB), not the old dark border
- [ ] Dark mode — no visual change (backgrounds still dark)

**Step 3: Final commit (if any follow-up tweaks needed)**

```bash
git add -p
git commit -m "fix(android): light theme color adjustments after visual review"
```
