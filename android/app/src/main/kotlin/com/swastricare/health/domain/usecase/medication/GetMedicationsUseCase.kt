package com.swastricare.health.domain.usecase.medication

import com.swastricare.health.domain.model.Medication
import com.swastricare.health.domain.model.MedicationDose
import com.swastricare.health.domain.model.MedicationLog
import com.swastricare.health.domain.model.MedicationSchedule
import com.swastricare.health.domain.model.MedicationWithDoses
import com.swastricare.health.domain.model.AdherenceStatus
import com.swastricare.health.domain.repository.MedicationRepository
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import javax.inject.Inject

/**
 * Use case for getting medications with their doses for a specific date.
 * Combines medications, schedules, and logs into a unified view.
 */
class GetMedicationsUseCase @Inject constructor(
    private val repository: MedicationRepository
) {
    /**
     * Executes the use case to get medications with doses.
     *
     * @param profileId The health profile ID
     * @param date The date to get doses for (defaults to today)
     * @return Result containing list of medications with doses
     */
    suspend operator fun invoke(
        profileId: String,
        date: LocalDate = LocalDate.now()
    ): Result<List<MedicationWithDoses>> {
        // Fetch medications
        val medicationsResult = repository.getMedications(profileId)
        if (medicationsResult.isFailure) {
            return Result.failure(medicationsResult.exceptionOrNull() ?: Exception("Failed to fetch medications"))
        }
        val medications = medicationsResult.getOrNull() ?: emptyList()

        // Fetch schedules
        val schedulesResult = repository.getSchedules(profileId)
        if (schedulesResult.isFailure) {
            return Result.failure(schedulesResult.exceptionOrNull() ?: Exception("Failed to fetch schedules"))
        }
        val schedules = schedulesResult.getOrNull() ?: emptyList()

        // Fetch logs for the date
        val logsResult = repository.getLogsForDate(profileId, date)
        if (logsResult.isFailure) {
            return Result.failure(logsResult.exceptionOrNull() ?: Exception("Failed to fetch logs"))
        }
        val logs = logsResult.getOrNull() ?: emptyList()

        // Build medications with doses
        val medicationsWithDoses = buildMedicationsWithDoses(
            medications = medications,
            schedules = schedules,
            logs = logs,
            date = date
        )

        return Result.success(medicationsWithDoses)
    }

    /**
     * Builds the combined view of medications with their doses.
     */
    private fun buildMedicationsWithDoses(
        medications: List<Medication>,
        schedules: List<MedicationSchedule>,
        logs: List<MedicationLog>,
        date: LocalDate
    ): List<MedicationWithDoses> {
        return medications.map { medication ->
            val medSchedules = schedules.filter { it.medicationId == medication.id }
            val medLogs = logs.filter { it.medicationId == medication.id }

            val doses = medSchedules.flatMap { schedule ->
                buildDosesForSchedule(medication, schedule, medLogs, date)
            }.sortedBy { it.scheduledTime }

            MedicationWithDoses(
                medication = medication,
                schedules = medSchedules,
                todayDoses = doses
            )
        }
    }

    /**
     * Builds doses for a specific schedule.
     */
    private fun buildDosesForSchedule(
        medication: Medication,
        schedule: MedicationSchedule,
        logs: List<MedicationLog>,
        date: LocalDate
    ): List<MedicationDose> {
        val times = expandScheduleTimes(schedule.timeOfDay, schedule.frequencyPerDay)

        return times.map { timeStr ->
            val scheduledDt = parseScheduledDateTime(date, timeStr)
            val log = logs.firstOrNull { log ->
                matchesScheduledTime(log.scheduledTime, scheduledDt)
            }

            MedicationDose(
                logId = log?.id,
                scheduleId = schedule.id,
                medicationId = medication.id,
                medicationName = medication.name,
                dosage = medication.displayDosage,
                medicationType = medication.form,
                scheduledTime = scheduledDt,
                status = log?.status ?: AdherenceStatus.PENDING,
                takenAt = log?.takenTime,
                skipReason = log?.skipReason
            )
        }
    }

    /**
     * Expands a base time into multiple times based on frequency.
     */
    private fun expandScheduleTimes(baseTime: String, count: Int): List<String> {
        if (count <= 1) return listOf(baseTime)

        val base = LocalDateTime.of(LocalDate.now(), parseLocalTime(baseTime))
        val intervalHours = 24 / count

        return (0 until count).map { i ->
            base.plusHours((i * intervalHours).toLong())
                .format(DateTimeFormatter.ofPattern("HH:mm:ss"))
        }
    }

    /**
     * Parses a time string to LocalTime.
     */
    private fun parseLocalTime(timeStr: String): java.time.LocalTime {
        val timeFormatter = DateTimeFormatter.ofPattern("HH:mm:ss")
        return java.time.LocalTime.parse(timeStr.take(8).padEnd(8, '0'), timeFormatter)
    }

    /**
     * Parses a scheduled date-time from date and time string.
     */
    private fun parseScheduledDateTime(date: LocalDate, timeStr: String): LocalDateTime {
        return LocalDateTime.of(date, parseLocalTime(timeStr))
    }

    /**
     * Checks if a log's scheduled time matches the target time.
     * Allows 30-minute window to handle timezone offsets.
     */
    private fun matchesScheduledTime(logTime: LocalDateTime, targetTime: LocalDateTime): Boolean {
        val diff = java.time.Duration.between(logTime, targetTime).abs()
        return diff.toMinutes() < 30
    }
}
