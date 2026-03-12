package com.swastricare.health.data.workers

import android.content.Context
import android.util.Log
import androidx.work.*
import com.swastricare.health.data.models.CyclePhase
import com.swastricare.health.data.services.NotificationService
import com.swastricare.health.di.AppContainer
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.temporal.ChronoUnit
import java.util.concurrent.TimeUnit

class CycleAINudgeWorker(appContext: Context, params: WorkerParameters) :
    CoroutineWorker(appContext, params) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            AppContainer.initialize(applicationContext)
            val notifService = AppContainer.notificationService

            // Early exit if cycle notifications are disabled
            if (!notifService.cycleEnabled) return@withContext Result.success()

            val repo = AppContainer.menstrualCycleRepository
            val cycles = repo.loadLocalCycles()

            // Early exit if no cycles logged
            if (cycles.isEmpty()) return@withContext Result.success()

            val settings = repo.loadSettings()
            val today = LocalDate.now()

            // Find the most recent cycle (sorted descending by start date)
            val latestCycle = cycles.sortedByDescending { it.startDate }.firstOrNull()
                ?: return@withContext Result.success()

            val cycleLength = settings.averageCycleLength
            val dayInCycle = ChronoUnit.DAYS.between(latestCycle.startDate, today).toInt() + 1
            if (dayInCycle < 1) return@withContext Result.success() // future-dated cycle start
            val daysUntilPeriod = (cycleLength - dayInCycle).coerceAtLeast(0)

            val currentPhase = repo.detectCurrentPhase(cycles, settings)
            val predictions = repo.calculatePredictions(cycles, settings)
            val stats = repo.calculateStatistics(cycles)

            val isFertile = predictions?.let { p ->
                !today.isBefore(p.fertileWindowStart) && !today.isAfter(p.fertileWindowEnd)
            } ?: false

            val logs = repo.loadLocalDailyLogs()

            // Last 3 days of logs
            val recentLogs = logs.filter { ChronoUnit.DAYS.between(it.date, today) in 0..2 }
            val todayLog = logs.firstOrNull { it.date == today }

            val symptomsText = recentLogs
                .flatMap { it.symptoms }
                .map { it.displayName }
                .distinct()
                .joinToString(", ")
                .ifBlank { "none logged" }

            val moodText = todayLog?.mood?.displayName ?: "not logged"
            val painLevel = todayLog?.painLevel ?: 0

            val regularity = when {
                stats.totalCyclesTracked < 2 -> "Unknown"
                stats.longestCycle - stats.shortestCycle <= 3 -> "Regular"
                stats.longestCycle - stats.shortestCycle <= 7 -> "Somewhat Irregular"
                else -> "Irregular"
            }

            val prompt = """
                You are a compassionate women's health assistant for a health app targeting Indian users.
                Generate a personalized 2-sentence push notification tip for today based on the following cycle context:

                - Current phase: ${currentPhase.displayName}
                - Day in cycle: $dayInCycle
                - Days until next period: $daysUntilPeriod
                - In fertile window: $isFertile
                - Recent symptoms (last 3 days): $symptomsText
                - Today's mood: $moodText
                - Today's pain level: $painLevel/10
                - Cycle regularity: $regularity
                - Average cycle length: ${stats.averageCycleLength.toInt()} days
                - Total cycles tracked: ${stats.totalCyclesTracked}

                Instructions:
                - Write exactly 2 sentences as a push notification tip.
                - Be warm, supportive, and actionable.
                - Tailor the tip to the current phase and symptoms.
                - Do not use markdown formatting or bullet points.
                - Keep it under 200 characters total.
            """.trimIndent()

            val message = try {
                AppContainer.aiService.sendChatMessage(prompt, emptyList())
                    .trim()
            } catch (e: Exception) {
                Log.w(TAG, "AI call failed, using static fallback: ${e.message}")
                staticFallback(currentPhase)
            }

            notifService.showNotification(
                channelId = NotificationService.CHANNEL_CYCLE,
                notificationId = NotificationService.NOTIF_CYCLE_LOG,
                title = "Today's Cycle Tip",
                body = message.take(200)
            )

            Log.d(TAG, "CycleAINudgeWorker completed — phase=${currentPhase.displayName}")
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "CycleAINudgeWorker failed unexpectedly: ${e.message}")
            Result.retry()
        }
    }

    private fun staticFallback(phase: CyclePhase): String = when (phase) {
        CyclePhase.MENSTRUAL ->
            "Rest and be kind to yourself today — your body is working hard. Warm herbal tea and light stretches can ease discomfort."
        CyclePhase.FOLLICULAR ->
            "Your energy is rising — a great time to start something new! Try a light workout or explore a nutritious recipe today."
        CyclePhase.OVULATION ->
            "You're at peak energy today — make the most of it! Stay hydrated and embrace social connections."
        CyclePhase.LUTEAL ->
            "Focus on calming foods and gentle movement to ease PMS symptoms. Journalling your mood can help you spot patterns."
        CyclePhase.UNKNOWN ->
            "Log your period to unlock personalized cycle insights. Consistent tracking leads to better health awareness."
    }

    companion object {
        private const val TAG = "CycleAINudgeWorker"
        const val WORK_TAG = "cycle_ai_nudge_daily"
        const val WORK_NAME = "cycle_ai_nudge_daily"

        fun enqueue(context: Context) {
            // Calculate initial delay to next 8 AM
            val now = LocalDateTime.now()
            val next8am = now.toLocalDate().atTime(8, 0).let { scheduled ->
                if (now.isBefore(scheduled)) scheduled else scheduled.plusDays(1)
            }
            val initialDelayMinutes = ChronoUnit.MINUTES.between(now, next8am)

            val request = PeriodicWorkRequestBuilder<CycleAINudgeWorker>(24, TimeUnit.HOURS)
                .setInitialDelay(initialDelayMinutes, TimeUnit.MINUTES)
                .setConstraints(
                    Constraints.Builder()
                        .setRequiredNetworkType(NetworkType.CONNECTED)
                        .build()
                )
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 5, TimeUnit.MINUTES)
                .addTag(WORK_TAG)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.UPDATE,
                request
            )
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }
    }
}
