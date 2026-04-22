package com.swastricare.health.ui.screens.menstrualcycle

import android.app.Application
import androidx.compose.ui.graphics.Color
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.services.AppAnalyticsService
import com.swastricare.health.data.workers.CycleSyncWorker
import com.swastricare.health.domain.model.menstrualcycle.CycleRecord
import com.swastricare.health.domain.model.menstrualcycle.CycleSettings as DomainCycleSettings
import com.swastricare.health.domain.repository.MenstrualCycleRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.gotrue.auth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import javax.inject.Inject

// ─────────────────────────────────────
// MARK: - Cycle Phase Enum (UI)
// ─────────────────────────────────────

enum class CyclePhase(
    val displayName: String,
    val icon: String,
    val color: Color,
    val description: String,
    val symptoms: List<String>,
    val recommendations: List<String>
) {
    MENSTRUAL(
        displayName = "Menstrual Phase",
        icon = "\uD83C\uDF39", // rose
        color = Color(0xFFE91E63),
        description = "Your body is shedding the uterine lining. Hormone levels (estrogen and progesterone) are at their lowest. This is a natural reset for your cycle, and your body is working to renew itself.",
        symptoms = listOf(
            "Cramps & lower back pain",
            "Fatigue & low energy",
            "Bloating",
            "Mood changes",
            "Headaches"
        ),
        recommendations = listOf(
            "Rest and gentle stretching or yoga",
            "Stay hydrated and eat iron-rich foods",
            "Use a heating pad for cramp relief"
        )
    ),
    FOLLICULAR(
        displayName = "Follicular Phase",
        icon = "\uD83C\uDF31", // seedling
        color = Color(0xFF4CAF50),
        description = "Estrogen levels begin rising as your body prepares to release an egg. Energy levels increase and you may feel more creative and social. The uterine lining starts thickening again.",
        symptoms = listOf(
            "Increased energy",
            "Improved mood",
            "Heightened creativity",
            "Clearer skin"
        ),
        recommendations = listOf(
            "Great time for high-intensity workouts",
            "Start new projects or social activities",
            "Focus on nutrient-dense whole foods"
        )
    ),
    OVULATION(
        displayName = "Ovulation Phase",
        icon = "\uD83E\uDD5A", // egg
        color = Color(0xFFFF9800),
        description = "An egg is released from the ovary, making this your most fertile window. Estrogen peaks and luteinizing hormone surges. You may feel your most confident and energetic during this brief phase.",
        symptoms = listOf(
            "Mild pelvic discomfort (mittelschmerz)",
            "Increased cervical mucus",
            "Slight rise in body temperature",
            "Higher libido"
        ),
        recommendations = listOf(
            "Peak performance time for workouts",
            "Stay well-hydrated",
            "Track basal body temperature if monitoring fertility"
        )
    ),
    LUTEAL(
        displayName = "Luteal Phase",
        icon = "\uD83C\uDF19", // crescent moon
        color = Color(0xFF9C27B0),
        description = "After ovulation, progesterone rises to prepare the uterus for a potential pregnancy. If the egg is not fertilized, hormone levels drop toward the end of this phase, triggering PMS symptoms.",
        symptoms = listOf(
            "Breast tenderness",
            "Bloating & water retention",
            "Mood swings & irritability",
            "Food cravings",
            "Fatigue"
        ),
        recommendations = listOf(
            "Opt for moderate exercise like walking or swimming",
            "Limit caffeine and salty foods to reduce bloating",
            "Prioritize sleep and stress management"
        )
    )
}

// ─────────────────────────────────────
// MARK: - Phase-Specific Tips
// ─────────────────────────────────────

data class PhaseTip(
    val icon: String,
    val title: String,
    val description: String
)

fun tipsForPhase(phase: CyclePhase): List<PhaseTip> = when (phase) {
    CyclePhase.MENSTRUAL -> listOf(
        PhaseTip("\uD83E\uDDD8", "Gentle Movement", "Try light yoga or stretching to ease cramps and boost circulation."),
        PhaseTip("\uD83C\uDF72", "Iron-Rich Meals", "Eat spinach, lentils, and red meat to replenish iron lost during menstruation."),
        PhaseTip("\u2615", "Warm Beverages", "Herbal teas like ginger or chamomile can soothe cramps and calm the mind."),
        PhaseTip("\uD83D\uDECC", "Rest & Recovery", "Honor your body's need for rest. Sleep 7-9 hours and avoid overexertion.")
    )
    CyclePhase.FOLLICULAR -> listOf(
        PhaseTip("\uD83C\uDFCB\uFE0F", "High-Intensity Training", "Your rising estrogen boosts strength and endurance. Push your limits!"),
        PhaseTip("\uD83E\uDD66", "Eat Fresh & Light", "Focus on fermented foods, lean proteins, and fresh vegetables."),
        PhaseTip("\uD83D\uDCA1", "Start New Projects", "Creativity peaks in this phase. Great time for brainstorming and planning."),
        PhaseTip("\uD83D\uDCA7", "Hydrate Well", "Drink at least 2-3 liters of water daily to support cell renewal.")
    )
    CyclePhase.OVULATION -> listOf(
        PhaseTip("\u26A1", "Peak Performance", "Your body is at peak physical capacity. Try HIIT, running, or group sports."),
        PhaseTip("\uD83E\uDD51", "Healthy Fats", "Avocados, nuts, and olive oil support hormone production during ovulation."),
        PhaseTip("\uD83C\uDF1E", "Social Connection", "Confidence and communication skills are at their best. Plan social events."),
        PhaseTip("\uD83C\uDF21\uFE0F", "Track Temperature", "Monitor basal body temperature for fertility awareness.")
    )
    CyclePhase.LUTEAL -> listOf(
        PhaseTip("\uD83D\uDEB6", "Moderate Exercise", "Switch to walking, Pilates, or swimming as energy levels start to dip."),
        PhaseTip("\uD83C\uDF6B", "Magnesium-Rich Foods", "Dark chocolate, bananas, and almonds help combat PMS and cravings."),
        PhaseTip("\uD83D\uDE34", "Prioritize Sleep", "Progesterone may cause drowsiness. Aim for consistent sleep patterns."),
        PhaseTip("\uD83E\uDDD8\u200D\u2640\uFE0F", "Stress Management", "Practice deep breathing or meditation to manage mood swings.")
    )
}

// ─────────────────────────────────────
// MARK: - Cycle History & Statistics
// ─────────────────────────────────────

data class CycleRecordUi(
    val startDate: LocalDate,
    val cycleLength: Int,
    val periodLength: Int
)

data class SymptomFrequency(
    val symptom: String,
    val percentage: Float // 0..1
)

data class CycleStatistics(
    val averageCycleLength: Float,
    val averagePeriodLength: Float,
    val lastPeriodDate: LocalDate?,
    val predictedNextPeriod: LocalDate?,
    val regularity: CycleRegularity,
    val recentCycles: List<CycleRecordUi>,
    val symptomFrequencies: List<SymptomFrequency>
)

enum class CycleRegularity(val displayName: String, val color: Color) {
    REGULAR("Regular", Color(0xFF4CAF50)),
    SOMEWHAT_IRREGULAR("Somewhat Irregular", Color(0xFFFF9800)),
    IRREGULAR("Irregular", Color(0xFFE91E63))
}

// ─────────────────────────────────────
// MARK: - Cycle Settings (UI)
// ─────────────────────────────────────

data class CycleSettings(
    val averageCycleLength: Int = 28,
    val averagePeriodLength: Int = 5,
    val periodReminderEnabled: Boolean = true,
    val fertileWindowReminderEnabled: Boolean = false,
    val pmsReminderEnabled: Boolean = false,
    val ovulationReminderEnabled: Boolean = false,
    val reminderDaysBefore: Int = 2,
    val lutealPhaseLength: Int = 14
)

// ─────────────────────────────────────
// MARK: - UI State
// ─────────────────────────────────────

data class MenstrualCycleUiState(
    val currentPhase: CyclePhase = CyclePhase.FOLLICULAR,
    val currentDayInCycle: Int = 1,
    val totalCycleDays: Int = 28,
    val daysUntilNextPeriod: Int = 14,
    val lastPeriodStart: LocalDate = LocalDate.now().minusDays(14),
    val settings: CycleSettings = CycleSettings(),
    val statistics: CycleStatistics? = null,
    val isLoading: Boolean = true,
    val isNotSetUp: Boolean = false,
    val error: String? = null,
    val selectedMonth: LocalDate = LocalDate.now().withDayOfMonth(1),
    val loggedPeriodDates: Set<LocalDate> = emptySet(),
    val predictedPeriodDates: Set<LocalDate> = emptySet(),
    val fertileWindowDates: Set<LocalDate> = emptySet()
) {
    val cycleProgress: Float
        get() = if (totalCycleDays > 0) currentDayInCycle.toFloat() / totalCycleDays else 0f
}

// ─────────────────────────────────────
// MARK: - ViewModel
// ─────────────────────────────────────

@HiltViewModel
class MenstrualCycleViewModel @Inject constructor(
    private val application: Application,
    private val analyticsService: AppAnalyticsService,
    private val cycleRepository: MenstrualCycleRepository,
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(MenstrualCycleUiState())
    val uiState: StateFlow<MenstrualCycleUiState> = _uiState.asStateFlow()

    private val dateFormatter = DateTimeFormatter.ofPattern("MMM dd, yyyy")

    /** Cached domain cycles for efficient togglePeriodDate logic */
    private var cachedCycles: List<CycleRecord> = emptyList()

    init {
        loadData()
        // Start periodic background sync
        CycleSyncWorker.enqueuePeriodicSync(application)
    }

    fun loadData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            val currentUserId = supabaseClient.auth.currentUserOrNull()?.id
            if (currentUserId == null) {
                _uiState.value = MenstrualCycleUiState(isLoading = false, isNotSetUp = true)
                return@launch
            }

            // Load settings from repository
            val settings = when (val result = cycleRepository.getSettings()) {
                is ResultWrapper.Success -> result.data
                is ResultWrapper.Error -> DomainCycleSettings()
                is ResultWrapper.Loading -> DomainCycleSettings()
            }
            val uiSettings = settings.toUiSettings()

            // Load cycles from repository
            val cycles = when (val result = cycleRepository.getCycles()) {
                is ResultWrapper.Success -> result.data
                is ResultWrapper.Error, is ResultWrapper.Loading -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        isNotSetUp = true,
                        error = if (result is ResultWrapper.Error) "Failed to load cycle data" else null
                    )
                    return@launch
                }
            }
            cachedCycles = cycles

            if (cycles.isEmpty()) {
                _uiState.value = MenstrualCycleUiState(
                    isLoading = false,
                    isNotSetUp = true,
                    settings = uiSettings,
                    selectedMonth = LocalDate.now().withDayOfMonth(1)
                )
                return@launch
            }

            buildStateFromCycles(cycles, uiSettings)

            // Trigger a one-shot sync to push any offline-only data to Supabase
            requestSync()
        }
    }

    /** Enqueue a one-shot background sync so local data reaches Supabase. */
    private fun requestSync() {
        CycleSyncWorker.enqueueOneTimeSync(application)
    }

    private fun buildStateFromCycles(
        cycles: List<CycleRecord>,
        settings: CycleSettings
    ) {
        val today = LocalDate.now()
        val lastCycle = cycles.maxByOrNull { it.startDate } ?: return
        val lastPeriodStart = lastCycle.startDate

        val dayInCycle = ChronoUnit.DAYS.between(lastPeriodStart, today).toInt() + 1
        val totalDays = settings.averageCycleLength
        val daysUntil = totalDays - dayInCycle
        val phase = calculatePhase(dayInCycle, settings)

        // Build logged period dates from all cycles
        val loggedDates = cycles.flatMap { cycle ->
            val periodLen = cycle.effectivePeriodLength ?: settings.averagePeriodLength
            val end = cycle.endDate ?: cycle.startDate.plusDays((periodLen).toLong() - 1)
            generateSequence(cycle.startDate) { d ->
                if (d < end) d.plusDays(1) else null
            }.toSet()
        }.toSet()

        val predictedDates = generatePredictedPeriodDates(lastPeriodStart, settings)
        val fertileDates = generateFertileWindowDates(lastPeriodStart, settings)
        val statistics = buildStatisticsFromCycles(cycles, lastPeriodStart, settings)

        _uiState.value = MenstrualCycleUiState(
            currentPhase = phase,
            currentDayInCycle = dayInCycle.coerceIn(1, totalDays),
            totalCycleDays = totalDays,
            daysUntilNextPeriod = daysUntil.coerceAtLeast(0),
            lastPeriodStart = lastPeriodStart,
            settings = settings,
            statistics = statistics,
            isLoading = false,
            isNotSetUp = false,
            selectedMonth = today.withDayOfMonth(1),
            loggedPeriodDates = loggedDates,
            predictedPeriodDates = predictedDates,
            fertileWindowDates = fertileDates
        )
    }

    /**
     * Starts a new period from the given date. Used by the onboarding flow
     * and calendar date tapping.
     */
    fun startPeriod(date: LocalDate) {
        viewModelScope.launch {
            when (cycleRepository.startCycle(date)) {
                is ResultWrapper.Success -> {
                    analyticsService.trackCycleLogged("start")
                    // Optimistically clear empty state so calendar shows immediately
                    _uiState.value = _uiState.value.copy(isNotSetUp = false, isLoading = true)
                    loadData()
                }
                is ResultWrapper.Error -> {
                    _uiState.value = _uiState.value.copy(error = "Failed to start period")
                }
                is ResultWrapper.Loading -> { /* no-op */ }
            }
        }
    }

    fun logPeriodWithDetails(
        startDate: LocalDate,
        flowLevel: com.swastricare.health.domain.model.menstrualcycle.FlowLevel,
        symptoms: List<com.swastricare.health.domain.model.menstrualcycle.Symptom>,
        mood: com.swastricare.health.domain.model.menstrualcycle.Mood?,
        painLevel: Int,
        notes: String?
    ) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            // 1. Start the cycle
            val cycleResult = cycleRepository.startCycle(startDate, notes)
            if (cycleResult is ResultWrapper.Error) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "Failed to log period"
                )
                return@launch
            }
            // 2. Log daily data for the start date
            val dailyResult = cycleRepository.logDailyData(
                date = startDate,
                flowLevel = flowLevel,
                symptoms = symptoms,
                mood = mood,
                notes = notes,
                painLevel = painLevel
            )
            if (dailyResult is ResultWrapper.Error) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = "Period started but failed to save details"
                )
                return@launch
            }
            analyticsService.trackCycleLogged("full_log")
            // 3. Optimistic clear + reload
            _uiState.value = _uiState.value.copy(isNotSetUp = false, isLoading = true)
            loadData()
        }
    }

    /**
     * Ends the current active period on the given date.
     */
    fun endPeriod(date: LocalDate) {
        viewModelScope.launch {
            val activeCycle = cachedCycles.firstOrNull { it.isActive }
            if (activeCycle == null) {
                _uiState.value = _uiState.value.copy(
                    error = "No active period to end"
                )
                return@launch
            }

            when (cycleRepository.endCycle(activeCycle.id, date)) {
                is ResultWrapper.Success -> {
                    analyticsService.trackCycleLogged("end")
                    loadData()
                }
                is ResultWrapper.Error -> {
                    _uiState.value = _uiState.value.copy(
                        error = "Failed to end period"
                    )
                }
                is ResultWrapper.Loading -> { /* no-op */ }
            }
        }
    }

    /**
     * Toggle a date as period or not. If the date is already logged, remove
     * the cycle. If it's not logged, start a new period or extend the
     * current active one.
     */
    fun togglePeriodDate(date: LocalDate) {
        val current = _uiState.value
        val isAlreadyLogged = current.loggedPeriodDates.contains(date)

        if (isAlreadyLogged) {
            // Find which cycle contains this date and delete it if it's the start,
            // or end the cycle on the previous day
            val containingCycle = cachedCycles.firstOrNull { cycle ->
                val periodLen = cycle.effectivePeriodLength ?: current.settings.averagePeriodLength
                val end = cycle.endDate ?: cycle.startDate.plusDays(periodLen.toLong() - 1)
                !date.isBefore(cycle.startDate) && !date.isAfter(end)
            }
            if (containingCycle != null) {
                if (date == containingCycle.startDate) {
                    // Delete the entire cycle
                    viewModelScope.launch {
                        cycleRepository.deleteCycle(containingCycle.id)
                        analyticsService.trackCycleLogged("delete")
                        loadData()
                    }
                } else {
                    // End the cycle on the day before this date
                    viewModelScope.launch {
                        cycleRepository.endCycle(containingCycle.id, date.minusDays(1))
                        analyticsService.trackCycleLogged("end")
                        loadData()
                    }
                }
            }
        } else {
            // Check if there's an active cycle we can extend, or start a new one
            val activeCycle = cachedCycles.firstOrNull { it.isActive }
            if (activeCycle != null) {
                // If the date is after the active period's estimated end,
                // the user is probably extending it
                val periodLen = activeCycle.effectivePeriodLength ?: current.settings.averagePeriodLength
                val estimatedEnd = activeCycle.startDate.plusDays(periodLen.toLong() - 1)

                if (date.isAfter(estimatedEnd) || date.isBefore(activeCycle.startDate)) {
                    // Start a new cycle for this date
                    startPeriod(date)
                } else {
                    // Date is within the active cycle range, just reload
                    loadData()
                }
            } else {
                // No active cycle, start a new one
                startPeriod(date)
            }
        }
    }

    fun changeMonth(delta: Int) {
        val current = _uiState.value
        val newMonth = current.selectedMonth.plusMonths(delta.toLong())
        _uiState.value = current.copy(selectedMonth = newMonth)
    }

    fun updateCycleSettings(
        cycleLength: Int,
        periodLength: Int,
        reminderDaysBefore: Int? = null
    ) {
        val current = _uiState.value
        val newSettings = current.settings.copy(
            averageCycleLength = cycleLength,
            averagePeriodLength = periodLength,
            reminderDaysBefore = reminderDaysBefore ?: current.settings.reminderDaysBefore
        )
        _uiState.value = current.copy(settings = newSettings)
        viewModelScope.launch {
            cycleRepository.updateSettings(newSettings.toDomain())
            recalculate()
        }
    }

    fun updateNotificationSettings(
        periodReminder: Boolean? = null,
        fertileReminder: Boolean? = null,
        pmsReminder: Boolean? = null,
        ovulationReminder: Boolean? = null,
        reminderDaysBefore: Int? = null
    ) {
        val current = _uiState.value
        val newSettings = current.settings.copy(
            periodReminderEnabled = periodReminder ?: current.settings.periodReminderEnabled,
            fertileWindowReminderEnabled = fertileReminder ?: current.settings.fertileWindowReminderEnabled,
            pmsReminderEnabled = pmsReminder ?: current.settings.pmsReminderEnabled,
            ovulationReminderEnabled = ovulationReminder ?: current.settings.ovulationReminderEnabled,
            reminderDaysBefore = reminderDaysBefore ?: current.settings.reminderDaysBefore
        )
        _uiState.value = current.copy(settings = newSettings)
        viewModelScope.launch {
            cycleRepository.updateSettings(newSettings.toDomain())
        }
    }

    fun loadStatistics() {
        viewModelScope.launch {
            val current = _uiState.value
            val stats = buildStatisticsFromCycles(cachedCycles, current.lastPeriodStart, current.settings)
            _uiState.value = current.copy(statistics = stats)
        }
    }

    fun dismissError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    // ─────────────────────────────────────
    // MARK: - Private Helpers
    // ─────────────────────────────────────

    private fun recalculate() {
        val current = _uiState.value
        val settings = current.settings
        val lastPeriod = current.lastPeriodStart
        val today = LocalDate.now()

        val dayInCycle = ChronoUnit.DAYS.between(lastPeriod, today).toInt() + 1
        val daysUntil = settings.averageCycleLength - dayInCycle
        val phase = calculatePhase(dayInCycle, settings)

        val predictedDates = generatePredictedPeriodDates(lastPeriod, settings)
        val fertileDates = generateFertileWindowDates(lastPeriod, settings)

        _uiState.value = current.copy(
            currentPhase = phase,
            currentDayInCycle = dayInCycle.coerceIn(1, settings.averageCycleLength),
            totalCycleDays = settings.averageCycleLength,
            daysUntilNextPeriod = daysUntil.coerceAtLeast(0),
            predictedPeriodDates = predictedDates,
            fertileWindowDates = fertileDates
        )
    }

    private fun calculatePhase(dayInCycle: Int, settings: CycleSettings): CyclePhase {
        val periodLength = settings.averagePeriodLength
        val cycleLength = settings.averageCycleLength
        val ovulationDay = cycleLength - 14 // Standard 14-day luteal phase

        if (dayInCycle <= 0 || dayInCycle > cycleLength) return CyclePhase.FOLLICULAR

        return when {
            dayInCycle <= periodLength -> CyclePhase.MENSTRUAL
            dayInCycle < ovulationDay - 3 -> CyclePhase.FOLLICULAR
            dayInCycle <= ovulationDay -> CyclePhase.OVULATION
            else -> CyclePhase.LUTEAL
        }
    }

    private fun generatePredictedPeriodDates(lastPeriodStart: LocalDate, settings: CycleSettings): Set<LocalDate> {
        val nextPeriodStart = lastPeriodStart.plusDays(settings.averageCycleLength.toLong())
        return (0 until settings.averagePeriodLength).map {
            nextPeriodStart.plusDays(it.toLong())
        }.toSet()
    }

    private fun generateFertileWindowDates(lastPeriodStart: LocalDate, settings: CycleSettings): Set<LocalDate> {
        val ovulationDay = settings.averageCycleLength - 14
        val fertileStart = lastPeriodStart.plusDays((ovulationDay - 5).toLong())
        return (0..6).map { fertileStart.plusDays(it.toLong()) }.toSet()
    }

    private fun buildStatisticsFromCycles(
        cycles: List<CycleRecord>,
        lastPeriodStart: LocalDate,
        settings: CycleSettings
    ): CycleStatistics {
        val sorted = cycles.sortedBy { it.startDate }

        val cycleLengths = if (sorted.size >= 2) {
            sorted.zipWithNext { a, b ->
                ChronoUnit.DAYS.between(a.startDate, b.startDate).toInt()
            }
        } else emptyList()

        val periodLengths = sorted.mapNotNull { it.effectivePeriodLength }

        val avgCycle = if (cycleLengths.isNotEmpty()) cycleLengths.average().toFloat()
        else settings.averageCycleLength.toFloat()
        val avgPeriod = if (periodLengths.isNotEmpty()) periodLengths.average().toFloat()
        else settings.averagePeriodLength.toFloat()

        val stdDev = if (cycleLengths.size > 1) {
            kotlin.math.sqrt(
                cycleLengths.map { (it - avgCycle).toDouble() * (it - avgCycle).toDouble() }.average()
            ).toFloat()
        } else 0f

        val regularity = when {
            cycleLengths.size < 2 -> CycleRegularity.SOMEWHAT_IRREGULAR
            stdDev <= 1.5f -> CycleRegularity.REGULAR
            stdDev <= 3.0f -> CycleRegularity.SOMEWHAT_IRREGULAR
            else -> CycleRegularity.IRREGULAR
        }

        val recentCycleRecords = sorted.takeLast(6).map { cycle ->
            CycleRecordUi(
                startDate = cycle.startDate,
                cycleLength = cycle.cycleLength ?: settings.averageCycleLength,
                periodLength = cycle.effectivePeriodLength ?: settings.averagePeriodLength
            )
        }

        val nextPeriod = lastPeriodStart.plusDays(settings.averageCycleLength.toLong())

        return CycleStatistics(
            averageCycleLength = avgCycle,
            averagePeriodLength = avgPeriod,
            lastPeriodDate = lastPeriodStart,
            predictedNextPeriod = nextPeriod,
            regularity = regularity,
            recentCycles = recentCycleRecords,
            symptomFrequencies = emptyList()
        )
    }

    fun formatDate(date: LocalDate): String = date.format(dateFormatter)

    fun logSymptoms(symptoms: List<String>) {
        symptoms.forEach { symptom ->
            analyticsService.trackSymptomLogged(symptom)
        }
    }

    fun trackCyclePredictionViewed() {
        analyticsService.trackCyclePredictionViewed()
    }
}

// ─────────────────────────────────────
// MARK: - Domain → UI Conversion
// ─────────────────────────────────────

private fun CycleSettings.toDomain() = DomainCycleSettings(
    averageCycleLength = averageCycleLength,
    averagePeriodLength = averagePeriodLength,
    reminderEnabled = periodReminderEnabled,
    reminderTime = "09:00",
    reminderDaysBefore = reminderDaysBefore,
    fertileReminderEnabled = fertileWindowReminderEnabled,
    pmsReminderEnabled = pmsReminderEnabled,
    ovulationReminderEnabled = ovulationReminderEnabled,
    lutealPhaseLength = lutealPhaseLength
)

private fun DomainCycleSettings.toUiSettings() = CycleSettings(
    averageCycleLength = averageCycleLength,
    averagePeriodLength = averagePeriodLength,
    periodReminderEnabled = reminderEnabled,
    fertileWindowReminderEnabled = fertileReminderEnabled,
    pmsReminderEnabled = pmsReminderEnabled,
    ovulationReminderEnabled = ovulationReminderEnabled,
    reminderDaysBefore = reminderDaysBefore,
    lutealPhaseLength = lutealPhaseLength
)
