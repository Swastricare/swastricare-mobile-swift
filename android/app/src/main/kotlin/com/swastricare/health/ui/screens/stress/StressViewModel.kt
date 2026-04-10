package com.swastricare.health.ui.screens.stress

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.repository.SupabaseProfileRepository
import com.swastricare.health.domain.model.stress.StressCategory
import com.swastricare.health.domain.model.stress.StressEntry
import com.swastricare.health.domain.model.stress.StressMood
import com.swastricare.health.domain.model.stress.StressSource
import com.swastricare.health.domain.repository.AuthRepository
import com.swastricare.health.domain.repository.StressRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import javax.inject.Inject

// ── Time Range ──

enum class StressTimeRange(val label: String, val days: Int) {
    WEEK("7D", 7),
    MONTH("30D", 30),
    QUARTER("90D", 90)
}

// ── Analytics data models ──

data class StressDailyAggregate(
    val date: LocalDate,
    val avgLevel: Int,
    val entryCount: Int
)

data class StressDayGroup(
    val date: LocalDate,
    val label: String,
    val entries: List<StressEntry>
)

data class StressSummary(
    val average: Int,
    val min: Int,
    val max: Int,
    val totalCount: Int
)

// ── UI State ──

data class StressUiState(
    val allEntries: List<StressEntry> = emptyList(),
    val currentEntry: StressEntry? = null,
    val selectedRange: StressTimeRange = StressTimeRange.WEEK,
    val isLoading: Boolean = true,
    val selectedStressLevel: Int = 5,
    val selectedMood: StressMood = StressMood.NEUTRAL,
    val logNotes: String = "",
    val isLogging: Boolean = false,
    val logSuccess: Boolean = false,
    val errorMessage: String? = null
)

// ── ViewModel ──

@HiltViewModel
class StressViewModel @Inject constructor(
    private val stressRepository: StressRepository,
    private val authRepository: AuthRepository,
    private val profileRepository: SupabaseProfileRepository
) : ViewModel() {

    companion object {
        private const val TAG = "StressVM"
    }

    private val _uiState = MutableStateFlow(StressUiState())
    val uiState: StateFlow<StressUiState> = _uiState.asStateFlow()

    init {
        loadData()
    }

    // ── Derived computed values ──

    fun getFilteredEntries(): List<StressEntry> {
        val state = _uiState.value
        val cutoff = LocalDateTime.now().minus(state.selectedRange.days.toLong(), ChronoUnit.DAYS)
        return state.allEntries
            .filter { it.timestamp.isAfter(cutoff) }
            .sortedBy { it.timestamp }
    }

    fun getSummary(): StressSummary {
        val filtered = getFilteredEntries()
        if (filtered.isEmpty()) {
            return StressSummary(average = 0, min = 0, max = 0, totalCount = 0)
        }
        return StressSummary(
            average = filtered.map { it.stressLevel }.average().toInt(),
            min = filtered.minOf { it.stressLevel },
            max = filtered.maxOf { it.stressLevel },
            totalCount = filtered.size
        )
    }

    fun getDailyAggregates(): List<StressDailyAggregate> {
        return getFilteredEntries()
            .groupBy { it.timestamp.toLocalDate() }
            .map { (date, entries) ->
                StressDailyAggregate(
                    date = date,
                    avgLevel = entries.map { it.stressLevel }.average().toInt(),
                    entryCount = entries.size
                )
            }
            .sortedBy { it.date }
    }

    fun getGroupedHistory(): List<StressDayGroup> {
        val today = LocalDate.now()
        val yesterday = today.minusDays(1)
        val dateFormatter = DateTimeFormatter.ofPattern("MMM d, yyyy")

        return getFilteredEntries()
            .sortedByDescending { it.timestamp }
            .groupBy { it.timestamp.toLocalDate() }
            .map { (date, entries) ->
                val label = when (date) {
                    today -> "Today"
                    yesterday -> "Yesterday"
                    else -> date.format(dateFormatter)
                }
                StressDayGroup(date = date, label = label, entries = entries)
            }
            .sortedByDescending { it.date }
    }

    fun getCategoryDistribution(): Map<StressCategory, Float> {
        val filtered = getFilteredEntries()
        if (filtered.isEmpty()) return emptyMap()
        val total = filtered.size.toFloat()
        return filtered.groupBy { it.category }
            .mapValues { (_, entries) -> entries.size / total }
    }

    // ── Actions ──

    fun setTimeRange(range: StressTimeRange) {
        _uiState.update { it.copy(selectedRange = range) }
    }

    fun setStressLevel(level: Int) {
        _uiState.update { it.copy(selectedStressLevel = level.coerceIn(1, 10)) }
    }

    fun setMood(mood: StressMood) {
        _uiState.update { it.copy(selectedMood = mood) }
    }

    fun setLogNotes(notes: String) {
        _uiState.update { it.copy(logNotes = notes) }
    }

    fun dismissLogSuccess() {
        _uiState.update { it.copy(logSuccess = false) }
    }

    fun logStress() {
        val state = _uiState.value
        if (state.isLogging) return

        viewModelScope.launch {
            _uiState.update { it.copy(isLogging = true, errorMessage = null) }

            val goodPercent = ((10 - state.selectedStressLevel) * 100) / 10
            val entry = StressEntry(
                stressLevel = state.selectedStressLevel,
                calculatedStressPercent = goodPercent,
                mood = state.selectedMood,
                notes = state.logNotes,
                timestamp = LocalDateTime.now(),
                source = StressSource.MANUAL
            )

            when (val result = stressRepository.addEntry(entry)) {
                is ResultWrapper.Success -> {
                    _uiState.update {
                        it.copy(
                            isLogging = false,
                            logSuccess = true,
                            selectedStressLevel = 5,
                            selectedMood = StressMood.NEUTRAL,
                            logNotes = ""
                        )
                    }
                    // Reload and try cloud sync
                    loadData()
                    syncToCloudInBackground(entry)
                }
                is ResultWrapper.Error -> {
                    _uiState.update {
                        it.copy(
                            isLogging = false,
                            errorMessage = "Failed to save entry"
                        )
                    }
                }
                is ResultWrapper.Loading -> { /* no-op */ }
            }
        }
    }

    // ── Data Loading ──

    private fun loadData() {
        viewModelScope.launch {
            try {
                val localEntries = stressRepository.loadLocalEntries()
                val latest = localEntries.maxByOrNull { it.timestamp }

                _uiState.update {
                    it.copy(
                        allEntries = localEntries,
                        currentEntry = latest,
                        isLoading = false,
                        errorMessage = null
                    )
                }

                // Background cloud fetch
                fetchCloudData(localEntries)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load data", e)
                _uiState.update {
                    it.copy(isLoading = false, errorMessage = "Failed to load data")
                }
            }
        }
    }

    private suspend fun fetchCloudData(localEntries: List<StressEntry>) {
        val profileId = resolveProfileId() ?: return

        when (val result = stressRepository.fetchFromCloud(profileId)) {
            is ResultWrapper.Success -> {
                val cloudEntries = result.data
                val localIds = localEntries.map { it.id }.toSet()
                val newFromCloud = cloudEntries.filter { it.id !in localIds }
                if (newFromCloud.isNotEmpty()) {
                    val merged = (localEntries + newFromCloud).sortedBy { it.timestamp }
                    _uiState.update {
                        it.copy(
                            allEntries = merged,
                            currentEntry = merged.maxByOrNull { e -> e.timestamp }
                        )
                    }
                }
            }
            is ResultWrapper.Error -> {
                Log.w(TAG, "Cloud fetch failed: ${result.exception}")
            }
            is ResultWrapper.Loading -> { /* no-op */ }
        }
    }

    private suspend fun syncToCloudInBackground(entry: StressEntry) {
        val profileId = resolveProfileId() ?: return
        stressRepository.syncToCloud(listOf(entry), profileId)
    }

    private suspend fun resolveProfileId(): String? {
        val userId = authRepository.getCurrentUser()?.id ?: return null
        val healthProfile = profileRepository.getHealthProfile(userId) ?: return null
        return healthProfile.id
    }
}
