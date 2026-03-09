# AI Health Context Integration - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Give the AI chat access to all health data (vitals, hydration, diet, medications, activity, cycle, vault) so it can provide personalized, context-aware health insights with every message.

**Architecture:** A new `HealthContextProvider` service aggregates data from 8 repositories/services into a structured text summary. This summary is attached to every `ChatRequest` as a `healthContext` field, forwarded through `ai-router` to `ai-chat` and `medgemma-chat` edge functions where it's injected into the system prompt.

**Tech Stack:** Kotlin/Jetpack Compose, Supabase Edge Functions (Deno/TypeScript), kotlinx.serialization

---

### Task 1: Add `healthContext` field to ChatRequest model

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/models/AIModels.kt:107-111`

**Step 1: Add the field**

In `AIModels.kt`, add `healthContext` to the `ChatRequest` data class:

```kotlin
@Serializable
data class ChatRequest(
    val message: String,
    val conversationHistory: List<ContextMessage>,
    val imageData: String? = null,
    val healthContext: String? = null
)
```

**Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/models/AIModels.kt
git commit -m "feat(android): add healthContext field to ChatRequest model"
```

---

### Task 2: Update AIService to accept and pass healthContext

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/AIService.kt:19-34`

**Step 1: Update `sendChatMessage` signature and body**

Add a `healthContext` parameter and include it in the `ChatRequest`:

```kotlin
suspend fun sendChatMessage(
    message: String,
    context: List<ChatMessage>,
    healthContext: String? = null
): String {
    val contextMessages = context.takeLast(10).map { msg ->
        ContextMessage(
            role = if (msg.isUser) "user" else "assistant",
            content = msg.content
        )
    }
    val request = ChatRequest(
        message = message,
        conversationHistory = contextMessages,
        healthContext = healthContext
    )

    val response = client.functions.invoke(
        function = "ai-router",
        body = request
    )
    val body = response.body<String>()
    return json.decodeFromString<ChatResponse>(body).response
}
```

**Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/services/AIService.kt
git commit -m "feat(android): pass healthContext through AIService to edge function"
```

---

### Task 3: Create HealthContextProvider

**Files:**
- Create: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/HealthContextProvider.kt`

**Step 1: Create the provider class**

This class aggregates all health data into a structured text string. Each section is built independently and omitted if data is unavailable.

```kotlin
package com.swasthicare.mobile.data.services

import android.util.Log
import com.swasthicare.mobile.data.model.MedicalDocument
import com.swasthicare.mobile.data.repository.*
import java.time.LocalDate
import java.time.Period
import java.time.format.DateTimeFormatter

class HealthContextProvider(
    private val profileRepository: ProfileRepository,
    private val healthConnectService: HealthConnectService,
    private val hydrationRepository: HydrationRepository,
    private val dietRepository: DietRepository,
    private val medicationRepository: MedicationRepository,
    private val runActivityRepository: RunActivityRepository,
    private val menstrualCycleRepository: MenstrualCycleRepository,
    private val vaultRepository: VaultRepository
) {
    companion object {
        private const val TAG = "HealthContextProvider"
        private const val MAX_VAULT_DOCS = 20
    }

    /**
     * Builds a comprehensive health context string from all data sources.
     * Each section is independent — if a source fails or has no data, it's omitted.
     */
    suspend fun buildContext(): String {
        val sections = mutableListOf<String>()

        buildProfileSection()?.let { sections.add(it) }
        buildVitalsSection()?.let { sections.add(it) }
        buildHydrationSection()?.let { sections.add(it) }
        buildDietSection()?.let { sections.add(it) }
        buildMedicationSection()?.let { sections.add(it) }
        buildActivitySection()?.let { sections.add(it) }
        buildCycleSection()?.let { sections.add(it) }
        buildVaultSection()?.let { sections.add(it) }

        return if (sections.isNotEmpty()) {
            sections.joinToString("\n\n")
        } else {
            ""
        }
    }

    private suspend fun buildProfileSection(): String? = tryOrNull {
        val userId = getCurrentUserId() ?: return@tryOrNull null
        val profile = profileRepository.getHealthProfile(userId) ?: return@tryOrNull null

        val parts = mutableListOf<String>()
        profile.dateOfBirth?.let { dob ->
            try {
                val birthDate = LocalDate.parse(dob)
                val age = Period.between(birthDate, LocalDate.now()).years
                parts.add("Age: $age")
            } catch (_: Exception) {}
        }
        profile.gender?.let { parts.add("Gender: $it") }
        profile.heightCm?.let { parts.add("Height: ${it}cm") }
        profile.weightKg?.let { parts.add("Weight: ${it}kg") }
        profile.bloodType?.let { parts.add("Blood Type: $it") }

        if (parts.isEmpty()) return@tryOrNull null
        "=== HEALTH PROFILE ===\n${parts.joinToString(" | ")}"
    }

    private suspend fun buildVitalsSection(): String? = tryOrNull {
        if (!healthConnectService.isAvailable || !healthConnectService.hasReadPermissions()) {
            return@tryOrNull null
        }

        val summary = healthConnectService.getTodaySummary()
        val parts = mutableListOf<String>()

        if (summary.steps > 0) parts.add("Steps: ${summary.steps}")
        if (summary.heartRate > 0) parts.add("Heart Rate: ${summary.heartRate} bpm")
        if (summary.sleepFormatted != "0h 0m" && summary.sleepFormatted.isNotEmpty()) {
            parts.add("Sleep: ${summary.sleepFormatted}")
        }
        if (summary.activeCalories > 0) parts.add("Active Calories: ${summary.activeCalories}")
        if (summary.exerciseMinutes > 0) parts.add("Exercise: ${summary.exerciseMinutes} min")
        if (summary.distanceKm > 0) parts.add("Distance: ${"%.1f".format(summary.distanceKm)} km")

        if (parts.isEmpty()) return@tryOrNull null
        "=== TODAY'S VITALS ===\n${parts.joinToString(" | ")}"
    }

    private suspend fun buildHydrationSection(): String? = tryOrNull {
        val entries = hydrationRepository.loadLocalEntries()
        val today = LocalDate.now().toString()
        val todayEntries = entries.filter { it.consumedAt?.startsWith(today) == true }

        if (todayEntries.isEmpty()) return@tryOrNull null

        val totalMl = todayEntries.sumOf { it.effectiveMl }
        val prefs = hydrationRepository.loadPreferences()
        val goalMl = prefs.customGoalMl ?: 2500

        val drinkBreakdown = todayEntries
            .groupBy { it.drinkType }
            .map { (type, items) -> "${type.name}: ${items.sumOf { it.effectiveMl }}ml" }
            .joinToString(", ")

        val pct = if (goalMl > 0) (totalMl * 100 / goalMl) else 0
        "=== HYDRATION (Today) ===\nIntake: ${totalMl}ml / ${goalMl}ml goal ($pct%) | $drinkBreakdown"
    }

    private suspend fun buildDietSection(): String? = tryOrNull {
        val allLogs = dietRepository.loadLocalLogs()
        val today = LocalDate.now()
        val weekAgo = today.minusDays(7)

        val todayStr = today.toString()
        val todayLogs = allLogs.filter { it.loggedAt?.startsWith(todayStr) == true }
        val weekLogs = allLogs.filter { log ->
            log.loggedAt?.let {
                try {
                    val logDate = LocalDate.parse(it.substring(0, 10))
                    !logDate.isBefore(weekAgo)
                } catch (_: Exception) { false }
            } ?: false
        }

        if (todayLogs.isEmpty() && weekLogs.isEmpty()) return@tryOrNull null

        val parts = mutableListOf<String>()

        // Today's meals
        if (todayLogs.isNotEmpty()) {
            val totalCal = todayLogs.sumOf { it.calories?.toInt() ?: 0 }
            val goals = dietRepository.loadGoals()
            val mealSummary = todayLogs
                .groupBy { it.mealType }
                .map { (meal, items) ->
                    "${meal?.name ?: "Other"} (${items.sumOf { it.calories?.toInt() ?: 0 }} cal)"
                }
                .joinToString(", ")
            parts.add("Today: $mealSummary | Total: $totalCal / ${goals.dailyCalories} cal goal")
        }

        // Weekly average
        if (weekLogs.size > todayLogs.size) {
            val days = weekLogs.mapNotNull { it.loggedAt?.substring(0, 10) }.distinct().size
            if (days > 0) {
                val totalWeekCal = weekLogs.sumOf { it.calories?.toInt() ?: 0 }
                val avgCal = totalWeekCal / days
                val avgProtein = weekLogs.sumOf { it.proteinG?.toInt() ?: 0 } / days
                val avgCarbs = weekLogs.sumOf { it.carbsG?.toInt() ?: 0 } / days
                val avgFat = weekLogs.sumOf { it.fatG?.toInt() ?: 0 } / days
                parts.add("Weekly avg: ${avgCal} cal/day | Protein: ${avgProtein}g, Carbs: ${avgCarbs}g, Fat: ${avgFat}g avg")
            }
        }

        if (parts.isEmpty()) return@tryOrNull null
        "=== DIET ===\n${parts.joinToString("\n")}"
    }

    private suspend fun buildMedicationSection(): String? = tryOrNull {
        val userId = getCurrentUserId() ?: return@tryOrNull null
        val profile = profileRepository.getHealthProfile(userId) ?: return@tryOrNull null
        val profileId = profile.id ?: return@tryOrNull null

        val today = LocalDate.now()
        val medications = medicationRepository.fetchMedications(profileId)
        val todayLogs = medicationRepository.fetchTodayLogs(profileId, today)
        val weekLogs = medicationRepository.fetchWeekLogs(profileId, today.minusDays(6))

        if (medications.isEmpty()) return@tryOrNull null

        val parts = mutableListOf<String>()

        // Active medications with today's status
        val activeMeds = medications.filter { it.status == "active" }
        if (activeMeds.isNotEmpty()) {
            val medStatuses = activeMeds.map { med ->
                val log = todayLogs.find { it.medicationId == med.id }
                val status = when (log?.status) {
                    "taken" -> "taken"
                    "skipped" -> "skipped"
                    else -> "pending"
                }
                "${med.name} ${med.dosage ?: ""}${med.dosageUnit ?: ""} ($status)"
            }
            parts.add("Active: ${medStatuses.joinToString(", ")}")
        }

        // Weekly adherence
        if (weekLogs.isNotEmpty()) {
            val taken = weekLogs.count { it.status == "taken" }
            val total = weekLogs.size
            val pct = if (total > 0) (taken * 100 / total) else 0
            parts.add("Weekly adherence: $pct% ($taken/$total doses taken)")
        }

        if (parts.isEmpty()) return@tryOrNull null
        "=== MEDICATIONS (Today) ===\n${parts.joinToString("\n")}"
    }

    private suspend fun buildActivitySection(): String? = tryOrNull {
        val activities = runActivityRepository.loadLocalActivities()
        val weekAgo = LocalDate.now().minusDays(7)

        val recentActivities = activities.filter { activity ->
            activity.startTime?.let {
                try {
                    val actDate = LocalDate.parse(it.substring(0, 10))
                    !actDate.isBefore(weekAgo)
                } catch (_: Exception) { false }
            } ?: false
        }.sortedByDescending { it.startTime }

        if (recentActivities.isEmpty()) return@tryOrNull null

        val formatter = DateTimeFormatter.ofPattern("MMM d")
        val activitySummaries = recentActivities.take(5).map { act ->
            val date = try {
                LocalDate.parse(act.startTime!!.substring(0, 10)).format(formatter)
            } catch (_: Exception) { "" }
            val distKm = "%.1f".format((act.distanceMeters ?: 0.0) / 1000.0)
            "${act.activityType?.name ?: "Activity"} ${distKm}km ($date)"
        }

        "=== ACTIVITY (Last 7 days) ===\n${recentActivities.size} activities: ${activitySummaries.joinToString(", ")}"
    }

    private suspend fun buildCycleSection(): String? = tryOrNull {
        val cycles = menstrualCycleRepository.loadLocalCycles()
        if (cycles.isEmpty()) return@tryOrNull null

        val settings = menstrualCycleRepository.loadSettings()
        val phase = menstrualCycleRepository.detectCurrentPhase(cycles, settings)

        val parts = mutableListOf<String>()
        parts.add("Phase: ${phase.name}")

        // Find current/latest cycle for day count
        val activeCycle = cycles.find { it.isActive } ?: cycles.maxByOrNull { it.startDate ?: "" }
        activeCycle?.startDate?.let { startStr ->
            try {
                val start = LocalDate.parse(startStr)
                val dayOfCycle = Period.between(start, LocalDate.now()).days + 1
                parts.add("Day $dayOfCycle")
            } catch (_: Exception) {}
        }

        // Last period
        val lastCompleted = cycles.filter { !it.isActive && it.endDate != null }
            .maxByOrNull { it.startDate ?: "" }
        lastCompleted?.let { cycle ->
            val startStr = cycle.startDate?.substring(0, 10) ?: ""
            val endStr = cycle.endDate?.substring(0, 10) ?: ""
            if (startStr.isNotEmpty()) {
                try {
                    val start = LocalDate.parse(startStr).format(DateTimeFormatter.ofPattern("MMM d"))
                    val end = if (endStr.isNotEmpty()) LocalDate.parse(endStr).format(DateTimeFormatter.ofPattern("d")) else "?"
                    parts.add("Last period: $start-$end")
                } catch (_: Exception) {}
            }
        }

        // Recent symptoms from daily logs
        val dailyLogs = menstrualCycleRepository.loadLocalDailyLogs()
        val recentLogs = dailyLogs.filter { log ->
            log.date?.let {
                try {
                    val logDate = LocalDate.parse(it)
                    !logDate.isBefore(LocalDate.now().minusDays(3))
                } catch (_: Exception) { false }
            } ?: false
        }
        val symptoms = recentLogs.flatMap { it.symptoms ?: emptyList() }.distinct()
        if (symptoms.isNotEmpty()) {
            parts.add("Recent symptoms: ${symptoms.joinToString(", ") { it.lowercase() }}")
        }

        "=== MENSTRUAL CYCLE ===\n${parts.joinToString(" | ")}"
    }

    private suspend fun buildVaultSection(): String? = tryOrNull {
        val documents = vaultRepository.getDocuments()
        if (documents.isEmpty()) return@tryOrNull null

        val limited = documents.take(MAX_VAULT_DOCS)
        val docSummaries = limited.map { doc ->
            val parts = mutableListOf(doc.title)
            doc.doctorName?.let { parts.add("Dr. $it") }
            doc.documentDate?.let {
                try {
                    val date = LocalDate.parse(it.substring(0, 10))
                    parts.add(date.format(DateTimeFormatter.ofPattern("MMM yyyy")))
                } catch (_: Exception) {}
            }
            parts.joinToString(", ")
        }

        val header = "${documents.size} documents"
        "=== MEDICAL VAULT ===\n$header: ${docSummaries.joinToString("; ")}"
    }

    private fun getCurrentUserId(): String? {
        // This will be resolved from the Supabase auth state
        return try {
            com.swasthicare.mobile.di.AppContainer.supabaseClient.auth.currentUserOrNull()?.id
        } catch (_: Exception) { null }
    }

    private inline fun <T> tryOrNull(block: () -> T?): T? {
        return try {
            block()
        } catch (e: Exception) {
            Log.w(TAG, "Section build failed: ${e.message}")
            null
        }
    }
}
```

**Step 2: Verify it compiles**

```bash
cd android && ./gradlew compileDebugKotlin 2>&1 | tail -5
```

Expected: BUILD SUCCESSFUL (or only pre-existing warnings)

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/data/services/HealthContextProvider.kt
git commit -m "feat(android): create HealthContextProvider to aggregate all health data for AI"
```

---

### Task 4: Register HealthContextProvider in AppContainer

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt`

**Step 1: Add the lazy property**

Add after line 193 (after `aiService`), inside the Services section:

```kotlin
val healthContextProvider: HealthContextProvider by lazy {
    HealthContextProvider(
        profileRepository = profileRepository,
        healthConnectService = healthConnectService,
        hydrationRepository = hydrationRepository,
        dietRepository = dietRepository,
        medicationRepository = medicationRepository,
        runActivityRepository = runActivityRepository,
        menstrualCycleRepository = menstrualCycleRepository,
        vaultRepository = vaultRepository
    )
}
```

Also add the import at the top of the file:
```kotlin
import com.swasthicare.mobile.data.services.HealthContextProvider
```

**Step 2: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/di/AppContainer.kt
git commit -m "feat(android): register HealthContextProvider in AppContainer"
```

---

### Task 5: Integrate HealthContextProvider into AIViewModel

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIViewModel.kt:71-77,158-213`

**Step 1: Add the dependency**

After line 76 (after `appAnalyticsService`), add:

```kotlin
private val healthContextProvider = AppContainer.healthContextProvider
```

**Step 2: Update `sendMessage()` to build and attach health context**

Replace the `sendMessage()` method (lines 158-213) with:

```kotlin
fun sendMessage() {
    val text = _uiState.value.inputText.trim()
    if (text.isEmpty()) return

    val userMessage = ChatMessage.userMessage(text)
    val priorMessages = _uiState.value.messages.filter { !it.isLoading }
    val currentMessages = _uiState.value.messages.toMutableList()
    currentMessages.add(userMessage)
    currentMessages.add(ChatMessage.loadingMessage())

    _uiState.value = _uiState.value.copy(
        messages = currentMessages,
        inputText = "",
        isLoading = true,
        showEmptyState = false,
        followUpSuggestions = emptyList()
    )

    persistMessage("user", text)

    val mode = _uiState.value.currentMode.label
    analyticsService.logAIMessageSent(mode)
    appAnalyticsService.trackAIMessageSent(mode)

    viewModelScope.launch {
        try {
            // Build health context from all data sources
            val healthContext = try {
                healthContextProvider.buildContext()
            } catch (e: Exception) {
                Log.w("AIViewModel", "Failed to build health context: ${e.message}")
                null
            }

            val responseText = aiService.sendChatMessage(
                text,
                priorMessages,
                healthContext = healthContext?.ifEmpty { null }
            )

            val newMessages = _uiState.value.messages.filter { !it.isLoading }.toMutableList()
            newMessages.add(ChatMessage.assistantMessage(responseText))

            val suggestions = generateFollowUpSuggestions(text, responseText)

            _uiState.value = _uiState.value.copy(
                messages = newMessages,
                isLoading = false,
                followUpSuggestions = suggestions
            )

            persistMessage("assistant", responseText)
        } catch (e: Exception) {
            val newMessages = _uiState.value.messages.filter { !it.isLoading }
            _uiState.value = _uiState.value.copy(
                messages = newMessages,
                isLoading = false,
                error = e.message ?: "Failed to send message"
            )
        }
    }
}
```

**Step 3: Commit**

```bash
git add android/app/src/main/kotlin/com/swasthicare/mobile/ui/screens/ai/AIViewModel.kt
git commit -m "feat(android): integrate health context into AI chat messages"
```

---

### Task 6: Update ai-router to forward healthContext

**Files:**
- Modify: `supabase/functions/ai-router/index.ts:61,139-146`

**Step 1: Extract healthContext from payload**

On line 61, add `healthContext` to the destructured payload:

```typescript
const { message, conversationHistory, imageData, forceModel, systemContext, healthContext } = payload
```

**Step 2: Include healthContext in the forwarded payload**

Update the `forwardPayload` object (lines 139-146):

```typescript
const forwardPayload = {
    message,
    conversationHistory,
    ...(imageData && { imageData }),
    ...(systemContext && { systemContext }),
    ...(healthContext && { healthContext }),
    routedFrom: 'ai-router',
    originalModel: targetModel
}
```

**Step 3: Also include healthContext in the fallback request (line 175-176)**

Update the fallback body:

```typescript
body: JSON.stringify({ message, conversationHistory, healthContext })
```

**Step 4: Commit**

```bash
git add supabase/functions/ai-router/index.ts
git commit -m "feat(supabase): forward healthContext through ai-router to sub-functions"
```

---

### Task 7: Update ai-chat to include healthContext in system prompt

**Files:**
- Modify: `supabase/functions/ai-chat/index.ts:50,99-104`

**Step 1: Extract healthContext from request body**

On line 50, add `healthContext`:

```typescript
const { message, conversationHistory, systemContext, healthContext } = await req.json()
```

**Step 2: Append healthContext to system prompt**

After line 103 (after `systemContext` append), add:

```typescript
if (healthContext && typeof healthContext === 'string') {
    systemContent += '\n\nUSER HEALTH DATA (use this to personalize responses):\n' + healthContext
}
```

**Step 3: Commit**

```bash
git add supabase/functions/ai-chat/index.ts
git commit -m "feat(supabase): include healthContext in ai-chat system prompt"
```

---

### Task 8: Verify medgemma-chat already handles healthContext

**Files:**
- Review: `supabase/functions/medgemma-chat/index.ts:42,94-96`

**Step 1: Verify**

The `medgemma-chat` function already extracts `healthContext` on line 42 and appends it to the system prompt on lines 94-96:

```typescript
if (healthContext) {
    systemContent += `\n\nHealth Context: ${healthContext}`
}
```

This already works. However, let's improve the label to match `ai-chat`:

Update lines 94-96:

```typescript
if (healthContext && typeof healthContext === 'string') {
    systemContent += '\n\nUSER HEALTH DATA (use this to personalize responses):\n' + healthContext
}
```

**Step 2: Commit**

```bash
git add supabase/functions/medgemma-chat/index.ts
git commit -m "feat(supabase): improve healthContext label in medgemma-chat system prompt"
```

---

### Task 9: Fix HealthContextProvider compilation issues

**Files:**
- Modify: `android/app/src/main/kotlin/com/swasthicare/mobile/data/services/HealthContextProvider.kt`

**Step 1: Build and fix any compilation errors**

Run:
```bash
cd android && ./gradlew compileDebugKotlin 2>&1 | grep -i "error"
```

Common issues to watch for:
- `HealthConnectService` method names may differ (e.g., `hasReadPermissions()` vs `hasAllPermissions()`) — check actual method names
- `HydrationEntry` field names (`consumedAt`, `effectiveMl`) may differ — verify against model
- `DietLogEntry` field names (`loggedAt`, `calories`, `mealType`) — verify against model
- `RunActivity` field names (`startTime`, `distanceMeters`, `activityType`) — verify against model
- `MenstrualCycle` field names — verify against model
- `HealthProfile` field names (`dateOfBirth`, `heightCm`, `weightKg`, `bloodType`) — verify against model
- Import for `io.github.jan.supabase.gotrue.auth` needed for `getCurrentUserId()`

Fix any errors found. The compiler output will guide you.

**Step 2: Run full debug build**

```bash
cd android && ./gradlew assembleDebug 2>&1 | tail -5
```

Expected: BUILD SUCCESSFUL

**Step 3: Commit fixes**

```bash
git add -A
git commit -m "fix(android): resolve compilation issues in HealthContextProvider"
```

---

### Task 10: End-to-end verification

**Step 1: Verify the full build succeeds**

```bash
cd android && ./gradlew assembleDebug
```

Expected: BUILD SUCCESSFUL

**Step 2: Review the data flow**

Trace the complete flow to verify correctness:
1. `AIViewModel.sendMessage()` → calls `healthContextProvider.buildContext()`
2. Passes result to `aiService.sendChatMessage(text, priorMessages, healthContext)`
3. `AIService` creates `ChatRequest(message, history, healthContext=healthContext)`
4. Serialized and sent to `ai-router` edge function
5. `ai-router` extracts `healthContext` and forwards to `ai-chat` or `medgemma-chat`
6. Target function appends `healthContext` to system prompt
7. AI responds with personalized, context-aware answer

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat(android): complete AI health context integration - all health data accessible to AI"
```
