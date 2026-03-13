package com.swastricare.health.domain.usecase.ai

import com.swastricare.health.domain.model.ai.HealthContext
import com.swastricare.health.domain.repository.AIRepository
import com.swastricare.health.domain.repository.HealthAnalysisResult
import javax.inject.Inject

/**
 * Use case: Analyze health metrics and get AI insights.
 */
class AnalyzeHealthUseCase @Inject constructor(
    private val repository: AIRepository,
    private val buildHealthContextUseCase: BuildHealthContextUseCase
) {
    /**
     * Analyze current health status.
     */
    suspend operator fun invoke(): HealthAnalysisResult {
        val healthContext = buildHealthContextUseCase()

        if (healthContext.isEmpty()) {
            return HealthAnalysisResult(
                assessment = "No health data available",
                insights = "Start tracking your health metrics to get personalized insights.",
                recommendations = listOf(
                    "Track your daily steps",
                    "Monitor your heart rate",
                    "Log your water intake",
                    "Record your medications"
                )
            )
        }

        return repository.analyzeHealth(healthContext)
    }

    /**
     * Analyze specific health context.
     */
    suspend fun analyzeCustom(healthContext: HealthContext): HealthAnalysisResult {
        if (healthContext.isEmpty()) {
            return HealthAnalysisResult(
                assessment = "No health data provided",
                insights = "Please provide health metrics for analysis.",
                recommendations = emptyList()
            )
        }

        return repository.analyzeHealth(healthContext)
    }
}
