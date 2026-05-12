package com.swastricare.health.domain.model

/**
 * Lightweight, read-only summary types consumed by the Family Member Dashboard
 * (Batch F). Each is intentionally small — these are not full domain entities,
 * just the minimum fields the dashboard cards need to render.
 */

/**
 * Summarised medication dose for "today's medication ring".
 *
 * @property logId `medication_logs.id` when a log already exists; null for
 *                 schedule-derived placeholder doses that have not been logged
 *                 yet (status will be `"pending"` in that case).
 * @property medicationId FK to `medications.id`.
 * @property medicationName Display name from `medications.name`.
 * @property scheduledAt ISO 8601 timestamp for the scheduled dose.
 * @property status One of `taken`, `skipped`, `missed`, `late`, `early`, or
 *                  the synthesised `pending` value for un-logged doses.
 */
data class MedicationDoseSummary(
    val logId: String?,
    val medicationId: String,
    val medicationName: String,
    val scheduledAt: String,
    val status: String,
)

/**
 * Latest heart-rate measurement for a profile.
 */
data class HeartRateSnapshot(
    val bpm: Int,
    val measuredAt: String,
)

/**
 * Summary row for the family-member vault list.
 */
data class VaultDocSummary(
    val id: String,
    val name: String,
    val docType: String?,
    val uploadedAt: String,
    /** Storage path inside the medical-vault bucket. Use [VaultRepository.getSignedUrl] to obtain a viewable URL. */
    val fileUrl: String? = null,
    val description: String? = null,
    val fileName: String? = null,
    val fileSizeBytes: Long? = null,
    val mimeType: String? = null,
    val thumbnailUrl: String? = null,
)
