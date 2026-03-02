# Android Home Screen — iOS Carbon Copy

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Close the remaining gaps between the Android HomeScreen and iOS HomeView — Server Nudges strip, Diet Quick Action card upgrade, and Cycle Tracker quick action card.

**Architecture:** All changes are confined to `HomeScreen.kt`, `HomeComponents.kt`, `HomeViewModel.kt`, and `MainScreen.kt`. No new repository is needed — Nudges are fetched directly via `supabaseClient` in the VM. Calorie/cycle data is stubbed (demo values) until those features land.

**Tech Stack:** Kotlin, Jetpack Compose, Material3, `rememberInfiniteTransition` for wave/pulse animations, Supabase Kotlin SDK for nudge fetch.

---

## What Already Exists (do NOT touch)

| Component | File | Status |
|-----------|------|--------|
| `LivingStatusHeader` | `HomeComponents.kt` | ✅ Complete — pulsing heart, notification bell, profile avatar |
| `WaterWave` | `HomeComponents.kt` | ✅ Complete |
| `RisingBubblesEffect` | `HomeComponents.kt` | ✅ Complete |
| `VitalCard` | `HomeComponents.kt` | ✅ Complete |
| `PremiumBackground` | `HomeComponents.kt` | ✅ Complete |
| Medication card | `HomeScreen.kt` | ✅ Complete — liquid fill + bubbles |
| Hydration card | `HomeScreen.kt` | ✅ Complete — dual water wave |
| Daily Activity row + ModelViewer | `HomeScreen.kt` | ✅ Complete |
| WeekDateSelector + WeeklyStepsChart + DetailedMetricsSection | `HomeScreen.kt` | ✅ Complete |

---

## What Needs to Change

### Task 1: Add `ServerNudge` model + nudge fetch to `HomeViewModel`

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/home/HomeViewModel.kt`

**Step 1: Add `ServerNudge` data class at top of file**

```kotlin
data class ServerNudge(
    val id: String,
    val title: String,
    val message: String,
    val icon: String = "heart.fill",
    val color: String = "#007AFF",
    val deepLink: String? = null
)
```

**Step 2: Add nudge fields + calorie fields to `HomeState`**

Add to the `HomeState` data class:
```kotlin
// Nudges
val serverNudges: List<ServerNudge> = emptyList(),
// Diet quick action data
val calorieCurrent: Int = 0,
val calorieGoal: Int = 2000,
// Cycle tracker stub
val cyclePhase: String = "Cycle Tracker"
```

**Step 3: Add `loadNudges()` and `dismissNudge()` to `HomeViewModel`**

```kotlin
fun loadNudges() {
    viewModelScope.launch {
        try {
            // Fetch from Supabase — table: server_nudges, filter: active = true
            // For now stub 1-2 demo nudges until Supabase table is confirmed
            val demoNudges = listOf(
                ServerNudge(
                    id = "1",
                    title = "Stay Hydrated",
                    message = "You're 750ml short of your daily water goal. Drink up!",
                    icon = "drop.fill",
                    color = "#00C7BE"
                ),
                ServerNudge(
                    id = "2",
                    title = "Medication Due",
                    message = "Your evening Vitamin D dose is due in 30 minutes.",
                    icon = "pills.fill",
                    color = "#30D158"
                )
            )
            _uiState.value = _uiState.value.copy(serverNudges = demoNudges)
        } catch (_: Exception) {}
    }
}

fun dismissNudge(nudgeId: String) {
    val current = _uiState.value.serverNudges.filter { it.id != nudgeId }
    _uiState.value = _uiState.value.copy(serverNudges = current)
}
```

**Step 4: Call `loadNudges()` inside the existing `loadData()` after the state update**

```kotlin
// At end of loadData():
loadNudges()
```

Also update the demo `HomeState` in `loadData()` to set calorie values:
```kotlin
calorieCurrent = 1240,
calorieGoal = 2000,
```

**Step 5: Commit**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/home/HomeViewModel.kt
git commit -m "feat(home): add ServerNudge model, nudge state, and calorie fields to HomeViewModel"
```

---

### Task 2: Add `NudgesCardStrip` composable to `HomeComponents.kt`

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/home/HomeComponents.kt`

Add these imports at top of file (if not already present):
```kotlin
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.ui.graphics.toArgb
```

**Step 1: Add `NudgeCard` composable**

```kotlin
@Composable
fun NudgeCard(
    nudge: ServerNudge,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    // Parse accent color (fallback to blue)
    val accentColor = remember(nudge.color) {
        try { Color(android.graphics.Color.parseColor(nudge.color)) }
        catch (_: Exception) { Color(0xFF007AFF) }
    }

    Box(
        modifier = modifier
            .width(260.dp)
            .glass(cornerRadius = 20.dp)
    ) {
        // Colored left accent bar
        Box(
            modifier = Modifier
                .align(Alignment.CenterStart)
                .width(4.dp)
                .fillMaxHeight()
                .clip(RoundedCornerShape(topStart = 20.dp, bottomStart = 20.dp))
                .background(accentColor)
        )
        Row(
            modifier = Modifier
                .padding(start = 12.dp, end = 12.dp, top = 12.dp, bottom = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            // Icon
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(accentColor.copy(alpha = 0.15f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Icons.Default.Bolt,
                    contentDescription = null,
                    tint = accentColor,
                    modifier = Modifier.size(18.dp)
                )
            }
            // Text
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    nudge.title,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    nudge.message,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
                    maxLines = 2,
                    overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis
                )
            }
            // Dismiss button
            Icon(
                imageVector = Icons.Default.Close,
                contentDescription = "Dismiss",
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.4f),
                modifier = Modifier
                    .size(18.dp)
                    .clickable { onDismiss() }
                    .align(Alignment.Top)
            )
        }
    }
}
```

**Step 2: Add `NudgesCardStrip` composable**

```kotlin
@Composable
fun NudgesCardStrip(
    nudges: List<ServerNudge>,
    onDismiss: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    if (nudges.isEmpty()) return

    val scrollState = rememberScrollState()
    Row(
        modifier = modifier
            .fillMaxWidth()
            .horizontalScroll(scrollState)
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        nudges.forEach { nudge ->
            NudgeCard(
                nudge = nudge,
                onDismiss = { onDismiss(nudge.id) }
            )
        }
    }
}
```

**Step 3: Commit**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/home/HomeComponents.kt
git commit -m "feat(home): add NudgeCard and NudgesCardStrip composables"
```

---

### Task 3: Add `DietQuickActionCard` and `CycleTrackerCard` to `HomeComponents.kt`

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/home/HomeComponents.kt`

Add needed imports:
```kotlin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.foundation.layout.aspectRatio
```

**Step 1: Add `DietQuickActionCard` (orange liquid fill, matching iOS DietQuickActionButton)**

```kotlin
// Diet accent
private val DietOrange = Color(0xFFFF9500)

@Composable
fun DietQuickActionCard(
    calorieCurrent: Int,
    calorieGoal: Int,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val progress = if (calorieGoal > 0) (calorieCurrent.toFloat() / calorieGoal).coerceIn(0f, 1f) else 0f

    val animatedProgress by animateFloatAsState(
        targetValue = progress,
        animationSpec = tween(durationMillis = 1200, easing = FastOutSlowInEasing),
        label = "dietProgress"
    )

    Box(
        modifier = modifier
            .height(150.dp)
            .glass(cornerRadius = 24.dp)
            .clickable { onClick() }
    ) {
        // Orange liquid fill
        Box(
            modifier = Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(24.dp))
        ) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .fillMaxHeight(animatedProgress)
                    .background(
                        brush = androidx.compose.ui.graphics.Brush.verticalGradient(
                            colors = listOf(
                                DietOrange.copy(alpha = 0.5f),
                                DietOrange.copy(alpha = 0.7f)
                            )
                        )
                    )
            )
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // Fork & knife icon
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .background(Color.White.copy(alpha = 0.2f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = androidx.compose.material.icons.Icons.Default.LocalFireDepartment,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(18.dp)
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    "Diet",
                    style = MaterialTheme.typography.labelMedium,
                    color = Color.White.copy(alpha = 0.9f),
                    fontWeight = FontWeight.Medium
                )
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(
                        "$calorieCurrent",
                        style = MaterialTheme.typography.headlineMedium,
                        fontWeight = FontWeight.Bold,
                        color = Color.White
                    )
                    Text(
                        " / $calorieGoal cal",
                        style = MaterialTheme.typography.bodySmall,
                        color = Color.White.copy(alpha = 0.7f),
                        modifier = Modifier.padding(bottom = 4.dp, start = 2.dp)
                    )
                }
            }
        }
    }
}
```

**Step 2: Add `CycleTrackerCard` (full-width, pulsing purple)**

```kotlin
private val CyclePurple = Color(0xFFBF5AF2)

@Composable
fun CycleTrackerCard(
    phaseLabel: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "cyclePulse")
    val pulseScale by infiniteTransition.animateFloat(
        initialValue = 0.85f,
        targetValue = 1.15f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "cycleScale"
    )
    val pulseAlpha by infiniteTransition.animateFloat(
        initialValue = 0.2f,
        targetValue = 0.5f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "cycleAlpha"
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(120.dp)
            .glass(cornerRadius = 24.dp)
            .clickable { onClick() }
    ) {
        // Gradient background
        Box(
            modifier = Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(24.dp))
                .background(
                    brush = androidx.compose.ui.graphics.Brush.horizontalGradient(
                        colors = listOf(
                            CyclePurple.copy(alpha = 0.6f),
                            CyclePurple.copy(alpha = 0.3f)
                        )
                    )
                )
        )

        // Pulsing circle decoration
        Box(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .padding(end = 20.dp)
                .size(80.dp)
                .scale(pulseScale)
                .background(Color.White.copy(alpha = pulseAlpha), CircleShape)
        )

        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .background(Color.White.copy(alpha = 0.2f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = androidx.compose.material.icons.Icons.Default.Favorite,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(22.dp)
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    "Cycle Tracker",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color.White
                )
                Text(
                    phaseLabel,
                    style = MaterialTheme.typography.bodySmall,
                    color = Color.White.copy(alpha = 0.8f)
                )
            }

            Spacer(modifier = Modifier.weight(1f))

            Icon(
                imageVector = androidx.compose.material.icons.Icons.Default.ChevronRight,
                contentDescription = null,
                tint = Color.White.copy(alpha = 0.7f),
                modifier = Modifier.size(24.dp)
            )
        }
    }
}
```

Also add this import at top of file since `ChevronRight` is needed:
```kotlin
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.ui.draw.scale
```

**Step 3: Commit**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/home/HomeComponents.kt
git commit -m "feat(home): add DietQuickActionCard and CycleTrackerCard composables"
```

---

### Task 4: Update `HomeScreen.kt` — wire nudges strip + replace Diet card + add Cycle Tracker card

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/home/HomeScreen.kt`

**Step 1: Add `onNavigateToCycleTracker` parameter to `HomeScreen`**

```kotlin
@Composable
fun HomeScreen(
    viewModel: HomeViewModel = viewModel(),
    onNavigateToMedications: () -> Unit = {},
    onNavigateToDiet: () -> Unit = {},
    onNavigateToCycleTracker: () -> Unit = {}  // ADD THIS
)
```

**Step 2: After the LivingStatusHeader + first Spacer(20.dp), add Nudges strip**

Insert after `Spacer(modifier = Modifier.height(20.dp))` (the one after `LivingStatusHeader`):

```kotlin
// Server Nudges
if (uiState.serverNudges.isNotEmpty()) {
    NudgesCardStrip(
        nudges = uiState.serverNudges,
        onDismiss = { id -> viewModel.dismissNudge(id) }
    )
    Spacer(modifier = Modifier.height(16.dp))
}
```

**Step 3: Replace the Diet Chart entry card block**

Find and remove the entire `// Diet Chart Card` block (lines 344–394 in current file — the 72dp `Box` with chevron). Replace with:

```kotlin
Spacer(modifier = Modifier.height(12.dp))

// Quick Actions Row 2 — Diet + [empty half]
Row(
    modifier = Modifier
        .fillMaxWidth()
        .padding(horizontal = 20.dp),
    horizontalArrangement = Arrangement.spacedBy(16.dp)
) {
    DietQuickActionCard(
        calorieCurrent = uiState.calorieCurrent,
        calorieGoal = uiState.calorieGoal,
        onClick = onNavigateToDiet,
        modifier = Modifier.weight(1f)
    )
    // Empty spacer on the right (matches iOS layout where diet is left-half)
    Spacer(modifier = Modifier.weight(1f))
}

Spacer(modifier = Modifier.height(16.dp))

// Cycle Tracker — full width
CycleTrackerCard(
    phaseLabel = uiState.cyclePhase,
    onClick = onNavigateToCycleTracker,
    modifier = Modifier.padding(horizontal = 20.dp)
)

Spacer(modifier = Modifier.height(20.dp))
```

**Step 4: Commit**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/home/HomeScreen.kt
git commit -m "feat(home): add nudges strip, diet quick action card, and cycle tracker card"
```

---

### Task 5: Update `MainScreen.kt` — pass `onNavigateToCycleTracker`

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/main/MainScreen.kt`

Find the `HomeScreen(...)` composable call and add the new callback:

```kotlin
HomeScreen(
    onNavigateToMedications = { navController.navigate("medications") },
    onNavigateToDiet = { navController.navigate("diet") },
    onNavigateToCycleTracker = { /* TODO: navController.navigate("cycle_tracker") */ }
)
```

**Commit:**
```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/main/MainScreen.kt
git commit -m "feat(home): wire cycle tracker navigation stub in MainScreen"
```

---

### Task 6: Build verification

```bash
cd android && ./gradlew assembleDebug
```

Expected: `BUILD SUCCESSFUL` with 0 errors.

If build fails, check:
- All new imports added correctly (especially `Icons.Default.ChevronRight`, `Icons.Default.Close`)
- `ServerNudge` class is accessible where `NudgesCardStrip` uses it
- `uiState.calorieCurrent`, `uiState.calorieGoal`, `uiState.cyclePhase` added to `HomeState`

---

## Visual Layout After Changes

```
┌─────────────────────────────────────────┐
│  LivingStatusHeader (existing ✓)        │
├─────────────────────────────────────────┤
│  [Nudge Card 1] [Nudge Card 2] ←scroll  │  ← NEW
├─────────────────────────────────────────┤
│  Daily Activity + 3D Model (existing ✓) │
├─────────────────────────────────────────┤
│  Health Vitals 3-card row (existing ✓)  │
├──────────────────┬──────────────────────┤
│  Medication      │  Hydration           │  ← existing ✓
│  (liquid fill)   │  (water wave)        │
├──────────────────┼──────────────────────┤
│  Diet            │  [empty space]       │  ← NEW (upgraded from chevron)
│  (orange fill)   │                      │
├─────────────────────────────────────────┤
│  Cycle Tracker (full width, pulsing)    │  ← NEW
├─────────────────────────────────────────┤
│  WeekDateSelector (existing ✓)          │
│  WeeklyStepsChart (existing ✓)          │
│  DetailedMetricsSection (existing ✓)   │
└─────────────────────────────────────────┘
```

---

## Testing Checklist

- [ ] `./gradlew assembleDebug` — 0 errors
- [ ] Nudge cards appear as horizontal scrollable strip below header
- [ ] Dismiss button on a nudge card removes it from the strip
- [ ] Diet card is now 150dp tall with animated orange liquid fill
- [ ] Diet card calorie values visible and progress bar fills proportionally
- [ ] Diet card taps → navigates to DietScreen
- [ ] Cycle Tracker card is full width with pulsing purple animation
- [ ] No visual regression to existing Medication/Hydration cards
- [ ] No visual regression to VitalCards, ActivityStatRows, WeeklyStepsChart
