package com.swastricare.health.ui.screens.heartrate

import android.content.SharedPreferences
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.repository.SupabaseProfileRepository
import com.swastricare.health.domain.model.heartrate.BPMCategory
import com.swastricare.health.domain.model.heartrate.HeartRateMeasurement
import com.swastricare.health.domain.model.heartrate.MeasurementSource
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.domain.repository.HeartRateRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import javax.inject.Inject
import kotlin.math.abs

// ─────────────────────────────────────
// MARK: - Time Range
// ─────────────────────────────────────

enum class AnalyticsTimeRange(val label: String, val days: Int) {
    WEEK("7D", 7),
    MONTH("30D", 30),
    QUARTER("90D", 90)
}

// ─────────────────────────────────────
// MARK: - Source Filter
// ─────────────────────────────────────

enum class SourceFilter(val label: String) {
    ALL("All"),
    DEVICE("On Device"),
    CLOUD("Cloud")
}

// ─────────────────────────────────────
// MARK: - Reading Source
// ─────────────────────────────────────

enum class ReadingSource {
    LOCAL,
    CLOUD
}

// ─────────────────────────────────────
// MARK: - Analytics Data Models
// ─────────────────────────────────────

data class AnalyticsReading(
    val bpm: Int,
    val timestamp: LocalDateTime,
    val source: ReadingSource,
    val measurementSource: MeasurementSource,
    val confidence: Float,
    val category: BPMCategory
)

data class AnalyticsSummary(
    val average: Int,
    val latest: AnalyticsReading?,
    val min: Int,
    val max: Int,
    val totalCount: Int
)

data class DailyAggregate(
    val date: LocalDate,
    val avgBpm: Int,
    val readingCount: Int
)

data class DayGroup(
    val date: LocalDate,
    val label: String,
    val readings: List<AnalyticsReading>
)

// ─────────────────────────────────────
// MARK: - UI State
// ─────────────────────────────────────

data class HeartRateAnalyticsUiState(
    val allReadings: List<AnalyticsReading> = emptyList(),
    val selectedRange: AnalyticsTimeRange = AnalyticsTimeRange.WEEK,
    val selectedSource: SourceFilter = SourceFilter.ALL,
    val isLoading: Boolean = true,
    val isRefreshing: Boolean = false,
    val cloudAvailable: Boolean = false,
    val errorMessage: String? = null,
    val showClearConfirmation: Boolean = false
)

// ─────────────────────────────────────
// MARK: - ViewModel
// ─────────────────────────────────────

@HiltViewModel
class HeartRateAnalyticsViewModel @Inject constructor(
    private val heartRateRepository: HeartRateRepository,
    private val authRepository: AuthRepository,
    private val profileRepository: SupabaseProfileRepository,
    private val prefs: SharedPreferences
) : ViewModel() {

    companion object {
        private const val TAG = "HRAnalyticsVM"
        private const val LEGACY_PREF_KEY = "heart_rate_readings"
        private const val DEDUP_THRESHOLD_SECONDS = 2L
    }

    private val _uiState = MutableStateFlow(HeartRateAnalyticsUiState())
    val uiState: StateFlow<HeartRateAnalyticsUiState> = _uiState.asStateFlow()

    private val json = Json { ignoreUnknownKeys = true }

    init {
        loadData()
    }

    // ── Derived computed values ──

    fun getFilteredReadings(): List<AnalyticsReading> {
        val state = _uiState.value
        val cutoff = LocalDateTime.now().minus(state.selectedRange.days.toLong(), ChronoUnit.DAYS)
        return state.allReadings
            .filter { it.timestamp.isAfter(cutoff) }
            .filter { reading ->
                when (state.selectedSource) {
                    SourceFilter.ALL -> true
                    SourceFilter.DEVICE -> reading.source == ReadingSource.LOCAL
                    SourceFilter.CLOUD -> reading.source == ReadingSource.CLOUD
                }
            }
            .sortedBy { it.timestamp }
    }

    fun getSummary(): AnalyticsSummary {
        val filtered = getFilteredReadings()
        if (filtered.isEmpty()) {
            return AnalyticsSummary(average = 0, latest = null, min = 0, max = 0, totalCount = 0)
        }
        return AnalyticsSummary(
            average = filtered.map { it.bpm }.average().toInt(),
            latest = filtered.maxByOrNull { it.timestamp },
            min = filtered.minOf { it.bpm },
            max = filtered.maxOf { it.bpm },
            totalCount = filtered.size
        )
    }

    fun getDailyAggregates(): List<DailyAggregate> {
        return getFilteredReadings()
            .groupBy { it.timestamp.toLocalDate() }
            .map { (date, readings) ->
                DailyAggregate(
                    date = date,
                    avgBpm = readings.map { it.bpm }.average().toInt(),
                    readingCount = readings.size
                )
            }
            .sortedBy { it.date }
    }

    fun getGroupedHistory(): List<DayGroup> {
        val today = LocalDate.now()
        val yesterday = today.minusDays(1)
        val dateFormatter = DateTimeFormatter.ofPattern("MMM d, yyyy")

        return getFilteredReadings()
            .sortedByDescending { it.timestamp }
            .groupBy { it.timestamp.toLocalDate() }
            .map { (date, readings) ->
                val label = when (date) {
                    today -> "Today"
                    yesterday -> "Yesterday"
                    else -> date.format(dateFormatter)
                }
                DayGroup(date = date, label = label, readings = readings)
            }
            .sortedByDescending { it.date }
    }

    // ── Actions ──

    fun setTimeRange(range: AnalyticsTimeRange) {
        _uiState.update { it.copy(selectedRange = range) }
    }

    fun setSourceFilter(filter: SourceFilter) {
        _uiState.update { it.copy(selectedSource = filter) }
    }

    fun showClearConfirmation() {
        _uiState.update { it.copy(showClearConfirmation = true) }
    }

    fun dismissClearConfirmation() {
        _uiState.update { it.copy(showClearConfirmation = false) }
    }

    fun clearHistory() {
        viewModelScope.launch {
            heartRateRepository.clearAllMeasurements()
            // Also clear legacy key
            prefs.edit().remove(LEGACY_PREF_KEY).apply()
            _uiState.update {
                it.copy(
                    allReadings = emptyList(),
                    showClearConfirmation = false
                )
            }
        }
    }

    fun refresh() {
        _uiState.update { it.copy(isRefreshing = true) }
        loadData(isRefresh = true)
    }

    // ── Data Loading ──

    private fun loadData(isRefresh: Boolean = false) {
        viewModelScope.launch {
            try {
                // 1. Load from repository (local storage)
                val localMeasurements = heartRateRepository.loadLocalMeasurements()
                val localReadings = localMeasurements.map { it.toAnalyticsReading(ReadingSource.LOCAL) }

                // 2. Load legacy SharedPreferences readings and merge
                val legacyReadings = loadLegacyReadings()

                // 3. Merge local + legacy (dedup)
                val mergedLocal = mergeAndDeduplicate(localReadings, legacyReadings)

                // Update UI with local data first
                _uiState.update {
                    it.copy(
                        allReadings = mergedLocal,
                        isLoading = false,
                        isRefreshing = false,
                        errorMessage = null
                    )
                }

                // 4. Try cloud fetch in background
                fetchCloudData(mergedLocal)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load data", e)
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        isRefreshing = false,
                        errorMessage = "Failed to load readings"
                    )
                }
            }
        }
    }

    private suspend fun fetchCloudData(localReadings: List<AnalyticsReading>) {
        val profileId = resolveProfileId()
        if (profileId == null) {
            _uiState.update { it.copy(cloudAvailable = false) }
            return
        }

        _uiState.update { it.copy(cloudAvailable = true) }

        heartRateRepository.fetchFromCloud(profileId).let { result ->
            when (result) {
                is com.swastricare.health.core.result.ResultWrapper.Success -> {
                    val cloudReadings = result.data.map { it.toAnalyticsReading(ReadingSource.CLOUD) }
                    val merged = mergeAndDeduplicate(localReadings, cloudReadings)
                    _uiState.update { it.copy(allReadings = merged) }
                }
                is com.swastricare.health.core.result.ResultWrapper.Error -> {
                    Log.w(TAG, "Cloud fetch failed: ${result.exception}")
                }
                is com.swastricare.health.core.result.ResultWrapper.Loading -> { /* no-op */ }
            }
        }
    }

    private suspend fun resolveProfileId(): String? {
        val userId = authRepository.getCurrentUser()?.id ?: return null
        val healthProfile = profileRepository.getHealthProfile(userId) ?: return null
        return healthProfile.id
    }

    // ── Legacy SharedPreferences Migration ──

    private fun loadLegacyReadings(): List<AnalyticsReading> {
        val raw = prefs.getString(LEGACY_PREF_KEY, null) ?: return emptyList()
        return try {
            val legacyReadings = json.decodeFromString<List<HeartRateReading>>(raw)
            legacyReadings.mapNotNull { reading ->
                try {
                    val dt = LocalDateTime.parse(reading.timestamp, DateTimeFormatter.ISO_LOCAL_DATE_TIME)
                    AnalyticsReading(
                        bpm = reading.bpm,
                        timestamp = dt,
                        source = ReadingSource.LOCAL,
                        measurementSource = if (reading.source == "Camera") MeasurementSource.CAMERA
                        else MeasurementSource.HEALTH_CONNECT,
                        confidence = reading.confidence,
                        category = BPMCategory.fromBPM(reading.bpm)
                    )
                } catch (_: Exception) {
                    null
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    // ── Deduplication ──

    private fun mergeAndDeduplicate(
        primary: List<AnalyticsReading>,
        secondary: List<AnalyticsReading>
    ): List<AnalyticsReading> {
        val merged = primary.toMutableList()
        for (reading in secondary) {
            val isDuplicate = merged.any { existing ->
                existing.bpm == reading.bpm &&
                        abs(ChronoUnit.SECONDS.between(existing.timestamp, reading.timestamp)) <= DEDUP_THRESHOLD_SECONDS
            }
            if (!isDuplicate) {
                merged.add(reading)
            }
        }
        return merged.sortedBy { it.timestamp }
    }

    // ── Mapping ──

    private fun HeartRateMeasurement.toAnalyticsReading(readingSource: ReadingSource): AnalyticsReading {
        return AnalyticsReading(
            bpm = bpm,
            timestamp = timestamp,
            source = readingSource,
            measurementSource = source,
            confidence = confidence,
            category = category
        )
    }
}
