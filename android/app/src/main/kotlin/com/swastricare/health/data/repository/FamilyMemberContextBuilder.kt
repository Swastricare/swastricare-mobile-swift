package com.swastricare.health.data.repository

import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.domain.repository.DietRepository
import com.swastricare.health.domain.repository.FamilyRepository
import com.swastricare.health.domain.repository.HydrationRepository
import com.swastricare.health.domain.repository.MedicationRepository
import com.swastricare.health.domain.repository.SleepRepository
import java.time.LocalDate
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Builds a Markdown-formatted context block scoped to a single family member,
 * prepended to AI prompts on the family-member AI chat screen.
 *
 * The builder uses repository methods that go through the caller's Supabase
 * session, so RLS (`has_family_access`) is what bounds visibility. If the
 * caller does not have access to the target profile, the helpers return null
 * / empty results and this builder degrades gracefully to an empty string —
 * the chat still works, just without enriched context.
 */
@Singleton
class FamilyMemberContextBuilder @Inject constructor(
    private val familyRepository: FamilyRepository,
    private val medicationRepository: MedicationRepository,
    private val hydrationRepository: HydrationRepository,
    private val heartRateRepository: HeartRateRepositoryImpl,
    private val sleepRepository: SleepRepository,
    private val dietRepository: DietRepository,
    private val authRepository: AuthRepository,
) {

    /**
     * Build a "today's snapshot" markdown block for [targetHealthProfileId].
     * Returns an empty string on any failure or when the caller is not in a
     * family group containing the target.
     */
    suspend fun build(targetHealthProfileId: String): String {
        return runCatching {
            val today = LocalDate.now()
            val callerId = authRepository.getCurrentUser()?.id
                ?: return@runCatching ""

            val group = familyRepository.getMyFamilyGroup(callerId).getOrNull()
                ?: return@runCatching ""
            val members = familyRepository.getMembers(group.id).getOrNull().orEmpty()
            val member = members.firstOrNull { it.healthProfileId == targetHealthProfileId }
                ?: return@runCatching ""

            // Today snapshot — each call is best-effort; RLS will trim what the
            // caller can't see, and we treat null as "no data".
            val hr = heartRateRepository.getLatestForProfile(targetHealthProfileId).getOrNull()
            val sleepToday = sleepRepository.getNightSleepHours(targetHealthProfileId, today).getOrNull()
            val hydrationToday = hydrationRepository.getTodayTotalMl(targetHealthProfileId, today).getOrNull() ?: 0
            val caloriesToday = dietRepository.getDayCalories(targetHealthProfileId, today).getOrNull() ?: 0
            val dosesToday = medicationRepository.getDosesForDay(targetHealthProfileId, today).getOrNull().orEmpty()

            val takenToday = dosesToday.count { it.status == "taken" }
            val totalToday = dosesToday.size
            val adherenceToday = if (totalToday > 0) takenToday * 100 / totalToday else null
            val displayName = member.fullName?.takeIf { it.isNotBlank() } ?: "this family member"

            buildString {
                appendLine("# Family member context (read-only, for AI reasoning)")
                appendLine("This conversation is about $displayName.")
                appendLine("Today's date: $today")
                appendLine()
                appendLine("## Today's snapshot")
                if (hr != null) {
                    appendLine("- Latest heart rate: ${hr.bpm} bpm (measured ${hr.measuredAt})")
                }
                if (sleepToday != null) {
                    appendLine("- Sleep last night: ${"%.1f".format(sleepToday)} hours")
                }
                appendLine("- Hydration today: $hydrationToday ml")
                appendLine("- Calories today: $caloriesToday kcal")
                if (totalToday > 0) {
                    appendLine("- Medication adherence today: $takenToday/$totalToday taken" +
                            (adherenceToday?.let { " ($it%)" } ?: ""))
                    val missed = dosesToday.filter { it.status == "missed" }
                    if (missed.isNotEmpty()) {
                        appendLine("- Missed today: ${missed.joinToString { it.medicationName }}")
                    }
                }
                appendLine()
                appendLine("## Notes")
                appendLine("- Caller is asking about this family member as a caregiver/family.")
                appendLine("- Be respectful, non-alarmist; suggest seeking professional medical advice for anything serious.")
                appendLine("- Don't expose specific log IDs, internal status codes, or raw data the caller didn't ask about.")
            }
        }.getOrElse {
            // Build is best-effort — on failure return empty so the chat still works.
            ""
        }
    }
}
