package com.swastricare.health.data.mapper

import androidx.health.connect.client.records.SleepSessionRecord
import com.swastricare.health.data.remote.dto.sleep.DailyMetricsSleepDto
import com.swastricare.health.data.services.HealthConnectService.SleepSessionDetail
import com.swastricare.health.data.services.HealthConnectService.SleepStageDetail
import com.swastricare.health.domain.model.sleep.SleepSession
import com.swastricare.health.domain.model.sleep.SleepStage
import com.swastricare.health.domain.model.sleep.SleepStageType
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
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

    /**
     * Rehydrates a SleepSession from a daily_health_metrics row. Used when the
     * user manually logged sleep (no Health Connect record exists for that date).
     *
     * Reconstructs start/end epoch millis by pairing bedtime/wakeTime with the
     * session date. If bedtime is later in the day than wake time (e.g. 23:00
     * → 07:00), bedtime is anchored to the previous calendar day.
     */
    fun fromDailyMetrics(dto: DailyMetricsSleepDto): SleepSession? {
        val date = runCatching { LocalDate.parse(dto.metricDate) }.getOrNull() ?: return null
        val hours = dto.sleepHours ?: return null
        val totalMinutes = (hours * 60.0).toInt().coerceAtLeast(0)
        if (totalMinutes <= 0) return null

        val zone = ZoneId.systemDefault()
        val bedLocalTime = dto.bedtime?.let { runCatching { LocalTime.parse(it, timeFormatter) }.getOrNull() }
        val wakeLocalTime = dto.wakeTime?.let { runCatching { LocalTime.parse(it, timeFormatter) }.getOrNull() }

        val startMillis: Long
        val endMillis: Long
        if (bedLocalTime != null && wakeLocalTime != null) {
            val wakesNextDay = bedLocalTime.isAfter(wakeLocalTime)
            val startDate = if (wakesNextDay) date.minusDays(1) else date
            startMillis = startDate.atTime(bedLocalTime).atZone(zone).toInstant().toEpochMilli()
            endMillis = date.atTime(wakeLocalTime).atZone(zone).toInstant().toEpochMilli()
        } else {
            // Fall back: anchor end-of-night to 07:00 on the session date, derive start from duration
            val fallbackWake = date.atTime(7, 0).atZone(zone).toInstant().toEpochMilli()
            endMillis = fallbackWake
            startMillis = fallbackWake - totalMinutes * 60_000L
        }

        return SleepSession(
            date = date,
            startTimeEpochMillis = startMillis,
            endTimeEpochMillis = endMillis,
            totalMinutes = totalMinutes
        )
    }

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
