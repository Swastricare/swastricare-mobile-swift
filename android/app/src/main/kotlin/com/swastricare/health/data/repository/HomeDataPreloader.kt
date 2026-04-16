package com.swastricare.health.data.repository

import android.util.Log
import com.swastricare.health.data.models.HydrationCalculator
import com.swastricare.health.data.models.HydrationPreferences
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.ui.screens.home.HomeState
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.time.LocalDate
import java.time.LocalDateTime
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Singleton that fetches + caches the initial Home screen state.
 *
 * The splash screen calls [preload] while the intro video plays so that by
 * the time the user reaches Home, the data is already available — no
 * loading state needs to render on the Home screen itself.
 *
 * Scope note: this deliberately only loads what HomeScreenV2 actually
 * displays (greeting, user chip, daily activity from Health Connect, and
 * hydration). Medication/diet/cycle data are fetched by their own
 * ViewModels (MedicationsViewModel is already invoked from HomeScreenV2)
 * so pulling them here would just duplicate work and slow the splash.
 *
 * [HomeViewModel] consumes the cache on first load via [consumeCache].
 */
@Singleton
class HomeDataPreloader @Inject constructor(
    private val healthConnectService: HealthConnectService,
    private val hydrationRepository: SupabaseHydrationRepository,
    private val authRepository: SupabaseAuthRepository,
) {
    @Volatile
    private var cached: HomeState? = null
    private val mutex = Mutex()

    /**
     * Load home data (if not already cached) and store it for the next
     * consumer. Safe to call multiple times — subsequent calls are no-ops
     * while the cache is populated.
     */
    suspend fun preload(): HomeState = mutex.withLock {
        cached?.let { return@withLock it }
        val fresh = fetchHomeState()
        cached = fresh
        fresh
    }

    /**
     * Consume the cached state, clearing it so a future [preload] will
     * actually re-fetch. HomeViewModel calls this on first init — if the
     * splash pre-populated it, we use it; otherwise HomeViewModel falls
     * back to its own fetch.
     */
    fun consumeCache(): HomeState? {
        val s = cached
        cached = null
        return s
    }

    fun invalidate() {
        cached = null
    }

    /**
     * Performs the full load. Runs the independent fetches concurrently
     * so the overall wall-clock cost is ~max(fetches) instead of their sum.
     */
    suspend fun fetchHomeState(): HomeState = coroutineScope {
        try {
            val currentUser = authRepository.currentUser
            val userId = currentUser?.id
            val userName = currentUser?.fullName
                ?: currentUser?.email?.substringBefore("@")
                ?: ""
            val userAvatarUrl = currentUser?.avatarUrl

            val hour = LocalDateTime.now().hour
            val greeting = when (hour) {
                in 5..11 -> "Good Morning,"
                in 12..16 -> "Good Afternoon,"
                in 17..20 -> "Good Evening,"
                else -> "Good Night,"
            }

            // Parallel fan-out — all of these are independent.
            val permissionsDeferred = async {
                healthConnectService.hasReadPermissions()
            }
            val summaryDeferred = async {
                try {
                    healthConnectService.getTodaySummary()
                } catch (e: SecurityException) {
                    Log.w("HomeDataPreloader", "HC SecurityException: ${e.message}")
                    HealthConnectService.DailyHealthSummary()
                }
            }
            val hydrationPrefsDeferred = async {
                try { hydrationRepository.loadPreferences() } catch (_: Exception) { HydrationPreferences() }
            }
            val hydrationEntriesDeferred = async {
                var entries = try { hydrationRepository.loadLocalEntries() } catch (_: Exception) { emptyList() }
                // Only fall back to cloud on first-install (empty local cache).
                // This network round-trip is the main offender for splash latency.
                if (entries.isEmpty() && userId != null) {
                    val cloud = try { hydrationRepository.fetchFromCloud(userId) } catch (_: Exception) { null }
                    cloud?.getOrNull()?.takeIf { it.isNotEmpty() }?.let {
                        hydrationRepository.saveLocalEntries(it)
                        entries = it
                    }
                }
                entries
            }

            val hasPermissions = permissionsDeferred.await()
            val summary = summaryDeferred.await()
            val hydrationPrefs = hydrationPrefsDeferred.await()
            val hydrationEntries = hydrationEntriesDeferred.await()

            val todayStr = LocalDate.now().toString()
            val todayHydration = hydrationEntries
                .filter { it.consumedAt.startsWith(todayStr) }
                .sumOf { it.effectiveMl }
            val hydrationGoalMl = HydrationCalculator.calculateGoal(hydrationPrefs).dailyGoalMl

            HomeState(
                userName = userName,
                userAvatarUrl = userAvatarUrl,
                greeting = greeting,
                stepCount = summary.steps,
                calories = summary.activeCalories,
                activeMinutes = summary.exerciseMinutes,
                standHours = summary.standHours,
                heartRate = summary.heartRate,
                sleepHours = summary.sleepFormatted,
                distance = summary.distanceKm,
                hydrationCurrent = todayHydration,
                hydrationGoal = hydrationGoalMl,
                isLoading = false,
                isAuthorized = hasPermissions,
                hasNoHealthData = hasPermissions && summary.steps == 0 && summary.heartRate == 0 && summary.activeCalories == 0,
            )
        } catch (e: Exception) {
            Log.w("HomeDataPreloader", "Error loading home data: ${e.message}")
            HomeState(isLoading = false)
        }
    }
}
