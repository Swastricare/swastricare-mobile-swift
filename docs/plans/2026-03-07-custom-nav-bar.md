# Custom Bottom Navigation Bar — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the standard Material3 `NavigationBar` with a fully custom animated bottom nav bar using Phosphor Icons, per-tab semantic colors, spring bounce scale, and icon fill animations.

**Architecture:** New `SwasthiCareNavBar.kt` composable replaces `MainBottomNavigation` inside `MainScaffold.kt`. `NavConfig.kt` is extended with color and icon fields per tab. Zero Material nav components used in the bar itself.

**Tech Stack:** Jetpack Compose, `com.adamglin:compose-phosphor-icon:2.1.0`, `animateFloatAsState`, `animateColorAsState`, `spring()`, `AnimatedVisibility`, `InfiniteTransition`

---

### Task 1: Add Phosphor Icons Dependency

**Files:**
- Modify: `android/app/build.gradle.kts` (inside `dependencies {}` block, after line 105)

**Step 1: Add the dependency**

In `build.gradle.kts`, add after the `material-icons-extended` line:

```kotlin
// Phosphor Icons — custom icon pack for nav bar and UI
implementation("com.adamglin:compose-phosphor-icon:2.1.0")
```

**Step 2: Sync gradle**

In Android Studio: click "Sync Now" in the banner, or run:
```bash
cd android && ./gradlew dependencies --configuration debugRuntimeClasspath | grep phosphor
```
Expected: `com.adamglin:compose-phosphor-icon:2.1.0` appears in output.

**Step 3: Commit**

```bash
cd android
git add app/build.gradle.kts
git commit -m "feat(android): add Phosphor Icons dependency for custom nav bar"
```

---

### Task 2: Extend NavConfig with Colors and Phosphor Icons

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/NavConfig.kt`

**Step 1: Replace the file content**

Replace the entire `NavConfig.kt` with:

```kotlin
package com.swasthicare.mobile.ui.navigation

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import com.adamglin.phosphoricons.PhosphorIcons
import com.adamglin.phosphoricons.fill.Heart as HeartFill
import com.adamglin.phosphoricons.fill.Lock as LockFill
import com.adamglin.phosphoricons.fill.Sparkle as SparkleFill
import com.adamglin.phosphoricons.fill.Sneaker as SneakerFill
import com.adamglin.phosphoricons.fill.User as UserFill
import com.adamglin.phosphoricons.regular.Heart
import com.adamglin.phosphoricons.regular.Lock
import com.adamglin.phosphoricons.regular.Sparkle
import com.adamglin.phosphoricons.regular.Sneaker
import com.adamglin.phosphoricons.regular.User
import com.swasthicare.mobile.ui.theme.HeartRateColor
import com.swasthicare.mobile.ui.theme.MedicationColor
import com.swasthicare.mobile.ui.theme.PrimaryColor
import com.swasthicare.mobile.ui.theme.StepsColor
import com.swasthicare.mobile.ui.theme.SystemBlue

/**
 * Defines a bottom navigation tab with route, label, icons, and semantic color.
 */
sealed class BottomNavTab(
    val route: String,
    val title: String,
    val icon: ImageVector,
    val selectedIcon: ImageVector,
    val color: Color
) {
    object Vitals : BottomNavTab(
        route = "vitals",
        title = "Vitals",
        icon = PhosphorIcons.Regular.Heart,
        selectedIcon = PhosphorIcons.Fill.Heart,
        color = HeartRateColor
    )
    object Vault : BottomNavTab(
        route = "vault",
        title = "Vault",
        icon = PhosphorIcons.Regular.Lock,
        selectedIcon = PhosphorIcons.Fill.Lock,
        color = MedicationColor
    )
    object AI : BottomNavTab(
        route = "ai",
        title = "AI",
        icon = PhosphorIcons.Regular.Sparkle,
        selectedIcon = PhosphorIcons.Fill.Sparkle,
        color = PrimaryColor
    )
    object Steps : BottomNavTab(
        route = "steps",
        title = "Steps",
        icon = PhosphorIcons.Regular.Sneaker,
        selectedIcon = PhosphorIcons.Fill.Sneaker,
        color = StepsColor
    )
    object Profile : BottomNavTab(
        route = "profile",
        title = "Profile",
        icon = PhosphorIcons.Regular.User,
        selectedIcon = PhosphorIcons.Fill.User,
        color = SystemBlue
    )

    companion object {
        val items = listOf(Vitals, Vault, AI, Steps, Profile)

        fun isTabRoute(route: String): Boolean = items.any { it.route == route }
    }
}

/**
 * Routes where bottom navigation should be hidden.
 */
object BottomNavConfig {
    val hiddenRoutes = setOf(
        "live_workout",
        "workout_summary",
        "ar_body_scan"
    )

    fun shouldShowBottomNav(currentRoute: String?): Boolean {
        if (currentRoute == null) return true
        if (BottomNavTab.isTabRoute(currentRoute)) return true
        return currentRoute !in hiddenRoutes
    }
}

/**
 * Navigation argument keys for type-safe navigation.
 */
object NavArgs {
    const val MEDICATION_ID = "medicationId"
    const val WORKOUT_ID = "workoutId"
    const val MEAL_TYPE = "mealTypeDb"
    const val WORKOUT_TYPE = "type"
    const val FAMILY_CODE = "code"
}
```

> **Note:** The Phosphor import paths use object nesting: `PhosphorIcons.Regular.Heart` and `PhosphorIcons.Fill.Heart`. If the library uses a flat import pattern (e.g., `com.adamglin.phosphoricons.regular.Heart`), use the direct imports shown in the imports block at the top. Check autocomplete after syncing to confirm which style the library uses.

**Step 2: Build to confirm no errors**

```bash
cd android && ./gradlew :app:compileDebugKotlin 2>&1 | tail -20
```
Expected: `BUILD SUCCESSFUL` or only pre-existing warnings (no new errors).

**Step 3: Commit**

```bash
git add app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/NavConfig.kt
git commit -m "feat(android): extend BottomNavTab with Phosphor icons and semantic colors"
```

---

### Task 3: Create SwasthiCareNavBar Composable

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/SwasthiCareNavBar.kt`

**Step 1: Create the file**

```kotlin
package com.swasthicare.mobile.ui.navigation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.InfiniteRepeatableSpec
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import com.swasthicare.mobile.ui.theme.AppColors

/**
 * Production-grade custom bottom navigation bar.
 * Uses Phosphor Icons, per-tab semantic colors, spring bounce scale,
 * and animated pill highlight. No Material3 nav components.
 */
@Composable
fun SwasthiCareNavBar(
    navController: NavController,
    currentRoute: String?
) {
    val surfaceColor = AppColors.surface
    val dividerColor = AppColors.outlineVariant

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .background(surfaceColor)
            .drawBehind {
                // 1dp top hairline divider
                drawLine(
                    color = dividerColor,
                    start = Offset(0f, 0f),
                    end = Offset(size.width, 0f),
                    strokeWidth = 1.dp.toPx()
                )
            }
            .windowInsetsPadding(WindowInsets.navigationBars)
            .height(72.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            BottomNavTab.items.forEach { tab ->
                val selected = currentRoute == tab.route
                NavBarTabItem(
                    tab = tab,
                    selected = selected,
                    modifier = Modifier.weight(1f),
                    onClick = {
                        if (currentRoute != tab.route) {
                            navController.navigate(tab.route) {
                                popUpTo(navController.graph.startDestinationId) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        }
                    }
                )
            }
        }
    }
}

@Composable
private fun NavBarTabItem(
    tab: BottomNavTab,
    selected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit
) {
    // Scale spring bounce: 1.0 → 1.18 on select
    val scale by animateFloatAsState(
        targetValue = if (selected) 1.18f else 1.0f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessMedium
        ),
        label = "iconScale"
    )

    // Pill background alpha: 0 → 0.13
    val pillAlpha by animateFloatAsState(
        targetValue = if (selected) 0.13f else 0f,
        animationSpec = tween(durationMillis = 200),
        label = "pillAlpha"
    )

    val interactionSource = remember { MutableInteractionSource() }

    Column(
        modifier = modifier
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick
            )
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Icon + pill
        Box(contentAlignment = Alignment.Center) {
            // Pill highlight background
            Box(
                modifier = Modifier
                    .size(width = 56.dp, height = 32.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(tab.color.copy(alpha = pillAlpha))
            )

            // AI tab glow ring (pulsing when selected)
            if (tab == BottomNavTab.AI && selected) {
                AIGlowRing(color = tab.color)
            }

            // Icon with scale + tint animation
            Icon(
                imageVector = if (selected) tab.selectedIcon else tab.icon,
                contentDescription = tab.title,
                tint = if (selected) tab.color else AppColors.onSurfaceVariant,
                modifier = Modifier
                    .size(24.dp)
                    .graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                    }
            )
        }

        Spacer(modifier = Modifier.height(2.dp))

        // Label: fades in when selected
        AnimatedVisibility(
            visible = selected,
            enter = fadeIn(tween(150)) + slideInVertically(tween(150)) { it / 2 },
            exit = fadeOut(tween(100)) + slideOutVertically(tween(100)) { it / 2 }
        ) {
            Text(
                text = tab.title,
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                color = tab.color,
                maxLines = 1
            )
        }
    }
}

/**
 * Subtle pulsing glow ring for the AI tab.
 */
@Composable
private fun AIGlowRing(color: Color) {
    val infiniteTransition = rememberInfiniteTransition(label = "aiGlow")
    val glowAlpha by infiniteTransition.animateFloat(
        initialValue = 0.25f,
        targetValue = 0.6f,
        animationSpec = InfiniteRepeatableSpec(
            animation = tween(durationMillis = 1800, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "glowAlpha"
    )

    Box(
        modifier = Modifier
            .size(40.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(color.copy(alpha = glowAlpha * 0.2f))
    )
}
```

**Step 2: Build to confirm no errors**

```bash
cd android && ./gradlew :app:compileDebugKotlin 2>&1 | tail -20
```
Expected: `BUILD SUCCESSFUL`.

**Step 3: Commit**

```bash
git add app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/SwasthiCareNavBar.kt
git commit -m "feat(android): create SwasthiCareNavBar with Phosphor icons and spring animations"
```

---

### Task 4: Wire SwasthiCareNavBar into MainScaffold

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/MainScaffold.kt`

**Step 1: Replace the file content**

```kotlin
package com.swasthicare.mobile.ui.navigation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.navigation.NavController
import androidx.navigation.compose.currentBackStackEntryAsState

/**
 * Reusable main scaffold with the custom SwasthiCare bottom navigation bar.
 */
@Composable
fun MainScaffold(
    navController: NavController,
    showBottomNav: Boolean,
    modifier: Modifier = Modifier,
    content: @Composable (Modifier) -> Unit
) {
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    Scaffold(
        modifier = modifier,
        bottomBar = {
            AnimatedVisibility(
                visible = showBottomNav,
                enter = slideInVertically(initialOffsetY = { it }),
                exit = slideOutVertically(targetOffsetY = { it })
            ) {
                SwasthiCareNavBar(
                    navController = navController,
                    currentRoute = currentRoute
                )
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentAlignment = Alignment.TopCenter
        ) {
            content(Modifier.fillMaxSize())
        }
    }
}
```

**Step 2: Build a debug APK to verify**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -30
```
Expected: `BUILD SUCCESSFUL` with an APK at `app/build/outputs/apk/debug/app-debug.apk`.

**Step 3: Commit**

```bash
git add app/src/main/kotlin/com/swasthicare/mobile/ui/navigation/MainScaffold.kt
git commit -m "feat(android): wire SwasthiCareNavBar into MainScaffold, remove Material NavigationBar"
```

---

## Manual Verification Checklist

After installing the debug APK on a device/emulator:

- [ ] All 5 tabs are visible and tappable
- [ ] Tapping a tab navigates to the correct screen
- [ ] Selected icon uses the fill variant (e.g. filled heart on Vitals)
- [ ] Selected icon tint matches the tab's semantic color
- [ ] Icon bounces/scales up with spring on tap
- [ ] Pill highlight appears behind selected icon with correct color
- [ ] Label appears only on selected tab with fade animation
- [ ] AI tab shows subtle pulsing glow ring when selected
- [ ] Bar background matches system surface (white light / dark in dark mode)
- [ ] Top hairline divider is visible
- [ ] Bar respects system navigation bar insets (not overlapping system gestures)
- [ ] Screens that should hide the nav bar (e.g. `live_workout`) still hide it correctly

## Troubleshooting

**Phosphor icon import not found:** Check autocomplete — the library may use flat imports like `import com.adamglin.phosphoricons.regular.Heart` directly rather than the nested `PhosphorIcons.Regular.Heart` accessor. Update imports in `NavConfig.kt` accordingly.

**Icon not rendering:** Verify the exact icon names in the Phosphor library. `Sneaker` might be named `Shoe` or `Boot`. Open the library in Android Studio and check available names via autocomplete on `PhosphorIcons.Regular.`.

**Navigation bar insets not applied:** Ensure `enableEdgeToEdge()` is present in `MainActivity.onCreate()` (it already is). The `windowInsetsPadding(WindowInsets.navigationBars)` in the bar handles the rest.
