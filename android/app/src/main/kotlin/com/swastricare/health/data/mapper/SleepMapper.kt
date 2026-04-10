package com.swastricare.health.data.mapper

import androidx.health.connect.client.records.SleepSessionRecord
import com.swastricare.health.data.remote.dto.sleep.DailyMetricsSleepDto
import com.swastricare.health.data.services.HealthConnectService.SleepSessionDetail
import com.swastricare.health.data.services.HealthConnectService.SleepStageDetail
import com.swastricare.health.domain.model.sleep.SleepSession
import com.swastricare.health.domain.model.sleep.SleepStage
import com.swastricare.health.domain.model.sleep.SleepStageType
import java.time.format.DateTimeFormatter

/**
 * Maps Health Connect sleep data to domain models and DTOs.
 */
object SleepMapper {

    fun toDomain(detail: SleepSessionDetail): SleepSession {
        val stages = detail.stages.map { stageToDomain(it) }
        val deepMin = stages.filter { it.type == SleepStageType.DEEP }.sumOf { it.durationMinutes }
        val lightMin = stages.filter { it.type == SleepStageType.LIGHT }.sumOf { it.durationMinutes }
        val remMin = stages.filter { it.type == SleepStageType.REM }.sumOf { it.durationMinutes }
        val awakeMin = stages.filter { it.type == SleepStageType.AWAKE }.sumOf { it.durationMinutes }

        return SleepSession(
            date = detail.nightDate,
            startTimeEpochMillis = detail.startTimeMillis,
            endTimeEpochMillis = detail.endTimeMillis,
            totalMinutes = detail.totalMinutes,
            deepMinutes = deepMin,
            lightMinutes = lightMin,
            remMinutes = remMin,
            awakeMinutes = awakeMin,
            stages = stages
        )
    }

    fun stageToDomain(stage: SleepStageDetail): SleepStage {
        val type = when (stage.stageType) {
            SleepSessionRecord.STAGE_TYPE_DEEP -> SleepStageType.DEEP
            SleepSessionRecord.STAGE_TYPE_LIGHT -> SleepStageType.LIGHT
            SleepSessionRecord.STAGE_TYPE_REM -> SleepStageType.REM
            SleepSessionRecord.STAGE_TYPE_AWAKE -> SleepStageType.AWAKE
            else -> SleepStageType.UNKNOWN
        }
        return SleepStage(
            type = type,
            startTimeEpochMillis = stage.startTimeMillis,
            endTimeEpochMillis = stage.endTimeMillis,
            durationMinutes = stage.durationMinutes
        )
    }

    private val timeFormatter = DateTimeFormatter.ofPattern("HH:mm")

    fun toDailyMetricsDto(session: SleepSession, profileId: String): DailyMetricsSleepDto {
        // DB constraint: sleep_quality BETWEEN 1 AND 5. Map 0-100 score to 1-5.
        val qualityDb = when {
            session.qualityScore >= 80 -> 5
            session.qualityScore >= 60 -> 4
            session.qualityScore >= 40 -> 3
            session.qualityScore >= 20 -> 2
            else -> 1
        }

        return DailyMetricsSleepDto(
            healthProfileId = profileId,
            metricDate = session.date.toString(),
            sleepHours = session.totalMinutes / 60.0,
            sleepQuality = qualityDb,
            bedtime = session.bedtime?.format(timeFormatter),
            wakeTime = session.wakeTime?.format(timeFormatter)
        )
    }
}
