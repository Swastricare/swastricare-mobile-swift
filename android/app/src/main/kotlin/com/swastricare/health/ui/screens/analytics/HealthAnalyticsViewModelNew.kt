package com.swastricare.health.ui.screens.analytics

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.domain.model.analytics.ChartDataPoint
import com.swastricare.health.domain.model.analytics.HealthInsight
import com.swastricare.health.domain.model.analytics.MetricSummary
import com.swastricare.health.domain.model.analytics.MetricType
import com.swastricare.health.domain.model.analytics.TimeRange
import com.swastricare.health.domain.usecase.analytics.GenerateInsightsUseCase
import com.swastricare.health.domain.usecase.analytics.GetHealthSummaryUseCase
import com.swastricare.health.domain.usecase.analytics.GetTrendsUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI state for HealthAnalytics screen.
 */
data class HealthAnalyticsState(
    val isLoading: Boolean = true,
    val selectedTimeRange: TimeRange = TimeRange.WEEK,
    val selectedMetric: MetricType = MetricType.STEPS,
    val summaries: List<MetricSummary> = emptyList(),
    val chartData: List<ChartDataPoint> = emptyList(),
    val insights: List<HealthInsight> = emptyList(),
    val error: String? = null
)

/**
 * ViewModel for HealthAnalytics screen.
 * Migrated to Clean Architecture with Hilt dependency injection.
 */
@HiltViewModel
class HealthAnalyticsViewModelNew @Inject constructor(
    private val getHealthSummaryUseCase: GetHealthSummaryUseCase,
    private val getTrendsUseCase: GetTrendsUseCase,
    private val generateInsightsUseCase: GenerateInsightsUseCase
) : ViewModel() {

    private val _uiState = MutableStateFlow(HealthAnalyticsState())
    val uiState: StateFlow<HealthAnalyticsState> = _uiState.asStateFlow()

    init {
        loadData()
    }

    // ── Public actions ──

    /**
     * Select a time range for analytics.
     */
    fun selectTimeRange(range: TimeRange) {
        _uiState.value = _uiState.value.copy(selectedTimeRange = range)
        refreshChart()
    }

    /**
     * Select a metric to view.
     */
    fun selectMetric(metric: MetricType) {
        _uiState.value = _uiState.value.copy(selectedMetric = metric)
        refreshChart()
    }

    /**
     * Refresh all data.
     */
    fun refresh() {
        loadData()
    }

    // ── Private helpers ──

    private fun loadData() {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            // Get health summary
            when (val summaryResult = getHealthSummaryUseCase()) {
                is ResultWrapper.Success -> {
                    val summary = summaryResult.data
                    val insights = generateInsightsUseCase(summary)

                    _uiState.value = _uiState.value.copy(
                        summaries = summary.summaries,
                        insights = insights,
                        isLoading = false
                    )

                    // Load chart data for current selection
                    refreshChart()
                }
                is ResultWrapper.Error -> {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = "Failed to load health data. Please try again."
                    )
                }
                is ResultWrapper.Loading -> {
                    // Already in loading state
                }
            }
        }
    }

    private fun refreshChart() {
        val state = _uiState.value
        viewModelScope.launch {
            when (val trendResult = getTrendsUseCase(state.selectedMetric, state.selectedTimeRange)) {
                is ResultWrapper.Success -> {
                    _uiState.value = state.copy(
                        chartData = trendResult.data.dataPoints
                    )
                }
                is ResultWrapper.Error -> {
                    _uiState.value = state.copy(
                        error = "Failed to load chart data"
                    )
                }
                is ResultWrapper.Loading -> {}
            }
        }
    }
}
