package com.swastricare.health.data.repository

import android.content.SharedPreferences
import com.swastricare.health.core.logger.Logger
import com.swastricare.health.core.result.AppException
import com.swastricare.health.core.result.ResultWrapper
import com.swastricare.health.data.services.HealthConnectService
import com.swastricare.health.domain.model.heartrate.HeartRateMeasurement
import com.swastricare.health.domain.model.heartrate.MeasurementSource
import com.swastricare.health.domain.model.heartrate.SignalQuality
import com.swastricare.health.domain.repository.HeartRateRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import javax.inject.Inject

/**
 * DTO for heart rate measurement persistence.
 */
@Serializable
private data class HeartRateMeasurementDto(
    val bpm: Int,
    val timestamp: String, // ISO 8601 LocalDateTime
    val source: String,
    val confidence: Float
)

/**
 * DTO for Supabase `vital_signs` table.
 */
@Serializable
private data class VitalSignRecord(
    val id: String,
    @SerialName("health_profile_id") val healthProfileId: String,
    @SerialName("measured_at") val measuredAt: String,
    @SerialName("heart_rate") val heartRate: Int,
    @SerialName("device_used") val deviceUsed: String? = null,
    @SerialName("measurement_context") val measurementContext: String? = null
)

/**
 * Implementation of HeartRateRepository.
 * Handles local storage via SharedPreferences and Health Connect integration.
 */
class HeartRateRepositoryImpl @Inject constructor(
    private val sharedPreferences: SharedPreferences,
    private val healthConnectService: HealthConnectService,
    private val supabaseClient: SupabaseClient,
    private val json: Json,
    private val logger: Logger
) : HeartRateRepository {

    companion object {
        private const val TAG = "HeartRateRepository"
        private const val KEY_MEASUREMENTS = "heart_rate_measurements"
        private const val MAX_MEASUREMENTS = 500
    }

    // ── Local storage ──

    override suspend fun loadLocalMeasurements(): List<HeartRateMeasurement> = withContext(Dispatchers.IO) {
        try {
            val raw = sharedPreferences.getString(KEY_MEASUREMENTS, null) ?: return@withContext emptyList()
            val dtos = json.decodeFromString<List<HeartRateMeasurementDto>>(raw)
            dtos.map { it.toDomain() }
        } catch (e: Exception) {
            logger.e(TAG, "Failed to load measurements", e)
            emptyList()
        }
    }

    override suspend fun loadMeasurementsForDate(date: LocalDate): List<HeartRateMeasurement> =
        withContext(Dispatchers.IO) {
            val allMeasurements = loadLocalMeasurements()
            allMeasurements.filter { it.timestamp.toLocalDate() == date }
        }

    override suspend fun addMeasurement(measurement: HeartRateMeasurement): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                val current = loadLocalMeasurements().toMutableList()
                current.add(measurement)

                // Keep only the most recent MAX_MEASUREMENTS
                val trimmed = if (current.size > MAX_MEASUREMENTS) {
                    current.sortedByDescending { it.timestamp }.take(MAX_MEASUREMENTS)
                } else {
                    current
                }

                saveMeasurements(trimmed)
                ResultWrapper.Success(Unit)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to add measurement", e)
                ResultWrapper.Error(AppException.UnknownException(e.message, e))
            }
        }

    override suspend fun deleteMeasurement(timestamp: Long): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                val current = loadLocalMeasurements()
                val filtered = current.filter {
                    it.timestamp.atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli() != timestamp
                }
                saveMeasurements(filtered)
                ResultWrapper.Success(Unit)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to delete measurement", e)
                ResultWrapper.Error(AppException.UnknownException(e.message, e))
            }
        }

    override suspend fun clearAllMeasurements(): ResultWrapper<Unit> = withContext(Dispatchers.IO) {
        try {
            sharedPreferences.edit().remove(KEY_MEASUREMENTS).apply()
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to clear measurements", e)
            ResultWrapper.Error(AppException.UnknownException(e.message, e))
        }
    }

    override suspend fun getLastMeasurement(): HeartRateMeasurement? = withContext(Dispatchers.IO) {
        loadLocalMeasurements().maxByOrNull { it.timestamp }
    }

    // ── Cloud sync ──

    override suspend fun fetchFromCloud(profileId: String): ResultWrapper<List<HeartRateMeasurement>> =
        withContext(Dispatchers.IO) {
            try {
                val records = supabaseClient.from("vital_signs").select {
                    filter { eq("health_profile_id", profileId) }
                }.decodeList<VitalSignRecord>().filter { it.heartRate > 0 }
                val measurements = records.mapNotNull { record ->
                    try {
                        HeartRateMeasurement(
                            bpm = record.heartRate,
                            timestamp = LocalDateTime.parse(
                                record.measuredAt.substringBefore("+").substringBefore("Z"),
                                DateTimeFormatter.ISO_LOCAL_DATE_TIME
                            ),
                            source = if (record.deviceUsed == "camera_ppg") MeasurementSource.CAMERA
                                     else MeasurementSource.HEALTH_CONNECT,
                            confidence = 0.9f,
                            quality = SignalQuality.GOOD
                        )
                    } catch (_: Exception) { null }
                }
                ResultWrapper.Success(measurements)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to fetch heart rate from cloud", e)
                ResultWrapper.Error(AppException.UnknownException("Cloud fetch failed", e))
            }
        }

    override suspend fun syncToCloud(
        measurements: List<HeartRateMeasurement>,
        profileId: String
    ): ResultWrapper<Unit> = withContext(Dispatchers.IO) {
        try {
            val records = measurements.map { m ->
                VitalSignRecord(
                    id = java.util.UUID.randomUUID().toString(),
                    healthProfileId = profileId,
                    measuredAt = m.timestamp.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                    heartRate = m.bpm,
                    deviceUsed = when (m.source) {
                        MeasurementSource.CAMERA -> "camera_ppg"
                        MeasurementSource.HEALTH_CONNECT -> "health_connect"
                        MeasurementSource.MANUAL -> "manual"
                    },
                    measurementContext = "at_rest"
                )
            }
            supabaseClient.from("vital_signs").upsert(records)
            logger.d(TAG, "Synced ${records.size} heart rate measurements to cloud")
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to sync heart rate to cloud", e)
            ResultWrapper.Error(AppException.UnknownException("Cloud sync failed", e))
        }
    }

    // ── Health Connect integration ──

    override suspend fun writeToHealthConnect(bpm: Long): ResultWrapper<Unit> {
        return try {
            healthConnectService.writeHeartRate(bpm)
            ResultWrapper.Success(Unit)
        } catch (e: Exception) {
            logger.e(TAG, "Failed to write to Health Connect", e)
            ResultWrapper.Error(AppException.UnknownException("Health Connect write failed", e))
        }
    }

    override suspend fun fetchFromHealthConnect(): ResultWrapper<List<HeartRateMeasurement>> {
        return try {
            // TODO: Implement when HealthConnectService has a read heart rate method
            ResultWrapper.Success(emptyList())
        } catch (e: Exception) {
            logger.e(TAG, "Failed to fetch from Health Connect", e)
            ResultWrapper.Error(AppException.UnknownException("Health Connect fetch failed", e))
        }
    }

    // ── Private helpers ──

    private suspend fun saveMeasurements(measurements: List<HeartRateMeasurement>): ResultWrapper<Unit> =
        withContext(Dispatchers.IO) {
            try {
                val dtos = measurements.map { it.toDto() }
                val encoded = json.encodeToString(dtos)
                sharedPreferences.edit().putString(KEY_MEASUREMENTS, encoded).apply()
                ResultWrapper.Success(Unit)
            } catch (e: Exception) {
                logger.e(TAG, "Failed to save measurements", e)
                ResultWrapper.Error(AppException.UnknownException(e.message, e))
            }
        }

    // ── Mapping ──

    private fun HeartRateMeasurement.toDto(): HeartRateMeasurementDto {
        return HeartRateMeasurementDto(
            bpm = bpm,
            timestamp = timestamp.format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
            source = source.name,
            confidence = confidence
        )
    }

    private fun HeartRateMeasurementDto.toDomain(): HeartRateMeasurement {
        return HeartRateMeasurement(
            bpm = bpm,
            timestamp = LocalDateTime.parse(timestamp, DateTimeFormatter.ISO_LOCAL_DATE_TIME),
            source = try {
                MeasurementSource.valueOf(source)
            } catch (e: Exception) {
                MeasurementSource.CAMERA
            },
            confidence = confidence,
            quality = SignalQuality.fromConfidence(confidence)
        )
    }
}
