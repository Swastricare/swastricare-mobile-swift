package com.swastricare.health.ui.screens.menstrualcycle

import androidx.compose.ui.graphics.Color
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.data.services.AppAnalyticsService
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import javax.inject.Inject

// ─────────────────────────────────────
// MARK: - Cycle Phase Enum
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

data class CycleRecord(
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
    val recentCycles: List<CycleRecord>,
    val symptomFrequencies: List<SymptomFrequency>
)

enum class CycleRegularity(val displayName: String, val color: Color) {
    REGULAR("Regular", Color(0xFF4CAF50)),
    SOMEWHAT_IRREGULAR("Somewhat Irregular", Color(0xFFFF9800)),
    IRREGULAR("Irregular", Color(0xFFE91E63))
}

// ─────────────────────────────────────
// MARK: - Cycle Settings
// ─────────────────────────────────────

data class CycleSettings(
    val averageCycleLength: Int = 28,
    val averagePeriodLength: Int = 5,
    val periodReminderEnabled: Boolean = true,
    val fertileWindowReminderEnabled: Boolean = false,
    val pmsReminderEnabled: Boolean = false
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
    private val analyticsService: AppAnalyticsService
) : ViewModel() {

    private val _uiState = MutableStateFlow(MenstrualCycleUiState())
    val uiState: StateFlow<MenstrualCycleUiState> = _uiState.asStateFlow()

    private val dateFormatter = DateTimeFormatter.ofPattern("MMM dd, yyyy")

    init {
        loadData()
    }

    private fun loadData() {
        viewModelScope.launch {
            // Simulate loading with demo data
            val settings = CycleSettings()
            val lastPeriodStart = LocalDate.now().minusDays(14)
            val today = LocalDate.now()

            val dayInCycle = ChronoUnit.DAYS.between(lastPeriodStart, today).toInt() + 1
            val totalDays = settings.averageCycleLength
            val daysUntil = totalDays - dayInCycle
            val phase = calculatePhase(dayInCycle, settings)

            // Generate demo calendar data
            val loggedDates = generateLoggedPeriodDates(lastPeriodStart, settings.averagePeriodLength)
            val predictedDates = generatePredictedPeriodDates(lastPeriodStart, settings)
            val fertileDates = generateFertileWindowDates(lastPeriodStart, settings)

            val statistics = generateDemoStatistics(lastPeriodStart, settings)

            _uiState.value = MenstrualCycleUiState(
                currentPhase = phase,
                currentDayInCycle = dayInCycle.coerceIn(1, totalDays),
                totalCycleDays = totalDays,
                daysUntilNextPeriod = daysUntil.coerceAtLeast(0),
                lastPeriodStart = lastPeriodStart,
                settings = settings,
                statistics = statistics,
                isLoading = false,
                selectedMonth = today.withDayOfMonth(1),
                loggedPeriodDates = loggedDates,
                predictedPeriodDates = predictedDates,
                fertileWindowDates = fertileDates
            )
        }
    }

    fun togglePeriodDate(date: LocalDate) {
        val current = _uiState.value
        val updatedDates = current.loggedPeriodDates.toMutableSet()
        if (updatedDates.contains(date)) {
            updatedDates.remove(date)
            analyticsService.trackCycleLogged("end")
        } else {
            updatedDates.add(date)
            analyticsService.trackCycleLogged("start")
        }
        _uiState.value = current.copy(loggedPeriodDates = updatedDates)
        recalculate()
    }

    fun changeMonth(delta: Int) {
        val current = _uiState.value
        val newMonth = current.selectedMonth.plusMonths(delta.toLong())
        _uiState.value = current.copy(selectedMonth = newMonth)
    }

    fun updateCycleSettings(cycleLength: Int, periodLength: Int) {
        val current = _uiState.value
        val newSettings = current.settings.copy(
            averageCycleLength = cycleLength,
            averagePeriodLength = periodLength
        )
        _uiState.value = current.copy(settings = newSettings)
        recalculate()
    }

    fun updateNotificationSettings(
        periodReminder: Boolean? = null,
        fertileReminder: Boolean? = null,
        pmsReminder: Boolean? = null
    ) {
        val current = _uiState.value
        val newSettings = current.settings.copy(
            periodReminderEnabled = periodReminder ?: current.settings.periodReminderEnabled,
            fertileWindowReminderEnabled = fertileReminder ?: current.settings.fertileWindowReminderEnabled,
            pmsReminderEnabled = pmsReminder ?: current.settings.pmsReminderEnabled
        )
        _uiState.value = current.copy(settings = newSettings)
    }

    fun loadStatistics() {
        viewModelScope.launch {
            val current = _uiState.value
            val stats = generateDemoStatistics(current.lastPeriodStart, current.settings)
            _uiState.value = current.copy(statistics = stats)
        }
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
        val statistics = generateDemoStatistics(lastPeriod, settings)

        _uiState.value = current.copy(
            currentPhase = phase,
            currentDayInCycle = dayInCycle.coerceIn(1, settings.averageCycleLength),
            totalCycleDays = settings.averageCycleLength,
            daysUntilNextPeriod = daysUntil.coerceAtLeast(0),
            predictedPeriodDates = predictedDates,
            fertileWindowDates = fertileDates,
            statistics = statistics
        )
    }

    private fun calculatePhase(dayInCycle: Int, settings: CycleSettings): CyclePhase {
        val periodLength = settings.averagePeriodLength
        val cycleLength = settings.averageCycleLength
        val ovulationDay = cycleLength - 14 // Ovulation typically 14 days before next period

        return when {
            dayInCycle <= periodLength -> CyclePhase.MENSTRUAL
            dayInCycle <= ovulationDay - 2 -> CyclePhase.FOLLICULAR
            dayInCycle <= ovulationDay + 2 -> CyclePhase.OVULATION
            else -> CyclePhase.LUTEAL
        }
    }

    private fun generateLoggedPeriodDates(lastPeriodStart: LocalDate, periodLength: Int): Set<LocalDate> {
        return (0 until periodLength).map { lastPeriodStart.plusDays(it.toLong()) }.toSet()
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

    private fun generateDemoStatistics(lastPeriodStart: LocalDate, settings: CycleSettings): CycleStatistics {
        val recentCycles = listOf(
            CycleRecord(lastPeriodStart, settings.averageCycleLength, settings.averagePeriodLength),
            CycleRecord(lastPeriodStart.minusDays(29), 29, 5),
            CycleRecord(lastPeriodStart.minusDays(57), 28, 4),
            CycleRecord(lastPeriodStart.minusDays(84), 27, 5),
            CycleRecord(lastPeriodStart.minusDays(113), 29, 6),
            CycleRecord(lastPeriodStart.minusDays(140), 27, 5)
        )

        val avgCycle = recentCycles.map { it.cycleLength }.average().toFloat()
        val avgPeriod = recentCycles.map { it.periodLength }.average().toFloat()

        val stdDev = kotlin.math.sqrt(
            recentCycles.map { (it.cycleLength - avgCycle).toDouble() * (it.cycleLength - avgCycle).toDouble() }
                .average()
        ).toFloat()

        val regularity = when {
            stdDev <= 1.5f -> CycleRegularity.REGULAR
            stdDev <= 3.0f -> CycleRegularity.SOMEWHAT_IRREGULAR
            else -> CycleRegularity.IRREGULAR
        }

        val symptomFrequencies = listOf(
            SymptomFrequency("Cramps", 0.83f),
            SymptomFrequency("Bloating", 0.67f),
            SymptomFrequency("Mood Swings", 0.50f),
            SymptomFrequency("Fatigue", 0.67f),
            SymptomFrequency("Headaches", 0.33f),
            SymptomFrequency("Back Pain", 0.50f)
        ).sortedByDescending { it.percentage }

        val nextPeriod = lastPeriodStart.plusDays(settings.averageCycleLength.toLong())

        return CycleStatistics(
            averageCycleLength = avgCycle,
            averagePeriodLength = avgPeriod,
            lastPeriodDate = lastPeriodStart,
            predictedNextPeriod = nextPeriod,
            regularity = regularity,
            recentCycles = recentCycles,
            symptomFrequencies = symptomFrequencies
        )
    }

    fun formatDate(date: LocalDate): String = date.format(dateFormatter)

    fun trackCyclePredictionViewed() {
        analyticsService.trackCyclePredictionViewed()
    }
}
