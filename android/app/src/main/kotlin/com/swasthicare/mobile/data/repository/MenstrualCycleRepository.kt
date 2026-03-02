package com.swasthicare.mobile.data.repository

import android.content.SharedPreferences
import com.swasthicare.mobile.data.models.*
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.temporal.ChronoUnit

private val mcJson = Json { ignoreUnknownKeys = true; isLenient = true }

// ------------------------------------
// MARK: - Repository Interface
// ------------------------------------

interface MenstrualCycleRepository {
    // Cycles
    fun loadLocalCycles(): List<MenstrualCycle>
    fun saveLocalCycles(cycles: List<MenstrualCycle>)
    suspend fun syncCyclesToCloud(cycles: List<MenstrualCycle>, profileId: String): Result<Unit>
    suspend fun fetchCyclesFromCloud(profileId: String): Result<List<MenstrualCycle>>

    // Daily Logs
    fun loadLocalDailyLogs(): List<MenstrualDailyLog>
    fun saveLocalDailyLogs(logs: List<MenstrualDailyLog>)
    suspend fun syncDailyLogsToCloud(logs: List<MenstrualDailyLog>, profileId: String): Result<Unit>
    suspend fun fetchDailyLogsFromCloud(profileId: String): Result<List<MenstrualDailyLog>>

    // Settings
    fun loadSettings(): MenstrualSettings
    fun saveSettings(settings: MenstrualSettings)
    suspend fun syncSettingsToCloud(settings: MenstrualSettings, profileId: String): Result<Unit>

    // Predictions & Statistics
    fun calculatePredictions(cycles: List<MenstrualCycle>, settings: MenstrualSettings): CyclePrediction?
    fun calculateStatistics(cycles: List<MenstrualCycle>): CycleStatistics
    fun detectCurrentPhase(cycles: List<MenstrualCycle>, settings: MenstrualSettings, date: LocalDate = LocalDate.now()): CyclePhase
    fun generateCalendarData(
        cycles: List<MenstrualCycle>,
        dailyLogs: List<MenstrualDailyLog>,
        predictions: CyclePrediction?,
        month: LocalDate
    ): List<CalendarDayData>
}

// ------------------------------------
// MARK: - Supabase Implementation
// ------------------------------------

class SupabaseMenstrualCycleRepository(
    private val supabaseClient: SupabaseClient,
    private val prefs: SharedPreferences
) : MenstrualCycleRepository {

    // ── Local Cycles ──

    override fun loadLocalCycles(): List<MenstrualCycle> = try {
        val raw = prefs.getString("menstrual_cycles", null) ?: return emptyList()
        mcJson.decodeFromString<List<MenstrualCycleDto>>(raw).map { it.toDomain() }
    } catch (_: Exception) { emptyList() }

    override fun saveLocalCycles(cycles: List<MenstrualCycle>) {
        val dtos = cycles.map { it.toDto("") }
        prefs.edit().putString("menstrual_cycles", mcJson.encodeToString(dtos)).apply()
    }

    override suspend fun syncCyclesToCloud(
        cycles: List<MenstrualCycle>,
        profileId: String
    ): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            if (cycles.isEmpty()) return@withContext Result.success(Unit)
            val dtos = cycles.filter { !it.synced }.map { it.toDto(profileId) }
            if (dtos.isNotEmpty()) {
                supabaseClient.from("menstrual_cycles").upsert(dtos)
            }
            // Mark as synced
            val updated = cycles.map { it.copy(synced = true) }
            saveLocalCycles(updated)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun fetchCyclesFromCloud(profileId: String): Result<List<MenstrualCycle>> =
        withContext(Dispatchers.IO) {
            try {
                val dtos = supabaseClient.from("menstrual_cycles").select {
                    filter { eq("health_profile_id", profileId) }
                }.decodeList<MenstrualCycleDto>()
                val cycles = dtos.map { it.toDomain() }
                saveLocalCycles(cycles)
                Result.success(cycles)
            } catch (e: Exception) {
                Result.failure(e)
            }
        }

    // ── Local Daily Logs ──

    override fun loadLocalDailyLogs(): List<MenstrualDailyLog> = try {
        val raw = prefs.getString("menstrual_daily_logs", null) ?: return emptyList()
        mcJson.decodeFromString<List<MenstrualDailyLogDto>>(raw).map { it.toDomain() }
    } catch (_: Exception) { emptyList() }

    override fun saveLocalDailyLogs(logs: List<MenstrualDailyLog>) {
        val dtos = logs.map { it.toDto("") }
        prefs.edit().putString("menstrual_daily_logs", mcJson.encodeToString(dtos)).apply()
    }

    override suspend fun syncDailyLogsToCloud(
        logs: List<MenstrualDailyLog>,
        profileId: String
    ): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val unsynced = logs.filter { !it.synced }
            if (unsynced.isEmpty()) return@withContext Result.success(Unit)
            val dtos = unsynced.map { it.toDto(profileId) }
            supabaseClient.from("menstrual_daily_logs").upsert(dtos)
            val updated = logs.map { it.copy(synced = true) }
            saveLocalDailyLogs(updated)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun fetchDailyLogsFromCloud(profileId: String): Result<List<MenstrualDailyLog>> =
        withContext(Dispatchers.IO) {
            try {
                val dtos = supabaseClient.from("menstrual_daily_logs").select {
                    filter { eq("health_profile_id", profileId) }
                }.decodeList<MenstrualDailyLogDto>()
                val logs = dtos.map { it.toDomain() }
                saveLocalDailyLogs(logs)
                Result.success(logs)
            } catch (e: Exception) {
                Result.failure(e)
            }
        }

    // ── Settings ──

    override fun loadSettings(): MenstrualSettings = try {
        val raw = prefs.getString("menstrual_settings", null)
            ?: return MenstrualSettings()
        val dto = mcJson.decodeFromString<MenstrualSettingsDto>(raw)
        MenstrualSettings(
            averageCycleLength = dto.averageCycleLength,
            averagePeriodLength = dto.averagePeriodLength,
            reminderEnabled = dto.reminderEnabled,
            reminderTime = dto.reminderTime.take(5)
        )
    } catch (_: Exception) { MenstrualSettings() }

    override fun saveSettings(settings: MenstrualSettings) {
        val dto = MenstrualSettingsDto(
            averageCycleLength = settings.averageCycleLength,
            averagePeriodLength = settings.averagePeriodLength,
            reminderEnabled = settings.reminderEnabled,
            reminderTime = "${settings.reminderTime}:00"
        )
        prefs.edit().putString("menstrual_settings", mcJson.encodeToString(dto)).apply()
    }

    override suspend fun syncSettingsToCloud(
        settings: MenstrualSettings,
        profileId: String
    ): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val dto = MenstrualSettingsDto(
                healthProfileId = profileId,
                averageCycleLength = settings.averageCycleLength,
                averagePeriodLength = settings.averagePeriodLength,
                reminderEnabled = settings.reminderEnabled,
                reminderTime = "${settings.reminderTime}:00"
            )
            supabaseClient.from("menstrual_settings").upsert(dto)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    // ── Predictions ──

    override fun calculatePredictions(
        cycles: List<MenstrualCycle>,
        settings: MenstrualSettings
    ): CyclePrediction? {
        val sorted = cycles.sortedByDescending { it.startDate }
        val lastCycle = sorted.firstOrNull() ?: return null

        val avgCycleLength = if (sorted.size >= 2) {
            sorted.zipWithNext { a, b -> ChronoUnit.DAYS.between(b.startDate, a.startDate).toInt() }
                .average().toInt()
        } else settings.averageCycleLength

        val nextPeriod = lastCycle.startDate.plusDays(avgCycleLength.toLong())
        val ovulation = nextPeriod.minusDays(14)
        val fertileStart = ovulation.minusDays(3)
        val fertileEnd = ovulation.plusDays(3)

        return CyclePrediction(
            nextPeriodDate = nextPeriod,
            ovulationDate = ovulation,
            fertileWindowStart = fertileStart,
            fertileWindowEnd = fertileEnd
        )
    }

    // ── Statistics ──

    override fun calculateStatistics(cycles: List<MenstrualCycle>): CycleStatistics {
        if (cycles.isEmpty()) return CycleStatistics()

        val sorted = cycles.sortedBy { it.startDate }
        val cycleLengths = sorted.zipWithNext { a, b ->
            ChronoUnit.DAYS.between(a.startDate, b.startDate).toInt()
        }
        val periodLengths = sorted.mapNotNull { it.periodLength ?: it.calculatedPeriodLength }

        return CycleStatistics(
            averageCycleLength = if (cycleLengths.isNotEmpty()) cycleLengths.average() else 0.0,
            averagePeriodLength = if (periodLengths.isNotEmpty()) periodLengths.average() else 0.0,
            longestCycle = cycleLengths.maxOrNull() ?: 0,
            shortestCycle = cycleLengths.minOrNull() ?: 0,
            totalCyclesTracked = cycles.size
        )
    }

    // ── Phase Detection ──

    override fun detectCurrentPhase(
        cycles: List<MenstrualCycle>,
        settings: MenstrualSettings,
        date: LocalDate
    ): CyclePhase {
        val sorted = cycles.sortedByDescending { it.startDate }
        val lastCycle = sorted.firstOrNull() ?: return CyclePhase.UNKNOWN

        val daysSinceStart = ChronoUnit.DAYS.between(lastCycle.startDate, date).toInt()
        if (daysSinceStart < 0) return CyclePhase.UNKNOWN

        val periodLen = lastCycle.periodLength ?: settings.averagePeriodLength
        val cycleLen = settings.averageCycleLength

        // If period is active (no end date and within period length)
        if (lastCycle.isActive && daysSinceStart < periodLen) {
            return CyclePhase.MENSTRUAL
        }

        // If period has ended or we're past period length
        val ovulationDay = cycleLen - 14
        return when {
            daysSinceStart < periodLen -> CyclePhase.MENSTRUAL
            daysSinceStart < ovulationDay - 3 -> CyclePhase.FOLLICULAR
            daysSinceStart in (ovulationDay - 3)..ovulationDay -> CyclePhase.OVULATION
            daysSinceStart <= cycleLen -> CyclePhase.LUTEAL
            else -> CyclePhase.UNKNOWN
        }
    }

    // ── Calendar Data ──

    override fun generateCalendarData(
        cycles: List<MenstrualCycle>,
        dailyLogs: List<MenstrualDailyLog>,
        predictions: CyclePrediction?,
        month: LocalDate
    ): List<CalendarDayData> {
        val firstDay = month.withDayOfMonth(1)
        val lastDay = month.withDayOfMonth(month.lengthOfMonth())
        val today = LocalDate.now()

        val logsByDate = dailyLogs.associateBy { it.date }

        return (0 until month.lengthOfMonth()).map { i ->
            val date = firstDay.plusDays(i.toLong())
            val log = logsByDate[date]

            // Check if date is in any logged period
            val inPeriod = cycles.any { cycle ->
                val end = cycle.endDate ?: cycle.startDate.plusDays(
                    (cycle.periodLength ?: 5).toLong() - 1
                )
                !date.isBefore(cycle.startDate) && !date.isAfter(end)
            }

            // Check predictions
            val isPredictedPeriod = predictions?.let { p ->
                val predEnd = p.nextPeriodDate.plusDays(4) // assume 5-day period
                !date.isBefore(p.nextPeriodDate) && !date.isAfter(predEnd)
            } ?: false

            val isFertile = predictions?.let { p ->
                !date.isBefore(p.fertileWindowStart) && !date.isAfter(p.fertileWindowEnd)
            } ?: false

            val isOvulation = predictions?.ovulationDate == date

            val phase = when {
                inPeriod -> CyclePhase.MENSTRUAL
                isOvulation -> CyclePhase.OVULATION
                isFertile -> CyclePhase.OVULATION // Fertile window around ovulation
                isPredictedPeriod -> CyclePhase.MENSTRUAL
                else -> {
                    // Determine phase from last cycle
                    val sorted = cycles.sortedByDescending { it.startDate }
                    val lastCycle = sorted.firstOrNull()
                    if (lastCycle != null) {
                        val daysSince = ChronoUnit.DAYS.between(lastCycle.startDate, date).toInt()
                        val periodLen = lastCycle.periodLength ?: 5
                        val cycleLen = 28
                        val ovDay = cycleLen - 14
                        when {
                            daysSince < 0 -> CyclePhase.UNKNOWN
                            daysSince < periodLen -> CyclePhase.MENSTRUAL
                            daysSince < ovDay - 3 -> CyclePhase.FOLLICULAR
                            daysSince <= ovDay + 1 -> CyclePhase.OVULATION
                            daysSince <= cycleLen -> CyclePhase.LUTEAL
                            else -> CyclePhase.UNKNOWN
                        }
                    } else CyclePhase.UNKNOWN
                }
            }

            CalendarDayData(
                date = date,
                phase = phase,
                isCurrentPeriod = inPeriod,
                isPredicted = isPredictedPeriod && !inPeriod,
                flowLevel = log?.flowLevel,
                hasLog = log != null
            )
        }
    }
}
