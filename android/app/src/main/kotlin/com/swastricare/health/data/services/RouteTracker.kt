package com.swastricare.health.data.services

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.location.Location
import android.os.BatteryManager
import android.os.Looper
import com.google.android.gms.location.*
import com.swastricare.health.data.model.RoutePoint
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * GPS route tracking service using FusedLocationProviderClient.
 *
 * Collects GPS coordinates at regular intervals during an active workout,
 * exposes a live route via StateFlow, and computes total distance.
 *
 * Applies accuracy filtering, teleportation guards, and rolling-window
 * auto-pause detection for clean route data.
 */
// ─────────────────────────────────────
// MARK: - Battery-Aware GPS Mode
// ─────────────────────────────────────

enum class GpsMode(val label: String) {
    HIGH_ACCURACY("High Accuracy"),
    BALANCED("Balanced"),
    LOW_POWER("Low Power")
}

class RouteTracker(private val context: Context) {

    // ─────────────────────────────────────
    // MARK: - GPS Fix Quality
    // ─────────────────────────────────────

    enum class GpsStatus {
        OFF,        // Not tracking / no permission
        SEARCHING,  // Waiting for first fix
        POOR,       // Accuracy > 25m
        FAIR,       // Accuracy 15-25m
        GOOD        // Accuracy <= 15m
    }

    // ─────────────────────────────────────
    // MARK: - State
    // ─────────────────────────────────────

    private val fusedClient: FusedLocationProviderClient =
        LocationServices.getFusedLocationProviderClient(context)

    private val _routePoints = MutableStateFlow<List<RoutePoint>>(emptyList())
    val routePoints: StateFlow<List<RoutePoint>> = _routePoints.asStateFlow()

    private val _totalDistanceMeters = MutableStateFlow(0.0)
    val totalDistanceMeters: StateFlow<Double> = _totalDistanceMeters.asStateFlow()

    private val _gpsStatus = MutableStateFlow(GpsStatus.OFF)
    val gpsStatus: StateFlow<GpsStatus> = _gpsStatus.asStateFlow()

    private val _currentSpeed = MutableStateFlow(0f) // m/s (smoothed)
    val currentSpeed: StateFlow<Float> = _currentSpeed.asStateFlow()

    private val _currentLocation = MutableStateFlow<Pair<Double, Double>?>(null)
    val currentLocation: StateFlow<Pair<Double, Double>?> = _currentLocation.asStateFlow()

    private val _isAutopaused = MutableStateFlow(false)
    val isAutopaused: StateFlow<Boolean> = _isAutopaused.asStateFlow()

    private var isTracking = false
    private var isPaused = false
    var autoPauseEnabled: Boolean = true

    private val _gpsMode = MutableStateFlow(GpsMode.HIGH_ACCURACY)
    val gpsMode: StateFlow<GpsMode> = _gpsMode.asStateFlow()

    private var batteryCheckJob: Job? = null

    // Speed smoothing buffer (rolling average of last 5 samples)
    private val speedBuffer = ArrayDeque<Float>(5)
    private val SPEED_BUFFER_SIZE = 5

    // Auto-pause: rolling-window check.
    // If cumulative distance across accepted points in the last window is below
    // AUTO_PAUSE_MIN_METERS, the user is considered stationary. Exit auto-pause
    // as soon as a new accepted point adds >= AUTO_PAUSE_RESUME_METERS of motion.
    private val AUTO_PAUSE_WINDOW_MS = 20_000L
    private val AUTO_PAUSE_MIN_METERS = 10.0
    private val AUTO_PAUSE_RESUME_METERS = 5.0

    // Accuracy & teleportation thresholds
    private val MAX_ACCURACY_METERS = 50f           // matches iOS horizontalAccuracy <= 50m
    private val MAX_DISTANCE_PER_UPDATE_METERS = 80.0 // ~96 km/h max, prevents teleportation
    private val MIN_DISTANCE_METERS = 2.0           // ignore sub-2m jitter

    // ─────────────────────────────────────
    // MARK: - Location Callback
    // ─────────────────────────────────────

    private val locationCallback = object : LocationCallback() {
        override fun onLocationResult(result: LocationResult) {
            if (isPaused) return

            for (location in result.locations) {
                processLocation(location)
            }
        }
    }

    private fun processLocation(location: Location) {
        val accuracy = location.accuracy

        // Always update raw current location (for map centering before route is built)
        _currentLocation.value = Pair(location.latitude, location.longitude)

        // Update GPS quality with finer tiers
        _gpsStatus.value = when {
            accuracy <= 15f -> GpsStatus.GOOD
            accuracy <= 25f -> GpsStatus.FAIR
            else -> GpsStatus.POOR
        }

        // Reject points with poor accuracy — they produce jagged routes
        if (accuracy > MAX_ACCURACY_METERS) return

        val smoothedLat = location.latitude
        val smoothedLng = location.longitude

        val newPoint = RoutePoint(
            latitude = smoothedLat,
            longitude = smoothedLng,
            altitude = if (location.hasAltitude()) location.altitude else 0.0,
            speed = 0f, // will be set below
            timestamp = location.time
        )

        // Calculate actual distance from last accepted point
        val current = _routePoints.value
        val actualDistance = if (current.isNotEmpty()) {
            distanceBetween(current.last(), newPoint)
        } else 0.0

        // Compute speed from actual distance (more reliable than location.speed)
        val timeDelta = if (current.isNotEmpty()) {
            (location.time - current.last().timestamp).coerceAtLeast(1L) / 1000.0
        } else 1.0
        val computedSpeed = (actualDistance / timeDelta).toFloat()

        // Also consider GPS-reported speed, but prefer computed
        val rawGpsSpeed = if (location.hasSpeed()) location.speed else 0f
        // Use the lower of computed vs GPS speed to be conservative about movement
        val effectiveSpeed = minOf(computedSpeed, rawGpsSpeed.takeIf { it > 0f } ?: computedSpeed)

        // Smooth speed with rolling average
        if (speedBuffer.size >= SPEED_BUFFER_SIZE) speedBuffer.removeFirst()
        speedBuffer.addLast(effectiveSpeed)
        val smoothedSpeed = speedBuffer.average().toFloat()
        _currentSpeed.value = smoothedSpeed

        // Auto-pause: rolling-window distance check.
        // Walking at ~1 m/s produces ~1 m deltas per second, which a per-update
        // threshold would misread as stationary. Instead, look at cumulative
        // distance over the last AUTO_PAUSE_WINDOW_MS milliseconds: real walking
        // easily beats the window total, standing still does not.
        if (autoPauseEnabled) {
            if (_isAutopaused.value) {
                // Currently paused — resume as soon as we see real motion.
                if (actualDistance >= AUTO_PAUSE_RESUME_METERS) {
                    _isAutopaused.value = false
                } else {
                    // Stay paused; swallow this point so drifty GPS doesn't inflate distance.
                    return
                }
            } else if (current.isNotEmpty()) {
                val cutoff = location.time - AUTO_PAUSE_WINDOW_MS
                val windowPoints = current.filter { it.timestamp >= cutoff }
                if (windowPoints.size >= 2) {
                    val windowDistance = totalDistance(windowPoints)
                    if (windowDistance < AUTO_PAUSE_MIN_METERS) {
                        _isAutopaused.value = true
                        return
                    }
                }
            }
        } else if (_isAutopaused.value) {
            _isAutopaused.value = false
        }

        // Update the point with smoothed speed
        val finalPoint = newPoint.copy(speed = smoothedSpeed)

        if (current.isNotEmpty()) {
            // Teleportation guard: reject impossibly large jumps
            if (actualDistance > MAX_DISTANCE_PER_UPDATE_METERS) return

            // Jitter filter: ignore sub-threshold movement
            if (actualDistance < MIN_DISTANCE_METERS) return

            _totalDistanceMeters.value += actualDistance
        }

        _routePoints.value = current + finalPoint
    }

    // ─────────────────────────────────────
    // MARK: - Public Controls
    // ─────────────────────────────────────

    /**
     * Start collecting GPS locations. Requires location permission to be granted.
     */
    @SuppressLint("MissingPermission")
    fun startTracking() {
        if (isTracking) return
        isTracking = true
        isPaused = false
        _gpsStatus.value = GpsStatus.SEARCHING
        _routePoints.value = emptyList()
        _totalDistanceMeters.value = 0.0
        _isAutopaused.value = false
        speedBuffer.clear()

        updateGpsMode()

        fusedClient.requestLocationUpdates(
            buildLocationRequest(_gpsMode.value),
            locationCallback,
            Looper.getMainLooper()
        )

        // Check battery every 60s
        batteryCheckJob = CoroutineScope(Dispatchers.Main).launch {
            while (isTracking) {
                delay(60_000)
                updateGpsMode()
            }
        }
    }

    /**
     * Pause GPS collection (e.g. workout paused). Keeps accumulated data.
     */
    fun pauseTracking() {
        isPaused = true
    }

    /**
     * Resume GPS collection after a pause.
     */
    @SuppressLint("MissingPermission")
    fun resumeTracking() {
        if (!isTracking) {
            startTracking()
            return
        }
        isPaused = false
    }

    /**
     * Stop tracking entirely and clean up the location callback.
     */
    fun stopTracking() {
        isTracking = false
        isPaused = false
        _gpsStatus.value = GpsStatus.OFF
        _gpsMode.value = GpsMode.HIGH_ACCURACY
        _isAutopaused.value = false
        fusedClient.removeLocationUpdates(locationCallback)
        batteryCheckJob?.cancel()
    }

    /**
     * Return current route snapshot (useful when saving workout).
     */
    fun getRouteSnapshot(): List<RoutePoint> = _routePoints.value

    /**
     * Return total distance in kilometers.
     */
    fun getTotalDistanceKm(): Double = _totalDistanceMeters.value / 1000.0

    /**
     * Clear all route data.
     */
    fun reset() {
        _routePoints.value = emptyList()
        _totalDistanceMeters.value = 0.0
        _currentSpeed.value = 0f
        _currentLocation.value = null
        _gpsStatus.value = GpsStatus.OFF
        _isAutopaused.value = false
        speedBuffer.clear()
    }

    /**
     * Whether GPS updates are actively being requested. Callers can use this
     * to avoid double-calling [startTracking].
     */
    fun isCurrentlyTracking(): Boolean = isTracking

    /**
     * Reset accumulated route/distance/speed state WITHOUT stopping the GPS
     * flow. Used when the tracker was pre-warmed (e.g. GPS started while the
     * workout screen was idle) and the actual workout is now beginning — we
     * want to keep GPS locked on, but start distance measurement from zero.
     */
    fun clearRouteData() {
        _routePoints.value = emptyList()
        _totalDistanceMeters.value = 0.0
        _currentSpeed.value = 0f
        _isAutopaused.value = false
        speedBuffer.clear()
    }

    // ─────────────────────────────────────
    // MARK: - Battery-Aware GPS
    // ─────────────────────────────────────

    private fun getBatteryPercent(): Int {
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
        return batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            ?.takeIf { it in 0..100 } ?: 100
    }

    private fun updateGpsMode() {
        val battery = getBatteryPercent()
        val newMode = when {
            battery > 20 -> GpsMode.HIGH_ACCURACY
            battery > 10 -> GpsMode.BALANCED
            else -> GpsMode.LOW_POWER
        }
        if (newMode != _gpsMode.value) {
            _gpsMode.value = newMode
            applyGpsMode(newMode)
        }
    }

    @SuppressLint("MissingPermission")
    private fun applyGpsMode(mode: GpsMode) {
        if (!isTracking) return
        fusedClient.removeLocationUpdates(locationCallback)
        fusedClient.requestLocationUpdates(
            buildLocationRequest(mode),
            locationCallback,
            Looper.getMainLooper()
        )
    }

    private fun buildLocationRequest(mode: GpsMode): LocationRequest {
        return when (mode) {
            GpsMode.HIGH_ACCURACY -> LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 2_000L)
                .setMinUpdateIntervalMillis(1_000L)
                .setMinUpdateDistanceMeters(0f)
                .setWaitForAccurateLocation(false)
            GpsMode.BALANCED -> LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, 5_000L)
                .setMinUpdateIntervalMillis(3_000L)
                .setMinUpdateDistanceMeters(5f)
                .setWaitForAccurateLocation(false)
            GpsMode.LOW_POWER -> LocationRequest.Builder(Priority.PRIORITY_LOW_POWER, 10_000L)
                .setMinUpdateIntervalMillis(5_000L)
                .setMinUpdateDistanceMeters(10f)
                .setWaitForAccurateLocation(false)
        }.build()
    }

    // ─────────────────────────────────────
    // MARK: - Distance Calculation
    // ─────────────────────────────────────

    companion object {
        /**
         * Uses Android's Location.distanceBetween() for accurate Haversine distance.
         */
        fun distanceBetween(a: RoutePoint, b: RoutePoint): Double {
            val results = FloatArray(1)
            Location.distanceBetween(
                a.latitude, a.longitude,
                b.latitude, b.longitude,
                results
            )
            return results[0].toDouble()
        }

        /**
         * Calculate total distance for a list of route points.
         */
        fun totalDistance(points: List<RoutePoint>): Double {
            if (points.size < 2) return 0.0
            var total = 0.0
            for (i in 1 until points.size) {
                total += distanceBetween(points[i - 1], points[i])
            }
            return total
        }
    }
}
