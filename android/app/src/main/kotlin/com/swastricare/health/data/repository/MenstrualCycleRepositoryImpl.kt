package com.swastricare.health.data.repository

import android.content.SharedPreferences
import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.mapper.*
import com.swastricare.health.data.remote.dto.menstrualcycle.MenstrualCycleDto
import com.swastricare.health.data.remote.dto.menstrualcycle.MenstrualDailyLogDto
import com.swastricare.health.domain.model.menstrualcycle.*
import com.swastricare.health.domain.repository.MenstrualCycleRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.YearMonth
import java.time.temporal.ChronoUnit
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.math.sqrt

private val json = Json { ignoreUnknownKeys = true; isLenient = true }

@Serializable
private data class HealthProfileIdRow(val id: String)

/**
 * Implementation of MenstrualCycleRepository using Supabase and local storage.
 * Handles data persistence, synchronization, and business logic for cycle tracking.
 */
@Singleton
class MenstrualCycleRepositoryImpl @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val prefs: SharedPreferences
) : MenstrualCycleRepository {

    // Keys are user-scoped to prevent cross-account data leakage on shared devices.
    // The legacy un-scoped keys are intentionally NOT read.
    private fun cyclesKey(profileId: String) = "menstrual_cycles_$profileId"
    private fun logsKey(profileId: String) = "menstrual_daily_logs_$profileId"
    private fun settingsKey(profileId: String) = "menstrual_settings_$profileId"

    private val profileIdMutex = Mutex()
    private var cachedProfileId: String? = null

    /**
     * Resolves the health_profile_id for the current user. Throws on
     * failure so callers can surface a real error instead of masquerading
     * as "not set up". Local helpers that should stay silent (e.g.
     * loadLocal*) catch the throw themselves.
     */
    private suspend fun getProfileId(): String {
        cachedProfileId?.let { return it }
        return profileIdMutex.withLock {
            cachedProfileId?.let { return@withLock it }
            val userId = supabaseClient.auth.currentUserOrNull()?.id
                ?: throw AppException.ApiException.Unauthorized()
            val id = supabaseClient.from("health_profiles")
                .select { filter { eq("user_id", userId) } }
                .decodeSingleOrNull<HealthProfileIdRow>()?.id
                ?: throw AppException.DatabaseException.NotFound("health_profile")
            cachedProfileId = id
            id
        }
    }

    private suspend fun getProfileIdOrEmpty(): String = try {
        getProfileId()
    } catch (_: Exception) {
        ""
    }

    fun clearProfileIdCache() { cachedProfileId = null }

    // ── Cycle Management ──

    override suspend fun getCycles(): ResultWrapper<List<CycleRecord>> = withContext(Dispatchers.IO) {
        try {
            val profileId = getProfileId()

            val dtos = supabaseClient.from("menstrual_cycles")
                .select {
                    filter { eq("health_profile_id", profileId) }
                }
                .decodeList<MenstrualCycleDto>()

            val cycles = dtos.map { it.toDomain() }
            saveLocalCycles(cycles)
            ResultWrapper.Success(cycles)
        } catch (e: java.io.IOException) {
            // Network failure — fall back to local cache silently.
            ResultWrapper.Success(loadLocalCycles())
        } catch (e: Exception) {
            android.util.Log.e("CycleRepo", "getCycles failed", e)
            ResultWrapper.Error(
                if (e is AppException) e else AppException.UnknownException(cause = e)
            )
        }
    }

    override suspend fun startCycle(
        startDate: LocalDate,
        notes: String?
    ): ResultWrapper<CycleRecord> = withContext(Dispatchers.IO) {
        try {
            val profileId = getProfileId()
            val cycleId = UUID.randomUUID().toString()

            val cycle = CycleRecord(
                id = cycleId,
                userId = profileId,
                startDate = startDate,
                endDate = null,
                cycleLength = null,
                periodLength = null,
                notes = notes
            )

            val dto = cycle.toDto(profileId)
            supabaseClient.from("menstrual_cycles").upsert(dto)

            val cycles = loadLocalCycles().toMutableList()
            cycles.add(cycle)
            saveLocalCycles(cycles)

            ResultWrapper.Success(cycle)
        } catch (e: AppException) {
            ResultWrapper.Error(e)
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun endCycle(
        cycleId: String,
        endDate: LocalDate
    ): ResultWrapper<CycleRecord> = withContext(Dispatchers.IO) {
        try {
            val cycles = loadLocalCycles().toMutableList()
            val cycleIndex = cycles.indexOfFirst { it.id == cycleId }

            if (cycleIndex == -1) {
                return@withContext ResultWrapper.Error(
                    AppException.ValidationException.Custom("Cycle not found")
                )
            }

            val cycle = cycles[cycleIndex]

            // Validate end date is not before start date
            if (endDate.isBefore(cycle.startDate)) {
                return@withContext ResultWrapper.Error(
                    AppException.ValidationException.Custom("End date cannot be before start date")
                )
            }

            val updatedCycle = cycle.copy(endDate = endDate)
            cycles[cycleIndex] = updatedCycle

            val profileId = getProfileId()
            val dto = updatedCycle.toDto(profileId)
            supabaseClient.from("menstrual_cycles").upsert(dto)

            saveLocalCycles(cycles)
            ResultWrapper.Success(updatedCycle)
        } catch (e: AppException) {
            ResultWrapper.Error(e)
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun deleteCycle(cycleId: String): ResultWrapper<Unit> = withContext(Dispatchers.IO) {
        try {
            val cycles = loadLocalCycles().toMutableList()
            cycles.removeIf { it.id == cycleId }
            saveLocalCycles(cycles)

            // getProfileId() here ensures we surface auth/profile errors;
            // the delete itself does not filter on profile_id because RLS
            // already scopes deletes to the current user.
            getProfileId()
            supabaseClient.from("menstrual_cycles")
                .delete {
                    filter { eq("id", cycleId) }
                }

            ResultWrapper.Success(Unit)
        } catch (e: AppException) {
            ResultWrapper.Error(e)
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    // ── Daily Logs ──

    override suspend fun getDailyLogs(
        startDate: LocalDate,
        endDate: LocalDate
    ): ResultWrapper<List<DailyLog>> = withContext(Dispatchers.IO) {
        try {
            val profileId = getProfileId()

            val dtos = supabaseClient.from("menstrual_daily_logs")
                .select {
                    filter {
                        eq("health_profile_id", profileId)
                        gte("date", startDate.toString())
                        lte("date", endDate.toString())
                    }
                }
                .decodeList<MenstrualDailyLogDto>()

            val logs = dtos.map { it.toDomain() }
            ResultWrapper.Success(logs)
        } catch (e: java.io.IOException) {
            ResultWrapper.Success(loadLocalLogs().filter { it.date in startDate..endDate })
        } catch (e: Exception) {
            android.util.Log.e("CycleRepo", "getDailyLogs failed", e)
            ResultWrapper.Error(
                if (e is AppException) e else AppException.UnknownException(cause = e)
            )
        }
    }

    override suspend fun logDailyData(
        date: LocalDate,
        flowLevel: FlowLevel,
        symptoms: List<Symptom>,
        mood: Mood?,
        notes: String?,
        painLevel: Int
    ): ResultWrapper<DailyLog> = withContext(Dispatchers.IO) {
        try {
            val profileId = getProfileId()

            // Determine cycle ID (find active cycle or create one)
            val cycles = loadLocalCycles().toMutableList()
            val activeCycle = cycles.firstOrNull { it.isActive }
            val cycleId: String
            if (activeCycle != null) {
                cycleId = activeCycle.id
            } else {
                cycleId = UUID.randomUUID().toString()
                val newCycle = CycleRecord(
                    id = cycleId,
                    userId = profileId,
                    startDate = date,
                    endDate = null,
                    cycleLength = null,
                    periodLength = null,
                    notes = null
                )
                cycles.add(newCycle)
                saveLocalCycles(cycles)

                val cycleDto = newCycle.toDto(profileId)
                supabaseClient.from("menstrual_cycles").upsert(cycleDto)
            }

            // Upsert on (health_profile_id, date) so re-logging the same day
            // updates in place. We look up an existing local log first to
            // preserve its id (unique constraint is on profile+date, PK on id).
            val existing = loadLocalLogs().firstOrNull { it.date == date }
            val log = DailyLog(
                id = existing?.id ?: UUID.randomUUID().toString(),
                cycleId = cycleId,
                date = date,
                flowLevel = flowLevel,
                symptoms = symptoms,
                mood = mood,
                notes = notes,
                painLevel = painLevel
            )

            val dto = log.toDto(profileId)
            supabaseClient.from("menstrual_daily_logs").upsert(dto)

            val logs = loadLocalLogs().toMutableList()
            val idx = logs.indexOfFirst { it.date == date }
            if (idx >= 0) logs[idx] = log else logs.add(log)
            saveLocalLogs(logs)

            ResultWrapper.Success(log)
        } catch (e: AppException) {
            ResultWrapper.Error(e)
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun updateDailyLog(log: DailyLog): ResultWrapper<DailyLog> = withContext(Dispatchers.IO) {
        try {
            val logs = loadLocalLogs().toMutableList()
            val index = logs.indexOfFirst { it.id == log.id }

            if (index != -1) {
                logs[index] = log
                saveLocalLogs(logs)
            }

            val profileId = getProfileId()
            val dto = log.toDto(profileId)
            supabaseClient.from("menstrual_daily_logs").upsert(dto)

            ResultWrapper.Success(log)
        } catch (e: AppException) {
            ResultWrapper.Error(e)
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun deleteDailyLog(logId: String): ResultWrapper<Unit> = withContext(Dispatchers.IO) {
        try {
            val logs = loadLocalLogs().toMutableList()
            logs.removeIf { it.id == logId }
            saveLocalLogs(logs)

            getProfileId()
            supabaseClient.from("menstrual_daily_logs")
                .delete {
                    filter { eq("id", logId) }
                }

            ResultWrapper.Success(Unit)
        } catch (e: AppException) {
            ResultWrapper.Error(e)
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    // ── Settings ──

    override suspend fun getSettings(): ResultWrapper<CycleSettings> = withContext(Dispatchers.IO) {
        try {
            val profileId = getProfileId()

            val dto = supabaseClient.from("menstrual_settings")
                .select {
                    filter { eq("health_profile_id", profileId) }
                    limit(1)
                }
                .decodeSingleOrNull<com.swastricare.health.data.remote.dto.menstrualcycle.MenstrualSettingsDto>()

            val settings = dto?.toDomain() ?: CycleSettings()
            saveLocalSettings(settings)
            ResultWrapper.Success(settings)
        } catch (e: java.io.IOException) {
            ResultWrapper.Success(loadLocalSettings())
        } catch (e: Exception) {
            android.util.Log.e("CycleRepo", "getSettings failed", e)
            ResultWrapper.Error(
                if (e is AppException) e else AppException.UnknownException(cause = e)
            )
        }
    }

    override suspend fun updateSettings(settings: CycleSettings): ResultWrapper<CycleSettings> = withContext(Dispatchers.IO) {
        try {
            saveLocalSettings(settings)

            val profileId = getProfileId()
            val dto = settings.toDto(profileId)
            supabaseClient.from("menstrual_settings").upsert(dto)

            ResultWrapper.Success(settings)
        } catch (e: AppException) {
            ResultWrapper.Error(e)
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    // ── Predictions & Insights ──

    override suspend fun getPrediction(): ResultWrapper<CyclePrediction?> = withContext(Dispatchers.IO) {
        try {
            val cycles = loadLocalCycles().sortedByDescending { it.startDate }
            val settings = loadLocalSettings()

            if (cycles.isEmpty()) {
                return@withContext ResultWrapper.Success(null)
            }

            val lastCycle = cycles.first()

            // Calculate average cycle length from history
            val avgCycleLength = if (cycles.size >= 2) {
                cycles.zipWithNext { a, b ->
                    ChronoUnit.DAYS.between(b.startDate, a.startDate).toInt()
                }.average().toInt()
            } else {
                settings.validatedCycleLength
            }

            val nextPeriod = lastCycle.startDate.plusDays(avgCycleLength.toLong())
            val ovulation = nextPeriod.minusDays(14)
            val fertileStart = ovulation.minusDays(3)
            val fertileEnd = ovulation.plusDays(3)

            val prediction = CyclePrediction(
                nextPeriodDate = nextPeriod,
                ovulationDate = ovulation,
                fertileWindowStart = fertileStart,
                fertileWindowEnd = fertileEnd
            )

            ResultWrapper.Success(prediction)
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun getStatistics(): ResultWrapper<CycleStatistics> = withContext(Dispatchers.IO) {
        try {
            val cycles = loadLocalCycles().sortedBy { it.startDate }

            if (cycles.isEmpty()) {
                return@withContext ResultWrapper.Success(
                    CycleStatistics(
                        averageCycleLength = 0.0,
                        averagePeriodLength = 0.0,
                        longestCycle = 0,
                        shortestCycle = 0,
                        totalCyclesTracked = 0,
                        regularity = CycleRegularity.INSUFFICIENT_DATA
                    )
                )
            }

            val cycleLengths = cycles.zipWithNext { a, b ->
                ChronoUnit.DAYS.between(a.startDate, b.startDate).toInt()
            }

            val periodLengths = cycles.mapNotNull { it.effectivePeriodLength }

            val avgCycle = if (cycleLengths.isNotEmpty()) cycleLengths.average() else 0.0
            val avgPeriod = if (periodLengths.isNotEmpty()) periodLengths.average() else 0.0

            val longest = cycleLengths.maxOrNull() ?: 0
            val shortest = cycleLengths.minOrNull() ?: 0

            // Calculate standard deviation for regularity
            val variance = if (cycleLengths.size > 1) {
                cycleLengths.map { (it - avgCycle) * (it - avgCycle) }.average()
            } else 0.0
            val stdDev = sqrt(variance)

            val regularity = CycleRegularity.fromVariability(stdDev, cycles.size)

            ResultWrapper.Success(
                CycleStatistics(
                    averageCycleLength = avgCycle,
                    averagePeriodLength = avgPeriod,
                    longestCycle = longest,
                    shortestCycle = shortest,
                    totalCyclesTracked = cycles.size,
                    regularity = regularity
                )
            )
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun getCurrentPhase(): ResultWrapper<CyclePhase> = withContext(Dispatchers.IO) {
        try {
            val cycles = loadLocalCycles().sortedByDescending { it.startDate }
            val settings = loadLocalSettings()
            val today = LocalDate.now()

            val lastCycle = cycles.firstOrNull()
                ?: return@withContext ResultWrapper.Success(CyclePhase.UNKNOWN)

            val daysSinceStart = ChronoUnit.DAYS.between(lastCycle.startDate, today).toInt() + 1

            val phase = CyclePhase.fromDayInCycle(
                dayInCycle = daysSinceStart,
                periodLength = lastCycle.effectivePeriodLength ?: settings.validatedPeriodLength,
                cycleLength = settings.validatedCycleLength
            )

            ResultWrapper.Success(phase)
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun getCalendarData(month: LocalDate): ResultWrapper<List<CalendarDayData>> = withContext(Dispatchers.IO) {
        try {
            val cycles = loadLocalCycles()
            val logs = loadLocalLogs()
            val prediction = getPrediction().getOrNull()
            val settings = loadLocalSettings()

            val yearMonth = YearMonth.from(month)
            val daysInMonth = yearMonth.lengthOfMonth()
            val firstDay = month.withDayOfMonth(1)

            val logsByDate = logs.associateBy { it.date }

            val calendarData = (1..daysInMonth).map { day ->
                val date = firstDay.plusDays((day - 1).toLong())

                // Check if date is in any logged period
                val inPeriod = cycles.any { cycle ->
                    val end = cycle.endDate ?: cycle.startDate.plusDays(
                        (cycle.effectivePeriodLength ?: settings.validatedPeriodLength).toLong() - 1
                    )
                    !date.isBefore(cycle.startDate) && !date.isAfter(end)
                }

                val isPredicted = prediction?.isPredictedPeriodDate(
                    date,
                    settings.validatedPeriodLength
                ) == true && !inPeriod

                val log = logsByDate[date]

                // Determine phase
                val phase = cycles.sortedByDescending { it.startDate }.firstOrNull()?.let { lastCycle ->
                    val daysSince = ChronoUnit.DAYS.between(lastCycle.startDate, date).toInt() + 1
                    CyclePhase.fromDayInCycle(
                        dayInCycle = daysSince,
                        periodLength = lastCycle.effectivePeriodLength ?: settings.validatedPeriodLength,
                        cycleLength = settings.validatedCycleLength
                    )
                } ?: CyclePhase.UNKNOWN

                CalendarDayData(
                    date = date,
                    phase = phase,
                    isCurrentPeriod = inPeriod,
                    isPredictedPeriod = isPredicted,
                    flowLevel = log?.flowLevel,
                    hasLog = log != null
                )
            }

            ResultWrapper.Success(calendarData)
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    override suspend fun syncData(): ResultWrapper<Unit> = withContext(Dispatchers.IO) {
        try {
            val profileId = getProfileId()

            val cycles = loadLocalCycles()
            cycles.forEach { cycle ->
                val dto = cycle.toDto(profileId)
                supabaseClient.from("menstrual_cycles").upsert(dto)
            }

            val logs = loadLocalLogs()
            logs.forEach { log ->
                val dto = log.toDto(profileId)
                supabaseClient.from("menstrual_daily_logs").upsert(dto)
            }

            val settings = loadLocalSettings()
            val settingsDto = settings.toDto(profileId)
            supabaseClient.from("menstrual_settings").upsert(settingsDto)

            ResultWrapper.Success(Unit)
        } catch (e: AppException) {
            ResultWrapper.Error(e)
        } catch (e: Exception) {
            ResultWrapper.Error(AppException.UnknownException(cause = e))
        }
    }

    // ── Local Storage Helpers ──

    private suspend fun loadLocalCycles(): List<CycleRecord> {
        val profileId = getProfileIdOrEmpty()
        if (profileId.isEmpty()) return emptyList()
        return try {
            val raw = prefs.getString(cyclesKey(profileId), null) ?: return emptyList()
            json.decodeFromString<List<MenstrualCycleDto>>(raw).map { it.toDomain() }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private suspend fun saveLocalCycles(cycles: List<CycleRecord>) {
        val profileId = getProfileIdOrEmpty()
        if (profileId.isEmpty()) return
        val dtos = cycles.map { it.toDto(profileId) }
        prefs.edit().putString(cyclesKey(profileId), json.encodeToString(dtos)).apply()
    }

    private suspend fun loadLocalLogs(): List<DailyLog> {
        val profileId = getProfileIdOrEmpty()
        if (profileId.isEmpty()) return emptyList()
        return try {
            val raw = prefs.getString(logsKey(profileId), null) ?: return emptyList()
            json.decodeFromString<List<MenstrualDailyLogDto>>(raw).map { it.toDomain() }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private suspend fun saveLocalLogs(logs: List<DailyLog>) {
        val profileId = getProfileIdOrEmpty()
        if (profileId.isEmpty()) return
        val dtos = logs.map { it.toDto(profileId) }
        prefs.edit().putString(logsKey(profileId), json.encodeToString(dtos)).apply()
    }

    private suspend fun loadLocalSettings(): CycleSettings {
        val profileId = getProfileIdOrEmpty()
        if (profileId.isEmpty()) return CycleSettings()
        return try {
            val raw = prefs.getString(settingsKey(profileId), null) ?: return CycleSettings()
            json.decodeFromString<com.swastricare.health.data.remote.dto.menstrualcycle.MenstrualSettingsDto>(raw).toDomain()
        } catch (e: Exception) {
            CycleSettings()
        }
    }

    private suspend fun saveLocalSettings(settings: CycleSettings) {
        val profileId = getProfileIdOrEmpty()
        if (profileId.isEmpty()) return
        val dto = settings.toDto(profileId)
        prefs.edit().putString(settingsKey(profileId), json.encodeToString(dto)).apply()
    }
}
