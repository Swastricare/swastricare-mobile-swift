package com.swastricare.health.data.services

import android.util.Log
import com.swastricare.health.data.repository.*
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import java.time.LocalDate
import java.time.Period
import java.time.format.DateTimeFormatter

class HealthContextProvider @javax.inject.Inject constructor(
    private val profileRepository: ProfileRepository,
    private val healthConnectService: HealthConnectService,
    private val hydrationRepository: HydrationRepository,
    private val dietRepository: DietRepository,
    private val medicationRepository: MedicationRepository,
    private val runActivityRepository: RunActivityRepository,
    private val menstrualCycleRepository: MenstrualCycleRepository,
    private val vaultRepository: VaultRepository,
    private val supabaseClient: SupabaseClient
) {
    companion object {
        private const val TAG = "HealthContextProvider"
        private const val MAX_VAULT_DOCS = 20
    }

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

        return sections.joinToString("\n\n")
    }

    private suspend fun buildProfileSection(): String? = tryOrNull {
        val userId = getCurrentUserId() ?: return@tryOrNull null
        val profile = profileRepository.getHealthProfile(userId) ?: return@tryOrNull null

        val parts = mutableListOf<String>()
        try {
            val birthDate = LocalDate.parse(profile.dateOfBirth)
            val age = Period.between(birthDate, LocalDate.now()).years
            parts.add("Age: $age")
        } catch (_: Exception) {}
        parts.add("Gender: ${profile.gender.name}")
        if (profile.heightCm > 0) parts.add("Height: ${profile.heightCm.toInt()}cm")
        if (profile.weightKg > 0) parts.add("Weight: ${profile.weightKg}kg")
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
        if (summary.sleepMinutes > 0) {
            val hours = summary.sleepMinutes / 60
            val mins = summary.sleepMinutes % 60
            parts.add("Sleep: ${hours}h ${mins}m")
        }
        if (summary.activeCalories > 0) parts.add("Active Calories: ${summary.activeCalories}")
        if (summary.exerciseMinutes > 0) parts.add("Exercise: ${summary.exerciseMinutes} min")
        if (summary.distanceKm > 0) parts.add("Distance: ${"%.1f".format(summary.distanceKm)} km")
        if (summary.systolic > 0 && summary.diastolic > 0) {
            parts.add("Blood Pressure: ${summary.systolic}/${summary.diastolic}")
        }

        if (parts.isEmpty()) return@tryOrNull null
        "=== TODAY'S VITALS ===\n${parts.joinToString(" | ")}"
    }

    private suspend fun buildHydrationSection(): String? = tryOrNull {
        val entries = hydrationRepository.loadLocalEntries()
        val today = LocalDate.now().toString()
        val todayEntries = entries.filter { it.consumedAt.startsWith(today) }

        if (todayEntries.isEmpty()) return@tryOrNull null

        val totalMl = todayEntries.sumOf { it.effectiveMl }
        val prefs = hydrationRepository.loadPreferences()
        val goalMl = prefs.customGoalMl ?: 2500

        val drinkBreakdown = todayEntries
            .groupBy { it.drinkType }
            .map { (type, items) -> "$type: ${items.sumOf { it.effectiveMl }}ml" }
            .joinToString(", ")

        val pct = if (goalMl > 0) (totalMl * 100 / goalMl) else 0
        "=== HYDRATION (Today) ===\nIntake: ${totalMl}ml / ${goalMl}ml goal ($pct%) | $drinkBreakdown"
    }

    private suspend fun buildDietSection(): String? = tryOrNull {
        val allLogs = dietRepository.loadLocalLogs()
        val today = LocalDate.now()
        val weekAgo = today.minusDays(7)

        val todayStr = today.toString()
        val todayLogs = allLogs.filter { it.loggedAt.startsWith(todayStr) }
        val weekLogs = allLogs.filter { log ->
            try {
                val logDate = LocalDate.parse(log.loggedAt.substring(0, 10))
                !logDate.isBefore(weekAgo)
            } catch (_: Exception) { false }
        }

        if (todayLogs.isEmpty() && weekLogs.isEmpty()) return@tryOrNull null

        val parts = mutableListOf<String>()

        if (todayLogs.isNotEmpty()) {
            val totalCal = todayLogs.sumOf { it.calories.toInt() }
            val goals = dietRepository.loadGoals()
            val mealSummary = todayLogs
                .groupBy { it.mealType }
                .map { (meal, items) -> "$meal (${items.sumOf { it.calories.toInt() }} cal)" }
                .joinToString(", ")
            parts.add("Today: $mealSummary | Total: $totalCal / ${goals.dailyCalories} cal goal")
        }

        if (weekLogs.size > todayLogs.size) {
            val days = weekLogs.map { it.loggedAt.substring(0, 10) }.distinct().size
            if (days > 0) {
                val avgCal = weekLogs.sumOf { it.calories.toInt() } / days
                val avgProtein = weekLogs.sumOf { it.proteinG.toInt() } / days
                val avgCarbs = weekLogs.sumOf { it.carbsG.toInt() } / days
                val avgFat = weekLogs.sumOf { it.fatG.toInt() } / days
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
        if (medications.isEmpty()) return@tryOrNull null

        val todayLogs = medicationRepository.fetchTodayLogs(profileId, today)
        val weekLogs = medicationRepository.fetchWeekLogs(profileId, today.minusDays(6))

        val parts = mutableListOf<String>()

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
            activity.startTime?.let { !it.toLocalDate().isBefore(weekAgo) } ?: false
        }.sortedByDescending { it.startTime }

        if (recentActivities.isEmpty()) return@tryOrNull null

        val formatter = DateTimeFormatter.ofPattern("MMM d")
        val activitySummaries = recentActivities.take(5).map { act ->
            val date = act.startTime?.toLocalDate()?.format(formatter) ?: ""
            val distKm = "%.1f".format(act.distanceMeters / 1000.0)
            "${act.activityType.name} ${distKm}km ($date)"
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

        // Current cycle day
        val activeCycle = cycles.find { it.isActive } ?: cycles.maxByOrNull { it.startDate }
        activeCycle?.let {
            val dayOfCycle = Period.between(it.startDate, LocalDate.now()).days + 1
            parts.add("Day $dayOfCycle")
        }

        // Last completed period
        val lastCompleted = cycles.filter { !it.isActive && it.endDate != null }
            .maxByOrNull { it.startDate }
        lastCompleted?.let { cycle ->
            val start = cycle.startDate.format(DateTimeFormatter.ofPattern("MMM d"))
            val end = cycle.endDate?.format(DateTimeFormatter.ofPattern("d")) ?: "?"
            parts.add("Last period: $start-$end")
        }

        // Recent symptoms
        val dailyLogs = menstrualCycleRepository.loadLocalDailyLogs()
        val recentLogs = dailyLogs.filter { !it.date.isBefore(LocalDate.now().minusDays(3)) }
        val symptoms = recentLogs.flatMap { it.symptoms }.distinct()
        if (symptoms.isNotEmpty()) {
            parts.add("Recent symptoms: ${symptoms.joinToString(", ") { it.name.lowercase() }}")
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

        "=== MEDICAL VAULT ===\n${documents.size} documents: ${docSummaries.joinToString("; ")}"
    }

    private fun getCurrentUserId(): String? {
        return try {
            supabaseClient.auth.currentUserOrNull()?.id
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
