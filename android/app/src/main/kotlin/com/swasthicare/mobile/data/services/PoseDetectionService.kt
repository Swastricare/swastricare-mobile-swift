package com.swasthicare.mobile.data.services

import android.graphics.PointF
import android.media.Image
import androidx.annotation.OptIn
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageProxy
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.pose.Pose
import com.google.mlkit.vision.pose.PoseDetection
import com.google.mlkit.vision.pose.PoseDetector
import com.google.mlkit.vision.pose.PoseLandmark
import com.google.mlkit.vision.pose.defaults.PoseDetectorOptions
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/**
 * Body scan result containing detected landmarks and calculated organ positions.
 */
data class BodyScanResult(
    val landmarks: Map<String, PointF>,
    val organPositions: Map<String, PointF>,
    val imageWidth: Int,
    val imageHeight: Int
)

/**
 * PoseDetectionService
 * Uses ML Kit Pose Detection to detect body landmarks from CameraX frames
 * and calculate organ overlay positions for the AR Body Scan feature.
 */
class PoseDetectionService {

    private val poseDetector: PoseDetector by lazy {
        val options = PoseDetectorOptions.Builder()
            .setDetectorMode(PoseDetectorOptions.STREAM_MODE)
            .build()
        PoseDetection.getClient(options)
    }

    /**
     * Process a CameraX ImageProxy frame and extract body landmarks + organ positions.
     * Returns null if no pose is detected.
     */
    @OptIn(ExperimentalGetImage::class)
    suspend fun processFrame(imageProxy: ImageProxy): BodyScanResult? {
        val mediaImage: Image = imageProxy.image ?: run {
            imageProxy.close()
            return null
        }

        val inputImage = InputImage.fromMediaImage(
            mediaImage,
            imageProxy.imageInfo.rotationDegrees
        )

        return try {
            val pose = detectPose(inputImage)
            val result = extractResult(pose, imageProxy.width, imageProxy.height)
            result
        } catch (e: Exception) {
            null
        } finally {
            imageProxy.close()
        }
    }

    private suspend fun detectPose(inputImage: InputImage): Pose =
        suspendCancellableCoroutine { cont ->
            poseDetector.process(inputImage)
                .addOnSuccessListener { pose -> if (cont.isActive) cont.resume(pose) }
                .addOnFailureListener { e -> if (cont.isActive) cont.resumeWithException(e) }
        }

    private fun extractResult(pose: Pose, imageWidth: Int, imageHeight: Int): BodyScanResult? {
        val allLandmarks = pose.allPoseLandmarks
        if (allLandmarks.isEmpty()) return null

        // Extract key body landmarks
        val landmarkMap = mutableMapOf<String, PointF>()

        fun addLandmark(name: String, type: Int) {
            pose.getPoseLandmark(type)?.let {
                landmarkMap[name] = PointF(it.position.x, it.position.y)
            }
        }

        addLandmark("left_shoulder", PoseLandmark.LEFT_SHOULDER)
        addLandmark("right_shoulder", PoseLandmark.RIGHT_SHOULDER)
        addLandmark("left_hip", PoseLandmark.LEFT_HIP)
        addLandmark("right_hip", PoseLandmark.RIGHT_HIP)
        addLandmark("left_elbow", PoseLandmark.LEFT_ELBOW)
        addLandmark("right_elbow", PoseLandmark.RIGHT_ELBOW)
        addLandmark("left_wrist", PoseLandmark.LEFT_WRIST)
        addLandmark("right_wrist", PoseLandmark.RIGHT_WRIST)
        addLandmark("left_knee", PoseLandmark.LEFT_KNEE)
        addLandmark("right_knee", PoseLandmark.RIGHT_KNEE)
        addLandmark("left_ankle", PoseLandmark.LEFT_ANKLE)
        addLandmark("right_ankle", PoseLandmark.RIGHT_ANKLE)
        addLandmark("nose", PoseLandmark.NOSE)
        addLandmark("left_ear", PoseLandmark.LEFT_EAR)
        addLandmark("right_ear", PoseLandmark.RIGHT_EAR)

        // Need at least shoulders and hips for organ calculation
        val leftShoulder = landmarkMap["left_shoulder"] ?: return null
        val rightShoulder = landmarkMap["right_shoulder"] ?: return null
        val leftHip = landmarkMap["left_hip"] ?: return null
        val rightHip = landmarkMap["right_hip"] ?: return null

        // Calculate organ positions relative to body landmarks
        val organPositions = calculateOrganPositions(
            leftShoulder, rightShoulder, leftHip, rightHip
        )

        return BodyScanResult(
            landmarks = landmarkMap,
            organPositions = organPositions,
            imageWidth = imageWidth,
            imageHeight = imageHeight
        )
    }

    /**
     * Calculate organ positions based on shoulder and hip landmarks.
     * Heart: midpoint between shoulders, slightly left
     * Lungs: between shoulders and hips, left and right sides
     * Stomach: center of torso, below midpoint
     * Liver: right side of torso
     * Kidneys: lower back area, left and right
     */
    private fun calculateOrganPositions(
        leftShoulder: PointF,
        rightShoulder: PointF,
        leftHip: PointF,
        rightHip: PointF
    ): Map<String, PointF> {
        val shoulderMidX = (leftShoulder.x + rightShoulder.x) / 2f
        val shoulderMidY = (leftShoulder.y + rightShoulder.y) / 2f
        val hipMidX = (leftHip.x + rightHip.x) / 2f
        val hipMidY = (leftHip.y + rightHip.y) / 2f
        val torsoHeight = hipMidY - shoulderMidY
        val torsoWidth = Math.abs(leftShoulder.x - rightShoulder.x)

        return mapOf(
            // Heart: midpoint of shoulders, shifted slightly left (from camera perspective = right shoulder side)
            "heart" to PointF(
                shoulderMidX + torsoWidth * 0.1f,
                shoulderMidY + torsoHeight * 0.2f
            ),
            // Left Lung
            "left_lung" to PointF(
                shoulderMidX + torsoWidth * 0.25f,
                shoulderMidY + torsoHeight * 0.25f
            ),
            // Right Lung
            "right_lung" to PointF(
                shoulderMidX - torsoWidth * 0.25f,
                shoulderMidY + torsoHeight * 0.25f
            ),
            // Stomach: center torso, below midpoint
            "stomach" to PointF(
                shoulderMidX,
                shoulderMidY + torsoHeight * 0.55f
            ),
            // Liver: right side of torso (camera-left)
            "liver" to PointF(
                shoulderMidX - torsoWidth * 0.2f,
                shoulderMidY + torsoHeight * 0.45f
            ),
            // Left Kidney
            "left_kidney" to PointF(
                shoulderMidX + torsoWidth * 0.2f,
                shoulderMidY + torsoHeight * 0.6f
            ),
            // Right Kidney
            "right_kidney" to PointF(
                shoulderMidX - torsoWidth * 0.2f,
                shoulderMidY + torsoHeight * 0.6f
            )
        )
    }

    fun close() {
        poseDetector.close()
    }
}
